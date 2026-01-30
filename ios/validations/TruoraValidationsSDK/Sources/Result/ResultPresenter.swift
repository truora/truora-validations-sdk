//
//  ResultPresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 21/12/25.
//

import Foundation

final class ResultPresenter {
    weak var view: ResultPresenterToView?
    var interactor: ResultPresenterToInteractor?
    weak var router: ValidationRouter?

    private let validationId: String
    private let shouldWaitForResults: Bool
    private let loadingType: ResultLoadingType
    private let timeProvider: TimeProvider

    private var finalResult: ValidationResult?

    private var delegateCalled = false

    init(
        view: ResultPresenterToView,
        interactor: ResultPresenterToInteractor?,
        router: ValidationRouter,
        loadingType: ResultLoadingType,
        timeProvider: TimeProvider = RealTimeProvider()
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.validationId = interactor?.validationId ?? ""
        self.loadingType = loadingType
        self.timeProvider = timeProvider

        let configWaitForResults = switch loadingType {
        case .face: ValidationConfig.shared.faceConfig.shouldWaitForResults
        case .document: ValidationConfig.shared.documentConfig.shouldWaitForResults
        }

        // Document validation always waits for results in current implementation
        self.shouldWaitForResults = loadingType == .document ? true : configWaitForResults
    }

    deinit {
        interactor?.cancelPolling()
    }
}

// MARK: - ResultViewToPresenter

extension ResultPresenter: ResultViewToPresenter {
    func viewDidLoad() async {
        if shouldWaitForResults {
            // Show loading and wait for result
            await view?.showLoading()
            interactor?.startPolling()
        } else {
            // Show completed immediately, poll in background
            await view?.showCompleted()
            interactor?.startPolling()
        }
    }

    func doneTapped() async {
        guard let router else {
            print("⚠️ ResultPresenter: Router is nil, cannot dismiss flow")
            return
        }

        if shouldWaitForResults {
            guard let result = finalResult else {
                print("⚠️ ResultPresenter: Done tapped but no result yet")
                return
            }

            await router.dismissFlow()
            await notifyDelegate(with: result)
        } else {
            await router.dismissFlow()
        }
    }
}

// MARK: - ResultInteractorToPresenter

extension ResultPresenter: ResultInteractorToPresenter {
    func pollingCompleted(result: ValidationResult) async {
        finalResult = result
        print("🟢 ResultPresenter: Polling completed with status: \(result.status)")

        if shouldWaitForResults {
            // Update UI to show result
            await view?.showResult(result)
        } else {
            // UI is already showing "Completed", just notify delegate
            await notifyDelegate(with: result)
        }
    }

    func pollingFailed(error: TruoraException) async {
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
            await view?.showResult(failedResult)
        } else {
            // Notify delegate of the error
            await notifyDelegateError(error)
        }
    }
}

// MARK: - Private Methods

private extension ResultPresenter {
    func notifyDelegate(with result: ValidationResult) async {
        guard !delegateCalled else {
            print("⚠️ ResultPresenter: Delegate already called, skipping")
            return
        }
        delegateCalled = true

        // Small delay to allow dismiss animation to complete
        try? await timeProvider.sleep(nanoseconds: 100_000_000)

        await MainActor.run {
            ValidationConfig.shared.delegate?(.complete(result))
        }
    }

    func notifyDelegateError(_ error: TruoraException) async {
        guard !delegateCalled else {
            print("⚠️ ResultPresenter: Delegate already called, skipping")
            return
        }
        delegateCalled = true

        try? await timeProvider.sleep(nanoseconds: 100_000_000)

        await MainActor.run {
            ValidationConfig.shared.delegate?(.failure(error))
        }
    }
}
