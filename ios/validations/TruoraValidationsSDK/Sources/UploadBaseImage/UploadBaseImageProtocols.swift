//
//  UploadBaseImageProtocols.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import Foundation
import UIKit

protocol UploadBaseImagePresenterToView: AnyObject {
    func showLoading()
    func hideLoading()
    func showError(_ message: String)
    func showImagePicker()
}

protocol UploadBaseImageViewToPresenter: AnyObject {
    func viewDidLoad()
    func selectImageTapped()
    func imageSelected(_ image: UIImage)
    func uploadTapped()
    func cancelTapped()
}

protocol UploadBaseImagePresenterToInteractor: AnyObject {
    func uploadImage(_ image: UIImage)
}

protocol UploadBaseImageInteractorToPresenter: AnyObject {
    func uploadCompleted()
    func uploadFailed(_ error: ValidationError)
}
