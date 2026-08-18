//
//  AuthorizationConsentLoaderTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

// MARK: - Consent terms routing stub

/// Routes consent-terms requests by `{terms_id}` (the URL's last path component)
/// to canned responses, recording every URL so tests can assert the per-call
/// company params.
private final class ConsentTermsRoutingStub: URLProtocol {
    /// `URLProtocol` callbacks arrive on arbitrary threads and the loader fires the
    /// basic and items requests concurrently, so every touch of this shared state
    /// goes through `lock`. Requests torn down by a cancelled prefetch can also
    /// land after the test that issued them finished, which is why `park` is
    /// fulfilled at most once per reset rather than once per request.
    private static let lock = NSLock()
    private nonisolated(unsafe) static var storedResponses: [String: (body: String, status: Int)] = [:]
    private nonisolated(unsafe) static var recordedURLs: [URL] = []
    private nonisolated(unsafe) static var parkExpectation: XCTestExpectation?
    private nonisolated(unsafe) static var parkFulfilled = false

    static var responses: [String: (body: String, status: Int)] {
        get { withLock { storedResponses } }
        set { withLock { storedResponses = newValue } }
    }

    static var requestedURLs: [URL] {
        withLock { recordedURLs }
    }

    /// When set, requests are recorded but never answered (the URL-loading system
    /// delivers the cancellation when the surrounding task is cancelled).
    static var park: XCTestExpectation? {
        get { withLock { parkExpectation } }
        set {
            withLock {
                parkExpectation = newValue
                parkFulfilled = false
            }
        }
    }

    static func reset() {
        withLock {
            storedResponses = [:]
            recordedURLs = []
            parkExpectation = nil
            parkFulfilled = false
        }
    }

    private static func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    /// Records the request and resolves how to answer it, atomically.
    /// - Returns: whether to leave the request hanging, and the expectation to
    ///   fulfill — non-nil only for the first parked request.
    private static func record(_ url: URL) -> (isParked: Bool, fulfill: XCTestExpectation?) {
        withLock {
            recordedURLs.append(url)

            guard let parkExpectation else {
                return (false, nil)
            }
            guard !parkFulfilled else {
                return (true, nil)
            }

            parkFulfilled = true
            return (true, parkExpectation)
        }
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let handling = Self.record(url)
        handling.fulfill?.fulfill()

        if handling.isParked {
            return // Never answer; cancellation tears the request down.
        }

        guard let stub = Self.responses[url.lastPathComponent],
              let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Fixtures

private let basicTermsBody = """
{
    "terms_id": "DPCTbasic",
    "terms": {
        "ALL": {"es": "Texto general", "en": "General text"},
        "CO": {"es": "Texto CO", "en": "CO text"}
    }
}
"""

private let itemsTermsBody = """
{
    "terms_id": "DPCTitems",
    "terms": {
        "ALL-credit_bureau": {"es": "Texto centrales", "en": "Credit bureau text"},
        "CO-face_search": {"es": "Texto biométrico CO", "en": "CO face text"}
    }
}
"""

// MARK: - Loader Tests

final class AuthorizationConsentLoaderTests: XCTestCase {
    override func tearDown() {
        ConsentTermsRoutingStub.reset()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeLoader() -> AuthorizationConsentLoader {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ConsentTermsRoutingStub.self]
        let client = ConsentTermsAPIClient(
            apiKey: "test-process-token",
            sessionConfig: .noRetry,
            session: URLSession(configuration: config)
        )
        return AuthorizationConsentLoader(
            client: client,
            executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in })
        )
    }

    private func authorizationStep(
        config: TruoraBlockConfigValues? = [
            "supported_countries": .object([
                "CO": .object(["name": .string("Acme"), "nit": .string("900123")]),
                "MX": .object(["name": .string("Acme MX")])
            ]),
            "custom_inputs": .object([
                "default-basic": .string("DPCTbasic"),
                "default-items": .string("DPCTitems")
            ])
        ],
        expectedInputs: [TruoraInput]? = nil
    ) -> TruoraStep {
        TruoraStep(stepId: "STP1", type: .enterAuthorization, config: config, expectedInputs: expectedInputs)
    }

    private func requestedURL(containing termsId: String) -> URL? {
        ConsentTermsRoutingStub.requestedURLs.first { $0.lastPathComponent == termsId }
    }

    // MARK: - Fetch fan-out

    func testLoadFetchesOnlyBasicWithoutCreditBureauBlock() async throws {
        ConsentTermsRoutingStub.responses = ["DPCTbasic": (basicTermsBody, 200)]

        let outcome = try await makeLoader().load(
            step: authorizationStep(),
            blockTypes: ["document_verification"],
            deviceCountry: "CO"
        )

        XCTAssertEqual(ConsentTermsRoutingStub.requestedURLs.count, 1)
        XCTAssertEqual(
            requestedURL(containing: "DPCTbasic")?.absoluteString,
            "https://api.account.truora.com/v1/consent-terms/DPCTbasic?CO.name=Acme&CO.nit=900123&terms=true"
        )
        XCTAssertNil(outcome.items, "No credit-bureau block means no items fetch")
        XCTAssertTrue(outcome.basic.isSuccess)
        XCTAssertEqual(outcome.userCountry, "CO")
    }

    func testLoadFetchesItemsWithEveryCountryWhenCreditBureauPresent() async throws {
        ConsentTermsRoutingStub.responses = [
            "DPCTbasic": (basicTermsBody, 200),
            "DPCTitems": (itemsTermsBody, 200)
        ]

        let outcome = try await makeLoader().load(
            step: authorizationStep(),
            blockTypes: ["credit_bureau_verification"],
            deviceCountry: "CO"
        )

        XCTAssertEqual(ConsentTermsRoutingStub.requestedURLs.count, 2)
        // Basic: the resolved country's params only. Items: every supported
        // country's params, in sorted key order.
        XCTAssertEqual(
            requestedURL(containing: "DPCTitems")?.absoluteString,
            "https://api.account.truora.com/v1/consent-terms/DPCTitems?CO.name=Acme&CO.nit=900123&MX.name=Acme%20MX&terms=true"
        )
        XCTAssertNotNil(outcome.items)
        XCTAssertEqual(outcome.items?.isSuccess, true)
    }

    func testLoadFallsBackToLiteralAliasesWithoutConfig() async throws {
        ConsentTermsRoutingStub.responses = ["default-basic": (basicTermsBody, 200)]

        let outcome = try await makeLoader().load(
            step: authorizationStep(config: nil),
            blockTypes: nil,
            deviceCountry: nil
        )

        // No config: no company params — the service answers 200 with raw
        // templates, which is still a success.
        XCTAssertEqual(
            requestedURL(containing: "default-basic")?.absoluteString,
            "https://api.account.truora.com/v1/consent-terms/default-basic?terms=true"
        )
        XCTAssertNil(outcome.config)
        XCTAssertEqual(outcome.userCountry, "ALL")
    }

    func testLoadExtractsCustomConsentAndFaceDetection() async throws {
        ConsentTermsRoutingStub.responses = ["DPCTbasic": (basicTermsBody, 200)]

        let outcome = try await makeLoader().load(
            step: authorizationStep(expectedInputs: [
                TruoraInput(type: "checkbox", name: "client_authorization", description: "Custom copy")
            ]),
            blockTypes: ["document_verification_with_face_recognition"],
            deviceCountry: "CO"
        )

        XCTAssertEqual(outcome.customConsentText, "Custom copy")
        XCTAssertTrue(outcome.hasFaceOrLiveness)
    }

    // MARK: - Retry policy contract

    /// The web runner's schedule: three attempts with 1s / 2s exponential backoff.
    func testRetryPolicyMatchesWebSchedule() {
        let policy = AuthorizationConsentLoader.retryPolicy

        XCTAssertEqual(policy.maxRetries, 2, "Two retries after the initial attempt = three attempts")
        XCTAssertEqual(policy.delay(forAttempt: 0), 1.0)
        XCTAssertEqual(policy.delay(forAttempt: 1), 2.0)
    }

    // MARK: - Hydration from the outcome

    func testConsentsHydrateWithLanguageFallback() async throws {
        ConsentTermsRoutingStub.responses = [
            "DPCTbasic": (basicTermsBody, 200),
            "DPCTitems": (itemsTermsBody, 200)
        ]

        let outcome = try await makeLoader().load(
            step: authorizationStep(expectedInputs: [
                TruoraInput(type: "checkbox", name: "client_authorization", description: "Custom copy")
            ]),
            blockTypes: ["credit_bureau_verification", "face_recognition"],
            deviceCountry: "CO"
        )

        // es-MX falls back to the base "es" texts.
        guard case .success(let consents) = outcome.consents(languageCode: "es-MX") else {
            return XCTFail("Expected hydrated consents")
        }

        XCTAssertEqual(consents.map(\.id), ["basic", "items", "custom"])
        XCTAssertEqual(consents[0].text, "Texto CO")
        // The web's literal `<br><br>` separator lands as a paragraph break.
        XCTAssertEqual(consents[1].text, "Texto biométrico CO\n\nTexto centrales")
        XCTAssertEqual(consents[2].text, "Custom copy")
        XCTAssertTrue(consents.allSatisfy(\.required))
    }

    // MARK: - Deadline

    func testLoadTimesOutIntoARetriableFailure() async throws {
        // Parked requests are never answered, so only the deadline can end the load.
        let parked = expectation(description: "consent fetch reached the wire")
        ConsentTermsRoutingStub.park = parked
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ConsentTermsRoutingStub.self]
        let loader = AuthorizationConsentLoader(
            client: ConsentTermsAPIClient(
                apiKey: "test-process-token",
                sessionConfig: .noRetry,
                session: URLSession(configuration: config)
            ),
            executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in }),
            deadline: 0.2
        )

        let outcome = try await loader.load(
            step: authorizationStep(),
            blockTypes: nil,
            deviceCountry: "CO"
        )
        await fulfillment(of: [parked], timeout: 2)

        // The step-derived half of the outcome survives a timeout.
        XCTAssertEqual(outcome.userCountry, "CO")
        XCTAssertEqual(outcome.basic.error?.kind, .network)
        XCTAssertEqual(outcome.basic.error?.isRetriable, true, "The host must be able to offer a retry")

        guard case .failure = outcome.consents(languageCode: "es") else {
            return XCTFail("A timed-out load has no legally-binding copy to render")
        }
    }

    func testDeadlineMatchesTheDocumentedCeiling() {
        XCTAssertEqual(AuthorizationConsentLoader.loadDeadline, 12)
        XCTAssertEqual(ConsentTermsAPIClient.defaultSessionConfig.maxRetries, 0, "The loader owns the retries")
        XCTAssertLessThanOrEqual(
            ConsentTermsAPIClient.defaultSessionConfig.timeoutIntervalForResource,
            AuthorizationConsentLoader.loadDeadline,
            "A single attempt must not be able to outlive the whole load"
        )
    }

    func testConsentsFailWhenBasicFetchFailed() async throws {
        ConsentTermsRoutingStub.responses = [
            "DPCTbasic": (#"{"message": "boom"}"#, 500),
            "DPCTitems": (itemsTermsBody, 200)
        ]

        let outcome = try await makeLoader().load(
            step: authorizationStep(),
            blockTypes: ["credit_bureau_verification"],
            deviceCountry: "CO"
        )

        guard case .failure = outcome.consents(languageCode: "es") else {
            return XCTFail("A failed basic fetch must fail the consent list — the copy is legally binding")
        }
    }

    func testConsentsFailWhenItemsFetchFailed() async throws {
        ConsentTermsRoutingStub.responses = [
            "DPCTbasic": (basicTermsBody, 200),
            "DPCTitems": (#"{"message": "boom"}"#, 500)
        ]

        let outcome = try await makeLoader().load(
            step: authorizationStep(),
            blockTypes: ["credit_bureau_verification"],
            deviceCountry: "CO"
        )

        guard case .failure = outcome.consents(languageCode: "es") else {
            return XCTFail("A failed items fetch must fail the consent list — the consent is required")
        }
    }

    func testConsentsSucceedWithUnsubstitutedTemplates() async throws {
        ConsentTermsRoutingStub.responses = [
            "default-basic": (#"{"terms": {"ALL": {"es": "Autorizo a {{.company}} el tratamiento."}}}"#, 200)
        ]

        let outcome = try await makeLoader().load(
            step: authorizationStep(config: nil),
            blockTypes: nil,
            deviceCountry: nil
        )

        guard case .success(let consents) = outcome.consents(languageCode: "es") else {
            return XCTFail("Unsubstituted templates are a 200 — not an error")
        }
        XCTAssertEqual(consents.first?.text, "Autorizo a {{.company}} el tratamiento.")
    }
}

// MARK: - Manager integration

/// Create-or-read responder for the manager's DI API session (separate protocol
/// class from the consent stub so each session only sees its own traffic).
private final class ConsentPrefetchProcessStub: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var storedBody = "{}"

    /// Read from `startLoading()` on arbitrary threads; see `ConsentTermsRoutingStub`.
    static var body: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedBody
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storedBody = newValue
        }
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let url = request.url,
           let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class TruoraProcessManagerConsentPrefetchTests: XCTestCase {
    override func tearDown() {
        ConsentTermsRoutingStub.reset()
        super.tearDown()
    }

    private let authorizationProcessBody = """
    {
        "process_id": "IPR1",
        "status": "pending",
        "country": "co",
        "identity_verification_names": ["credit_bureau_verification", "face_recognition"],
        "current_step": 0,
        "steps": [{
            "step_id": "STP1",
            "type": "enter_authorization",
            "config": {
                "supported_countries": {
                    "CO": {"name": "Acme", "nit": "900123"},
                    "MX": {"name": "Acme MX"}
                },
                "custom_inputs": {
                    "default-basic": "DPCTbasic",
                    "default-items": "DPCTitems"
                }
            },
            "expected_inputs": [
                {"type": "checkbox", "name": "authorization"},
                {"type": "checkbox", "name": "client_authorization", "description": "Custom copy"}
            ]
        }]
    }
    """

    private func makeManager(processBody: String, withLoader: Bool = true) -> TruoraProcessManager {
        ConsentPrefetchProcessStub.body = processBody
        let processConfig = URLSessionConfiguration.ephemeral
        processConfig.protocolClasses = [ConsentPrefetchProcessStub.self]
        let client = TruoraProcessAPIClient(
            apiKey: "test-key",
            sessionConfig: .noRetry,
            session: URLSession(configuration: processConfig)
        )

        var loader: AuthorizationConsentLoader?
        if withLoader {
            let consentConfig = URLSessionConfiguration.ephemeral
            consentConfig.protocolClasses = [ConsentTermsRoutingStub.self]
            loader = AuthorizationConsentLoader(
                client: ConsentTermsAPIClient(
                    apiKey: "test-key",
                    sessionConfig: .noRetry,
                    session: URLSession(configuration: consentConfig)
                ),
                executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in })
            )
        }

        return TruoraProcessManager(
            apiClient: client,
            executor: TruoraProcessRequestExecutor(retryPolicy: .none, sleep: { _ in }),
            consentLoader: loader
        )
    }

    func testPrefetchStartsOnCreateOrReadAndHydratesConsents() async {
        ConsentTermsRoutingStub.responses = [
            "DPCTbasic": (basicTermsBody, 200),
            "DPCTitems": (itemsTermsBody, 200)
        ]
        let manager = makeManager(processBody: authorizationProcessBody)

        await manager.start()
        await manager.awaitCurrentRun()

        guard case .success(let consents) = await manager.authorizationConsents(languageCode: "es") else {
            return XCTFail("Expected hydrated consents")
        }
        XCTAssertEqual(consents.map(\.id), ["basic", "items", "custom"])
        // No `geolocation_ip_country` on this process, so the lowercase `country`
        // fallback resolves the CO variant + CO params.
        XCTAssertEqual(consents[0].text, "Texto CO")
        XCTAssertEqual(consents[1].text, "Texto biométrico CO\n\nTexto centrales")
        XCTAssertEqual(consents[2].text, "Custom copy")
        XCTAssertEqual(ConsentTermsRoutingStub.requestedURLs.count, 2, "Both fetches fired at process load")
    }

    /// The web resolves the consent variant against the geo-IP country, not the
    /// process's own `country`, so `geolocation_ip_country` has to win.
    func testPrefetchPrefersGeolocationIPCountryOverProcessCountry() async {
        ConsentTermsRoutingStub.responses = [
            "DPCTbasic": (basicTermsBody, 200),
            "DPCTitems": (itemsTermsBody, 200)
        ]
        let body = authorizationProcessBody.replacingOccurrences(
            of: #""country": "co","#,
            with: #""country": "co", "geolocation_ip_country": "MX","#
        )
        let manager = makeManager(processBody: body)

        await manager.start()
        await manager.awaitCurrentRun()

        guard case .success(let consents) = await manager.authorizationConsents(languageCode: "es") else {
            return XCTFail("Expected hydrated consents")
        }
        // MX has no basic variant of its own, so it falls back to "ALL" — the point
        // is that it did *not* resolve CO.
        XCTAssertEqual(consents[0].text, "Texto general")
        XCTAssertEqual(
            ConsentTermsRoutingStub.requestedURLs.first { $0.lastPathComponent == "DPCTbasic" }?.absoluteString,
            "https://api.account.truora.com/v1/consent-terms/DPCTbasic?MX.name=Acme%20MX&terms=true",
            "The basic fetch carries the geo-IP country's company params"
        )
    }

    func testAuthorizationConsentsFailureWhenBasicFetchFails() async {
        ConsentTermsRoutingStub.responses = [
            "DPCTbasic": (#"{"message": "boom"}"#, 500),
            "DPCTitems": (itemsTermsBody, 200)
        ]
        let manager = makeManager(processBody: authorizationProcessBody)

        await manager.start()
        await manager.awaitCurrentRun()

        guard case .failure = await manager.authorizationConsents(languageCode: "es") else {
            return XCTFail("Expected a failure after the basic fetch failed")
        }
    }

    func testAuthorizationConsentsNilWithoutEnterAuthorizationStep() async {
        let manager = makeManager(
            processBody: #"{"process_id": "IPR1", "status": "pending", "steps": [{"step_id": "S1", "type": "enter_response"}]}"#
        )

        await manager.start()
        await manager.awaitCurrentRun()

        let consents = await manager.authorizationConsents(languageCode: "es")
        XCTAssertNil(consents, "No enter_authorization step means nothing to prefetch")
        XCTAssertTrue(ConsentTermsRoutingStub.requestedURLs.isEmpty)
    }

    func testAuthorizationConsentsNilWithoutLoader() async {
        let manager = makeManager(processBody: authorizationProcessBody, withLoader: false)

        await manager.start()
        await manager.awaitCurrentRun()

        let consents = await manager.authorizationConsents(languageCode: "es")
        XCTAssertNil(consents)
    }

    func testCancelCancelsThePrefetch() async {
        let parked = expectation(description: "consent fetch reached the wire")
        ConsentTermsRoutingStub.park = parked
        let manager = makeManager(processBody: authorizationProcessBody)

        await manager.start()
        await manager.awaitCurrentRun()
        await fulfillment(of: [parked], timeout: 2)

        await manager.cancel()

        let consents = await manager.authorizationConsents(languageCode: "es")
        XCTAssertNil(consents, "A cancelled prefetch reports nothing")
    }
}
