//
//  ValidationConfigLogoTests.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 06/01/26.
//

import Foundation
import XCTest
@testable import TruoraValidationsSDK

@MainActor final class ValidationConfigLogoTests: XCTestCase {
    @MainActor private final class MockLogoDownloader: LogoDownloading {
        var downloadedUrl: URL?
        var resultToReturn: Result<Data, Error>?

        func downloadLogo(from url: URL) async throws -> Data {
            downloadedUrl = url
            guard let result = resultToReturn else {
                throw URLError(.unknown)
            }
            switch result {
            case .success(let data):
                return data
            case .failure(let error):
                throw error
            }
        }

        @discardableResult
        func downloadLogo(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) -> URLSessionDataTask? {
            downloadedUrl = url
            if let resultToReturn {
                completion(resultToReturn)
            }
            return nil
        }

        func downloadLogoSync(from url: URL) -> Result<Data, Error> {
            downloadedUrl = url
            return resultToReturn ?? .failure(URLError(.unknown))
        }
    }

    func testConfigureWithLogoUrlTriggersDownloadAndUpdatesUIConfigOnSuccess() async throws {
        let mock = MockLogoDownloader()
        mock.resultToReturn = .success(Data([0x0A, 0x0B, 0x0C]))
        let sut = ValidationConfig.makeForTesting(logoDownloader: mock)

        let uiConfig = UIConfig()
            .setLogo("https://example.com/logo.png", width: 111, height: 22)

        try await sut.configure(
            apiKey: "dummy-api-key",
            accountId: "user-1",
            delegate: nil,
            baseUrl: nil,
            uiConfig: uiConfig
        )

        XCTAssertEqual(mock.downloadedUrl?.absoluteString, "https://example.com/logo.png")
        XCTAssertNotNil(sut.uiConfig.customLogoData, "Logo should be set after successful download")
        XCTAssertEqual(sut.uiConfig.customLogoData?.count, 3)
        XCTAssertEqual(sut.uiConfig.logoWidth, 111)
        XCTAssertEqual(sut.uiConfig.logoHeight, 22)
    }

    func testConfigureWithLogoUrlDoesNotCrashOnDownloadFailure() async throws {
        let mock = MockLogoDownloader()
        mock.resultToReturn = .failure(URLError(.badServerResponse))
        let sut = ValidationConfig.makeForTesting(logoDownloader: mock)

        let uiConfig = UIConfig()
            .setLogo("https://example.com/logo.png")

        try await sut.configure(
            apiKey: "dummy-api-key",
            accountId: "user-1",
            delegate: nil,
            baseUrl: nil,
            uiConfig: uiConfig
        )

        XCTAssertEqual(mock.downloadedUrl?.absoluteString, "https://example.com/logo.png")
        XCTAssertNil(sut.uiConfig.customLogoData, "Logo should remain nil when download fails")
    }
}
