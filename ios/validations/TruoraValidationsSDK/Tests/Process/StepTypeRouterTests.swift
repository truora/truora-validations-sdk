//
//  StepTypeRouterTests.swift
//  TruoraValidationsSDKTests
//

import XCTest
@testable import TruoraValidationsSDK

@MainActor final class StepTypeRouterTests: XCTestCase {
    private let router = StepTypeRouter()

    private func step(_ type: TruoraStepType) -> TruoraStep {
        TruoraStep(stepId: "STP1", type: type)
    }

    func testRouteEnterAuthorization() {
        XCTAssertEqual(router.route(step(.enterAuthorization)).screen, .authorization)
    }

    func testRouteEnterDocumentType() {
        XCTAssertEqual(router.route(step(.enterDocumentType)).screen, .documentType)
    }

    func testRouteTakeDocumentPhoto() {
        XCTAssertEqual(router.route(step(.takeDocumentPhoto)).screen, .documentPhoto)
    }

    func testRouteLivenessFaceSteps() {
        XCTAssertEqual(router.route(step(.recordFacePhotoLiveness)).screen, .faceLiveness)
        XCTAssertEqual(router.route(step(.recordFaceVideoLiveness)).screen, .faceLiveness)
        XCTAssertEqual(router.route(step(.enterFaceVerificationLiveness)).screen, .faceLiveness)
    }

    func testRouteInvoiceSteps() {
        XCTAssertEqual(router.route(step(.enterInvoiceCountry)).screen, .invoice)
        XCTAssertEqual(router.route(step(.takeInvoicePhoto)).screen, .invoice)
    }

    func testRouteUnknownAndNonV1StepsAreUnsupported() {
        XCTAssertEqual(router.route(step(.unknown)).screen, .unsupported)
        XCTAssertEqual(router.route(step(.recordFacePhoto)).screen, .unsupported)
        XCTAssertEqual(router.route(step(.recordFaceVideo)).screen, .unsupported)
        XCTAssertEqual(router.route(step(.enterFaceVerification)).screen, .unsupported)
        XCTAssertEqual(router.route(step(.enterResponse)).screen, .unsupported)
    }

    func testRouteForwardsStepPayloadUnchanged() {
        let step = TruoraStep(
            stepId: "STP1",
            type: .takeDocumentPhoto,
            config: ["country": .string("CO")],
            expectedInputs: [TruoraInput(type: "file", name: "document-front")],
            filesUploadUrls: [TruoraFileUpload(name: "document-front", url: "https://upload/front")]
        )

        let routed = router.route(step)

        XCTAssertEqual(routed.screen, .documentPhoto)
        XCTAssertEqual(routed.step.stepId, "STP1")
        XCTAssertEqual(routed.step.config?["country"], .string("CO"))
        XCTAssertEqual(routed.step.expectedInputs?.first?.name, "document-front")
        XCTAssertEqual(routed.step.filesUploadUrls?.first?.url, "https://upload/front")
    }
}
