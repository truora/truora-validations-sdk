//
//  UploadBaseImageInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import UIKit

class UploadBaseImageInteractor {
    weak var presenter: UploadBaseImageInteractorToPresenter?
    let enrollmentData: EnrollmentData

    init(presenter: UploadBaseImageInteractorToPresenter, enrollmentData: EnrollmentData) {
        self.presenter = presenter
        self.enrollmentData = enrollmentData
    }
}

extension UploadBaseImageInteractor: UploadBaseImagePresenterToInteractor {
    func uploadImage(_ image: UIImage) {
        print("🟢 UploadBaseImageInteractor: Uploading image (size: \(image.size))...")

        guard presenter != nil else {
            print("❌ UploadBaseImageInteractor: Presenter is nil")
            return
        }

        // Simulate upload with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else {
                print("❌ UploadBaseImageInteractor: Self deallocated before completion")
                return
            }

            print("🟢 UploadBaseImageInteractor: Image upload completed for enrollment " +
                "\(self.enrollmentData.enrollmentId)")
            self.presenter?.uploadCompleted()
        }
    }
}
