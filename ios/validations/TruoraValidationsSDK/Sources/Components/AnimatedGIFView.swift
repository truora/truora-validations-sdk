//
//  AnimatedGIFView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 04/03/26.
//

import ImageIO
import SwiftUI
import UIKit

struct AnimatedGIFView: UIViewRepresentable {
    let gifName: String
    var tintColor: UIColor?
    var size: CGSize

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: size.width),
            imageView.heightAnchor.constraint(equalToConstant: size.height),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        guard let url = Bundle.truoraModule.url(forResource: gifName, withExtension: "gif"),
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return container }

        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var totalDuration: Double = 0

        for index in 0 ..< count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            var frame = UIImage(cgImage: cgImage)
            if tintColor != nil {
                frame = frame.withRenderingMode(.alwaysTemplate)
            }
            images.append(frame)
            let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any]
            let gifProps = props?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            let delay = gifProps?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                ?? gifProps?[kCGImagePropertyGIFDelayTime as String] as? Double
                ?? 0.1
            totalDuration += delay
        }

        imageView.image = UIImage.animatedImage(with: images, duration: totalDuration)
        if let tintColor {
            imageView.tintColor = tintColor
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let imageView = uiView.subviews.first as? UIImageView,
              let tintColor else { return }
        imageView.tintColor = tintColor
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        guard let imageView = uiView.subviews.first as? UIImageView else { return }
        imageView.stopAnimating()
        imageView.image = nil
    }
}
