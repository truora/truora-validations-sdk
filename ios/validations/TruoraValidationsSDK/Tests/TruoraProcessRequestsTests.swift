//
//  TruoraProcessRequestsTests.swift
//  SDKTests
//
//  Created by Truora on 27/05/26.
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class TruoraProcessRequestsTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private let decoder = JSONDecoder()

    // MARK: - Helper

    /// Encodes a value and returns the resulting dictionary for key inspection.
    private func encodeToDictionary(_ value: some Encodable) throws -> [String: Any] {
        let data = try encoder.encode(value)
        let obj = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(obj as? [String: Any])
    }

    // MARK: - TruoraBlockInput

    func testBlockInputEncoding() throws {
        let input = TruoraBlockInput(
            type: .documentVerification,
            config: [
                "country": .string("CO"),
                "document_type": .string("national-id")
            ]
        )

        let dict = try encodeToDictionary(input)

        XCTAssertEqual(dict["type"] as? String, "document_verification")
        let config = try XCTUnwrap(dict["config"] as? [String: Any])
        XCTAssertEqual(config["country"] as? String, "CO")
        XCTAssertEqual(config["document_type"] as? String, "national-id")
    }

    // MARK: - TruoraCreateProcessRequest

    func testCreateProcessRequestAlwaysIncludesProcessType() throws {
        let request = TruoraCreateProcessRequest(
            block: TruoraBlockInput(
                type: .faceRecognition,
                config: [:]
            )
        )

        let dict = try encodeToDictionary(request)

        XCTAssertEqual(dict["process_type"] as? String, "dynamic")
    }

    func testCreateProcessRequestFullEncoding() throws {
        let request = TruoraCreateProcessRequest(
            block: TruoraBlockInput(
                type: .documentVerification,
                config: ["country": .string("CO")]
            ),
            ttl: 3600,
            label: "sdk-test",
            geolocationIp: "1.2.3.4",
            processIp: "5.6.7.8",
            city: "Bogota",
            lang: "es",
            deviceInfo: "iPhone14,2"
        )

        let dict = try encodeToDictionary(request)

        XCTAssertEqual(dict["process_type"] as? String, "dynamic")
        XCTAssertEqual(dict["ttl"] as? Int, 3600)
        XCTAssertEqual(dict["label"] as? String, "sdk-test")
        XCTAssertEqual(dict["geolocation_ip"] as? String, "1.2.3.4")
        XCTAssertEqual(dict["process_ip"] as? String, "5.6.7.8")
        XCTAssertEqual(dict["city"] as? String, "Bogota")
        XCTAssertEqual(dict["lang"] as? String, "es")
        XCTAssertEqual(dict["device_info"] as? String, "iPhone14,2")

        let block = try XCTUnwrap(dict["verification"] as? [String: Any])
        XCTAssertEqual(block["type"] as? String, "document_verification")
    }

    func testCreateProcessRequestOmitsNilFields() throws {
        let request = TruoraCreateProcessRequest(
            block: TruoraBlockInput(
                type: .faceRecognition,
                config: [:]
            )
        )

        let dict = try encodeToDictionary(request)

        // Required fields present
        XCTAssertNotNil(dict["process_type"])
        XCTAssertNotNil(dict["verification"])

        // Optional fields absent
        XCTAssertNil(dict["ttl"])
        XCTAssertNil(dict["label"])
        XCTAssertNil(dict["geolocation_ip"])
        XCTAssertNil(dict["process_ip"])
        XCTAssertNil(dict["city"])
        XCTAssertNil(dict["lang"])
        XCTAssertNil(dict["device_info"])
    }

    func testCreateProcessRequestSnakeCaseKeys() throws {
        let request = TruoraCreateProcessRequest(
            block: TruoraBlockInput(
                type: .faceRecognition,
                config: [:]
            ),
            geolocationIp: "1.2.3.4",
            processIp: "5.6.7.8",
            deviceInfo: "test"
        )

        let dict = try encodeToDictionary(request)

        // Verify snake_case keys (not camelCase)
        XCTAssertNotNil(dict["process_type"])
        XCTAssertNil(dict["processType"])
        XCTAssertNotNil(dict["geolocation_ip"])
        XCTAssertNil(dict["geolocationIp"])
        XCTAssertNotNil(dict["process_ip"])
        XCTAssertNil(dict["processIp"])
        XCTAssertNotNil(dict["device_info"])
        XCTAssertNil(dict["deviceInfo"])
    }

    // MARK: - TruoraAddBlockRequest

    func testAddBlockRequestEncoding() throws {
        let request = TruoraAddBlockRequest(
            block: TruoraBlockInput(
                type: .invoiceVerification,
                config: ["provider": .string("electric")]
            )
        )

        let dict = try encodeToDictionary(request)
        let block = try XCTUnwrap(dict["verification"] as? [String: Any])
        XCTAssertEqual(block["type"] as? String, "invoice_verification")

        let config = try XCTUnwrap(block["config"] as? [String: Any])
        XCTAssertEqual(config["provider"] as? String, "electric")
    }

    // MARK: - TruoraAddBlockResponse

    func testAddBlockResponseDecoding() throws {
        let json = """
        {
            "verification_id": "VRF000000000001",
            "step_id": "STP000000000001",
            "step_type": "enter_document_type",
            "verifications": {
                "document_verification": "pending",
                "face_recognition": "success"
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try decoder.decode(TruoraAddBlockResponse.self, from: data)

        XCTAssertEqual(response.blockId, "VRF000000000001")
        XCTAssertEqual(response.stepId, "STP000000000001")
        XCTAssertEqual(response.stepType, .enterDocumentType)
        XCTAssertEqual(response.blocks?["document_verification"], .pending)
        XCTAssertEqual(response.blocks?["face_recognition"], .success)
    }

    func testAddBlockResponseDecodingMinimal() throws {
        let json = """
        {
            "verification_id": "VRF001",
            "step_id": "STP001",
            "step_type": "record_face_video_liveness"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try decoder.decode(TruoraAddBlockResponse.self, from: data)

        XCTAssertEqual(response.blockId, "VRF001")
        XCTAssertEqual(response.stepId, "STP001")
        XCTAssertEqual(response.stepType, .recordFaceVideoLiveness)
        XCTAssertNil(response.blocks)
    }

    func testAddBlockResponseRoundtrip() throws {
        let original = TruoraAddBlockResponse(
            blockId: "VRF001",
            stepId: "STP001",
            stepType: .enterAuthorization,
            blocks: [
                "document_verification": .success,
                "face_recognition": .pending
            ]
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TruoraAddBlockResponse.self, from: data)

        XCTAssertEqual(decoded.blockId, original.blockId)
        XCTAssertEqual(decoded.stepId, original.stepId)
        XCTAssertEqual(decoded.stepType, original.stepType)
        XCTAssertEqual(decoded.blocks?["document_verification"], .success)
        XCTAssertEqual(decoded.blocks?["face_recognition"], .pending)
    }

    func testAddBlockResponseSnakeCaseKeys() throws {
        let json = """
        {
            "verification_id": "VRF001",
            "step_id": "STP001",
            "step_type": "enter_authorization"
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))

        // Decodes from snake_case
        let response = try decoder.decode(TruoraAddBlockResponse.self, from: data)
        XCTAssertEqual(response.blockId, "VRF001")

        // Re-encodes to snake_case
        let reEncoded = try encodeToDictionary(response)
        XCTAssertNotNil(reEncoded["verification_id"])
        XCTAssertNil(reEncoded["blockId"])
        XCTAssertNotNil(reEncoded["step_id"])
        XCTAssertNil(reEncoded["stepId"])
        XCTAssertNotNil(reEncoded["step_type"])
        XCTAssertNil(reEncoded["stepType"])
    }

    // MARK: - TruoraVerifyStepRequest

    /// A step as the process would hand it to the runner, with two inputs to fill.
    private func documentTypeStep() -> TruoraStep {
        TruoraStep(
            stepId: "STP001",
            processId: "IPR001",
            type: .enterDocumentType,
            expectedInputs: [
                TruoraInput(type: "checkbox", name: "authorized"),
                TruoraInput(type: "text", name: "country")
            ],
            remainingRetries: 2
        )
    }

    /// The backend decodes the body into an embedded `*models.Step`, so the step's
    /// own fields must sit at the top level of the body, not nested under a key.
    func testVerifyStepRequestFlattensStepToTopLevel() throws {
        let request = TruoraVerifyStepRequest(step: documentTypeStep())

        let dict = try encodeToDictionary(request)

        XCTAssertEqual(dict["step_id"] as? String, "STP001")
        XCTAssertEqual(dict["process_id"] as? String, "IPR001")
        XCTAssertEqual(dict["type"] as? String, "enter_document_type")
        XCTAssertNil(dict["step"], "The step must not be nested under a `step` key")
    }

    /// `SetRequestValuesToCurrentStep` reads `remaining_retries` off the submitted
    /// step, so it has to survive the round trip.
    func testVerifyStepRequestEchoesRemainingRetries() throws {
        let request = TruoraVerifyStepRequest(step: documentTypeStep())

        let dict = try encodeToDictionary(request)

        XCTAssertEqual(dict["remaining_retries"] as? Int, 2)
    }

    /// `log_id` is the web runner's WASM-generated signature. The backend only
    /// reads it for `created_via == "web"` media steps, and the SDK cannot sign
    /// one, so it must never appear in the body.
    func testVerifyStepRequestNeverSendsLogId() throws {
        let request = TruoraVerifyStepRequest(step: documentTypeStep())

        let dict = try encodeToDictionary(request)

        XCTAssertNil(dict["log_id"])
    }

    /// `Step.GetInputValue` matches an expected input on **both** type and name, so
    /// every submitted input must carry its type.
    func testVerifyStepRequestCarriesInputTypeNameAndValue() throws {
        let step = documentTypeStep().settingInputValues([
            TruoraStepInputValue(type: "checkbox", name: "authorized", value: "true"),
            TruoraStepInputValue(type: "text", name: "country", value: "CO")
        ])

        let dict = try encodeToDictionary(TruoraVerifyStepRequest(step: step))
        let inputs = try XCTUnwrap(dict["expected_inputs"] as? [[String: Any]])

        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(inputs[0]["type"] as? String, "checkbox")
        XCTAssertEqual(inputs[0]["name"] as? String, "authorized")
        XCTAssertEqual(inputs[0]["value"] as? String, "true")
        XCTAssertEqual(inputs[1]["type"] as? String, "text")
        XCTAssertEqual(inputs[1]["name"] as? String, "country")
        XCTAssertEqual(inputs[1]["value"] as? String, "CO")
    }

    // MARK: - TruoraStep.settingInputValues

    func testSettingInputValuesMatchesOnTypeAndName() {
        let step = documentTypeStep().settingInputValues([
            TruoraStepInputValue(type: "text", name: "country", value: "CO")
        ])

        XCTAssertEqual(step.expectedInputs?[1].value, "CO")
    }

    /// A value whose type does not line up is dropped server-side, so the SDK must
    /// not pretend it applied.
    func testSettingInputValuesIgnoresValueWithMismatchedType() {
        let step = documentTypeStep().settingInputValues([
            TruoraStepInputValue(type: "number", name: "country", value: "CO")
        ])

        XCTAssertNil(step.expectedInputs?[1].value)
    }

    func testSettingInputValuesLeavesUnmatchedInputsUntouched() {
        let step = documentTypeStep().settingInputValues([
            TruoraStepInputValue(type: "text", name: "country", value: "CO")
        ])

        XCTAssertNil(step.expectedInputs?.first?.value)
        XCTAssertEqual(step.expectedInputs?.count, 2)
    }

    func testSettingInputValuesOnStepWithoutInputsIsANoop() {
        let step = TruoraStep(stepId: "STP001", type: .enterAuthorization)
            .settingInputValues([TruoraStepInputValue(type: "text", name: "country", value: "CO")])

        XCTAssertNil(step.expectedInputs)
    }
}
