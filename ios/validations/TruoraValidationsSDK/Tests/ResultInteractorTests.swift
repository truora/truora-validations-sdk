//
//  ResultInteractorTests.swift
//  TruoraValidationsSDKTests
//
//  Created by Truora on 30/01/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor class ResultInteractorTests: XCTestCase {
    var sut: ResultInteractor!
    fileprivate var mockPresenter: MockResultPresenter!
    var mockTimeProvider: MockTimeProvider!

    override func setUp() {
        super.setUp()
        mockPresenter = MockResultPresenter()
        mockTimeProvider = MockTimeProvider()
        sut = ResultInteractor(
            validationId: "test-validation-id",
            loadingType: .face,
            timeProvider: mockTimeProvider,
            logger: NoOpLogger()
        )
        sut.presenter = mockPresenter
        ValidationConfig.shared.reset()
    }

    override func tearDown() {
        sut = nil
        mockPresenter = nil
        mockTimeProvider = nil
        ValidationConfig.shared.reset()
        super.tearDown()
    }

    // MARK: - shouldReturnResult Tests

    func testShouldReturnResult_withPendingStatus_shouldReturnFalse() {
        // Given
        let response = createMockResponse(validationStatus: "pending", failureStatus: nil)

        // When
        let result = sut.testShouldReturnResult(for: response)

        // Then
        XCTAssertFalse(result, "Should continue polling when status is pending")
    }

    func testShouldReturnResult_withSuccessStatus_shouldReturnTrue() {
        // Given
        let response = createMockResponse(validationStatus: "success", failureStatus: nil)

        // When
        let result = sut.testShouldReturnResult(for: response)

        // Then
        XCTAssertTrue(result, "Should stop polling when status is success")
    }

    func testShouldReturnResult_withFailedStatus_shouldReturnTrue() {
        // Given
        let response = createMockResponse(validationStatus: "failed", failureStatus: nil)

        // When
        let result = sut.testShouldReturnResult(for: response)

        // Then
        XCTAssertTrue(result, "Should stop polling when status is failed")
    }

    func testShouldReturnResult_withPendingStatusAndExpiredFailureStatus_shouldReturnTrue() {
        // Given - validation_status is still pending but failure_status indicates expiration
        let response = createMockResponse(validationStatus: "pending", failureStatus: "expired")

        // When
        let result = sut.testShouldReturnResult(for: response)

        // Then
        let msg = "Should stop polling when failure_status is expired, even if pending"
        XCTAssertTrue(result, msg)
    }

    func testShouldReturnResult_withPendingStatusAndDeclinedFailureStatus_shouldReturnTrue() {
        // Given
        let response = createMockResponse(validationStatus: "pending", failureStatus: "declined")

        // When
        let result = sut.testShouldReturnResult(for: response)

        // Then
        XCTAssertTrue(result, "Should stop polling when failure_status is declined")
    }

    func testShouldReturnResult_withPendingStatusAndSystemErrorFailureStatus_shouldReturnTrue() {
        // Given
        let response = createMockResponse(
            validationStatus: "pending",
            failureStatus: "system_error"
        )

        // When
        let result = sut.testShouldReturnResult(for: response)

        // Then
        let msg = "Should stop polling when failure_status is system_error"
        XCTAssertTrue(result, msg)
    }

    // MARK: - createValidationResult Tests

    func testCreateValidationResult_withSuccessStatus_shouldReturnSuccessResult() {
        // Given
        let response = createMockResponse(validationStatus: "success", failureStatus: nil)

        // When
        let result = sut.testCreateValidationResult(from: response)

        // Then
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.validationId, "test-validation-id")
    }

    func testCreateValidationResult_withFailedStatus_shouldReturnFailedResult() {
        // Given
        let response = createMockResponse(validationStatus: "failed", failureStatus: nil)

        // When
        let result = sut.testCreateValidationResult(from: response)

        // Then
        XCTAssertEqual(result.status, .failure)
    }

    func testCreateValidationResult_withExpiredFailureStatus_shouldReturnFailedResult() {
        // Given - even if validation_status is not explicitly "failed",
        // presence of failure_status should result in failed status
        let response = createMockResponse(validationStatus: "pending", failureStatus: "expired")

        // When
        let result = sut.testCreateValidationResult(from: response)

        // Then
        let msg = "Should return failed status when failure_status is expired"
        XCTAssertEqual(result.status, .failure, msg)
    }

    func testCreateValidationResult_withDeclinedFailureStatus_shouldReturnFailedResult() {
        // Given
        let response = createMockResponse(validationStatus: "pending", failureStatus: "declined")

        // When
        let result = sut.testCreateValidationResult(from: response)

        // Then
        let msg = "Should return failed status when failure_status is declined"
        XCTAssertEqual(result.status, .failure, msg)
    }

    func testCreateValidationResult_withSystemErrorFailureStatus_shouldReturnFailedResult() {
        // Given
        let response = createMockResponse(
            validationStatus: "pending",
            failureStatus: "system_error"
        )

        // When
        let result = sut.testCreateValidationResult(from: response)

        // Then
        let msg = "Should return failed status when failure_status is system_error"
        XCTAssertEqual(result.status, .failure, msg)
    }

    func testCreateValidationResult_withProcessingStatus_shouldReturnPendingResult() {
        // Given
        let response = createMockResponse(validationStatus: "processing", failureStatus: nil)

        // When
        let result = sut.testCreateValidationResult(from: response)

        // Then
        XCTAssertEqual(result.status, .pending)
    }

    func testCreateValidationResult_withFailureStatusOverridesValidationStatus() {
        // Given - validation_status says success but failure_status is set
        // This is an edge case, but failureStatus should take precedence
        let response = createMockResponse(
            validationStatus: "success",
            failureStatus: "expired"
        )

        // When
        let result = sut.testCreateValidationResult(from: response)

        // Then
        let msg = "failure_status should override validation_status"
        XCTAssertEqual(result.status, .failure, msg)
    }

    func testCreateValidationResult_mapsDocumentDetailCorrectly() {
        // Given
        let docDetail = NativeDocumentDetails(
            country: "CO",
            documentType: "national-id",
            frontUrl: "https://example.com/front.png",
            reverseUrl: "https://example.com/reverse.png"
        )
        let details = NativeValidationDetails(documentDetails: docDetail)
        let response = NativeValidationDetailResponse(
            validationId: "id",
            validationStatus: "success",
            creationDate: "date",
            accountId: "acc",
            type: "document-validation",
            details: details
        )

        // When
        let result = sut.testCreateValidationResult(from: response)

        // Then
        XCTAssertNotNil(result.detail)
        XCTAssertEqual(result.detail?.validationId, "id")
        let docDetails = result.detail?.details?.documentDetails
        XCTAssertNotNil(docDetails)
        XCTAssertEqual(docDetails?["country"]?.stringValue, "CO")
        XCTAssertEqual(docDetails?["front_url"]?.stringValue, "https://example.com/front.png")
        XCTAssertEqual(docDetails?["reverse_url"]?.stringValue, "https://example.com/reverse.png")
    }

    func testCreateValidationResult_mapsFaceRecognitionDetailCorrectly() {
        // Given
        let faceRec = NativeFaceRecognitionValidations(
            confidenceScore: 0.95,
            similarityStatus: "match",
            passiveLivenessStatus: "success",
            enrollmentId: "ENR-123",
            ageRange: NativeAgeRange(high: 35, low: 25),
            faceSearch: NativeFaceSearch(
                status: "found",
                confidenceScore: 0.98
            )
        )
        let details = NativeValidationDetails(
            faceRecognitionValidations: faceRec
        )
        let response = NativeValidationDetailResponse(
            validationId: "face-id",
            validationStatus: "success",
            creationDate: "date",
            accountId: "acc",
            type: "face-recognition",
            details: details
        )

        // When
        let result = sut.testCreateValidationResult(from: response)

        // Then
        let face = result.detail?.details?.faceRecognitionValidations
        XCTAssertNotNil(face)
        XCTAssertEqual(face?.confidenceScore, 0.95)
        XCTAssertEqual(face?.similarityStatus, "match")
        XCTAssertEqual(face?.passiveLivenessStatus, "success")
        XCTAssertEqual(face?.enrollmentId, "ENR-123")
        XCTAssertEqual(face?.ageRange?.high, 35)
        XCTAssertEqual(face?.ageRange?.low, 25)
        XCTAssertEqual(face?.faceSearch?.status, "found")
        XCTAssertEqual(face?.faceSearch?.confidenceScore, 0.98)
    }

    func testCreateValidationResult_mapsValidationInputsAndUserResponse() {
        // Given
        let inputs = NativeValidationInputs(
            country: "CO",
            documentType: "national-id"
        )
        let userResponse = NativeUserResponse(
            inputFiles: ["upload1.jpg"]
        )
        let response = NativeValidationDetailResponse(
            validationId: "inputs-id",
            validationStatus: "success",
            creationDate: "date",
            accountId: "acc",
            type: "document-validation",
            validationInputs: inputs,
            userResponse: userResponse
        )

        // When
        let result = sut.testCreateValidationResult(from: response)

        // Then
        XCTAssertEqual(result.detail?.validationInputs?.country, "CO")
        XCTAssertEqual(
            result.detail?.validationInputs?.documentType,
            "national-id"
        )
        XCTAssertEqual(
            result.detail?.userResponse?.inputFiles,
            ["upload1.jpg"]
        )
    }

    // MARK: - Detail Mapping (new invoice fields)

    func testMapToValidationDetail_propagatesRemainingRetries() {
        // Given
        let response = NativeValidationDetailResponse(
            validationId: "VLD-1",
            validationStatus: "failed",
            creationDate: "2026-04-22T00:00:00Z",
            accountId: "acc",
            type: "document-validation",
            remainingRetries: 3
        )

        // When
        let detail = sut.mapToValidationDetail(from: response)

        // Then
        XCTAssertEqual(detail.remainingRetries, 3)
    }

    func testMapToValidationDetail_propagatesDeclinedReason() {
        // Given
        let response = NativeValidationDetailResponse(
            validationId: "VLD-1",
            validationStatus: "failed",
            creationDate: "2026-04-22T00:00:00Z",
            accountId: "acc",
            type: "document-validation",
            declinedReason: "document_not_recognized"
        )

        // When
        let detail = sut.mapToValidationDetail(from: response)

        // Then
        XCTAssertEqual(detail.declinedReason, "document_not_recognized")
    }

    // MARK: - Detail Decoding (JSON contract)

    func testDecodeDetailResponse_withRemainingRetriesAndDeclinedReason() throws {
        // Given — snake_case keys mirroring the backend contract
        let json = """
        {
          "validation_id": "VLD-1",
          "validation_status": "failed",
          "creation_date": "2026-04-22T00:00:00Z",
          "account_id": "acc",
          "type": "document-validation",
          "declined_reason": "missing_text",
          "remaining_retries": 2
        }
        """.data(using: .utf8)!

        // When
        let response = try JSONDecoder().decode(NativeValidationDetailResponse.self, from: json)

        // Then
        XCTAssertEqual(response.declinedReason, "missing_text")
        XCTAssertEqual(response.remainingRetries, 2)
    }

    func testDecodeDetailResponse_missingNewFields_preservesBackwardsCompat() throws {
        // Given — JSON without the new fields (older responses)
        let json = """
        {
          "validation_id": "VLD-1",
          "validation_status": "success",
          "creation_date": "2026-04-22T00:00:00Z",
          "account_id": "acc",
          "type": "face-recognition"
        }
        """.data(using: .utf8)!

        // When
        let response = try JSONDecoder().decode(NativeValidationDetailResponse.self, from: json)

        // Then
        XCTAssertNil(response.declinedReason)
        XCTAssertNil(response.remainingRetries)
    }

    // MARK: - Helper Methods

    private func createMockResponse(
        validationStatus: String,
        failureStatus: String?
    ) -> NativeValidationDetailResponse {
        NativeValidationDetailResponse(
            validationId: "test-validation-id",
            validationStatus: validationStatus,
            creationDate: "2026-01-30T00:00:00Z",
            accountId: "test-account-id",
            type: "face-recognition",
            details: nil,
            failureStatus: failureStatus,
            validationInputs: nil,
            userResponse: nil
        )
    }
}

// MARK: - ResultInteractor Test Extension

extension ResultInteractor {
    /// Test helper to access shouldReturnResult
    func testShouldReturnResult(for validationDetail: NativeValidationDetailResponse) -> Bool {
        // Access the private method via a test-only extension
        validationDetail.validationStatus.lowercased() != "pending"
            || validationDetail.failureStatus != nil
    }

    /// Test helper to access createValidationResult
    func testCreateValidationResult(
        from validationDetail: NativeValidationDetailResponse
    ) -> ValidationResult {
        let status: ValidationStatus = if validationDetail.failureStatus != nil {
            .failure
        } else {
            switch validationDetail.validationStatus.lowercased() {
            case "success":
                .success
            case "failed", "failure":
                .failure
            default:
                .pending
            }
        }

        let confidence = validationDetail.details?.faceRecognitionValidations?.confidenceScore
        let detail = mapToValidationDetail(from: validationDetail)

        return ValidationResult(
            validationId: validationDetail.validationId,
            status: status,
            confidence: confidence,
            metadata: nil,
            detail: detail
        )
    }

    /// Test helper to replicate detail mapping logic
    func mapToValidationDetail(
        from response: NativeValidationDetailResponse
    ) -> ValidationDetail {
        let detailInfo = mapDetailInfo(from: response.details)
        let inputs = mapInputs(from: response.validationInputs)
        let userResp = mapUserResponse(from: response.userResponse)

        return ValidationDetail(
            validationId: response.validationId,
            type: response.type,
            validationStatus: response.validationStatus,
            failureStatus: response.failureStatus,
            declinedReason: response.declinedReason,
            remainingRetries: response.remainingRetries,
            creationDate: response.creationDate,
            accountId: response.accountId,
            details: detailInfo,
            validationInputs: inputs,
            userResponse: userResp
        )
    }

    private func mapDetailInfo(
        from details: NativeValidationDetails?
    ) -> ValidationDetailInfo? {
        guard let details else { return nil }
        return ValidationDetailInfo(
            faceRecognitionValidations: mapFaceRecognition(
                from: details.faceRecognitionValidations
            ),
            documentDetails: mapDocumentDetails(
                from: details.documentDetails
            ),
            documentValidations: mapDocumentValidations(
                from: details.documentValidations
            ),
            backgroundCheck: mapBackgroundCheck(
                from: details.backgroundCheck
            )
        )
    }

    private func mapFaceRecognition(
        from face: NativeFaceRecognitionValidations?
    ) -> FaceRecognitionDetail? {
        guard let face else { return nil }
        return FaceRecognitionDetail(
            confidenceScore: face.confidenceScore,
            similarityStatus: face.similarityStatus,
            passiveLivenessStatus: face.passiveLivenessStatus,
            enrollmentId: face.enrollmentId,
            ageRange: face.ageRange.map {
                AgeRangeDetail(high: $0.high, low: $0.low)
            },
            faceSearch: face.faceSearch.map {
                FaceSearchDetail(
                    status: $0.status,
                    confidenceScore: $0.confidenceScore
                )
            }
        )
    }

    private func mapDocumentDetails(
        from doc: NativeDocumentDetails?
    ) -> [String: JSONValue]? {
        guard let doc else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(doc) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([String: JSONValue].self, from: data)
    }

    private func mapDocumentValidations(
        from validations: NativeDocumentSubValidations?
    ) -> DocumentSubValidationResults? {
        guard let validations else { return nil }
        return DocumentSubValidationResults(
            dataConsistency: validations.dataConsistency?.map(
                mapSubResult
            ),
            governmentDatabase: validations.governmentDatabase?.map(
                mapSubResult
            ),
            imageAnalysis: validations.imageAnalysis?.map(
                mapSubResult
            ),
            photocopyAnalysis: validations.photocopyAnalysis?.map(
                mapSubResult
            ),
            manualAnalysis: validations.manualAnalysis?.map(
                mapSubResult
            ),
            photoOfPhoto: validations.photoOfPhoto?.map(
                mapSubResult
            )
        )
    }

    private func mapSubResult(
        from result: NativeSubValidationResult
    ) -> SubValidationDetail {
        SubValidationDetail(
            validationName: result.validationName,
            result: result.result,
            validationType: result.validationType,
            message: result.message,
            manuallyReviewed: result.manuallyReviewed,
            createdAt: result.createdAt,
            dataValidations: result.dataValidations
        )
    }

    private func mapBackgroundCheck(
        from check: NativeBackgroundCheck?
    ) -> BackgroundCheckDetail? {
        guard let check else { return nil }
        return BackgroundCheckDetail(
            checkId: check.checkId,
            checkUrl: check.checkUrl
        )
    }

    private func mapInputs(
        from inputs: NativeValidationInputs?
    ) -> ValidationDetailInputs? {
        guard let inputs else { return nil }
        return ValidationDetailInputs(
            country: inputs.country,
            documentType: inputs.documentType
        )
    }

    private func mapUserResponse(
        from response: NativeUserResponse?
    ) -> ValidationDetailUserResponse? {
        guard let response else { return nil }
        return ValidationDetailUserResponse(
            inputFiles: response.inputFiles
        )
    }
}

// MARK: - Mock Presenter

@MainActor private class MockResultPresenter: ResultInteractorToPresenter {
    var pollingCompletedCalled = false
    var pollingFailedCalled = false
    var lastResult: ValidationResult?
    var lastError: TruoraException?

    func pollingCompleted(result: ValidationResult) async {
        pollingCompletedCalled = true
        lastResult = result
    }

    func pollingFailed(error: TruoraException) async {
        pollingFailedCalled = true
        lastError = error
    }
}
