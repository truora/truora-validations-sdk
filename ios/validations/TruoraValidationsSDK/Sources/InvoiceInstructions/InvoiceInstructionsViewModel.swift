//
//  InvoiceInstructionsViewModel.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import Foundation

/// ViewModel for the invoice intro screen.
/// Uses @Published properties which automatically notify SwiftUI on the main thread.
@MainActor final class InvoiceInstructionsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    var presenter: InvoiceInstructionsViewToPresenter?

    func onAppear() {
        // Fires every time Instructions becomes visible — the presenter decides
        // whether work is needed (e.g., re-create validation for a retry flow).
        Task { await presenter?.viewDidLoad() }
    }

    func uploadFile() {
        Task { await presenter?.uploadFileTapped() }
    }

    func takePhoto() {
        Task { await presenter?.takePhotoTapped() }
    }

    func cancel() {
        Task { await presenter?.cancelTapped() }
    }
}

// MARK: - InvoiceInstructionsPresenterToView

extension InvoiceInstructionsViewModel: InvoiceInstructionsPresenterToView {
    func showLoading() {
        isLoading = true
    }

    func hideLoading() {
        isLoading = false
    }

    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
