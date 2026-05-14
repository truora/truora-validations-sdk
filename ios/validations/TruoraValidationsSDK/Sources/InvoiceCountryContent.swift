//
//  InvoiceCountryContent.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 16/04/26.
//

import Foundation

// MARK: - Invoice Country Content

/// Provides country-specific content for the invoice flow.
/// The view structure is the same for all countries; only text and images change.
enum InvoiceCountryContent {
    case mx
    case co

    /// Unknown country codes fall back to `.mx` (the default launch market). The fallback
    /// is logged so unsupported values surface during development.
    init(country: String) {
        switch country.lowercased() {
        case "mx":
            self = .mx
        case "co":
            self = .co
        default:
            debugLog("⚠️ InvoiceCountryContent: Unsupported country '\(country)', defaulting to .mx")
            self = .mx
        }
    }

    // MARK: - Intro screen keys

    var titleKey: String {
        switch self {
        case .mx: LocalizationKeys.invoiceInstructionsTitleMx
        case .co: LocalizationKeys.invoiceInstructionsTitleCo
        }
    }

    /// Whether to show the bold-red "vigencia máxima de 3 meses" line.
    /// CO does not have this requirement.
    var showsValidityPeriod: Bool {
        switch self {
        case .mx: true
        case .co: false
        }
    }

    /// Subtitle prefix (before the bold validity text). Only used when `showsValidityPeriod` is true.
    var subtitlePrefixKey: String {
        LocalizationKeys.invoiceInstructionsSubtitlePrefixMx
    }

    var validityPeriodKey: String {
        LocalizationKeys.invoiceInstructionsValidityPeriod
    }

    var subtitleSuffixKey: String {
        LocalizationKeys.invoiceInstructionsSubtitleSuffixMx
    }

    /// Full subtitle for countries without the validity period split (CO).
    var subtitleKey: String {
        LocalizationKeys.invoiceInstructionsSubtitleCo
    }

    var providerLogoNames: [String] {
        switch self {
        case .mx: ["mx_invoice_cfe_logo", "mx_invoice_telmex_logo", "mx_invoice_totalplay_logo"]
        case .co: ["co_invoice_alcanos_logo", "co_invoice_gases_oriente_logo", "co_invoice_metrogas_logo"]
        }
    }

    /// Logo spacing in points. MX providers are wider, CO logos need tighter spacing.
    var logoSpacing: CGFloat {
        switch self {
        case .mx: 40
        case .co: 32
        }
    }

    // MARK: - Feedback screen keys

    var feedbackMissingTextTitleKey: String {
        switch self {
        case .mx: LocalizationKeys.invoiceFeedbackMissingTextTitleMx
        case .co: LocalizationKeys.invoiceFeedbackMissingTextTitleCo
        }
    }

    var feedbackNotFoundTitleKey: String {
        switch self {
        case .mx: LocalizationKeys.invoiceFeedbackNotFoundTitleMx
        case .co: LocalizationKeys.invoiceFeedbackNotFoundTitleCo
        }
    }

    /// Not-found description split into 3 parts for mixed formatting (bold provider names).
    var feedbackNotFoundDescPrefixKey: String {
        switch self {
        case .mx: LocalizationKeys.invoiceFeedbackNotFoundDescPrefixMx
        case .co: LocalizationKeys.invoiceFeedbackNotFoundDescPrefixCo
        }
    }

    var feedbackNotFoundProvidersKey: String {
        switch self {
        case .mx: LocalizationKeys.invoiceFeedbackNotFoundProvidersMx
        case .co: LocalizationKeys.invoiceFeedbackNotFoundProvidersCo
        }
    }

    var feedbackNotFoundDescSuffixKey: String {
        switch self {
        case .mx: LocalizationKeys.invoiceFeedbackNotFoundDescSuffixMx
        case .co: LocalizationKeys.invoiceFeedbackNotFoundDescSuffixCo
        }
    }

    var feedbackExpiredTitleKey: String {
        switch self {
        case .mx: LocalizationKeys.invoiceFeedbackExpiredTitleMx
        case .co: LocalizationKeys.invoiceFeedbackExpiredTitleCo
        }
    }

    var feedbackExpiredDescKey: String {
        switch self {
        case .mx: LocalizationKeys.invoiceFeedbackExpiredDescMx
        case .co: LocalizationKeys.invoiceFeedbackExpiredDescCo
        }
    }

    var feedbackTipCornersKey: String {
        switch self {
        case .mx: LocalizationKeys.invoiceFeedbackTipCornersMx
        case .co: LocalizationKeys.invoiceFeedbackTipCornersCo
        }
    }

    var feedbackTipGlareKey: String {
        switch self {
        case .mx: LocalizationKeys.invoiceFeedbackTipGlareMx
        case .co: LocalizationKeys.invoiceFeedbackTipGlareCo
        }
    }

    /// Reference thumbnails shown in the document_not_found feedback screen.
    /// These are full-invoice sample images, not just the provider logos.
    var referenceImageNames: [String] {
        switch self {
        case .mx: [
                "mx_invoice_cfe_front",
                "mx_invoice_telmex_front",
                "mx_invoice_totalplay_front"
            ]
        case .co: [
                "co_invoice_alcanos_front",
                "co_invoice_gases_oriente_front",
                "co_invoice_metrogas_front"
            ]
        }
    }
}
