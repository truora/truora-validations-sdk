//
//  DocumentSelectionInteractor.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 07/01/26.
//

import Foundation

final class DocumentSelectionInteractor {
    weak var presenter: DocumentSelectionInteractorToPresenter?
    private let logger: TruoraLogger

    /// Constants for logging
    private static let viewName = "doc_selection"
    private static let validationType = "document_validation"

    init(
        presenter: DocumentSelectionInteractorToPresenter?,
        logger: TruoraLogger
    ) {
        self.presenter = presenter
        self.logger = logger
    }
}

extension DocumentSelectionInteractor: DocumentSelectionPresenterToInteractor {
    func fetchSupportedCountries() {
        let allCountries: [NativeCountry] = [
            .all, .ar, .bo, .br, .cl, .co, .cr, .ec, .mx, .pe, .sv, .ve
        ]

        let documentConfig = ValidationConfig.shared.documentConfig
        let allowedCountries = documentConfig.allowedCountriesList

        let filtered: [NativeCountry] = if allowedCountries.isEmpty {
            allCountries
        } else {
            allCountries.filter { country in
                allowedCountries.contains { $0.lowercased() == country.rawValue }
            }
        }

        Task { await presenter?.didLoadCountries(filtered) }
    }

    // MARK: - Logging Methods

    func logViewRendered() async {
        await logger.logView(
            viewName: "render_\(Self.viewName)_succeeded",
            level: .info,
            retention: .oneWeek,
            metadata: [
                "name": Self.viewName,
                "validation_type": Self.validationType
            ]
        )
    }

    func logContinueButtonClicked(selectedCountry: NativeCountry?, selectedDocument: NativeDocumentType?) async {
        var metadata: [String: Any] = [
            "name": Self.viewName,
            "validation_type": Self.validationType
        ]
        if let country = selectedCountry {
            metadata["selected_country"] = country.rawValue
        }
        if let document = selectedDocument {
            metadata["selected_document"] = document.rawValue
        }
        await logger.logView(
            viewName: "continue_button_clicked",
            level: .info,
            retention: .oneWeek,
            metadata: metadata
        )
    }

    func logCancelButtonClicked() async {
        await logger.logView(
            viewName: "cancel_button_clicked",
            level: .info,
            retention: .oneWeek,
            metadata: [
                "name": Self.viewName,
                "validation_type": Self.validationType
            ]
        )
    }

    func createValidation(accountId: String) async throws -> NativeValidationCreateResponse {
        guard let apiClient = ValidationConfig.shared.apiClient else {
            throw TruoraException.sdk(SDKError(type: .invalidConfiguration, details: "API client not configured"))
        }

        let documentConfig = ValidationConfig.shared.documentConfig
        let request = NativeValidationRequest(
            type: NativeValidationTypeEnum.documentValidation.rawValue,
            country: documentConfig.country.lowercased(),
            accountId: accountId,
            threshold: nil,
            subvalidations: nil,
            documentType: documentConfig.documentType,
            timeout: documentConfig.timeout,
            userAuthorized: true,
            checkManualReviewAvailability: true
        )

        return try await apiClient.createValidation(request: request)
    }

    func fetchDocumentExample(country: String, documentType: String) async -> URL? {
        guard let apiClient = ValidationConfig.shared.apiClient else { return nil }

        do {
            let response = try await apiClient.getDocumentSelection()
            let matchedCountry = response.countries.first {
                $0.country.lowercased() == country.lowercased()
            }
            let matchedDocType = matchedCountry?.documentTypes.first {
                $0.documentType.lowercased() == documentType.lowercased()
            }
            guard let urlString = matchedDocType?.examples.first?.url else { return nil }
            return URL(string: urlString)
        } catch {
            debugLog("⚠️ DocumentSelectionInteractor: Failed to fetch document example: \(error)")
            return nil
        }
    }
}
