//
//  TruoraNativeEnums.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 25/01/26.
//

import Foundation

// MARK: - NativeCountry

public enum NativeCountry: String, CaseIterable, Identifiable {
    case all
    case ar
    case br
    case cl
    case co
    case cr
    case mx
    case pe
    case sv
    case ve

    public var id: String {
        rawValue
    }

    /// Returns localized display name for the country
    public var displayName: String {
        let key = "country_\(rawValue)"
        return NSLocalizedString(key, bundle: .module, comment: "")
    }

    /// Returns the flag emoji for the country
    public var flagEmoji: String {
        switch self {
        case .all: "🌍"
        case .ar: "🇦🇷"
        case .br: "🇧🇷"
        case .cl: "🇨🇱"
        case .co: "🇨🇴"
        case .cr: "🇨🇷"
        case .mx: "🇲🇽"
        case .pe: "🇵🇪"
        case .sv: "🇸🇻"
        case .ve: "🇻🇪"
        }
    }

    /// Returns the list of available document types for this country
    public var documentTypes: [NativeDocumentType] {
        switch self {
        case .mx:
            [.nationalId, .taxId, .foreignId, .passport]
        case .br:
            [.cnh, .generalRegistration, .nationalId, .taxId]
        case .co:
            [.nationalId, .foreignId, .rut, .ppt, .passport, .identityCard, .taxId, .temporaryNationalId, .ptp]
        case .cl:
            [.nationalId, .foreignId, .driverLicense, .passport]
        case .cr:
            [.nationalId, .foreignId, .passport]
        case .pe:
            [.nationalId, .foreignId, .taxId, .ptp]
        case .ve:
            [.nationalId]
        case .all:
            [.passport]
        case .ar:
            [.nationalId]
        case .sv:
            [.nationalId, .foreignId, .passport]
        }
    }
}

// MARK: - NativeDocumentType

public enum NativeDocumentType: String, CaseIterable, Identifiable {
    case nationalId = "national-id"
    case identityCard = "identity-card"
    case foreignId = "foreign-id"
    case ppt
    case driverLicense = "driver-license"
    case cnh
    case passport
    case invoice
    case taxId = "tax-id"
    case ptp
    case rut
    case nativeNationalId = "native-national-id"
    case generalRegistration = "general-registration"
    case temporaryNationalId = "temporary-national-id"

    public var id: String {
        rawValue
    }

    /// Returns localized display label for the document type
    public var label: String {
        let key = switch self {
        case .nationalId: "document_type_national_id"
        case .identityCard: "document_type_identity_card"
        case .foreignId: "document_type_foreign_id"
        case .ppt: "document_type_ppt"
        case .driverLicense: "document_type_driver_license"
        case .cnh: "doc_br_cnh"
        case .passport: "document_type_passport"
        case .invoice: "document_type_invoice"
        case .taxId: "document_type_tax_id"
        case .ptp: "document_type_ptp"
        case .rut: "document_type_rut"
        case .nativeNationalId: "document_type_native_national_id"
        case .generalRegistration: "doc_br_general_reg"
        case .temporaryNationalId: "doc_co_temp_id"
        }
        return NSLocalizedString(key, bundle: .module, comment: "")
    }

    /// Returns localized description for the document type based on country context
    public func descriptionText(for country: NativeCountry) -> String? {
        let key: String? = switch country {
        case .mx:
            switch self {
            case .nationalId, .foreignId: "desc_original_valid"
            case .taxId: "desc_taxpayer_id"
            case .passport: "desc_mx_passport"
            default: nil
            }
        case .br:
            switch self {
            case .cnh, .generalRegistration: "desc_physical_original"
            default: nil
            }
        case .co:
            switch self {
            case .nationalId, .rut, .identityCard: "desc_physical_original"
            case .foreignId, .ppt: "desc_co_valid_issued"
            case .passport: "desc_co_passport"
            case .temporaryNationalId: "desc_co_temp_id"
            case .ptp: "doc_co_ppt"
            case .taxId: "desc_co_tax_id"
            default: nil
            }
        case .cl:
            switch self {
            case .nationalId: "desc_physical_original"
            case .foreignId, .driverLicense: "desc_cl_foreign_id"
            case .passport: "desc_cl_passport"
            default: nil
            }
        case .pe:
            switch self {
            case .nationalId: "desc_physical_original"
            default: nil
            }
        case .sv:
            "desc_sv_keep_hand"
        case .ve:
            self == .nationalId ? "desc_physical_original" : nil
        case .all:
            self == .passport ? "desc_original_valid" : nil
        case .ar:
            self == .nationalId ? "desc_physical_original" : nil
        case .cr:
            nil
        }
        guard let key else { return nil }
        return NSLocalizedString(key, bundle: .module, comment: "")
    }
}

// MARK: - DocumentCaptureSide

public enum DocumentCaptureSide: String {
    case front
    case back
}

// MARK: - DocumentFeedbackType

public enum DocumentFeedbackType: String {
    case none
    case searching
    case locate
    case closer
    case further
    case rotate
    case center
    case scanning
    case scanningManual = "scanning_manual"
    case multipleDocuments = "multiple_documents"
}

// MARK: - CaptureStatus

public enum CaptureStatus: String {
    case loading
    case success
}

// MARK: - FeedbackScenario

public enum FeedbackScenario: String {
    case blurryImage = "blurry_image"
    case imageWithReflection = "image_with_reflection"
    case documentNotFound = "document_not_found"
    case frontOfDocumentNotFound = "front_of_document_not_found"
    case backOfDocumentNotFound = "back_of_document_not_found"
    case faceNotFound = "face_not_found"
    case lowLight = "low_light"
}

// MARK: - DocumentAutoCaptureEvent

public enum DocumentAutoCaptureEvent {
    case helpRequested
    case helpDismissed
    case switchToManualMode
    case manualCaptureRequested
}
