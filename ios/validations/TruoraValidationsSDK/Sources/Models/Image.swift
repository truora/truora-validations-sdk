//
//  Image.swift
//  TruoraValidationsSDK
//
//  Created by Brayan Escobar on 10/11/25.
//

import Foundation

/// Represents an image for validation usage. Can be created from various
/// sources using factory methods.
public struct Image: Equatable {
    public let url: String?
    public let filePath: String?

    private init(url: String?, filePath: String?) {
        self.url = url
        self.filePath = filePath
    }

    public static func fromURL(_ url: String) -> Image {
        Image(url: url, filePath: nil)
    }

    public static func fromFile(_ filePath: String) -> Image {
        Image(url: nil, filePath: filePath)
    }
}
