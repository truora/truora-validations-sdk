//
//  DocumentFeedbackView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/01/26.
//

import SwiftUI
import UIKit

// MARK: - View Model

@MainActor final class DocumentFeedbackViewModel: ObservableObject {
    let feedback: FeedbackScenario
    let capturedImageData: Data?
    let retriesLeft: Int
    var presenter: DocumentFeedbackViewToPresenter?

    init(feedback: FeedbackScenario, capturedImageData: Data?, retriesLeft: Int) {
        self.feedback = feedback
        self.capturedImageData = capturedImageData
        self.retriesLeft = retriesLeft
    }

    func onAppear() {
        guard let presenter else {
            #if DEBUG
            print("⚠️ DocumentFeedbackViewModel: presenter is nil in onAppear")
            #endif
            return
        }
        Task { await presenter.viewDidLoad() }
    }

    func retryTapped() {
        Task { await presenter?.retryTapped() }
    }

    func dismissTapped() {
        Task { await presenter?.dismissed() }
    }
}

extension DocumentFeedbackViewModel: DocumentFeedbackPresenterToView {}

// MARK: - View

struct DocumentFeedbackView: View {
    @ObservedObject var viewModel: DocumentFeedbackViewModel
    @ObservedObject private var theme: TruoraTheme

    init(viewModel: DocumentFeedbackViewModel, config: UIConfig?) {
        self.viewModel = viewModel
        self.theme = TruoraTheme(config: config)
    }

    var body: some View {
        VStack(spacing: 0) {
            TruoraHeaderView { viewModel.dismissTapped() }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 14) {
                        FeedbackIconView(feedback: viewModel.feedback, errorColor: theme.colors.error)
                            .frame(width: 60, height: 60)

                        Text(feedbackTitle(for: viewModel.feedback))
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(theme.colors.error)
                            .tracking(0.25)
                            .multilineTextAlignment(.leading)
                    }

                    Text(feedbackDescription(for: viewModel.feedback))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(theme.colors.onSurface)
                        .multilineTextAlignment(.leading)

                    if let imageData = viewModel.capturedImageData,
                       let uiImage = UIImage(data: imageData) {
                        GeometryReader { geometry in
                            HStack {
                                Spacer()
                                SwiftUI.Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: geometry.size.width * 0.6)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(theme.colors.error, lineWidth: 2)
                                    )
                                Spacer()
                            }
                        }
                        .aspectRatio(1.5, contentMode: .fit)
                        .padding(.top, 32)
                    }
                }
                .frame(maxWidth: 810, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }

            Spacer()

            if viewModel.retriesLeft > 0 {
                VStack(spacing: 10) {
                    retriesText

                    TruoraFooterView(
                        securityTip: nil,
                        buttonText: TruoraValidationsSDKStrings.documentFeedbackRetry,
                        isLoading: false
                    ) {
                        viewModel.retryTapped()
                    }

                    HStack {
                        Spacer()
                        TruoraValidationsSDKAsset.byTruoraDark.swiftUIImage
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
        .background(Color.white)
        .environmentObject(theme)
        .navigationBarHidden(true)
        .onAppear { viewModel.onAppear() }
    }

    private func feedbackTitle(for feedback: FeedbackScenario) -> String {
        switch feedback {
        case .blurryImage, .lowLight: TruoraValidationsSDKStrings.documentFeedbackBlurryTitle
        case .imageWithReflection: TruoraValidationsSDKStrings.documentFeedbackGlareTitle
        case .faceNotFound: TruoraValidationsSDKStrings.documentFeedbackFaceNotFoundTitle
        case .documentNotFound, .frontOfDocumentNotFound, .backOfDocumentNotFound:
            TruoraValidationsSDKStrings.documentFeedbackNoDocumentTitle
        }
    }

    private func feedbackDescription(for feedback: FeedbackScenario) -> String {
        switch feedback {
        case .blurryImage, .lowLight: TruoraValidationsSDKStrings.documentFeedbackBlurryDescription
        case .imageWithReflection: TruoraValidationsSDKStrings.documentFeedbackGlareDescription
        case .faceNotFound: TruoraValidationsSDKStrings.documentFeedbackFaceNotFoundDescription
        case .documentNotFound, .frontOfDocumentNotFound, .backOfDocumentNotFound:
            TruoraValidationsSDKStrings.documentFeedbackNoDocumentDescription
        }
    }

    @ViewBuilder
    private var retriesText: some View {
        let fullText = TruoraValidationsSDKStrings.documentFeedbackRetriesLeft(String(viewModel.retriesLeft))
        let numberString = String(viewModel.retriesLeft)

        if let range = fullText.range(of: numberString) {
            let prefix = String(fullText[..<range.lowerBound])
            let suffix = String(fullText[range.upperBound...])

            HStack(spacing: 0) {
                Text(prefix)
                    .font(theme.typography.bodySmall)
                    .foregroundColor(theme.colors.onSurface)
                Text(numberString)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.colors.onSurface)
                Text(suffix)
                    .font(theme.typography.bodySmall)
                    .foregroundColor(theme.colors.onSurface)
            }
        } else {
            Text(fullText)
                .font(theme.typography.bodySmall)
                .foregroundColor(theme.colors.onSurface)
        }
    }
}

// MARK: - Feedback Icon View

private struct FeedbackIconView: View {
    let feedback: FeedbackScenario
    let errorColor: Color

    var iconName: String {
        switch feedback {
        case .blurryImage, .lowLight: "eye.slash"
        case .imageWithReflection: "sun.max.fill"
        case .faceNotFound: "person.fill.questionmark"
        case .documentNotFound, .frontOfDocumentNotFound, .backOfDocumentNotFound:
            "doc.text.magnifyingglass"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background rounded rectangle with icon (light purple #EFF2FF)
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(red: 0.94, green: 0.95, blue: 1.0)) // #EFF2FF
                .frame(width: 50, height: 50)
                .overlay(
                    SwiftUI.Image(systemName: iconName)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color(red: 0.0, green: 0.01, blue: 0.18)) // Dark navy #01022E
                        .padding(12)
                )

            // Error indicator (red X) at bottom right
            ZStack {
                Circle()
                    .fill(errorColor)
                    .frame(width: 23, height: 23)
                SwiftUI.Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(x: 8, y: 8)
        }
    }
}

// MARK: - Previews

private func createPlaceholderImageData() -> Data? {
    let size = CGSize(width: 500, height: 300)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
        UIColor.lightGray.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        UIColor.darkGray.setFill()
        let text = "Document Preview"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.darkGray
        ]
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
    }
    return image.pngData()
}

#Preview("Blurry Image Feedback") {
    DocumentFeedbackView(
        viewModel: DocumentFeedbackViewModel(
            feedback: .blurryImage,
            capturedImageData: createPlaceholderImageData(),
            retriesLeft: 2
        ),
        config: nil
    )
}

#Preview("Glare Feedback") {
    DocumentFeedbackView(
        viewModel: DocumentFeedbackViewModel(
            feedback: .imageWithReflection,
            capturedImageData: createPlaceholderImageData(),
            retriesLeft: 1
        ),
        config: nil
    )
}

#Preview("Document Not Found") {
    DocumentFeedbackView(
        viewModel: DocumentFeedbackViewModel(
            feedback: .documentNotFound,
            capturedImageData: createPlaceholderImageData(),
            retriesLeft: 3
        ),
        config: nil
    )
}

#Preview("No Retries Left") {
    DocumentFeedbackView(
        viewModel: DocumentFeedbackViewModel(
            feedback: .blurryImage,
            capturedImageData: nil,
            retriesLeft: 0
        ),
        config: nil
    )
}
