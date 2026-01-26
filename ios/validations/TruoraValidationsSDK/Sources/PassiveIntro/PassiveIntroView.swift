//
//  PassiveIntroView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 31/10/25.
//

import SwiftUI
import TruoraShared

class PassiveIntroViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    var presenter: PassiveIntroViewToPresenter?

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

extension PassiveIntroViewModel: PassiveIntroPresenterToView {
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

struct ComposeViewWrapper: UIViewControllerRepresentable {
    let onStart: () -> Void
    let onCancel: () -> Void
    let composeConfig: TruoraUIConfig

    func makeUIViewController(context _: Context) -> UIViewController {
        TruoraUIExportsKt.createPassiveIntroViewController(
            onStart: onStart,
            onCancel: onCancel,
            config: composeConfig
        )
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}
}

struct PassiveIntroView: View {
    @ObservedObject var viewModel: PassiveIntroViewModel
    let composeConfig: TruoraUIConfig

    var body: some View {
        ZStack {
            ComposeViewWrapper(
                onStart: { viewModel.start() },
                onCancel: { viewModel.cancel() },
                composeConfig: composeConfig
            )
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
