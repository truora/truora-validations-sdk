//
//  LogoDownloaderTests.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 06/01/26.
//

import Foundation
import XCTest
@testable import TruoraValidationsSDK

// MARK: - Test Helpers

private struct URLProtocolStubResponse {
    let data: Data?
    let response: URLResponse?
    let error: Error?
}

private final class URLProtocolStub: URLProtocol {
    static var stub: URLProtocolStubResponse?

    override static func canInit(with _: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = Self.stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        if let response = stub.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data = stub.data {
            client?.urlProtocol(self, didLoad: data)
        }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

// MARK: - Async Tests

final class LogoDownloaderAsyncTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.stub = nil
        super.tearDown()
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    func testDownloadLogoSuccessReturnsData() {
        let url = URL(string: "https://example.com/logo.png")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/png"]
        )!
        // Valid PNG magic bytes
        let expected = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        URLProtocolStub.stub = .init(data: expected, response: response, error: nil)

        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        _ = sut.downloadLogo(from: url) { result in
            switch result {
            case .success(let data):
                XCTAssertEqual(data, expected)
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testDownloadLogoRejectsNonHttps() {
        let url = URL(string: "http://example.com/logo.png")!
        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        let task = sut.downloadLogo(from: url) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertEqual(error as? LogoDownloaderError, .insecureUrl)
            }
            exp.fulfill()
        }

        XCTAssertNil(task, "Non-https URLs should not create a URLSessionDataTask")
        wait(for: [exp], timeout: 1.0)
    }

    func testDownloadLogoRejectsNonImageContentType() {
        let url = URL(string: "https://example.com/logo")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/html"]
        )!
        URLProtocolStub.stub = .init(data: Data([0x00]), response: response, error: nil)

        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        _ = sut.downloadLogo(from: url) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                guard case .invalidContentType = (error as? LogoDownloaderError) else {
                    XCTFail("Expected invalidContentType, got: \(error)")
                    exp.fulfill()
                    return
                }
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testDownloadLogoRejectsOversizedBody() {
        let url = URL(string: "https://example.com/logo.png")!
        let tooBig = Data(count: 5 * 1024 * 1024 + 1)
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/png"]
        )!
        URLProtocolStub.stub = .init(data: tooBig, response: response, error: nil)

        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        _ = sut.downloadLogo(from: url) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                guard case .sizeExceeded = (error as? LogoDownloaderError) else {
                    XCTFail("Expected sizeExceeded, got: \(error)")
                    exp.fulfill()
                    return
                }
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }
}

// MARK: - Sync Tests

final class LogoDownloaderSyncTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.stub = nil
        super.tearDown()
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    func testDownloadLogoSync_success() {
        // Valid JPEG magic bytes
        let testData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let testUrl = URL(string: "https://example.com/logo.png")!
        let response = HTTPURLResponse(
            url: testUrl,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/jpeg"]
        )
        URLProtocolStub.stub = URLProtocolStubResponse(data: testData, response: response, error: nil)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let sut = LogoDownloader(session: URLSession(configuration: config))

        let result = sut.downloadLogoSync(from: testUrl)

        switch result {
        case .success(let data):
            XCTAssertEqual(data, testData)
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testDownloadLogoSync_insecureUrl() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let sut = LogoDownloader(session: URLSession(configuration: config))

        let result = sut.downloadLogoSync(from: URL(string: "http://example.com/logo.png")!)

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error as? LogoDownloaderError, .insecureUrl)
        }
    }

    func testDownloadLogoSync_httpError() {
        let testUrl = URL(string: "https://example.com/logo.png")!
        URLProtocolStub.stub = URLProtocolStubResponse(
            data: nil,
            response: HTTPURLResponse(url: testUrl, statusCode: 404, httpVersion: nil, headerFields: nil),
            error: nil
        )

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let sut = LogoDownloader(session: URLSession(configuration: config))

        let result = sut.downloadLogoSync(from: testUrl)

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error as? LogoDownloaderError, .httpError(statusCode: 404))
        }
    }

    func testDownloadLogoSync_invalidContentType() {
        let testUrl = URL(string: "https://example.com/logo.png")!
        URLProtocolStub.stub = URLProtocolStubResponse(
            data: Data([0x42]),
            response: HTTPURLResponse(
                url: testUrl,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html"]
            ),
            error: nil
        )

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let sut = LogoDownloader(session: URLSession(configuration: config))

        let result = sut.downloadLogoSync(from: testUrl)

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error as? LogoDownloaderError, .invalidContentType("text/html"))
        }
    }

    func testDownloadLogoSync_emptyData() {
        let testUrl = URL(string: "https://example.com/logo.png")!
        let response = HTTPURLResponse(
            url: testUrl,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/png"]
        )
        URLProtocolStub.stub = URLProtocolStubResponse(data: Data(), response: response, error: nil)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let sut = LogoDownloader(session: URLSession(configuration: config))

        let result = sut.downloadLogoSync(from: testUrl)

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error as? LogoDownloaderError, .invalidResponse)
        }
    }
}

// MARK: - Async Tests (Additional)

extension LogoDownloaderAsyncTests {
    func testDownloadLogoRejectsMissingContentType() {
        let url = URL(string: "https://example.com/logo.png")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        // Valid PNG data but no Content-Type
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        URLProtocolStub.stub = .init(data: data, response: response, error: nil)

        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        _ = sut.downloadLogo(from: url) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                guard case .invalidContentType = (error as? LogoDownloaderError) else {
                    XCTFail("Expected invalidContentType, got: \(error)")
                    exp.fulfill()
                    return
                }
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testDownloadLogoRejectsInvalidImageData() {
        let url = URL(string: "https://example.com/logo.png")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/png"]
        )!
        // Invalid magic bytes
        let data = Data([0x00, 0x01, 0x02, 0x03])
        URLProtocolStub.stub = .init(data: data, response: response, error: nil)

        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        _ = sut.downloadLogo(from: url) { result in
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertEqual(error as? LogoDownloaderError, .invalidImageData)
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testDownloadLogoAcceptsPNG() {
        let url = URL(string: "https://example.com/logo.png")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/png"]
        )!
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        URLProtocolStub.stub = .init(data: data, response: response, error: nil)

        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        _ = sut.downloadLogo(from: url) { result in
            switch result {
            case .success(let data):
                XCTAssertEqual(data[0], 0x89)
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testDownloadLogoAcceptsJPEG() {
        let url = URL(string: "https://example.com/logo.jpg")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/jpeg"]
        )!
        let data = Data([0xFF, 0xD8, 0xFF, 0xE0])
        URLProtocolStub.stub = .init(data: data, response: response, error: nil)

        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        _ = sut.downloadLogo(from: url) { result in
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testDownloadLogoAcceptsGIF() {
        let url = URL(string: "https://example.com/logo.gif")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/gif"]
        )!
        let data = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])
        URLProtocolStub.stub = .init(data: data, response: response, error: nil)

        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        _ = sut.downloadLogo(from: url) { result in
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testDownloadLogoAcceptsWebP() {
        let url = URL(string: "https://example.com/logo.webp")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/webp"]
        )!
        let data = Data([0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50])
        URLProtocolStub.stub = .init(data: data, response: response, error: nil)

        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        _ = sut.downloadLogo(from: url) { result in
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    func testDownloadLogoAcceptsSVG() {
        let url = URL(string: "https://example.com/logo.svg")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/svg+xml"]
        )!
        let svgData = Data("<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>".utf8)
        URLProtocolStub.stub = .init(data: svgData, response: response, error: nil)

        let sut = LogoDownloader(session: makeSession())
        let exp = expectation(description: "download completes")

        _ = sut.downloadLogo(from: url) { result in
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }
}
