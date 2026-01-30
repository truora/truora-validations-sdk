//
//  ResultView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import SwiftUI

struct ResultView: View {
    @ObservedObject var viewModel: ResultViewModel
    @ObservedObject private var theme: TruoraTheme

    init(viewModel: ResultViewModel, config: UIConfig?) {
        self.viewModel = viewModel
        self.theme = TruoraTheme(config: config)
    }

    var body: some View {
        Group {
            if viewModel.showLoadingScreen {
                ValidationLoadingView(loadingType: viewModel.loadingType)
            } else {
                resultContent
            }
        }
        .environmentObject(theme)
        .navigationBarHidden(true)
        .onAppear {
            viewModel.onAppear()
        }
    }

    private var resultContent: some View {
        GeometryReader { geometry in
            let isPhone = geometry.size.width < 600
            let maxImageHeight: CGFloat = isPhone
                ? geometry.size.height * 0.35
                : min(500, geometry.size.height * 0.4)

            VStack(spacing: 0) {
                TruoraHeaderView(onCancel: nil)

                Spacer()

                // Result content based on state
                Group {
                    switch viewModel.validationResultType {
                    case .success:
                        SuccessResultContent(date: viewModel.formattedDate, maxImageHeight: maxImageHeight)
                    case .failure:
                        FailureResultContent(maxImageHeight: maxImageHeight)
                    case .completed:
                        CompletedResultContent(date: viewModel.formattedDate, maxImageHeight: maxImageHeight)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                TruoraFooterView(
                    securityTip: nil,
                    buttonText: TruoraValidationsSDKStrings.resultButtonLabel,
                    isLoading: viewModel.isButtonLoading
                ) {
                    viewModel.doneTapped()
                }
            }
            .background(theme.colors.surface)
        }
    }
}

// MARK: - Previews

@available(iOS 14.0, *)
private struct ResultViewLoadingPreview: View {
    @StateObject private var viewModel = ResultViewModel(loadingType: .face)
    var body: some View {
        ResultView(viewModel: viewModel, config: nil)
    }
}

@available(iOS 14.0, *)
private struct ResultViewSuccessPreview: View {
    @StateObject private var viewModel = ResultViewModel(loadingType: .face)
    var body: some View {
        ResultView(viewModel: viewModel, config: nil)
            .onAppear {
                viewModel.showResult(
                    ValidationResult(
                        validationId: "preview-123",
                        status: .success
                    )
                )
            }
    }
}

@available(iOS 14.0, *)
private struct ResultViewFailurePreview: View {
    @StateObject private var viewModel = ResultViewModel(loadingType: .face)
    var body: some View {
        ResultView(viewModel: viewModel, config: nil)
            .onAppear {
                viewModel.showResult(
                    ValidationResult(
                        validationId: "preview-456",
                        status: .failed
                    )
                )
            }
    }
}

@available(iOS 14.0, *)
private struct ResultViewCompletedPreview: View {
    @StateObject private var viewModel = ResultViewModel(loadingType: .document)
    var body: some View {
        ResultView(viewModel: viewModel, config: nil)
            .onAppear {
                viewModel.showCompleted()
            }
    }
}

#Preview("Loading") {
    if #available(iOS 14.0, *) {
        ResultViewLoadingPreview()
    }
}

#Preview("Success") {
    if #available(iOS 14.0, *) {
        ResultViewSuccessPreview()
    }
}

#Preview("Failure") {
    if #available(iOS 14.0, *) {
        ResultViewFailurePreview()
    }
}

#Preview("Completed") {
    if #available(iOS 14.0, *) {
        ResultViewCompletedPreview()
    }
}
