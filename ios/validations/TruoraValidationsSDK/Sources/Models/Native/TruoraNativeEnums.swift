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
    case bo
    case br
    case cl
    case co
    case cr
    case ec
    case mx
    case pe
    case sv
    case ve

    public var id: String {
        rawValue
    }

    /// Returns localized display name for the country
    public var displayName: String {
        TruoraLocalization.string(forKey: LocalizationKeys.countryKey(isoCode: rawValue))
    }

    /// Returns the flag emoji for the country
    public var flagEmoji: String {
        switch self {
        case .all: "🌍"
        case .ar: "🇦🇷"
        case .bo: "🇧🇴"
        case .br: "🇧🇷"
        case .cl: "🇨🇱"
        case .co: "🇨🇴"
        case .cr: "🇨🇷"
        case .ec: "🇪🇨"
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
        case .bo:
            [.nationalId]
        case .br:
            [.cnh, .generalRegistration]
        case .co:
            [.nationalId, .foreignId, .rut, .ppt, .passport, .identityCard, .temporaryNationalId]
        case .cl:
            [.nationalId, .foreignId, .driverLicense, .passport]
        case .cr:
            [.nationalId, .foreignId]
        case .ec:
            [.nationalId]
        case .pe:
            [.nationalId, .foreignId]
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

    /// Returns generic localized display label for the document type
    public var label: String {
        TruoraLocalization.string(forKey: genericLabelKey)
    }

    /// Returns localized display label for the document type based on country context
    public func label(for country: NativeCountry) -> String {
        TruoraLocalization.string(forKey: labelKey(for: country))
    }

    /// Returns the localization key for a specific country, or generic if not available
    private func labelKey(for country: NativeCountry) -> String {
        switch country {
        case .mx: labelKeyForMx
        case .br: labelKeyForBr
        case .co: labelKeyForCo
        case .cl: labelKeyForCl
        case .pe: labelKeyForPe
        case .ve: labelKeyForVe
        case .ar: labelKeyForAr
        case .bo: labelKeyForBo
        case .sv: labelKeyForSv
        case .cr: labelKeyForCr
        case .ec: labelKeyForEc
        case .all: genericLabelKey
        }
    }

    private var labelKeyForMx: String {
        switch self {
        case .nationalId: LocalizationKeys.docMxNationalId
        case .taxId: LocalizationKeys.docMxTaxId
        case .foreignId: LocalizationKeys.docMxForeignId
        default: genericLabelKey
        }
    }

    private var labelKeyForBr: String {
        switch self {
        case .cnh: LocalizationKeys.docBrCnh
        case .generalRegistration: LocalizationKeys.docBrGeneralReg
        case .nationalId: LocalizationKeys.docBrNationalId
        case .taxId: LocalizationKeys.docBrTaxId
        default: genericLabelKey
        }
    }

    private var labelKeyForCo: String {
        switch self {
        case .nationalId: LocalizationKeys.docCoNationalId
        case .foreignId: LocalizationKeys.docCoForeignId
        case .ppt: LocalizationKeys.docCoPpt
        case .taxId: LocalizationKeys.docCoTaxId
        case .temporaryNationalId: LocalizationKeys.docCoTempId
        case .ptp: LocalizationKeys.docCoPtp
        default: genericLabelKey
        }
    }

    private var labelKeyForCl: String {
        switch self {
        case .nationalId: LocalizationKeys.docClNationalId
        default: genericLabelKey
        }
    }

    private var labelKeyForPe: String {
        switch self {
        case .nationalId: LocalizationKeys.docPeNationalId
        case .foreignId: LocalizationKeys.docPeForeignId
        case .taxId: LocalizationKeys.docPeTaxId
        case .ptp: LocalizationKeys.docPePtp
        default: genericLabelKey
        }
    }

    private var labelKeyForVe: String {
        switch self {
        case .nationalId: LocalizationKeys.docVeNationalId
        default: genericLabelKey
        }
    }

    private var labelKeyForAr: String {
        switch self {
        case .nationalId: LocalizationKeys.docArNationalId
        default: genericLabelKey
        }
    }

    private var labelKeyForBo: String {
        switch self {
        case .nationalId: LocalizationKeys.docBoNationalId
        default: genericLabelKey
        }
    }

    private var labelKeyForSv: String {
        switch self {
        case .nationalId: LocalizationKeys.docSvNationalId
        case .foreignId: LocalizationKeys.docSvForeignId
        default: genericLabelKey
        }
    }

    private var labelKeyForEc: String {
        switch self {
        case .nationalId: LocalizationKeys.docEcNationalId
        default: genericLabelKey
        }
    }

    private var labelKeyForCr: String {
        switch self {
        case .nationalId: LocalizationKeys.docCrNationalId
        case .foreignId: LocalizationKeys.docCrForeignId
        default: genericLabelKey
        }
    }

    /// Returns the generic localization key for this document type
    private var genericLabelKey: String {
        switch self {
        case .nationalId: LocalizationKeys.documentTypeNationalId
        case .identityCard: LocalizationKeys.documentTypeIdentityCard
        case .foreignId: LocalizationKeys.documentTypeForeignId
        case .ppt: LocalizationKeys.documentTypePpt
        case .driverLicense: LocalizationKeys.documentTypeDriverLicense
        case .cnh: LocalizationKeys.docBrCnh
        case .passport: LocalizationKeys.documentTypePassport
        case .invoice: LocalizationKeys.documentTypeInvoice
        case .taxId: LocalizationKeys.documentTypeTaxId
        case .ptp: LocalizationKeys.documentTypePtp
        case .rut: LocalizationKeys.documentTypeRut
        case .nativeNationalId: LocalizationKeys.documentTypeNativeNationalId
        case .generalRegistration: LocalizationKeys.docBrGeneralReg
        case .temporaryNationalId: LocalizationKeys.docCoTempId
        }
    }

    /// Returns localized description for the document type based on country context
    public func descriptionText(for country: NativeCountry) -> String? {
        let key: String? = switch country {
        case .mx:
            switch self {
            case .nationalId, .foreignId: LocalizationKeys.descOriginalValid
            case .taxId: LocalizationKeys.descTaxpayerId
            case .passport: LocalizationKeys.descMxPassport
            default: nil
            }
        case .br:
            switch self {
            case .cnh, .generalRegistration: LocalizationKeys.descPhysicalOriginal
            case .taxId: LocalizationKeys.descTaxpayerId
            default: nil
            }
        case .co:
            switch self {
            case .nationalId, .rut, .identityCard: LocalizationKeys.descPhysicalOriginal
            case .foreignId, .ppt: LocalizationKeys.descCoValidIssued
            case .passport: LocalizationKeys.descCoPassport
            case .taxId: LocalizationKeys.descCoTaxpayerId
            case .temporaryNationalId: LocalizationKeys.descCoTempId
            case .ptp: LocalizationKeys.descCoPtp
            default: nil
            }
        case .cl:
            switch self {
            case .nationalId: LocalizationKeys.descPhysicalOriginal
            case .foreignId, .driverLicense: LocalizationKeys.descClForeignId
            case .passport: LocalizationKeys.descClPassport
            default: nil
            }
        case .pe:
            switch self {
            case .nationalId: LocalizationKeys.descPhysicalOriginal
            default: nil
            }
        case .sv:
            LocalizationKeys.descSvKeepHand
        case .ve:
            self == .nationalId ? LocalizationKeys.descPhysicalOriginal : nil
        case .all:
            self == .passport ? LocalizationKeys.descOriginalValid : nil
        case .ar:
            self == .nationalId ? LocalizationKeys.descPhysicalOriginal : nil
        case .bo:
            self == .nationalId ? LocalizationKeys.descPhysicalOriginal : nil
        case .ec:
            self == .nationalId ? LocalizationKeys.descPhysicalOriginal : nil
        case .cr:
            nil
        }
        guard let key else { return nil }
        return TruoraLocalization.string(forKey: key)
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
    case missingText = "missing_text"
    case documentNotRecognized = "document_not_recognized"
    case documentHasExpired = "document_has_expired"
    case wrongDocumentFound = "wrong_document_found"
    case grayscaleImage = "grayscale_image"
}

// MARK: - DocumentAutoCaptureEvent

public enum DocumentAutoCaptureEvent {
    case helpRequested
    case helpDismissed
    case switchToManualMode
    case manualCaptureRequested
}
