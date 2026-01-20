//
//  DocumentFeedbackView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/01/26.
//

import SwiftUI
import TruoraShared

final class DocumentFeedbackViewModel: ObservableObject {
    let feedback: FeedbackScenario
    let capturedImageData: Data?
    let retriesLeft: Int

    var presenter: DocumentFeedbackViewToPresenter?

    init(
        feedback: FeedbackScenario,
        capturedImageData: Data?,
        retriesLeft: Int
    ) {
        self.feedback = feedback
        self.capturedImageData = capturedImageData
        self.retriesLeft = retriesLeft
    }

    func onAppear() {
        guard let presenter else {
            print("⚠️ DocumentFeedbackViewModel: presenter is nil in onAppear")
            return
        }
        presenter.viewDidLoad()
    }

    func handleEvent(_ event: DocumentAutoCaptureFeedbackEvent) {
        if event is DocumentAutoCaptureFeedbackEventRetryClicked {
            presenter?.retryTapped()
            return
        }

        if event is DocumentAutoCaptureFeedbackEventTipsClicked {
            presenter?.tipsTapped()
            return
        }

        if event is DocumentAutoCaptureFeedbackEventDismissed {
            presenter?.dismissed()
            return
        }

        print("⚠️ Unhandled DocumentAutoCaptureFeedbackEvent: \(type(of: event))")
    }
}

extension DocumentFeedbackViewModel: DocumentFeedbackPresenterToView {}

private struct DocumentFeedbackComposeUIViewWrapper: UIViewControllerRepresentable {
    let feedback: FeedbackScenario
    let capturedImageData: Data?
    let retriesLeft: Int
    let composeConfig: TruoraUIConfig
    let onEvent: (DocumentAutoCaptureFeedbackEvent) -> Void

    func makeUIViewController(context _: Context) -> UIViewController {
        TruoraUIExportsKt.createDocumentFeedbackViewController(
            feedback: feedback,
            capturedImageData: capturedImageData?.toKotlinByteArray(),
            photoWidthDp: Int32(240),
            photoHeightDp: Int32(140),
            retriesLeft: Int32(retriesLeft),
            onEvent: onEvent,
            config: composeConfig
        )
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}
}

struct DocumentFeedbackView: View {
    @ObservedObject var viewModel: DocumentFeedbackViewModel
    let composeConfig: TruoraUIConfig

    var body: some View {
        DocumentFeedbackComposeUIViewWrapper(
            feedback: viewModel.feedback,
            capturedImageData: viewModel.capturedImageData,
            retriesLeft: viewModel.retriesLeft,
            composeConfig: composeConfig,
            onEvent: { event in
                viewModel.handleEvent(event)
            }
        )
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
        .onAppear {
            viewModel.onAppear()
        }
    }
}
