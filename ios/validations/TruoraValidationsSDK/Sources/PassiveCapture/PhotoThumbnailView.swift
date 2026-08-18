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

            // Status overlays: dim the thumbnail, then center a 24px indicator
            // (matches the Figma loading/success thumbnail states).
            if uploadState == .uploading || uploadState == .success {
                Color(red: 1.0 / 255.0, green: 12.0 / 255.0, blue: 35.0 / 255.0)
                    .opacity(0.28)
                    .frame(width: size, height: size)
            }

            if uploadState == .uploading {
                CircularSpinnerView(size: size * 0.5, lineWidth: size * 0.05, color: .white)
            } else if uploadState == .success {
                ZStack {
                    Circle()
                        .fill(theme.colors.layoutSuccess)
                        .frame(width: size * 0.5, height: size * 0.5)
                    SwiftUI.Image(systemName: "checkmark")
                        .font(.system(size: size * 0.29, weight: .bold))
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
