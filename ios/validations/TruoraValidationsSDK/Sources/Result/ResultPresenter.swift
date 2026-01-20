//
//  ResultPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 21/12/25.
//

import Foundation
import TruoraShared

final class ResultPresenter {
    weak var view: ResultPresenterToView?
    var interactor: ResultPresenterToInteractor?
    weak var router: ValidationRouter?

    private let validationId: String
    private let shouldWaitForResults: Bool
    private let loadingType: LoadingType

    private var finalResult: ValidationResult?

    private var delegateCalled = false

    init(validationId: String, loadingType: LoadingType, shouldWaitForResults: Bool) {
        self.validationId = validationId
        self.loadingType = loadingType
        self.shouldWaitForResults = loadingType == .document ? true : shouldWaitForResults
    }

    deinit {
        interactor?.cancelPolling()
    }
}

// MARK: - ResultViewToPresenter

extension ResultPresenter: ResultViewToPresenter {
    func viewDidLoad() {
        if shouldWaitForResults {
            // Show loading and wait for result
            view?.showLoading()
            interactor?.startPolling()
        } else {
            // Show completed immediately, poll in background
            view?.showCompleted()
            interactor?.startPolling()
        }
    }

    func doneTapped() {
        guard let router else {
            print("⚠️ ResultPresenter: Router is nil, cannot dismiss flow")
            return
        }

        if shouldWaitForResults {
            guard let result = finalResult else {
                print("⚠️ ResultPresenter: Done tapped but no result yet")
                return
            }

            router.dismissFlow()
            notifyDelegate(with: result)
        } else {
            router.dismissFlow()
        }
    }
}

// MARK: - ResultInteractorToPresenter

extension ResultPresenter: ResultInteractorToPresenter {
    func pollingCompleted(result: ValidationResult) {
        finalResult = result
        print("🟢 ResultPresenter: Polling completed with status: \(result.status)")

        if shouldWaitForResults {
            // Update UI to show result
            view?.showResult(result)
        } else {
            // UI is already showing "Completed", just notify delegate
            notifyDelegate(with: result)
        }
    }

    func pollingFailed(error: ValidationError) {
        print("❌ ResultPresenter: Polling failed: \(error)")

        // Create a failed result for display purposes
        let failedResult = ValidationResult(
            validationId: validationId,
            status: .failed,
            confidence: nil,
            metadata: nil
        )
        finalResult = failedResult

        if shouldWaitForResults {
            view?.showResult(failedResult)
        } else {
            // Notify delegate of the error
            notifyDelegateError(error)
        }
    }
}

// MARK: - Private Methods

private extension ResultPresenter {
    func notifyDelegate(with result: ValidationResult) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !delegateCalled else {
            print("⚠️ ResultPresenter: Delegate already called, skipping")
            return
        }
        delegateCalled = true

        // Small delay to allow dismiss animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard self != nil else { return }
            ValidationConfig.shared.delegate?(.complete(result))
        }
    }

    func notifyDelegateError(_ error: ValidationError) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !delegateCalled else {
            print("⚠️ ResultPresenter: Delegate already called, skipping")
            return
        }
        delegateCalled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard self != nil else { return }
            ValidationConfig.shared.delegate?(.failure(error))
        }
    }
}
