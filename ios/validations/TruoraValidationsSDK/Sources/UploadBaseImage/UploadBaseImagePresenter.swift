//
//  UploadBaseImagePresenter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import UIKit

class UploadBaseImagePresenter {
    weak var view: UploadBaseImagePresenterToView?
    var interactor: UploadBaseImagePresenterToInteractor?
    weak var router: ValidationRouter?
    private var selectedImage: UIImage?

    init(
        view: UploadBaseImagePresenterToView,
        interactor: UploadBaseImagePresenterToInteractor?,
        router: ValidationRouter
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
}

extension UploadBaseImagePresenter: UploadBaseImageViewToPresenter {
    func viewDidLoad() {}

    func selectImageTapped() {
        view?.showImagePicker()
    }

    func imageSelected(_ image: UIImage) {
        selectedImage = image
    }

    func uploadTapped() {
        guard let image = selectedImage else { return }
        view?.showLoading()
        interactor?.uploadImage(image)
    }

    func cancelTapped() {
        router?.handleCancellation()
    }
}

extension UploadBaseImagePresenter: UploadBaseImageInteractorToPresenter {
    func uploadCompleted() {
        view?.hideLoading()
        do {
            try router?.navigateToEnrollmentStatus()
        } catch {
            view?.showError(error.localizedDescription)
        }
    }

    func uploadFailed(_ error: ValidationError) {
        view?.hideLoading()
        view?.showError(error.localizedDescription)
    }
}
