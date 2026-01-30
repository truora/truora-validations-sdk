//
//  PassiveIntroViewModel.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import Combine
import Foundation

/// ViewModel for the passive face capture intro screen.
/// Uses @Published properties which automatically notify SwiftUI on the main thread.
@MainActor final class PassiveIntroViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showCancelButton = true

    var presenter: PassiveIntroViewToPresenter?

    func onAppear() {
        Task { await presenter?.viewDidLoad() }
    }

    func start() {
        Task { await presenter?.startTapped() }
    }

    func cancel() {
        Task { await presenter?.cancelTapped() }
    }
}

// MARK: - PassiveIntroPresenterToView

extension PassiveIntroViewModel: PassiveIntroPresenterToView {
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
