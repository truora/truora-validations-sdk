//
//  DocumentFeedbackView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 05/01/26.
//

import SwiftUI
import UIKit

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
            TruoraHeaderView {
                viewModel.cancelTapped()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 14) {
                        FeedbackIconView(
                            feedback: viewModel.feedback,
                            errorColor: theme.colors.error
                        )
                        .frame(width: 60, height: 60)

                        Text(feedbackTitle(for: viewModel.feedback))
                            .font(theme.typography.titleLarge)
                            .foregroundColor(theme.colors.error)
                            .tracking(0.25)
                            .multilineTextAlignment(.leading)
                    }

                    Text(feedbackDescription(for: viewModel.feedback))
                        .font(theme.typography.bodyLarge)
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
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            Spacer()

            if viewModel.retriesLeft > 0 {
                VStack(spacing: 10) {
                    retriesText

                    TruoraFooterView(
                        securityTip: nil,
                        buttonText: TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackRetry),
                        isLoading: false
                    ) {
                        viewModel.retryTapped()
                    }
                }
            }
        }
        .environmentObject(theme)
        .background(theme.colors.surface.extendingIntoSafeArea())
        .navigationBarHidden(true)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private func feedbackTitle(for feedback: FeedbackScenario) -> String {
        switch feedback {
        case .lowLight:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackDefaultTitle)
        case .blurryImage:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackBlurryTitle)
        case .imageWithReflection:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackGlareTitle)
        case .faceNotFound:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackFaceNotFoundTitle)
        case .documentNotFound:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackNoDocumentTitle)
        case .frontOfDocumentNotFound:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackFrontNotFoundTitle)
        case .backOfDocumentNotFound:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackBackNotFoundTitle)
        // These scenarios come from the invoice OCR / polling path (see
        // `ResultPresenter.mapInvoiceDeclinedReason` and the invoice
        // `failure_status` values). `DocumentCapturePresenter.mapReasonToScenario`
        // never emits them, so this branch is unreachable in the Document flow —
        // kept only so the switch is exhaustive over `FeedbackScenario`, which is
        // shared with Invoice. The generic default copy is a safe fallback.
        case .missingText, .documentNotRecognized, .documentHasExpired,
             .wrongDocumentFound, .grayscaleImage:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackDefaultTitle)
        }
    }

    private func feedbackDescription(for feedback: FeedbackScenario) -> String {
        switch feedback {
        case .blurryImage, .lowLight:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackBlurryDescription)
        case .imageWithReflection:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackGlareDescription)
        case .faceNotFound:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackFaceNotFoundDescription)
        case .documentNotFound:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackNoDocumentDescription)
        case .frontOfDocumentNotFound:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackFrontNotFoundDescription)
        case .backOfDocumentNotFound:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackBackNotFoundDescription)
        // Unreachable in the Document flow — see note on `feedbackTitle`.
        case .missingText, .documentNotRecognized, .documentHasExpired,
             .wrongDocumentFound, .grayscaleImage:
            TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackNoDocumentDescription)
        }
    }

    @ViewBuilder
    private var retriesText: some View {
        let fullText = TruoraLocalization.string(
            forKey: LocalizationKeys.documentFeedbackRetriesLeft,
            arguments: String(viewModel.retriesLeft)
        )
        let numberString = String(viewModel.retriesLeft)

        if let range = fullText.range(of: numberString) {
            let prefix = String(fullText[..<range.lowerBound])
            let suffix = String(fullText[range.upperBound...])

            HStack(spacing: 0) {
                Text(prefix)
                    .font(theme.typography.bodySmall)
                    .foregroundColor(theme.colors.onSurface)
                Text(numberString)
                    .font(theme.typography.bodyMedium)
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
    @EnvironmentObject var theme: TruoraTheme

    var iconName: String {
        switch feedback {
        case .blurryImage, .lowLight, .grayscaleImage: "eye.slash"
        case .imageWithReflection: "sun.max.fill"
        case .faceNotFound: "person.fill.questionmark"
        case .documentNotFound, .frontOfDocumentNotFound, .backOfDocumentNotFound,
             .wrongDocumentFound, .documentNotRecognized: "doc.text.magnifyingglass"
        case .missingText: "doc.text"
        case .documentHasExpired: "clock"
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
                        .foregroundColor(Color(red: 0.0, green: 0.01, blue: 0.18))
                        // Dark navy #01022E
                        .padding(12)
                )

            // Error indicator (red X) at bottom right
            ZStack {
                Circle()
                    .fill(errorColor)
                    .frame(width: 23, height: 23)
                SwiftUI.Image(systemName: "xmark")
                    .font(theme.typography.bodySmall)
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

#Preview("Front Of Document Not Found") {
    DocumentFeedbackView(
        viewModel: DocumentFeedbackViewModel(
            feedback: .frontOfDocumentNotFound,
            capturedImageData: createPlaceholderImageData(),
            retriesLeft: 2
        ),
        config: nil
    )
}

#Preview("Back Of Document Not Found") {
    DocumentFeedbackView(
        viewModel: DocumentFeedbackViewModel(
            feedback: .backOfDocumentNotFound,
            capturedImageData: createPlaceholderImageData(),
            retriesLeft: 1
        ),
        config: nil
    )
}

#Preview("Low Light Feedback") {
    DocumentFeedbackView(
        viewModel: DocumentFeedbackViewModel(
            feedback: .lowLight,
            capturedImageData: createPlaceholderImageData(),
            retriesLeft: 1
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
