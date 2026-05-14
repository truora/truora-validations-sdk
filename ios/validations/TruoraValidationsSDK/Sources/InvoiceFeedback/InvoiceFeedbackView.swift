//
//  InvoiceFeedbackView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import SwiftUI
import UIKit

// MARK: - View

struct InvoiceFeedbackView: View {
    @ObservedObject var viewModel: InvoiceFeedbackViewModel
    @ObservedObject private var theme: TruoraTheme

    init(viewModel: InvoiceFeedbackViewModel, config: UIConfig?) {
        self.viewModel = viewModel
        self.theme = TruoraTheme(config: config)
    }

    var body: some View {
        VStack(spacing: 0) {
            TruoraHeaderView {
                viewModel.cancelTapped()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 16) {
                        InvoiceFeedbackIconView(
                            feedback: viewModel.feedback,
                            errorColor: theme.colors.error
                        )
                        .frame(width: 60, height: 80)

                        Text(feedbackTitle(for: viewModel.feedback))
                            .font(titleFont(for: viewModel.feedback))
                            .foregroundColor(theme.colors.error)
                            .multilineTextAlignment(.leading)
                    }

                    feedbackDescriptionView

                    if showsTipsLink(for: viewModel.feedback) {
                        Button {
                            viewModel.tipsTapped()
                        } label: {
                            Text(TruoraLocalization.string(forKey: LocalizationKeys.invoiceFeedbackTipsLink))
                                .font(Font.system(size: 16, weight: .medium))
                                .foregroundColor(theme.colors.primary)
                                .underline()
                        }
                        .padding(.top, 4)
                    }

                    contentImages
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
                        buttonText: TruoraLocalization.string(
                            forKey: LocalizationKeys.invoiceFeedbackRetry
                        ),
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
        .overlay(tipsOverlay)
    }

    @ViewBuilder
    private var tipsOverlay: some View {
        if viewModel.showTips {
            InvoiceTipsSheet(country: viewModel.country) {
                viewModel.showTips = false
            }
            .environmentObject(theme)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var contentImages: some View {
        if showsReferenceImages(for: viewModel.feedback) {
            // Horizontal row of sample invoice thumbnails (per Figma)
            let content = InvoiceCountryContent(country: viewModel.country)
            HStack(alignment: .top, spacing: 24) {
                ForEach(content.referenceImageNames, id: \.self) { imageName in
                    SwiftUI.Image(imageName, bundle: .truoraModule)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 104)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 16)
        }

        if showsCapturedImage(for: viewModel.feedback),
           let uiImage = viewModel.capturedImage {
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
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private var feedbackDescriptionView: some View {
        switch viewModel.feedback {
        case .documentNotFound, .documentNotRecognized, .wrongDocumentFound:
            notFoundDescription
        default:
            Text(feedbackDescription(for: viewModel.feedback))
                .font(theme.typography.bodyLarge)
                .foregroundColor(theme.colors.onSurface)
                .multilineTextAlignment(.leading)
        }
    }

    /// Description for "not found" scenarios with bold provider names.
    /// MX: "Asegurate de que sea de **CFE, TELMEX o Totalplay** como los que se muestran a continuacion:"
    @ViewBuilder
    private var notFoundDescription: some View {
        let content = InvoiceCountryContent(country: viewModel.country)
        let prefix = TruoraLocalization.string(forKey: content.feedbackNotFoundDescPrefixKey)
        let providers = TruoraLocalization.string(forKey: content.feedbackNotFoundProvidersKey)
        let suffix = TruoraLocalization.string(forKey: content.feedbackNotFoundDescSuffixKey)

        (
            Text(prefix)
                .font(theme.typography.bodyLarge)
                .foregroundColor(theme.colors.onSurface)
                + Text(providers)
                .font(Font.system(size: 16, weight: .bold))
                .foregroundColor(theme.colors.onSurface)
                + Text(suffix)
                .font(theme.typography.bodyLarge)
                .foregroundColor(theme.colors.onSurface)
        )
        .multilineTextAlignment(.leading)
    }

    private func showsCapturedImage(for feedback: FeedbackScenario) -> Bool {
        switch feedback {
        case .missingText, .blurryImage, .imageWithReflection, .lowLight,
             .grayscaleImage, .documentHasExpired,
             .documentNotFound, .documentNotRecognized, .wrongDocumentFound:
            true
        default:
            false
        }
    }

    private func showsReferenceImages(for feedback: FeedbackScenario) -> Bool {
        switch feedback {
        case .documentNotFound, .documentNotRecognized, .wrongDocumentFound:
            true
        default:
            false
        }
    }

    /// Tips link only shown for scenarios where the user can improve the capture (lighting, focus, glare).
    /// Not shown for not_found scenarios where the issue is the document type itself.
    private func showsTipsLink(for feedback: FeedbackScenario) -> Bool {
        switch feedback {
        case .missingText, .blurryImage, .imageWithReflection, .lowLight, .grayscaleImage:
            true
        default:
            false
        }
    }

    /// Per Figma: not_found uses 20pt bold, missing_text uses 19pt bold.
    private func titleFont(for feedback: FeedbackScenario) -> Font {
        switch feedback {
        case .documentNotFound, .documentNotRecognized, .wrongDocumentFound:
            Font.system(size: 20, weight: .bold)
        default:
            Font.system(size: 19, weight: .bold)
        }
    }

    private func feedbackTitle(for feedback: FeedbackScenario) -> String {
        let content = InvoiceCountryContent(country: viewModel.country)
        switch feedback {
        case .missingText:
            return TruoraLocalization.string(forKey: content.feedbackMissingTextTitleKey)
        case .documentNotFound, .documentNotRecognized, .wrongDocumentFound:
            return TruoraLocalization.string(forKey: content.feedbackNotFoundTitleKey)
        case .documentHasExpired:
            return TruoraLocalization.string(forKey: content.feedbackExpiredTitleKey)
        case .blurryImage:
            return TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackBlurryTitle)
        case .imageWithReflection:
            return TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackGlareTitle)
        case .lowLight, .grayscaleImage:
            return TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackDefaultTitle)
        default:
            return TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackDefaultTitle)
        }
    }

    private func feedbackDescription(for feedback: FeedbackScenario) -> String {
        let content = InvoiceCountryContent(country: viewModel.country)
        switch feedback {
        case .missingText:
            return TruoraLocalization.string(forKey: LocalizationKeys.invoiceFeedbackMissingTextDesc)
        case .documentHasExpired:
            return TruoraLocalization.string(forKey: content.feedbackExpiredDescKey)
        case .blurryImage, .lowLight, .grayscaleImage:
            return TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackBlurryDescription)
        case .imageWithReflection:
            return TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackGlareDescription)
        default:
            return TruoraLocalization.string(forKey: LocalizationKeys.documentFeedbackNoDocumentDescription)
        }
    }

    @ViewBuilder
    private var retriesText: some View {
        let fullText = TruoraLocalization.string(
            forKey: LocalizationKeys.invoiceFeedbackRetriesLeft,
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

/// Custom invoice icon shown on feedback screens.
/// - missing_text / reflection: adds yellow sparkle stars (glare indicator)
/// - document_not_found/recognized/wrongDocument: rotates -21.83° (tilted rejected document)
/// - All scenarios: red X badge overlay at bottom-left
private struct InvoiceFeedbackIconView: View {
    let feedback: FeedbackScenario
    let errorColor: Color
    @EnvironmentObject var theme: TruoraTheme

    private var showsSparkles: Bool {
        switch feedback {
        case .missingText, .imageWithReflection:
            true
        default:
            false
        }
    }

    private var rotationAngle: Double {
        switch feedback {
        case .documentNotFound, .documentNotRecognized, .wrongDocumentFound:
            -21.83
        default:
            0
        }
    }

    /// Per Figma: not_found uses a bigger illustration that gets clipped by the card,
    /// while missing_text fits a smaller illustration inside.
    private var illustrationSize: CGSize {
        switch feedback {
        case .documentNotFound, .documentNotRecognized, .wrongDocumentFound:
            CGSize(width: 58, height: 79.6)
        default:
            CGSize(width: 39, height: 54)
        }
    }

    /// Not-found scenarios offset the rotated illustration up-and-left so only the
    /// top-left corner peeks into the card (matches Figma node 1155:1818 where the
    /// illustration center sits at (0.26, 9.75) in the 45×63 card coord space —
    /// i.e. (-22.24, -21.75) from the card center).
    private var illustrationOffset: CGSize {
        switch feedback {
        case .documentNotFound, .documentNotRecognized, .wrongDocumentFound:
            CGSize(width: -22.24, height: -21.75)
        default:
            .zero
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Mini-card: fill + clipped illustration + sparkles, stroke overlayed on top.
            ZStack {
                Color(red: 0.76, green: 0.76, blue: 0.80) // #C2C2CB

                SwiftUI.Image("invoice_tip_illustration", bundle: .truoraModule)
                    .resizable()
                    .scaledToFit()
                    .frame(width: illustrationSize.width, height: illustrationSize.height)
                    .rotationEffect(.degrees(rotationAngle))
                    .offset(illustrationOffset)

                if showsSparkles {
                    // Matches TipCard.glare: white sparkles, larger size, two placements
                    SwiftUI.Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: -10, y: -14)
                    SwiftUI.Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 8, y: 6)
                }
            }
            .frame(width: 45, height: 63)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(errorColor, lineWidth: 1)
            )

            // Red X badge (bottom-center)
            ZStack {
                Circle()
                    .fill(errorColor)
                    .frame(width: 22, height: 22)
                SwiftUI.Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 2)
            .offset(x: 0, y: 6)
        }
        .frame(width: 60, height: 80)
    }
}

// MARK: - Tips Sheet (Bottom-anchored, horizontally-scrollable)

struct InvoiceTipsSheet: View {
    @EnvironmentObject var theme: TruoraTheme

    let country: String
    let onDismiss: () -> Void

    init(country: String, onDismiss: @escaping () -> Void = {}) {
        self.country = country
        self.onDismiss = onDismiss
    }

    var body: some View {
        let content = InvoiceCountryContent(country: country)

        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .extendingIntoSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                HStack {
                    Text(TruoraLocalization.string(forKey: LocalizationKeys.invoiceFeedbackTipsTitle))
                        .font(Font.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.colors.onSurface)
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        SwiftUI.Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.colors.onSurface)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)

                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        TipCard(
                            type: .corners,
                            caption: TruoraLocalization.string(forKey: content.feedbackTipCornersKey)
                        )
                        TipCard(
                            type: .glare,
                            caption: TruoraLocalization.string(forKey: content.feedbackTipGlareKey)
                        )
                        TipCard(
                            type: .angle,
                            caption: TruoraLocalization.string(forKey: LocalizationKeys.invoiceFeedbackTipAngle)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
            // Two-layer bg: outer layer fills the bottom safe area with the same
            // surface color, inner clipShape gives the top-rounded sheet look.
            // Without the outer layer, the home-indicator safe area was showing the
            // dim overlay through, as a lighter strip below the sheet.
            .background(theme.colors.surface.clipShape(TopRoundedRectangle(radius: 16)))
            .background(theme.colors.surface.edgesIgnoringSafeArea(.bottom))
        }
    }
}

/// Rounds only the top two corners — used for the bottom-anchored sheet card.
private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

/// Individual tip card shown inside the carousel.
/// Each card has a mini-illustration of the invoice with type-specific overlays and a colored border.
private struct TipCard: View {
    enum TipType {
        case corners // good example: 4 corners visible, green border
        case glare // bad example: sparkle stars, red border
        case angle // bad example: fold/angle overlay, red border
    }

    let type: TipType
    let caption: String
    @EnvironmentObject var theme: TruoraTheme

    private var borderColor: Color {
        switch type {
        case .corners:
            Color(red: 0.07, green: 0.84, blue: 0.49) // #12D57D success
        case .glare, .angle:
            Color(red: 1.0, green: 0.33, blue: 0.33) // #FF5454 error
        }
    }

    private var badgeIcon: String {
        switch type {
        case .corners: "checkmark"
        case .glare, .angle: "xmark"
        }
    }

    /// All badges straddle the card's bottom border (card is 130x170, so y=75 puts the
    /// 34pt badge overlapping the bottom stroke).
    private var badgeOffset: CGSize {
        CGSize(width: 0, height: 85)
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Base card with colored border
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.69, green: 0.73, blue: 0.79)) // #B1BACA
                    .frame(width: 130, height: 170)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 2)
                    )

                SwiftUI.Image("invoice_tip_illustration", bundle: .truoraModule)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 75, height: 105)

                overlayView

                // Status badge - check at bottom center (card 1), X at center (cards 2, 3)
                ZStack {
                    Circle()
                        .fill(borderColor)
                        .frame(width: 34, height: 34)
                    SwiftUI.Image(systemName: badgeIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: -2, y: 2)
                .offset(badgeOffset)
            }

            Text(caption)
                .font(Font.system(size: 14, weight: .regular))
                .foregroundColor(theme.colors.onSurface)
                .multilineTextAlignment(.center)
                .frame(width: 200)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var overlayView: some View {
        switch type {
        case .corners:
            // 4 green ring markers centered exactly on the invoice corners (75x105 centered)
            ZStack {
                Circle().stroke(borderColor, lineWidth: 2).frame(width: 11, height: 11).offset(x: -37.5, y: -52.5)
                Circle().stroke(borderColor, lineWidth: 2).frame(width: 11, height: 11).offset(x: 37.5, y: -52.5)
                Circle().stroke(borderColor, lineWidth: 2).frame(width: 11, height: 11).offset(x: -37.5, y: 52.5)
                Circle().stroke(borderColor, lineWidth: 2).frame(width: 11, height: 11).offset(x: 37.5, y: 52.5)
            }
        case .glare:
            // Sparkle stars (glare indicator) - larger for visibility
            ZStack {
                SwiftUI.Image(systemName: "sparkles")
                    .font(.system(size: 45, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: -20, y: -28)
                SwiftUI.Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: 15, y: 12)
            }
        case .angle:
            // Folded corner at TOP-LEFT of invoice. 26x26 square split by its diagonal:
            // - Upper-left triangle: card background color (what's "behind" the folded corner)
            // - Lower-right triangle: slightly darker than invoice (shadow cast on invoice)
            ZStack {
                // Upper-left triangle: card background color
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 26, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 26))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.69, green: 0.73, blue: 0.79)) // #B1BACA (card bg)

                // Lower-right triangle: slight shadow on invoice
                Path { path in
                    path.move(to: CGPoint(x: 26, y: 0))
                    path.addLine(to: CGPoint(x: 26, y: 26))
                    path.addLine(to: CGPoint(x: 0, y: 26))
                    path.closeSubpath()
                }
                .fill(Color(white: 0.82)) // slightly darker than invoice
            }
            .frame(width: 26, height: 26)
            .offset(x: -24.5, y: -39.5)
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
    }
    return image.pngData()
}

#Preview("Missing Text - MX") {
    InvoiceFeedbackView(
        viewModel: InvoiceFeedbackViewModel(
            feedback: .missingText,
            capturedImageData: createPlaceholderImageData(),
            retriesLeft: 1,
            country: "MX"
        ),
        config: nil
    )
}

#Preview("Missing Text - CO") {
    InvoiceFeedbackView(
        viewModel: InvoiceFeedbackViewModel(
            feedback: .missingText,
            capturedImageData: createPlaceholderImageData(),
            retriesLeft: 1,
            country: "CO"
        ),
        config: nil
    )
}

#Preview("Document Not Found - MX") {
    InvoiceFeedbackView(
        viewModel: InvoiceFeedbackViewModel(
            feedback: .documentNotFound,
            capturedImageData: createPlaceholderImageData(),
            retriesLeft: 2,
            country: "MX"
        ),
        config: nil
    )
}

#Preview("Document Not Found - CO") {
    InvoiceFeedbackView(
        viewModel: InvoiceFeedbackViewModel(
            feedback: .documentNotFound,
            capturedImageData: createPlaceholderImageData(),
            retriesLeft: 2,
            country: "CO"
        ),
        config: nil
    )
}

#Preview("Tips Sheet") {
    InvoiceTipsSheet(country: "MX")
        .environmentObject(TruoraTheme(config: nil))
}
