//
//  DocumentFeedbackViewModel.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/01/26.
//

import Foundation

// MARK: - View Model

@MainActor final class DocumentFeedbackViewModel: ObservableObject {
    let feedback: FeedbackScenario
    let capturedImageData: Data?
    let retriesLeft: Int
    var presenter: DocumentFeedbackViewToPresenter?
    private let audioPlayer: TruoraAudioPlayer

    init(feedback: FeedbackScenario, capturedImageData: Data?, retriesLeft: Int) {
        self.feedback = feedback
        self.capturedImageData = capturedImageData
        self.retriesLeft = retriesLeft
        let configuredCountry = ValidationConfig.shared.documentConfig.country.lowercased()
        self.audioPlayer = TruoraAudioPlayer(
            languageCode: ValidationConfig.shared.lang?.rawValue ?? Locale.current.languageCode ?? "es",
            countryCode: configuredCountry.isEmpty ? "co" : configuredCountry
        )
    }

    func onAppear() {
        if let instruction = audioInstruction(for: feedback) {
            audioPlayer.play(instruction)
        }
        guard let presenter else {
            debugLog("⚠️ DocumentFeedbackViewModel: presenter is nil in onAppear")
            return
        }
        Task { await presenter.viewDidLoad() }
    }

    func onDisappear() {
        audioPlayer.stop()
    }

    private func audioInstruction(for scenario: FeedbackScenario) -> TruoraAudioInstruction? {
        switch scenario {
        case .documentNotFound: .documentNotFound
        case .frontOfDocumentNotFound: .placeTheFront
        case .backOfDocumentNotFound: .placeTheBack
        case .blurryImage, .imageWithReflection, .faceNotFound, .lowLight: nil
        case .missingText, .documentNotRecognized, .documentHasExpired, .wrongDocumentFound, .grayscaleImage:
            nil
        }
    }

    func retryTapped() {
        Task { await presenter?.retryTapped() }
    }

    func cancelTapped() {
        Task { await presenter?.cancelTapped() }
    }
}

// MARK: - DocumentFeedbackPresenterToView

extension DocumentFeedbackViewModel: DocumentFeedbackPresenterToView {}
