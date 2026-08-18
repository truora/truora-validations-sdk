//
//  LocalizationKeys.swift
//  TruoraValidationsSDK
//
//  Centralized keys for TruoraLocalization. Use these instead of raw strings
//  to get autocomplete and avoid typos.
//

import Foundation

enum LocalizationKeys {
    // MARK: - Camera

    static let cameraErrorInitializationFailed = "camera_error_initialization_failed"
    static let cameraErrorCaptureFailed = "camera_error_capture_failed"
    static let cameraErrorViewNotAvailable = "camera_error_view_not_available"
    static let cameraErrorNotReady = "camera_error_not_ready"
    static let cameraPermissionDeniedTitle = "camera_permission_denied_title"
    static let cameraPermissionDeniedDescription = "camera_permission_denied_description"
    static let cameraPermissionOpenSettings = "camera_permission_open_settings"

    // MARK: - Common

    static let commonError = "common_error"
    static let commonOk = "common_ok"
    static let commonCancel = "common_cancel"
    static let commonGoToSettings = "common_go_to_settings"

    // MARK: - Cancel alert

    static let cancelAlertTitle = "cancel_alert_title"
    static let cancelAlertMessage = "cancel_alert_message"
    static let cancelAlertCancel = "cancel_alert_cancel"
    static let cancelAlertConfirm = "cancel_alert_confirm"

    // MARK: - Document selection

    static let documentSelectionTitle = "document_selection_title"
    static let documentSelectionLockedTitle = "document_selection_locked_title"
    static let documentSelectionCountryLabel = "document_selection_country_label"
    static let documentSelectionCountryPlaceholder = "document_selection_country_placeholder"
    static let documentSelectionCountryError = "document_selection_country_error"
    static let documentSelectionDocumentLabel = "document_selection_document_label"
    static let documentSelectionDocumentPlaceholder = "document_selection_document_placeholder"
    static let documentSelectionDocumentError = "document_selection_document_error"
    static let documentSelectionAcceptedDocuments = "document_selection_accepted_documents"
    static let documentSelectionContinue = "document_selection_continue"
    static let documentSelectionLoading = "document_selection_loading"
    static let documentFixedSubtitle = "document_fixed_subtitle"
    static let documentFirstSuggestion = "document_first_suggestion"
    static let documentSecondSuggestion = "document_second_suggestion"
    static let documentSelectionLockedTitleCoNationalId = "document_selection_locked_title_co_national_id"

    // MARK: - Document intro

    static let documentIntroTitle = "document_intro_title"
    static let documentIntroSubtitle = "document_intro_subtitle"
    static let documentIntroSecurityTip = "document_intro_security_tip"
    static let documentIntroStartCapture = "document_intro_start_capture"
    static let documentIntroStartCaptureCoNationalId = "document_intro_start_capture_co_national_id"
    static let documentIntroCreatingValidation = "document_intro_creating_validation"

    // MARK: - Document capture

    static let documentCaptureRotateInstruction = "document_capture_rotate_instruction"
    static let documentCaptureFrontInstruction = "document_capture_front_instruction"
    static let documentCaptureBackInstruction = "document_capture_back_instruction"
    static let documentCaptureFeedbackLocate = "document_capture_feedback_locate"
    static let documentCaptureFeedbackCloser = "document_capture_feedback_closer"
    static let documentCaptureFeedbackFurther = "document_capture_feedback_further"
    static let documentCaptureFeedbackRotate = "document_capture_feedback_rotate"
    static let documentCaptureFeedbackCenter = "document_capture_feedback_center"
    static let documentCaptureScanning = "document_capture_scanning"
    static let documentCaptureScanningManual = "document_capture_scanning_manual"
    static let documentCaptureFeedbackMultiple = "document_capture_feedback_multiple"
    static let documentCaptureTakePhoto = "document_capture_take_photo"
    static let documentCaptureHelpTitle = "document_capture_help_title"
    static let documentCaptureHelpTip1 = "document_capture_help_tip1"
    static let documentCaptureHelpTip2 = "document_capture_help_tip2"
    static let documentCaptureHelpTip3 = "document_capture_help_tip3"
    static let documentCaptureHelpTip4 = "document_capture_help_tip4"
    static let documentCaptureManualButton = "document_capture_manual_button"

    // MARK: - Document feedback

    static let documentFeedbackRetry = "document_feedback_retry"
    static let documentFeedbackRetriesLeft = "document_feedback_retries_left"
    static let documentFeedbackDefaultTitle = "document_feedback_default_title"
    static let documentFeedbackBlurryTitle = "document_feedback_blurry_title"
    static let documentFeedbackBlurryDescription = "document_feedback_blurry_description"
    static let documentFeedbackGlareTitle = "document_feedback_glare_title"
    static let documentFeedbackGlareDescription = "document_feedback_glare_description"
    static let documentFeedbackFaceNotFoundTitle = "document_feedback_face_not_found_title"
    static let documentFeedbackFaceNotFoundDescription = "document_feedback_face_not_found_description"
    static let documentFeedbackNoDocumentTitle = "document_feedback_no_document_title"
    static let documentFeedbackNoDocumentDescription = "document_feedback_no_document_description"
    static let documentFeedbackFrontNotFoundTitle = "document_feedback_front_not_found_title"
    static let documentFeedbackFrontNotFoundDescription = "document_feedback_front_not_found_description"
    static let documentFeedbackBackNotFoundTitle = "document_feedback_back_not_found_title"
    static let documentFeedbackBackNotFoundDescription = "document_feedback_back_not_found_description"

    // MARK: - Passive intro

    static let passiveInstructionsTitle = "passive_instructions_title"
    static let passiveInstructionsText = "passive_instructions_text"
    static let passiveInstructionsSecurityTip = "passive_instructions_security_tip"
    static let passiveInstructionsStartVerification = "passive_instructions_start_verification"

    // MARK: - Passive capture

    static let passiveCaptureLoadingTitle = "passive_capture_loading_title"
    static let passiveCaptureRecordVideo = "passive_capture_record_video"
    static let passiveCaptureCannotRecord = "passive_capture_cannot_record"
    static let passiveCaptureHelp = "passive_capture_help"
    static let passiveCaptureStartInstruction = "passive_capture_start_instruction"
    static let passiveCaptureFeedbackShowFace = "passive_capture_feedback_show_face"
    static let passiveCaptureFeedbackRemoveGlasses = "passive_capture_feedback_remove_glasses"
    static let passiveCaptureFeedbackMultiplePeople = "passive_capture_feedback_multiple_people"
    static let passiveCaptureFeedbackHiddenFace = "passive_capture_feedback_hidden_face"
    static let passiveCaptureFeedbackCenterFace = "passive_capture_feedback_center_face"
    static let passiveCaptureFeedbackLookForward = "passive_capture_feedback_look_forward"
    static let passiveCaptureFeedbackRecording = "passive_capture_feedback_recording"
    static let passiveCaptureFeedbackMoveCloser = "passive_capture_feedback_move_closer"
    static let passiveCaptureFeedbackMoveBack = "passive_capture_feedback_move_back"
    static let passiveCaptureTip1 = "passive_capture_tip_1"
    static let passiveCaptureTip2 = "passive_capture_tip_2"
    static let passiveCaptureTip3 = "passive_capture_tip_3"
    static let passiveCaptureTip4 = "passive_capture_tip_4"
    static let passiveCaptureTipsTitle = "passive_capture_tips_title"
    static let passiveCaptureManualRecording = "passive_capture_manual_recording"
    static let passiveCaptureTryAgain = "passive_capture_try_again"
    static let passiveCaptureUploadingTitle = "passive_capture_uploading_title"
    static let passiveCaptureReadyTitle = "passive_capture_ready_title"

    // MARK: - Document autocapture loading

    static let documentAutocaptureLoadingVerifying = "document_autocapture_loading_verifying"
    static let docAutocaptureVerifyingDesc = "document_autocapture_loading_verifying_description"

    // MARK: - Result

    static let resultButtonLabel = "result_button_label"
    static let successResultTitle = "success_result_title"
    static let successResultDescription = "success_result_description"
    static let completedResultTitle = "completed_result_title"
    static let completedResultDescription = "completed_result_description"
    static let failureResultTitle = "failure_result_title"
    static let failureResultDescription = "failure_result_description"

    // MARK: - Countries (dynamic key by ISO code)

    static func countryKey(isoCode: String) -> String {
        "country_\(isoCode)"
    }

    // MARK: - Document types (generic labels)

    static let documentTypeNationalId = "document_type_national_id"
    static let documentTypeIdentityCard = "document_type_identity_card"
    static let documentTypeForeignId = "document_type_foreign_id"
    static let documentTypePpt = "document_type_ppt"
    static let documentTypeDriverLicense = "document_type_driver_license"
    static let documentTypePassport = "document_type_passport"
    static let documentTypeInvoice = "document_type_invoice"
    static let documentTypeTaxId = "document_type_tax_id"
    static let documentTypePtp = "document_type_ptp"
    static let documentTypeRut = "document_type_rut"
    static let documentTypeNativeNationalId = "document_type_native_national_id"

    // MARK: - Country-specific document labels

    // Mexico
    static let docMxNationalId = "doc_mx_national_id"
    static let docMxForeignId = "doc_mx_foreign_id"
    static let docMxTaxId = "doc_mx_tax_id"

    // Brazil
    static let docBrCnh = "doc_br_cnh"
    static let docBrGeneralReg = "doc_br_general_reg"
    static let docBrNationalId = "doc_br_national_id"
    static let docBrTaxId = "doc_br_tax_id"

    // Colombia
    static let docCoNationalId = "doc_co_national_id"
    static let docCoForeignId = "doc_co_foreign_id"
    static let docCoPpt = "doc_co_ppt"
    static let docCoTaxId = "doc_co_tax_id"
    static let docCoTempId = "doc_co_temp_id"
    static let docCoPtp = "doc_co_ptp"

    // Chile
    static let docClNationalId = "doc_cl_national_id"

    // Peru
    static let docPeNationalId = "doc_pe_national_id"
    static let docPeForeignId = "doc_pe_foreign_id"
    static let docPeTaxId = "doc_pe_tax_id"
    static let docPePtp = "doc_pe_ptp"

    // Venezuela
    static let docVeNationalId = "doc_ve_national_id"

    // Argentina
    static let docArNationalId = "doc_ar_national_id"

    // El Salvador
    static let docSvNationalId = "doc_sv_national_id"
    static let docSvForeignId = "doc_sv_foreign_id"

    // Bolivia
    static let docBoNationalId = "doc_bo_national_id"

    // Ecuador
    static let docEcNationalId = "doc_ec_national_id"

    // Costa Rica
    static let docCrNationalId = "doc_cr_national_id"
    static let docCrForeignId = "doc_cr_foreign_id"

    // MARK: - Invoice intro (country-specific)

    static let invoiceInstructionsTitleMx = "invoice_instructions_title_mx"
    static let invoiceInstructionsTitleCo = "invoice_instructions_title_co"
    static let invoiceInstructionsSubtitlePrefixMx = "invoice_instructions_subtitle_prefix_mx"
    static let invoiceInstructionsValidityPeriod = "invoice_instructions_validity_period"
    static let invoiceInstructionsSubtitleSuffixMx = "invoice_instructions_subtitle_suffix_mx"
    static let invoiceInstructionsSubtitleCo = "invoice_instructions_subtitle_co"
    static let invoiceInstructionsUploadFile = "invoice_instructions_upload_file"
    static let invoiceInstructionsTakePhoto = "invoice_instructions_take_photo"
    static let invoiceInstructionsCreatingValidation = "invoice_instructions_creating_validation"

    // MARK: - Invoice feedback (country-specific titles)

    static let invoiceFeedbackMissingTextTitleMx = "invoice_feedback_missing_text_title_mx"
    static let invoiceFeedbackMissingTextTitleCo = "invoice_feedback_missing_text_title_co"
    static let invoiceFeedbackMissingTextDesc = "invoice_feedback_missing_text_desc"
    static let invoiceFeedbackNotFoundTitleMx = "invoice_feedback_not_found_title_mx"
    static let invoiceFeedbackNotFoundTitleCo = "invoice_feedback_not_found_title_co"
    static let invoiceFeedbackNotFoundDescPrefixMx = "invoice_feedback_not_found_desc_prefix_mx"
    static let invoiceFeedbackNotFoundProvidersMx = "invoice_feedback_not_found_providers_mx"
    static let invoiceFeedbackNotFoundDescSuffixMx = "invoice_feedback_not_found_desc_suffix_mx"
    static let invoiceFeedbackNotFoundDescPrefixCo = "invoice_feedback_not_found_desc_prefix_co"
    static let invoiceFeedbackNotFoundProvidersCo = "invoice_feedback_not_found_providers_co"
    static let invoiceFeedbackNotFoundDescSuffixCo = "invoice_feedback_not_found_desc_suffix_co"
    static let invoiceFeedbackExpiredTitleMx = "invoice_feedback_expired_title_mx"
    static let invoiceFeedbackExpiredTitleCo = "invoice_feedback_expired_title_co"
    static let invoiceFeedbackExpiredDescMx = "invoice_feedback_expired_desc_mx"
    static let invoiceFeedbackExpiredDescCo = "invoice_feedback_expired_desc_co"
    static let invoiceFeedbackTipsLink = "invoice_feedback_tips_link"
    static let invoiceFeedbackRetry = "invoice_feedback_retry"
    static let invoiceFeedbackRetriesLeft = "invoice_feedback_retries_left"
    static let invoiceFeedbackTipsTitle = "invoice_feedback_tips_title"
    static let invoiceFeedbackTipCornersMx = "invoice_feedback_tip_corners_mx"
    static let invoiceFeedbackTipCornersCo = "invoice_feedback_tip_corners_co"
    static let invoiceFeedbackTipGlareMx = "invoice_feedback_tip_glare_mx"
    static let invoiceFeedbackTipGlareCo = "invoice_feedback_tip_glare_co"
    static let invoiceFeedbackTipAngle = "invoice_feedback_tip_angle"
    static let invoiceFeedbackBlurryTitle = "invoice_feedback_blurry_title"
    static let invoiceFeedbackBlurryDesc = "invoice_feedback_blurry_desc"
    static let invoiceFeedbackGlareTitle = "invoice_feedback_glare_title"
    static let invoiceFeedbackGlareDesc = "invoice_feedback_glare_desc"
    static let invoiceFeedbackDefaultTitle = "invoice_feedback_default_title"
    static let invoiceFeedbackDefaultDesc = "invoice_feedback_default_desc"

    // MARK: - Document descriptions (by country/type)

    static let descOriginalValid = "desc_original_valid"
    static let descTaxpayerId = "desc_taxpayer_id"
    static let descMxPassport = "desc_mx_passport"
    static let descPhysicalOriginal = "desc_physical_original"
    static let descCoValidIssued = "desc_co_valid_issued"
    static let descCoPassport = "desc_co_passport"
    static let descCoTempId = "desc_co_temp_id"
    static let descCoTaxpayerId = "desc_co_taxpayer_id"
    static let descCoPtp = "desc_co_ptp"
    static let descClForeignId = "desc_cl_foreign_id"
    static let descClPassport = "desc_cl_passport"
    static let descSvKeepHand = "desc_sv_keep_hand"

    // MARK: - Authorization (enter_authorization step)

    static let authorizationTitle = "authorization_title"
    static let authorizationAccept = "authorization_accept"
    static let authorizationDataPolicyText = "authorization_data_policy_text"
    static let authorizationDataPolicyLink = "authorization_data_policy_link"
    static let authorizationRequiredFieldsError = "authorization_required_fields_error"
    static let authorizationSecurityTip = "authorization_security_tip"
}
