//
//  PhotoThumbnailView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 25/01/26.
//

import SwiftUI
import UIKit

struct PhotoThumbnailView: View {
    let image: UIImage
    let uploadState: UploadState
    let size: CGFloat

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        ZStack {
            // Captured Image
            SwiftUI.Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipped()

            // Status Overlays
            if uploadState == .uploading {
                ZStack {
                    // Spinner #447AEE
                    ActivityIndicator(
                        isAnimating: .constant(true),
                        style: .large,
                        color: UIColor(red: 0.267, green: 0.478, blue: 0.933, alpha: 1.0)
                    )
                    .scaleEffect(1.4)
                }
            } else if uploadState == .success {
                ZStack {
                    Circle()
                        .fill(theme.colors.layoutSuccess)
                        .frame(width: size * 0.60, height: size * 0.60)
                    SwiftUI.Image(systemName: "checkmark")
                        .font(.system(size: size * 0.25, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(2)
    }
}

#Preview {
    HStack(spacing: 20) {
        if let image = UIImage(systemName: "person.fill") {
            PhotoThumbnailView(
                image: image,
                uploadState: .none,
                size: 80
            )

            PhotoThumbnailView(
                image: image,
                uploadState: .uploading,
                size: 80
            )

            PhotoThumbnailView(
                image: image,
                uploadState: .success,
                size: 80
            )
        }
    }
    .padding()
    .background(Color.gray)
    .environmentObject(TruoraTheme())
}
