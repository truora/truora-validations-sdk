//
//  DocumentIntroView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/12/25.
//

import SwiftUI
import TruoraShared

class DocumentIntroViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    var presenter: DocumentIntroViewToPresenter?

    func onAppear() {
        presenter?.viewDidLoad()
    }

    func start() {
        presenter?.startTapped()
    }

    func cancel() {
        presenter?.cancelTapped()
    }
}

extension DocumentIntroViewModel: DocumentIntroPresenterToView {
    func showLoading() {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }

    func hideLoading() {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }

    func showError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
}

// MARK: - Compose UI Integration

struct ComposeDocumentIntroWrapper: UIViewControllerRepresentable {
    let isLoading: Bool
    let onEvent: (DocumentAutoCaptureIntroEvent) -> Void
    let composeConfig: TruoraUIConfig

    func makeUIViewController(context _: Context) -> UIViewController {
        TruoraUIExportsKt.createDocumentIntroViewController(
            isLoading: isLoading,
            showHeader: true,
            onEvent: onEvent,
            config: composeConfig
        )
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}
}

struct DocumentIntroView: View {
    @ObservedObject var viewModel: DocumentIntroViewModel
    let composeConfig: TruoraUIConfig

    var body: some View {
        ZStack {
            ComposeDocumentIntroWrapper(
                isLoading: viewModel.isLoading,
                onEvent: { event in
                    if event is DocumentAutoCaptureIntroEventStartClicked {
                        viewModel.start()
                        return
                    }
                    if event is DocumentAutoCaptureIntroEventCancelClicked {
                        viewModel.cancel()
                        return
                    }
                },
                composeConfig: composeConfig
            )
            .id(viewModel.isLoading)
            .edgesIgnoringSafeArea(.all)
            .navigationBarHidden(true)

            if viewModel.isLoading {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    LoadingIndicatorView(
                        isAnimating: .constant(viewModel.isLoading),
                        style: .large,
                        color: .white
                    )

                    Text("Creating validation...")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: viewModel.errorMessage.map { Text($0) },
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

private struct LoadingIndicatorView: UIViewRepresentable {
    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style
    let color: UIColor

    func makeUIView(context _: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: style)
        indicator.color = color
        return indicator
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context _: Context) {
        if isAnimating {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }
}
