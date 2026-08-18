//
//  TruoraProcessModelsTests.swift
//  SDKTests
//
//  Created by Truora on 26/05/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class TruoraProcessModelsTests: XCTestCase {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - TruoraProcessResponse

    func testProcessResponseDecodesMinimalJSON() throws {
        let json = """
        {
            "process_id": "IPR000000000001",
            "status": "pending",
            "process_type": "dynamic"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try decoder.decode(TruoraProcessResponse.self, from: data)

        XCTAssertEqual(response.processId, "IPR000000000001")
        XCTAssertEqual(response.status, .pending)
        XCTAssertEqual(response.processType, .dynamic)
        XCTAssertNil(response.steps)
        XCTAssertNil(response.identityBlocks)
    }

    func testProcessResponseDecodesFullJSON() throws {
        let json = """
        {
            "process_id": "IPR000000000001",
            "status": "success",
            "process_type": "dynamic",
            "current_step_id": "STP001",
            "current_step_type": "enter_authorization",
            "failure_status": "declined",
            "declined_reason": "document_expired",
            "country": "CO",
            "label": "test-label",
            "time_to_live": 3600,
            "identity_verification_names": ["document_verification", "face_recognition"],
            "verifications": {
                "document_verification": "success",
                "face_recognition": "pending"
            },
            "identity_verifications": [
                {
                    "verification_id": "VRF001",
                    "name": "document_verification",
                    "steps": []
                }
            ],
            "steps": [
                {
                    "step_id": "STP001",
                    "type": "enter_authorization"
                }
            ],
            "risk_evaluation": {
                "risk_evaluation_id": "REV001",
                "risk_evaluation_status": "success",
                "risk_evaluation_result": "not_risky",
                "source": "identity_process"
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try decoder.decode(TruoraProcessResponse.self, from: data)

        XCTAssertEqual(response.status, .success)
        XCTAssertEqual(response.currentStepId, "STP001")
        XCTAssertEqual(response.currentStepType, .enterAuthorization)
        XCTAssertEqual(response.failureStatus, .declined)
        XCTAssertEqual(response.declinedReason, "document_expired")
        XCTAssertEqual(response.country, "CO")
        XCTAssertEqual(response.label, "test-label")
        XCTAssertEqual(response.timeToLive, 3600)
        XCTAssertEqual(response.identityBlockTypes, ["document_verification", "face_recognition"])
        XCTAssertEqual(response.blocks?["document_verification"], .success)
        XCTAssertEqual(response.blocks?["face_recognition"], .pending)
        XCTAssertEqual(response.identityBlocks?.count, 1)
        XCTAssertEqual(response.identityBlocks?.first?.blockId, "VRF001")
        XCTAssertEqual(response.steps?.count, 1)
        XCTAssertEqual(response.riskEvaluation?.riskEvaluationId, "REV001")
        XCTAssertEqual(response.riskEvaluation?.riskEvaluationStatus, .success)
        XCTAssertEqual(response.riskEvaluation?.riskEvaluationResult, .notRisky)
        XCTAssertEqual(response.riskEvaluation?.source, .identityProcess)
    }

    /// `geolocation_ip_country` is a distinct field from `country` — it is the
    /// geo-IP signal consent-terms variants resolve against.
    func testProcessResponseDecodesGeolocationIPCountrySeparatelyFromCountry() throws {
        let json = #"{"process_id": "IPR001", "country": "CO", "geolocation_ip_country": "MX"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let response = try decoder.decode(TruoraProcessResponse.self, from: data)

        XCTAssertEqual(response.country, "CO")
        XCTAssertEqual(response.geolocationIpCountry, "MX")
    }

    func testProcessResponseGeolocationIPCountryIsNilWhenAbsent() throws {
        let json = #"{"process_id": "IPR001", "country": "CO"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let response = try decoder.decode(TruoraProcessResponse.self, from: data)

        XCTAssertNil(response.geolocationIpCountry, "Callers fall back to `country` when the backend omits it")
    }

    func testProcessResponseRoundtrip() throws {
        let original = TruoraProcessResponse(
            processId: "IPR000000000001",
            status: .pending,
            processType: .dynamic,
            country: "CO",
            label: "sdk-test"
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TruoraProcessResponse.self, from: data)

        XCTAssertEqual(decoded.processId, original.processId)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.processType, original.processType)
        XCTAssertEqual(decoded.country, original.country)
        XCTAssertEqual(decoded.label, original.label)
    }

    // MARK: - TruoraStep

    func testStepDecoding() throws {
        let json = """
        {
            "step_id": "STP001",
            "process_id": "IPR001",
            "verification_id": "VRF001",
            "verification_type": "document_verification",
            "type": "take_document_photo",
            "title": "Take a photo of your document",
            "description": "Please capture the front of your ID",
            "is_process_first_step": false,
            "is_process_final_step": false,
            "remaining_retries": 3,
            "async_step": false,
            "expected_inputs": [
                {
                    "type": "file",
                    "name": "document_front"
                }
            ],
            "files_upload_urls": [
                {
                    "name": "document_front",
                    "url": "https://upload.example.com/presigned"
                }
            ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let step = try decoder.decode(TruoraStep.self, from: data)

        XCTAssertEqual(step.stepId, "STP001")
        XCTAssertEqual(step.processId, "IPR001")
        XCTAssertEqual(step.blockId, "VRF001")
        XCTAssertEqual(step.blockType, .documentVerification)
        XCTAssertEqual(step.type, .takeDocumentPhoto)
        XCTAssertEqual(step.title, "Take a photo of your document")
        XCTAssertEqual(step.isProcessFirstStep, false)
        XCTAssertEqual(step.isProcessFinalStep, false)
        XCTAssertEqual(step.remainingRetries, 3)
        XCTAssertEqual(step.asyncStep, false)
        XCTAssertEqual(step.expectedInputs?.count, 1)
        XCTAssertEqual(step.expectedInputs?.first?.name, "document_front")
        XCTAssertEqual(step.filesUploadUrls?.count, 1)
        XCTAssertEqual(step.filesUploadUrls?.first?.url, "https://upload.example.com/presigned")
    }

    func testStepRoundtrip() throws {
        let original = TruoraStep(
            stepId: "STP001",
            processId: "IPR001",
            type: .enterAuthorization,
            remainingRetries: 2,
            asyncStep: false
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TruoraStep.self, from: data)

        XCTAssertEqual(decoded.stepId, original.stepId)
        XCTAssertEqual(decoded.processId, original.processId)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.remainingRetries, original.remainingRetries)
    }

    // MARK: - TruoraCurrentStepData

    func testCurrentStepDataDecoding() throws {
        let json = """
        {
            "type": "take_document_photo",
            "async_step": false,
            "description": "Capture front side",
            "retry_status": "available",
            "retry_reason": "blurry_image",
            "expected_inputs": [
                {
                    "type": "file",
                    "name": "front_photo"
                }
            ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let stepData = try decoder.decode(TruoraCurrentStepData.self, from: data)

        XCTAssertEqual(stepData.type, "take_document_photo")
        XCTAssertEqual(stepData.asyncStep, false)
        XCTAssertEqual(stepData.description, "Capture front side")
        XCTAssertEqual(stepData.retryStatus, .available)
        XCTAssertEqual(stepData.retryReason, "blurry_image")
        XCTAssertEqual(stepData.expectedInputs?.count, 1)
    }

    // MARK: - TruoraInput

    func testInputDecoding() throws {
        let json = """
        {
            "type": "select",
            "name": "document_type",
            "options": ["national-id", "passport", "foreign-id"],
            "optional": false,
            "read_only": false,
            "file_upload_url": "https://upload.example.com/file"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let input = try decoder.decode(TruoraInput.self, from: data)

        XCTAssertEqual(input.type, "select")
        XCTAssertEqual(input.name, "document_type")
        XCTAssertEqual(input.options, ["national-id", "passport", "foreign-id"])
        XCTAssertEqual(input.optional, false)
        XCTAssertEqual(input.readOnly, false)
        XCTAssertEqual(input.fileUploadUrl, "https://upload.example.com/file")
    }

    func testInputRoundtrip() throws {
        let original = TruoraInput(
            type: "text",
            name: "authorized",
            value: "true"
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TruoraInput.self, from: data)

        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.value, original.value)
    }

    // MARK: - TruoraFileUpload

    func testFileUploadDecoding() throws {
        let json = """
        {
            "name": "document_front",
            "url": "https://upload.example.com/presigned-url",
            "description": "Front of document",
            "media_type": "image/jpeg"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let upload = try decoder.decode(TruoraFileUpload.self, from: data)

        XCTAssertEqual(upload.name, "document_front")
        XCTAssertEqual(upload.url, "https://upload.example.com/presigned-url")
        XCTAssertEqual(upload.description, "Front of document")
        XCTAssertEqual(upload.mediaType, "image/jpeg")
    }

    // MARK: - TruoraIdentityBlock

    func testIdentityBlockDecoding() throws {
        let json = """
        {
            "verification_id": "VRF000000000001",
            "name": "document_verification",
            "config": {
                "country": "CO",
                "document_type": "national-id"
            },
            "steps": [
                {
                    "step_id": "STP001",
                    "type": "enter_document_type"
                },
                {
                    "step_id": "STP002",
                    "type": "take_document_photo"
                }
            ],
            "if": ["has_document == true"]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let block = try decoder.decode(TruoraIdentityBlock.self, from: data)

        XCTAssertEqual(block.blockId, "VRF000000000001")
        XCTAssertEqual(block.type, .documentVerification)
        XCTAssertEqual(block.config?["country"]?.stringValue, "CO")
        XCTAssertEqual(block.config?["document_type"]?.stringValue, "national-id")
        XCTAssertEqual(block.steps?.count, 2)
        XCTAssertEqual(block.steps?.first?.type, .enterDocumentType)
        XCTAssertEqual(block.logic, ["has_document == true"])
    }

    func testIdentityBlockRoundtrip() throws {
        let original = TruoraIdentityBlock(
            blockId: "VRF001",
            type: .faceRecognition,
            steps: [
                TruoraStep(stepId: "STP001", type: .recordFaceVideoLiveness)
            ],
            logic: ["always"]
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TruoraIdentityBlock.self, from: data)

        XCTAssertEqual(decoded.blockId, original.blockId)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.steps?.count, 1)
        XCTAssertEqual(decoded.steps?.first?.type, .recordFaceVideoLiveness)
        XCTAssertEqual(decoded.logic, ["always"])
    }

    // MARK: - Enum Decoding

    func testBlockStatusDecoding() throws {
        let json = """
        {"status": "success"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        struct Wrapper: Codable { let status: TruoraBlockStatus }
        let wrapper = try decoder.decode(Wrapper.self, from: data)
        XCTAssertEqual(wrapper.status, .success)
    }

    func testFailureStatusDecoding() throws {
        let json = """
        {"failure_status": "system_error"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        struct Wrapper: Codable {
            let failureStatus: TruoraFailureStatus
            enum CodingKeys: String, CodingKey { case failureStatus = "failure_status" }
        }
        let wrapper = try decoder.decode(Wrapper.self, from: data)
        XCTAssertEqual(wrapper.failureStatus, .systemError)
    }

    // MARK: - TruoraStepType

    func testStepTypeKnownValues() {
        XCTAssertEqual(TruoraStepType(stepType: "enter_authorization"), .enterAuthorization)
        XCTAssertEqual(TruoraStepType(stepType: "enter_document_type"), .enterDocumentType)
        XCTAssertEqual(TruoraStepType(stepType: "take_document_photo"), .takeDocumentPhoto)
        XCTAssertEqual(TruoraStepType(stepType: "record_face_video_liveness"), .recordFaceVideoLiveness)
        XCTAssertEqual(TruoraStepType(stepType: "record_face_photo_liveness"), .recordFacePhotoLiveness)
        XCTAssertEqual(TruoraStepType(stepType: "record_face_video"), .recordFaceVideo)
        XCTAssertEqual(TruoraStepType(stepType: "record_face_photo"), .recordFacePhoto)
        XCTAssertEqual(TruoraStepType(stepType: "enter_face_verification"), .enterFaceVerification)
        XCTAssertEqual(TruoraStepType(stepType: "enter_face_verification_liveness"), .enterFaceVerificationLiveness)
        XCTAssertEqual(TruoraStepType(stepType: "enter_invoice_country"), .enterInvoiceCountry)
        XCTAssertEqual(TruoraStepType(stepType: "take_invoice_photo"), .takeInvoicePhoto)
        XCTAssertEqual(TruoraStepType(stepType: "enter_response"), .enterResponse)
    }

    func testStepTypeUnknownFallback() {
        XCTAssertEqual(TruoraStepType(stepType: "enter_email"), .unknown)
        XCTAssertEqual(TruoraStepType(stepType: "some_future_step"), .unknown)
        XCTAssertEqual(TruoraStepType(stepType: ""), .unknown)
    }

    func testStepTypeDecodesUnknownGracefully() throws {
        let json = """
        {
            "step_id": "STP001",
            "type": "some_future_step_type"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let step = try decoder.decode(TruoraStep.self, from: data)

        XCTAssertEqual(step.type, .unknown)
    }

    // MARK: - TruoraBlockType

    func testBlockTypeKnownValues() throws {
        let json = """
        {"verification_id": "VRF001", "name": "document_verification"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let v = try decoder.decode(TruoraIdentityBlock.self, from: data)
        XCTAssertEqual(v.type, .documentVerification)
    }

    func testBlockTypeDecodesUnknownGracefully() throws {
        let json = """
        {"verification_id": "VRF001", "name": "some_future_verification"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let v = try decoder.decode(TruoraIdentityBlock.self, from: data)
        XCTAssertEqual(v.type, .unknown)
    }

    func testBlockTypeAllCases() {
        XCTAssertEqual(TruoraBlockType(rawValue: "document_verification"), .documentVerification)
        XCTAssertEqual(TruoraBlockType(rawValue: "document_verification_with_face_recognition"), .documentVerificationWithFaceRecognition)
        XCTAssertEqual(TruoraBlockType(rawValue: "document_verification_with_liveness"), .documentVerificationWithLiveness)
        XCTAssertEqual(TruoraBlockType(rawValue: "enter_authorization"), .enterAuthorization)
        XCTAssertEqual(TruoraBlockType(rawValue: "invoice_verification"), .invoiceVerification)
        XCTAssertEqual(TruoraBlockType(rawValue: "face_recognition"), .faceRecognition)
        XCTAssertEqual(TruoraBlockType(rawValue: "custom_question"), .customQuestion)
    }

    // MARK: - TruoraRiskEvaluationOutput

    func testRiskEvaluationOutputDecoding() throws {
        let json = """
        {
            "risk_evaluation_id": "REV001",
            "risk_evaluation_status": "success",
            "risk_evaluation_result": "not_risky",
            "document_validation_id": "DVL001",
            "face_validation_id": "FVL001",
            "manually_reviewed": false,
            "source": "document_validation"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let output = try decoder.decode(TruoraRiskEvaluationOutput.self, from: data)

        XCTAssertEqual(output.riskEvaluationId, "REV001")
        XCTAssertEqual(output.riskEvaluationStatus, .success)
        XCTAssertEqual(output.riskEvaluationResult, .notRisky)
        XCTAssertEqual(output.documentValidationId, "DVL001")
        XCTAssertEqual(output.faceValidationId, "FVL001")
        XCTAssertEqual(output.manuallyReviewed, false)
        XCTAssertEqual(output.source, .documentValidation)
    }

    func testRiskEvaluationOutputRoundtrip() throws {
        let original = TruoraRiskEvaluationOutput(
            riskEvaluationId: "REV001",
            riskEvaluationStatus: .pending,
            riskEvaluationResult: .notEstablished,
            source: .identityProcess
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TruoraRiskEvaluationOutput.self, from: data)

        XCTAssertEqual(decoded.riskEvaluationId, original.riskEvaluationId)
        XCTAssertEqual(decoded.riskEvaluationStatus, original.riskEvaluationStatus)
        XCTAssertEqual(decoded.riskEvaluationResult, original.riskEvaluationResult)
        XCTAssertEqual(decoded.source, original.source)
    }

    // MARK: - Unknown Fields Tolerance

    func testProcessResponseIgnoresUnknownFields() throws {
        let json = """
        {
            "process_id": "IPR001",
            "account_id": "ACC001",
            "client_id": "CLI001",
            "flow_id": "FLW001",
            "some_future_field": "unexpected_value",
            "another_new_thing": 42
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try decoder.decode(TruoraProcessResponse.self, from: data)

        XCTAssertEqual(response.processId, "IPR001")
    }

    func testStepIgnoresUnknownFields() throws {
        let json = """
        {
            "step_id": "STP001",
            "type": "enter_authorization",
            "future_field": true
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let step = try decoder.decode(TruoraStep.self, from: data)

        XCTAssertEqual(step.stepId, "STP001")
        XCTAssertEqual(step.type, .enterAuthorization)
    }

    // MARK: - current_step

    /// `current_step` is `omitempty` on the wire: the backend drops the key when
    /// the index is `0`, so an absent value means the first step, not "unknown".
    func testCurrentStepIndexDefaultsToZeroWhenKeyAbsent() throws {
        let json = #"{"process_id": "IPR001", "status": "pending"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try decoder.decode(TruoraProcessResponse.self, from: data)

        XCTAssertNil(response.currentStep)
        XCTAssertEqual(response.currentStepIndex, 0)
    }

    func testCurrentStepIndexDecodesWireValue() throws {
        let json = #"{"process_id": "IPR001", "status": "pending", "current_step": 2}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try decoder.decode(TruoraProcessResponse.self, from: data)

        XCTAssertEqual(response.currentStepIndex, 2)
    }

    // MARK: - Step resolution

    private func processWithSteps(currentStep: Int? = nil, currentStepId: String? = nil) -> TruoraProcessResponse {
        TruoraProcessResponse(
            processId: "IPR001",
            status: .pending,
            currentStepId: currentStepId,
            currentStep: currentStep,
            steps: [
                TruoraStep(stepId: "STP001", type: .enterAuthorization),
                TruoraStep(stepId: "STP002", type: .enterDocumentType),
                TruoraStep(stepId: "STP003", type: .takeDocumentPhoto)
            ]
        )
    }

    func testStepAtIndexReturnsPositionalStep() {
        XCTAssertEqual(processWithSteps().step(at: 1)?.stepId, "STP002")
    }

    func testStepAtIndexReturnsNilWhenOutOfBounds() {
        let process = processWithSteps()

        XCTAssertNil(process.step(at: 3))
        XCTAssertNil(process.step(at: -1))
    }

    func testStepAtIndexReturnsNilWhenStepsAbsent() {
        let process = TruoraProcessResponse(processId: "IPR001", status: .pending)

        XCTAssertNil(process.step(at: 0))
    }

    func testActiveStepPrefersCurrentStepId() {
        let process = processWithSteps(currentStep: 0, currentStepId: "STP003")

        XCTAssertEqual(process.activeStep()?.stepId, "STP003")
    }

    func testActiveStepFallsBackToIndexWhenStepIdAbsent() {
        XCTAssertEqual(processWithSteps(currentStep: 1).activeStep()?.stepId, "STP002")
    }

    func testActiveStepFallsBackToIndexWhenStepIdEmpty() {
        let process = processWithSteps(currentStep: 1, currentStepId: "")

        XCTAssertEqual(process.activeStep()?.stepId, "STP002")
    }

    func testActiveStepDefaultsToFirstStepWhenCurrentStepAbsent() {
        XCTAssertEqual(processWithSteps().activeStep()?.stepId, "STP001")
    }

    // MARK: - TruoraStepOutput

    func testStepOutputDecodesTypedFields() throws {
        let json = """
        {
            "step_id": "STP001",
            "type": "take_document_photo",
            "remaining_retries": 1,
            "verification_output": {
                "status": "failure",
                "failure_status": "declined",
                "declined_reason": "blurry document",
                "media_uploaded": true
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let step = try decoder.decode(TruoraStep.self, from: data)

        XCTAssertEqual(step.output?.status, .failure)
        XCTAssertEqual(step.output?.failureStatus, .declined)
        XCTAssertEqual(step.output?.declinedReason, "blurry document")
        XCTAssertEqual(step.output?.mediaUploaded, true)
    }

    /// An unverified step carries `verification_output` with no `status`; the
    /// runner reads that as "still resolving", not as a decode failure.
    func testStepOutputDecodesWithoutStatus() throws {
        let json = """
        {"step_id": "STP001", "type": "take_document_photo", "verification_output": {}}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let step = try decoder.decode(TruoraStep.self, from: data)

        XCTAssertNotNil(step.output)
        XCTAssertNil(step.output?.status)
    }

    func testStepOutputAbsentDecodesToNil() throws {
        let json = #"{"step_id": "STP001", "type": "take_document_photo"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))
        let step = try decoder.decode(TruoraStep.self, from: data)

        XCTAssertNil(step.output)
    }

    // MARK: - Finalization (hasGetResults / isRiskEvaluationPending / toResult)

    private func decodeProcess(_ json: String) throws -> TruoraProcessResponse {
        try decoder.decode(TruoraProcessResponse.self, from: Data(json.utf8))
    }

    func testGetValidationsResultBlockTypeDecodes() {
        XCTAssertEqual(TruoraBlockType(rawValue: "get_validations_result"), .getValidationsResult)
    }

    func testHasGetResultsReflectsIdentityBlockTypes() throws {
        let present = try decodeProcess(
            #"{"process_id": "IPR1", "identity_verification_names": ["document_verification", "get_validations_result"]}"#
        )
        let absent = try decodeProcess(
            #"{"process_id": "IPR1", "identity_verification_names": ["document_verification"]}"#
        )
        let missing = try decodeProcess(#"{"process_id": "IPR1"}"#)

        XCTAssertTrue(present.hasGetResults)
        XCTAssertFalse(absent.hasGetResults)
        XCTAssertFalse(missing.hasGetResults, "Absent names are not get-results")
    }

    func testIsRiskEvaluationPendingTrueOnlyForPendingStatus() throws {
        let pending = try decodeProcess(
            #"{"process_id": "IPR1", "risk_evaluation": {"risk_evaluation_status": "pending"}}"#
        )
        let resolved = try decodeProcess(
            #"{"process_id": "IPR1", "risk_evaluation": {"risk_evaluation_status": "success"}}"#
        )
        let absent = try decodeProcess(#"{"process_id": "IPR1"}"#)

        XCTAssertTrue(pending.isRiskEvaluationPending)
        XCTAssertFalse(resolved.isRiskEvaluationPending)
        XCTAssertFalse(absent.isRiskEvaluationPending, "No risk evaluation is not pending")
    }

    func testToResultCarriesStatusFailureAndRisk() throws {
        let process = try decodeProcess(
            """
            {
              "process_id": "IPR9",
              "status": "failure",
              "failure_status": "declined",
              "risk_evaluation": {"risk_evaluation_status": "success", "risk_evaluation_result": "risky"}
            }
            """
        )

        let result = process.toResult()

        XCTAssertEqual(result.processId, "IPR9")
        XCTAssertEqual(result.status, .failure)
        XCTAssertEqual(result.failureStatus, .declined)
        XCTAssertEqual(result.risk?.riskEvaluationStatus, .success)
        XCTAssertEqual(result.risk?.riskEvaluationResult, .risky)
    }

    func testToResultDefaultsStatusToPendingWhenAbsent() throws {
        XCTAssertEqual(try decodeProcess(#"{"process_id": "IPR1"}"#).toResult().status, .pending)
    }

    /// The wire keys the map with `"<name>:<verification_id>"`, so each leaf splits
    /// into its name and id, and entries come back sorted by key.
    func testToResultFlattensBlockMapSortedByKey() throws {
        let process = try decodeProcess(
            """
            {
              "process_id": "IPR1",
              "verifications": {
                "face_recognition:VRF_face_2": "pending",
                "document_verification:VRF_doc_1": "success"
              }
            }
            """
        )

        let blocks = process.toResult().blocks

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].type, .documentVerification, "Sorted by composite key")
        XCTAssertEqual(blocks[0].blockId, "VRF_doc_1")
        XCTAssertEqual(blocks[0].status, .success)
        XCTAssertEqual(blocks[1].type, .faceRecognition)
        XCTAssertEqual(blocks[1].blockId, "VRF_face_2")
        XCTAssertEqual(blocks[1].status, .pending)
    }

    func testToResultUnknownBlockTypeFallsBack() throws {
        let process = try decodeProcess(
            #"{"process_id": "IPR1", "verifications": {"teleport_check:VRF_x": "success"}}"#
        )

        let block = try XCTUnwrap(process.toResult().blocks.first)

        XCTAssertEqual(block.type, .unknown)
        XCTAssertEqual(block.blockId, "VRF_x")
    }

    /// A key with no separator degrades to name-only, empty id — never a crash.
    func testToResultBlockKeyWithoutSeparator() throws {
        let process = try decodeProcess(
            #"{"process_id": "IPR1", "verifications": {"document_verification": "success"}}"#
        )

        let block = try XCTUnwrap(process.toResult().blocks.first)

        XCTAssertEqual(block.type, .documentVerification)
        XCTAssertEqual(block.blockId, "")
    }

    func testToResultEmptyWhenNoBlocks() throws {
        XCTAssertTrue(try decodeProcess(#"{"process_id": "IPR1"}"#).toResult().blocks.isEmpty)
    }
}
