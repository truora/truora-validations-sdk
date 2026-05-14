//
//  InvoiceFeedbackViewModel.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import Foundation
import ImageIO
import UIKit

// MARK: - View Model

@MainActor final class InvoiceFeedbackViewModel: ObservableObject {
    let feedback: FeedbackScenario
    let capturedImageData: Data?
    /// Thumbnail decoded once at init via `ImageIO` so SwiftUI re-renders don't
    /// re-decode, and so we don't hold the full-resolution bitmap of a ~20 MB
    /// source in memory when the view only displays it at ~60 % of the screen
    /// width. See `decodeThumbnail(from:)` for the sizing rationale.
    let capturedImage: UIImage?
    let retriesLeft: Int
    let country: String
    var presenter: InvoiceFeedbackViewToPresenter?

    @Published var showTips = false

    init(
        feedback: FeedbackScenario,
        capturedImageData: Data?,
        retriesLeft: Int,
        country: String
    ) {
        self.feedback = feedback
        self.capturedImageData = capturedImageData
        self.capturedImage = capturedImageData.flatMap(Self.decodeThumbnail(from:))
        self.retriesLeft = retriesLeft
        self.country = country
    }

    /// Ceiling on the larger thumbnail edge (in pixels). 1200 px covers the
    /// widest iPhone / iPad at 3x when the image occupies ~60 % of the screen,
    /// while shrinking a 20 MB source from ~48 MB decoded bitmap to ~4 MB.
    private static let thumbnailMaxPixelSize: CGFloat = 1200

    /// Uses `CGImageSourceCreateThumbnailAtIndex` so decoding and downsampling
    /// happen in a single pass — `UIImage(data:)` would decode the full image
    /// into memory first, which is what this avoids.
    private static func decodeThumbnail(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    func onAppear() {
        guard let presenter else {
            debugLog("⚠️ InvoiceFeedbackViewModel: presenter is nil in onAppear")
            return
        }
        Task { await presenter.viewDidLoad() }
    }

    func onDisappear() {}

    func retryTapped() {
        Task { await presenter?.retryTapped() }
    }

    func tipsTapped() {
        showTips = true
    }

    func cancelTapped() {
        Task { await presenter?.cancelTapped() }
    }
}

// MARK: - InvoiceFeedbackPresenterToView

extension InvoiceFeedbackViewModel: InvoiceFeedbackPresenterToView {}
