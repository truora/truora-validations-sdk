//
//  ResultView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import SwiftUI
import TruoraShared

// MARK: - View State

enum ResultViewState {
    case loading
    case completed
    case result(ValidationResult)
}

// MARK: - ViewModel

class ResultViewModel: ObservableObject {
    @Published private(set) var viewState: ResultViewState = .loading
    @Published private(set) var isButtonLoading = false

    let loadingType: LoadingType

    var presenter: ResultViewToPresenter?

    init(loadingType: LoadingType = .face) {
        self.loadingType = loadingType
    }

    func onAppear() {
        presenter?.viewDidLoad()
    }

    func doneTapped() {
        presenter?.doneTapped()
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
        DispatchQueue.main.async { [weak self] in
            self?.viewState = .loading
        }
    }

    func showResult(_ result: ValidationResult) {
        DispatchQueue.main.async { [weak self] in
            self?.viewState = .result(result)
        }
    }

    func showCompleted() {
        DispatchQueue.main.async { [weak self] in
            self?.viewState = .completed
        }
    }

    func setLoadingButtonState(_ isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isButtonLoading = isLoading
        }
    }
}

// MARK: - Compose View Wrapper

private struct ResultComposeViewWrapper: UIViewControllerRepresentable {
    let validationResult: ValidationResultType
    let date: String
    let isLoading: Bool
    let showLoadingScreen: Bool
    let loadingType: LoadingType
    let onEvent: () -> Void
    let composeConfig: TruoraUIConfig

    func makeUIViewController(context _: Context) -> UIViewController {
        let containerVC = UIViewController()
        let composeVC = createViewController()
        embedChild(composeVC, in: containerVC)
        return containerVC
    }

    func updateUIViewController(_ containerVC: UIViewController, context _: Context) {
        // Remove existing child view controller properly
        for child in containerVC.children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        // Add new child view controller
        let composeVC = createViewController()
        embedChild(composeVC, in: containerVC)
    }

    private func embedChild(_ child: UIViewController, in parent: UIViewController) {
        parent.addChild(child)
        guard let childView = child.view else { return }
        guard let parentView = parent.view else { return }
        childView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(childView)
        NSLayoutConstraint.activate([
            childView.topAnchor.constraint(equalTo: parentView.topAnchor),
            childView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            childView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
        ])
        child.didMove(toParent: parent)
    }

    private func createViewController() -> UIViewController {
        TruoraUIExportsKt.createValidationResultViewController(
            validationResult: validationResult,
            date: date,
            isLoading: isLoading,
            showLoadingScreen: showLoadingScreen,
            loadingType: loadingType,
            onEvent: onEvent,
            config: composeConfig
        )
    }
}

// MARK: - View

struct ResultView: View {
    @ObservedObject var viewModel: ResultViewModel
    let composeConfig: TruoraUIConfig

    var body: some View {
        ResultComposeViewWrapper(
            validationResult: viewModel.validationResultType,
            date: viewModel.formattedDate,
            isLoading: viewModel.isButtonLoading,
            showLoadingScreen: viewModel.showLoadingScreen,
            loadingType: viewModel.loadingType,
            onEvent: { viewModel.doneTapped() },
            composeConfig: composeConfig
        )
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
        .onAppear {
            viewModel.onAppear()
        }
    }
}
