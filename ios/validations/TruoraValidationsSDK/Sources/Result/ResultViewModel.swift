//
//  ResultViewModel.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Combine
import Foundation

enum ResultViewState {
    case loading
    case completed
    case result(ValidationResult)
}

/// ViewModel for the validation result screen.
/// Uses @Published properties which automatically notify SwiftUI on the main thread.
@MainActor final class ResultViewModel: ObservableObject {
    @Published private(set) var viewState: ResultViewState = .loading
    @Published private(set) var isButtonLoading = false

    let loadingType: ResultLoadingType

    var presenter: ResultViewToPresenter?

    init(loadingType: ResultLoadingType = .face) {
        self.loadingType = loadingType
    }

    func onAppear() {
        Task { await presenter?.viewDidLoad() }
    }

    func doneTapped() {
        Task { await presenter?.doneTapped() }
    }

    var validationResultType: ValidationResultType {
        switch viewState {
        case .loading:
            .completed // Placeholder, will show loading screen
        case .completed:
            .completed
        case .result(let result):
            switch result.status {
            case .success:
                .success
            case .failed:
                .failure
            case .pending, .processing:
                .completed
            }
        }
    }

    var showLoadingScreen: Bool {
        if case .loading = viewState {
            return true
        }
        return false
    }

    lazy var formattedDate: String = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }()
}

// MARK: - ResultPresenterToView

extension ResultViewModel: ResultPresenterToView {
    func showLoading() {
        viewState = .loading
    }

    func showResult(_ result: ValidationResult) {
        viewState = .result(result)
    }

    func showCompleted() {
        viewState = .completed
    }

    func setLoadingButtonState(_ isLoading: Bool) {
        isButtonLoading = isLoading
    }
}
