//
//  AsyncImageView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import Combine
import SwiftUI
import UIKit

/// A cross-platform async image view that uses native AsyncImage on iOS 15+
/// and falls back to a Combine-based implementation for iOS 13-14.
struct AsyncImageView: View {
    let url: URL?
    let placeholder: SwiftUI.Image

    var body: some View {
        if #available(iOS 15.0, *) {
            // Use native AsyncImage on iOS 15+
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                case .failure:
                    placeholder.resizable()
                case .empty:
                    ProgressView()
                @unknown default:
                    placeholder.resizable()
                }
            }
        } else {
            // Fallback for iOS 13-14
            LegacyAsyncImageView(url: url, placeholder: placeholder)
        }
    }
}

// MARK: - Legacy Implementation for iOS 13-14

/// Combine-based async image loading for iOS 13-14 compatibility.
private struct LegacyAsyncImageView: View {
    let url: URL?
    let placeholder: SwiftUI.Image

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var subscription: AnyCancellable?

    var body: some View {
        Group {
            if let image {
                SwiftUI.Image(uiImage: image)
                    .resizable()
            } else if isLoading {
                ActivityIndicator(isAnimating: .constant(true), style: .medium)
            } else {
                placeholder
                    .resizable()
            }
        }
        .onAppear(perform: loadImage)
        .onDisappear(perform: cancelLoad)
    }

    private func loadImage() {
        guard let url, image == nil else { return }

        isLoading = true

        subscription = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { loadedImage in
                image = loadedImage
                isLoading = false
            }
    }

    private func cancelLoad() {
        subscription?.cancel()
    }
}

// MARK: - Previews

#Preview("With Valid URL") {
    AsyncImageView(
        url: URL(string: "https://picsum.photos/200"),
        placeholder: SwiftUI.Image(systemName: "photo")
    )
    .frame(width: 200, height: 200)
}

#Preview("With Invalid URL") {
    AsyncImageView(
        url: nil,
        placeholder: SwiftUI.Image(systemName: "photo")
    )
    .frame(width: 200, height: 200)
}
