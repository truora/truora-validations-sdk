//
//  MediaUploadTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

final class MediaUploadTests: XCTestCase {
    /// The body S3 returns when a presigned URL has already been consumed.
    private let accessDeniedXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Error><Code>AccessDenied</Code><Message>Request has expired</Message></Error>
    """

    override func setUp() {
        super.setUp()
        MediaUploadURLStub.reset()
    }

    override func tearDown() {
        MediaUploadURLStub.reset()
        super.tearDown()
    }

    // MARK: - s3ErrorCode

    func testS3ErrorCodeExtractsCodeFromXMLBody() {
        XCTAssertEqual(MediaUploadError.s3ErrorCode(in: accessDeniedXML), "AccessDenied")
    }

    func testS3ErrorCodeReturnsNilForNonXMLBody() {
        XCTAssertNil(MediaUploadError.s3ErrorCode(in: #"{"message": "nope"}"#))
        XCTAssertNil(MediaUploadError.s3ErrorCode(in: nil))
        XCTAssertNil(MediaUploadError.s3ErrorCode(in: "<Code></Code>"))
    }

    /// Only the two codes that mean "this signature is spent" count.
    func testSignedUrlExpiryCodeIgnoresOtherS3Codes() {
        XCTAssertNil(MediaUploadError.signedUrlExpiryCode(in: "<Error><Code>NoSuchBucket</Code></Error>"))
        XCTAssertEqual(MediaUploadError.signedUrlExpiryCode(in: accessDeniedXML), "AccessDenied")
    }

    // MARK: - from(TruoraProcessAPIError)

    /// A spent presigned URL arrives as `403 AccessDenied`. Without reading the XML
    /// body it is indistinguishable from any other forbidden response.
    func testClassifiesAccessDeniedAsSignedUrlRejected() {
        let error = TruoraProcessAPIError.serverError(statusCode: 403, body: accessDeniedXML)

        XCTAssertEqual(MediaUploadError.from(error), .signedUrlRejected(code: "AccessDenied"))
    }

    func testClassifiesSignatureDoesNotMatchAsSignedUrlRejected() {
        let error = TruoraProcessAPIError.serverError(statusCode: 403, body: "<Error><Code>SignatureDoesNotMatch</Code></Error>")

        XCTAssertEqual(MediaUploadError.from(error), .signedUrlRejected(code: "SignatureDoesNotMatch"))
    }

    func testClassifiesUnauthorizedCarryingTheCodeAsSignedUrlRejected() {
        let error = TruoraProcessAPIError.unauthorized(body: accessDeniedXML)

        XCTAssertEqual(MediaUploadError.from(error), .signedUrlRejected(code: "AccessDenied"))
    }

    func testClassifiesEverythingElseAsUploadFailed() {
        XCTAssertEqual(
            MediaUploadError.from(.serverError(statusCode: 500, body: nil)),
            .uploadFailed(.serverError(statusCode: 500, body: nil))
        )
        XCTAssertEqual(
            MediaUploadError.from(.serverError(statusCode: 404, body: nil)),
            .uploadFailed(.serverError(statusCode: 404, body: nil))
        )
        XCTAssertEqual(MediaUploadError.from(.emptyUploadUrl), .uploadFailed(.emptyUploadUrl))
        XCTAssertEqual(MediaUploadError.from(.invalidURL), .uploadFailed(.invalidURL))
    }

    /// A 5xx whose body happens to name a spent signature is still a spent
    /// signature — retrying it would burn the whole capture again for nothing.
    func testSignedUrlRejectionIsDetectedRegardlessOfStatus() {
        let error = TruoraProcessAPIError.serverError(statusCode: 500, body: accessDeniedXML)

        XCTAssertEqual(MediaUploadError.from(error), .signedUrlRejected(code: "AccessDenied"))
    }

    // MARK: - ProcessError mapping

    func testSignedUrlRejectionSurfacesTheCodeToTheRunner() {
        let error = ProcessError.from(MediaUploadError.signedUrlRejected(code: "AccessDenied"))

        XCTAssertEqual(error, .mediaUploadFailed(reason: "Upload URL rejected by storage (AccessDenied)"))
    }

    // MARK: - classify

    func testClassifiesServerErrorsAsRetryable() {
        XCTAssertEqual(MediaUploader.classify(.serverError(statusCode: 500, body: nil)), .retryable)
        XCTAssertEqual(MediaUploader.classify(.serverError(statusCode: 503, body: nil)), .retryable)
    }

    /// The runner treats every 4xx as terminal, including 408 and 429.
    func testClassifiesAllClientErrorsAsFatal() {
        XCTAssertEqual(MediaUploader.classify(.serverError(statusCode: 400, body: nil)), .fatal)
        XCTAssertEqual(MediaUploader.classify(.serverError(statusCode: 408, body: nil)), .fatal)
        XCTAssertEqual(MediaUploader.classify(.serverError(statusCode: 429, body: nil)), .fatal)
        XCTAssertEqual(MediaUploader.classify(.unauthorized(body: nil)), .fatal)
    }

    func testClassifiesNetworkAbortsAsRetryable() {
        let underlying = URLError(.networkConnectionLost)

        XCTAssertEqual(MediaUploader.classify(.uploadFailed(underlying)), .retryable)
        XCTAssertEqual(MediaUploader.classify(.networkError(underlying)), .retryable)
    }

    func testClassifiesInputValidationAsFatal() {
        XCTAssertEqual(MediaUploader.classify(.emptyUploadUrl), .fatal)
        XCTAssertEqual(MediaUploader.classify(.emptyFileData), .fatal)
        XCTAssertEqual(MediaUploader.classify(.invalidURL), .fatal)
    }

    /// A 5xx whose body names a spent signature short-circuits the status check.
    func testSignedUrlRejectionBeatsStatusClassification() {
        XCTAssertEqual(
            MediaUploader.classify(.serverError(statusCode: 500, body: accessDeniedXML)),
            .signedUrlRejected(code: "AccessDenied")
        )
    }

    // MARK: - backoff

    /// The effective upload schedule is 250ms then 1s (attempt 1 does not wait).
    /// With no jitter the schedule is exact.
    func testDelayScheduleMatchesTheRunner() {
        let noJitter = { 0.5 } // midpoint of 0..<1 -> zero offset

        XCTAssertEqual(MediaUploader.delay(forAttempt: 1, random: noJitter), 0)
        XCTAssertEqual(MediaUploader.delay(forAttempt: 2, random: noJitter), 0.25)
        XCTAssertEqual(MediaUploader.delay(forAttempt: 3, random: noJitter), 1)
    }

    /// Attempt counts past the schedule (unreachable at ``maxAttempts`` = 3, but
    /// guarded anyway) clamp to the last slot rather than reading out of bounds.
    func testDelayClampsToTheLastSlot() {
        let noJitter = { 0.5 }

        XCTAssertEqual(MediaUploader.delay(forAttempt: 4, random: noJitter), 1)
        XCTAssertEqual(MediaUploader.delay(forAttempt: 9, random: noJitter), 1)
    }

    func testJitterStaysWithinTwentyFivePercent() {
        XCTAssertEqual(MediaUploader.jitter(1, random: { 0 }), 0.75, accuracy: 0.0001)
        XCTAssertEqual(MediaUploader.jitter(1, random: { 1 }), 1.25, accuracy: 0.0001)
        XCTAssertEqual(MediaUploader.jitter(1, random: { 0.5 }), 1, accuracy: 0.0001)
    }

    func testJitterNeverGoesNegative() {
        XCTAssertGreaterThanOrEqual(MediaUploader.jitter(0, random: { 0 }), 0)
    }

    // MARK: - upload

    private func makeUploader(status: Int, body: String = "", delays: DelayRecorder) -> MediaUploader {
        MediaUploadURLStub.stub = (Data(body.utf8), status)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MediaUploadURLStub.self]
        let session = URLSession(configuration: config)
        // No explicit sessionConfig: this exercises the client's default, which must
        // not retry underneath the uploader.
        let client = TruoraProcessAPIClient(apiKey: "test-key", session: session)

        return MediaUploader(apiClient: client, sleep: { await delays.record($0) }, random: { 0.5 })
    }

    private let file = TruoraFileUpload(name: "document_front", url: "https://files.truora.com/upload/abc")
    private let media = StepMedia(data: Data("jpeg".utf8), contentType: "image/jpeg")

    func testUploadSucceedsWithoutRetrying() async throws {
        let delays = DelayRecorder()
        let uploader = makeUploader(status: 200, delays: delays)

        try await uploader.upload(file, media: media)

        let recorded = await delays.values
        XCTAssertTrue(recorded.isEmpty)
        XCTAssertEqual(MediaUploadURLStub.requestCount, 1)
    }

    /// Three attempts total, waiting 250ms then 1s in between — and exactly three
    /// `PUT`s, proving `TruoraProcessAPIClient`'s transport did not retry underneath.
    func testUploadRetriesServerErrorsExactlyToTheAttemptBudget() async {
        let delays = DelayRecorder()
        let uploader = makeUploader(status: 503, delays: delays)

        do {
            try await uploader.upload(file, media: media)
            XCTFail("Expected uploadFailed")
        } catch let error as MediaUploadError {
            guard case .uploadFailed = error else {
                return XCTFail("Expected uploadFailed, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        let recorded = await delays.values
        XCTAssertEqual(recorded, [0.25, 1])
        XCTAssertEqual(MediaUploadURLStub.requestCount, 3, "One retry layer only: 3 PUTs, not 12")
    }

    /// A spent signed URL is terminal on the first attempt — no retries burned.
    func testUploadDoesNotRetrySignedUrlRejection() async {
        let delays = DelayRecorder()
        let uploader = makeUploader(status: 403, body: accessDeniedXML, delays: delays)

        do {
            try await uploader.upload(file, media: media)
            XCTFail("Expected signedUrlRejected")
        } catch let error as MediaUploadError {
            XCTAssertEqual(error, .signedUrlRejected(code: "AccessDenied"))
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        let recorded = await delays.values
        XCTAssertTrue(recorded.isEmpty)
        XCTAssertEqual(MediaUploadURLStub.requestCount, 1)
    }

    func testUploadDoesNotRetryOtherClientErrors() async {
        let delays = DelayRecorder()
        let uploader = makeUploader(status: 400, delays: delays)

        do {
            try await uploader.upload(file, media: media)
            XCTFail("Expected uploadFailed")
        } catch let error as MediaUploadError {
            guard case .uploadFailed = error else {
                return XCTFail("Expected uploadFailed, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        XCTAssertEqual(MediaUploadURLStub.requestCount, 1)
    }

    // MARK: - uploadAll

    func testUploadAllRejectsAnUntrustedHost() async {
        let delays = DelayRecorder()
        let uploader = makeUploader(status: 200, delays: delays)
        let evil = TruoraFileUpload(name: "document_front", url: "https://evil.example.com/upload")
        let step = TruoraStep(stepId: "STP1", type: .takeDocumentPhoto, filesUploadUrls: [evil])

        do {
            try await uploader.uploadAll(for: step, media: ["document_front": media])
            XCTFail("Expected untrustedHost")
        } catch let error as MediaUploadError {
            XCTAssertEqual(error, .untrustedHost(url: "https://evil.example.com/upload"))
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        XCTAssertEqual(MediaUploadURLStub.requestCount, 0, "User media never leaves the device")
    }

    func testUploadAllFailsWhenAStepFileHasNoCapturedMedia() async {
        let delays = DelayRecorder()
        let uploader = makeUploader(status: 200, delays: delays)
        let step = TruoraStep(stepId: "STP1", type: .takeDocumentPhoto, filesUploadUrls: [file])

        do {
            try await uploader.uploadAll(for: step, media: [:])
            XCTFail("Expected missingMedia")
        } catch let error as MediaUploadError {
            XCTAssertEqual(error, .missingMedia(name: "document_front"))
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testUploadAllIsANoopWhenTheStepHasNoFiles() async throws {
        let delays = DelayRecorder()
        let uploader = makeUploader(status: 500, delays: delays)
        let step = TruoraStep(stepId: "STP1", type: .enterDocumentType)

        try await uploader.uploadAll(for: step, media: [:])

        XCTAssertEqual(MediaUploadURLStub.requestCount, 0)
    }
}

// MARK: - Helpers

/// Records the retry schedule instead of waiting it out.
private actor DelayRecorder {
    private(set) var values: [TimeInterval] = []

    func record(_ delay: TimeInterval) {
        values.append(delay)
    }
}

/// Serves a canned response to every presigned `PUT` and counts them.
private final class MediaUploadURLStub: URLProtocol {
    nonisolated(unsafe) static var stub: (Data, Int) = (Data(), 200)
    nonisolated(unsafe) static var requestCount = 0

    static func reset() {
        stub = (Data(), 200)
        requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        // Counted here, not in `canInit`, which the loader may consult more than
        // once per request.
        Self.requestCount += 1

        let (data, status) = Self.stub
        let response = HTTPURLResponse(
            url: request.url ?? URL(fileURLWithPath: "/"),
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )

        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
