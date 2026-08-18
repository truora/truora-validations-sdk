//
//  MediaUpload.swift
//  TruoraValidationsSDK
//

import Foundation

// MARK: - Step Media

/// Bytes captured for one of a step's `files_upload_urls` entries.
struct StepMedia: Equatable {
    let data: Data
    /// Sent as `Content-Type` on the presigned `PUT`.
    let contentType: String
}

// MARK: - Media Upload Error

/// Why captured media could not be delivered to its presigned URL.
enum MediaUploadError: Error, Equatable {
    /// S3 rejected the signature: the URL is spent or expired.
    ///
    /// Terminal. Re-reading the process does not mint a fresh upload URL for the
    /// SDK's step set — the backend only regenerates them for `enter_response`
    /// steps created via the web client.
    case signedUrlRejected(code: String)

    /// The upload URL points somewhere other than Truora's file host.
    case untrustedHost(url: String)

    /// The step expects media under `name` that the screen did not capture.
    case missingMedia(name: String)

    /// The `PUT` failed for any other reason.
    case uploadFailed(TruoraProcessAPIError)

    /// Error codes S3 returns for a presigned URL that is spent or expired.
    /// Mirrors `SIGNED_URL_EXPIRY_CODES` in the web runner's `upload_retry.ts`.
    static let signedUrlExpiryCodes: Set<String> = ["AccessDenied", "SignatureDoesNotMatch"]

    /// Classifies a failed `PUT`.
    ///
    /// A consumed presigned URL arrives as `403 AccessDenied`, which is otherwise
    /// indistinguishable from any other forbidden response — the code only exists
    /// in the XML body.
    static func from(_ error: TruoraProcessAPIError) -> MediaUploadError {
        switch error {
        case .serverError(_, let body), .unauthorized(let body):
            if let code = signedUrlExpiryCode(in: body) {
                return .signedUrlRejected(code: code)
            }

            return .uploadFailed(error)

        default:
            return .uploadFailed(error)
        }
    }

    /// Extracts `<Code>…</Code>` from an S3 XML error body when it names a
    /// signed-URL expiry, otherwise `nil`.
    static func signedUrlExpiryCode(in body: String?) -> String? {
        guard let code = s3ErrorCode(in: body), signedUrlExpiryCodes.contains(code) else {
            return nil
        }

        return code
    }

    /// Extracts `<Code>…</Code>` from an S3 XML error body.
    static func s3ErrorCode(in body: String?) -> String? {
        guard let body, let open = body.range(of: "<Code>"),
              let close = body.range(of: "</Code>", range: open.upperBound ..< body.endIndex) else {
            return nil
        }

        let code = body[open.upperBound ..< close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)

        return code.isEmpty ? nil : code
    }
}

// MARK: - Upload Outcome

/// How a failed `PUT` should be treated. Mirrors `classifyUploadError` +
/// `isRetryableOutcome` in the web runner's `upload_retry.ts`.
enum UploadOutcome: Equatable {
    /// The signed URL is spent or expired. Asking again cannot help.
    case signedUrlRejected(code: String)

    /// A network abort or a 5xx from S3/CloudFront — worth another attempt.
    case retryable

    /// A 4xx, or a request the SDK built wrong. Never retried.
    case fatal
}

// MARK: - Media Uploader

/// Uploads captured media to the presigned URLs a step carries.
///
/// Owns the retry policy for presigned `PUT`s, ported from `upload_retry.ts`:
/// three attempts, backing off 250ms then 1s with ±25% jitter, retrying only
/// transient failures. A 4xx is never retried — including the `AccessDenied` /
/// `SignatureDoesNotMatch` a consumed presigned URL produces.
///
/// This is the *only* retry layer on the upload path: ``TruoraProcessAPIClient`` defaults to
/// a non-retrying transport, and `uploadFile` is not wrapped in
/// ``TruoraProcessRequestExecutor``. Reintroducing either would multiply the attempts and
/// re-send the whole capture each time.
struct MediaUploader {
    /// `MAX_UPLOAD_ATTEMPTS`.
    static let maxAttempts = 3

    /// Delay before each retry, in seconds — one entry per retry, so
    /// ``maxAttempts`` = 3 (two retries) means two delays: 0.25s then 1s.
    static let retryDelays: [TimeInterval] = [0.25, 1]

    /// `JITTER_RATIO`.
    static let jitterRatio = 0.25

    private let apiClient: TruoraProcessAPIClient
    private let sleep: (TimeInterval) async throws -> Void
    /// Jitter source, in `0..<1`. Injectable so tests get a deterministic schedule.
    private let random: () -> Double

    init(
        apiClient: TruoraProcessAPIClient,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        },
        random: @escaping () -> Double = { Double.random(in: 0 ..< 1) }
    ) {
        self.apiClient = apiClient
        self.sleep = sleep
        self.random = random
    }

    /// Uploads every entry of `filesUploadUrls`, pulling its bytes from `media` by
    /// the entry's `name`.
    func uploadAll(for step: TruoraStep, media: [String: StepMedia]) async throws {
        for file in step.filesUploadUrls ?? [] {
            // The presigned URL comes from the backend, but the SDK still refuses to
            // ship user media to an arbitrary host (the runner's `validateFileURL`).
            guard UploadUrlValidator.isTruoraFilesUploadUrl(file.url) else {
                throw MediaUploadError.untrustedHost(url: file.url)
            }

            guard let bytes = media[file.name] else {
                throw MediaUploadError.missingMedia(name: file.name)
            }

            try await upload(file, media: bytes)
        }
    }

    /// `PUT`s `media` to `file`'s presigned URL, retrying transient failures.
    func upload(_ file: TruoraFileUpload, media: StepMedia) async throws {
        var attempt = 1

        while true {
            try Task.checkCancellation()

            do {
                try await apiClient.uploadFile(
                    uploadUrl: file.url,
                    fileData: media.data,
                    contentType: media.contentType
                )
                return
            } catch let error as TruoraProcessAPIError {
                switch Self.classify(error) {
                case .signedUrlRejected(let code):
                    throw MediaUploadError.signedUrlRejected(code: code)

                case .fatal:
                    throw MediaUploadError.uploadFailed(error)

                case .retryable:
                    guard attempt < Self.maxAttempts else {
                        throw MediaUploadError.uploadFailed(error)
                    }
                }

                attempt += 1
                try await sleep(Self.delay(forAttempt: attempt, random: random))
            }
        }
    }

    // MARK: - Classification

    /// Classifies a failed `PUT`.
    ///
    /// The signed-URL check runs before the status check: S3 reports a spent URL
    /// as `403 AccessDenied`, and that must never be mistaken for a transient
    /// permission blip.
    static func classify(_ error: TruoraProcessAPIError) -> UploadOutcome {
        if case .signedUrlRejected(let code) = MediaUploadError.from(error) {
            return .signedUrlRejected(code: code)
        }

        switch error {
        case .serverError(let statusCode, _):
            // Mirrors `isRetryableOutcome` in the web runner's `upload_retry.ts`:
            // only 5xx (s3 / cloudfront) is retryable. Every 4xx — including 408 and
            // 429 — is fatal: an expired signed URL, a malformed body, or an auth
            // failure will not fix itself on a re-PUT of the same capture.
            return (500 ..< 600).contains(statusCode) ? .retryable : .fatal

        // No response reached the server: DNS, TLS, connection reset, offline.
        case .uploadFailed, .networkError:
            return .retryable

        case .unauthorized, .invalidURL, .emptyUploadUrl, .emptyFileData,
             .encodingError, .decodingError, .invalidResponse,
             .emptyProcessId, .emptyStepId:
            return .fatal
        }
    }

    // MARK: - Backoff

    /// Delay to wait *before* the given 1-based `attempt`. The first attempt does
    /// not wait; later ones walk ``retryDelays``, clamped to its last slot.
    static func delay(forAttempt attempt: Int, random: () -> Double) -> TimeInterval {
        guard attempt > 1 else {
            return 0
        }

        let slot = min(attempt - 2, retryDelays.count - 1)

        return jitter(retryDelays[slot], random: random)
    }

    /// Spreads `base` by ±``jitterRatio`` so retries do not stampede.
    static func jitter(_ base: TimeInterval, random: () -> Double) -> TimeInterval {
        let offset = (random() * 2 - 1) * base * jitterRatio

        return max(0, base + offset)
    }
}
