//
//  AuthorizationConsentLoader.swift
//  TruoraValidationsSDK
//

import Foundation

// MARK: - Fetch Outcome

/// Everything the `enter_authorization` consent fetch produced, kept
/// language-agnostic: the raw responses carry every language, so hydration
/// applies the locale at read time and a locale change between prefetch and
/// step entry needs no refetch.
struct AuthorizationTermsFetchOutcome {
    /// The always-required basic terms fetch.
    let basic: TruoraNetworkResult<ConsentTermsResponse>
    /// The items (credit-bureau) terms fetch; `nil` when the process has no
    /// credit-bureau block and the fetch was skipped.
    let items: TruoraNetworkResult<ConsentTermsResponse>?
    /// Decoded step config; `nil` when absent or undecodable.
    let config: EnterAuthorizationConfig?
    /// The country resolved for the basic fetch's company params.
    let userCountry: String
    let hasFaceOrLiveness: Bool
    /// The `client_authorization` expected input's description, when non-empty.
    let customConsentText: String?

    /// Hydrates the outcome into the consent list for `languageCode`.
    ///
    /// A failed **required** fetch is a failure of the whole list: the basic and
    /// credit-bureau consents are legally binding copy with no local fallback,
    /// so rendering the screen without one of them is worse than surfacing the
    /// error and letting the host retry. Unparsed template copy (`{{.company}}`)
    /// is *not* a failure — the service answered 200 and the copy flows through
    /// verbatim.
    func consents(languageCode: String) -> TruoraNetworkResult<[AuthorizationConsent]> {
        let basicResponse: ConsentTermsResponse
        switch basic {
        case .success(let response):
            basicResponse = response
        case .failure(let error):
            return .failure(error)
        }

        var itemsResponse: ConsentTermsResponse?
        switch items {
        case .success(let response):
            itemsResponse = response
        case .failure(let error):
            return .failure(error)
        case nil:
            itemsResponse = nil
        }

        let basicText = AuthorizationHydration.basicText(
            response: basicResponse,
            userCountry: userCountry,
            languageCode: languageCode
        )
        let itemsText = itemsResponse.flatMap { response in
            AuthorizationHydration.itemsText(
                response: response,
                supportedCountries: config?.supportedCountries ?? [:],
                hasFaceOrLiveness: hasFaceOrLiveness,
                languageCode: languageCode
            )
        }

        return .success(AuthorizationHydration.buildConsents(
            basicText: basicText,
            itemsText: itemsText,
            customText: customConsentText
        ))
    }
}

// MARK: - Loader

/// Fetches the `enter_authorization` consent terms from the Account API.
///
/// Ports the web process-runner's `fetchConsentTerms`: the basic and items
/// fetches run **in parallel**, each retried on transient failures per
/// ``retryPolicy`` — three attempts with 1s/2s exponential backoff, the web's
/// exact schedule. The items fetch only fires when the process has a
/// credit-bureau block.
///
/// Unlike the web — which leaves its skeleton on screen indefinitely when the
/// fetches never resolve — the whole load is capped by ``loadDeadline``, because
/// `TruoraProcessManager.authorizationConsents(languageCode:)` is documented as
/// *being* the authorization screen's loading state.
struct AuthorizationConsentLoader {
    /// The web runner's consent-terms schedule: `maxAttempts = 3` with
    /// `exponentialBackoffDelay(attempt, 1000)` → waits of 1s then 2s.
    static let retryPolicy = TruoraRetryPolicy(maxRetries: 2, baseDelay: 1.0, multiplier: 2.0)

    /// Wall-clock ceiling on ``load(step:blockTypes:deviceCountry:)``.
    ///
    /// The retry budget alone bounds a load at roughly three transport timeouts
    /// plus 3s of backoff (~33s with ``ConsentTermsAPIClient/defaultSessionConfig``),
    /// which is far too long to hold a consent screen in a spinner. Exceeding this
    /// reports a retriable network failure so the host can offer a retry instead
    /// of waiting out the full budget.
    static let loadDeadline: TimeInterval = 12

    private let client: ConsentTermsAPIClient
    private let executor: TruoraProcessRequestExecutor
    private let deadline: TimeInterval

    /// - Parameter deadline: Overall ceiling on a load; see ``loadDeadline``.
    ///   Tests shorten it to trip the timeout without waiting.
    init(
        client: ConsentTermsAPIClient,
        executor: TruoraProcessRequestExecutor = TruoraProcessRequestExecutor(
            retryPolicy: AuthorizationConsentLoader.retryPolicy
        ),
        deadline: TimeInterval = AuthorizationConsentLoader.loadDeadline
    ) {
        self.client = client
        self.executor = executor
        self.deadline = deadline
    }

    /// Convenience wiring for production use: a ``ConsentTermsAPIClient`` with
    /// the (non-retrying) default transport, retried by this loader's executor.
    init(apiKey: String, baseUrl: String = ConsentTermsAPIClient.defaultBaseUrl) {
        self.init(client: ConsentTermsAPIClient(apiKey: apiKey, baseUrl: baseUrl))
    }

    /// Runs the consent-terms fetches for the given `enter_authorization` step.
    ///
    /// - Parameters:
    ///   - step: The process's `enter_authorization` step (config + expected inputs).
    ///   - blockTypes: The process's raw `identity_verification_names`.
    ///   - deviceCountry: The caller's geo-IP country
    ///     (``TruoraProcessResponse/geolocationIpCountry``) — what the web resolves
    ///     variants against via `deviceInfo.location.country`.
    /// - Throws: `CancellationError` only; every fetch failure — including the
    ///   ``loadDeadline`` expiring — is captured in the outcome's
    ///   ``TruoraNetworkResult`` fields.
    func load(
        step: TruoraStep,
        blockTypes: [String]?,
        deviceCountry: String?
    ) async throws -> AuthorizationTermsFetchOutcome {
        let context = LoadContext(step: step, blockTypes: blockTypes, deviceCountry: deviceCountry)

        let outcome = try await withDeadline {
            try await fetch(context: context, blockTypes: blockTypes)
        }

        guard let outcome else {
            return context.outcome(basic: .failure(.network(message: "Consent terms fetch timed out")), items: nil)
        }

        return outcome
    }

    // MARK: - Fetching

    private func fetch(
        context: LoadContext,
        blockTypes: [String]?
    ) async throws -> AuthorizationTermsFetchOutcome {
        let config = context.config
        let userCountry = context.userCountry

        async let basicFetch = executor.execute { [client] in
            try await client.fetchTerms(
                termsId: AuthorizationHydration.basicTermsId(config: config),
                queryItems: AuthorizationHydration.basicQueryItems(config: config, userCountry: userCountry)
            )
        }

        var items: TruoraNetworkResult<ConsentTermsResponse>?
        if AuthorizationHydration.hasCreditBureauBlock(blockTypes: blockTypes) {
            async let itemsFetch = executor.execute { [client] in
                try await client.fetchTerms(
                    termsId: AuthorizationHydration.itemsTermsId(config: config),
                    queryItems: AuthorizationHydration.itemsQueryItems(config: config)
                )
            }
            items = try await itemsFetch
        }

        return try await context.outcome(basic: basicFetch, items: items)
    }

    /// Races `operation` against ``deadline``, returning `nil` when the deadline
    /// wins.
    ///
    /// Cancellation of the surrounding task cancels the sleeper too, so its
    /// `CancellationError` propagates out rather than being mistaken for a
    /// timeout — the prefetch's cancelled-resolves-nil contract depends on that.
    private func withDeadline(
        _ operation: @escaping () async throws -> AuthorizationTermsFetchOutcome
    ) async throws -> AuthorizationTermsFetchOutcome? {
        try await withThrowingTaskGroup(of: AuthorizationTermsFetchOutcome?.self) { group in
            group.addTask { try await operation() }
            group.addTask { [deadline] in
                try await Task.sleep(nanoseconds: UInt64(deadline * 1_000_000_000))
                return nil
            }

            // `next()` yields `Outcome??`; one unwrap leaves the child's own
            // optional, where `nil` means the deadline child won the race.
            guard let first = try await group.next() else {
                return nil
            }
            group.cancelAll()

            return first
        }
    }
}

// MARK: - Load Context

/// The pure half of a load: everything resolvable from the step alone, hoisted
/// out of the fetch so a timed-out load can still report the config and country
/// it was resolving for.
private struct LoadContext {
    let config: EnterAuthorizationConfig?
    let userCountry: String
    let hasFaceOrLiveness: Bool
    let customConsentText: String?

    init(step: TruoraStep, blockTypes: [String]?, deviceCountry: String?) {
        let config = EnterAuthorizationConfig(configValues: step.config)
        self.config = config
        userCountry = AuthorizationHydration.resolveUserCountry(
            supportedCountries: config?.supportedCountries ?? [:],
            deviceCountry: deviceCountry
        )
        hasFaceOrLiveness = AuthorizationHydration.hasFaceOrLivenessValidation(blockTypes: blockTypes)
        customConsentText = AuthorizationHydration.customConsentText(expectedInputs: step.expectedInputs)
    }

    func outcome(
        basic: TruoraNetworkResult<ConsentTermsResponse>,
        items: TruoraNetworkResult<ConsentTermsResponse>?
    ) -> AuthorizationTermsFetchOutcome {
        AuthorizationTermsFetchOutcome(
            basic: basic,
            items: items,
            config: config,
            userCountry: userCountry,
            hasFaceOrLiveness: hasFaceOrLiveness,
            customConsentText: customConsentText
        )
    }
}
