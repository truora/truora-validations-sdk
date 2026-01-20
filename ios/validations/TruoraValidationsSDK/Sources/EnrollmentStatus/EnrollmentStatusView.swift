//
//  EnrollmentStatusView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import SwiftUI

class EnrollmentStatusViewModel: ObservableObject {
    @Published var statusText = "Checking enrollment status..."
    @Published var isChecking = true
    @Published var showError = false
    @Published var errorMessage: String?

    var presenter: EnrollmentStatusViewToPresenter?

    func onAppear() {
        presenter?.viewDidLoad()
    }
}

// MARK: - EnrollmentStatusPresenterToView

extension EnrollmentStatusViewModel: EnrollmentStatusPresenterToView {
    func showLoading() {
        DispatchQueue.main.async {
            self.isChecking = true
        }
    }

    func hideLoading() {
        DispatchQueue.main.async {
            self.isChecking = false
        }
    }

    func updateStatus(_ message: String) {
        DispatchQueue.main.async {
            self.statusText = message
        }
    }

    func showError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
}

struct EnrollmentStatusView: View {
    @ObservedObject var viewModel: EnrollmentStatusViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if viewModel.isChecking {
                LoadingIndicatorView(isAnimating: $viewModel.isChecking, style: .large, color: .systemBlue)
                    .scaleEffect(1.5)
            }

            Text(viewModel.statusText)
                .font(.system(size: 18))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer()
        }
        .navigationBarTitle("Enrollment Status", displayMode: .inline)
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
