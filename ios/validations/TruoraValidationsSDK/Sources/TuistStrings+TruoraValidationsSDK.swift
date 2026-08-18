// swiftlint:disable:this file_name
// swiftlint:disable all
// swift-format-ignore-file
// swiftformat:disable all
// Generated using tuist — https://github.com/tuist/tuist

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name
public enum TruoraValidationsSDKStrings: Sendable {
  /// Unable to take picture
  public static let cameraErrorCaptureFailed = TruoraValidationsSDKStrings.tr("Localizable", "camera_error_capture_failed")
  /// Camera initialization failed
  public static let cameraErrorInitializationFailed = TruoraValidationsSDKStrings.tr("Localizable", "camera_error_initialization_failed")
  /// Camera not ready
  public static let cameraErrorNotReady = TruoraValidationsSDKStrings.tr("Localizable", "camera_error_not_ready")
  /// Camera view not available
  public static let cameraErrorViewNotAvailable = TruoraValidationsSDKStrings.tr("Localizable", "camera_error_view_not_available")
  /// To continue, please allow camera access in your device settings.
  public static let cameraPermissionDeniedDescription = TruoraValidationsSDKStrings.tr("Localizable", "camera_permission_denied_description")
  /// Camera access is required
  public static let cameraPermissionDeniedTitle = TruoraValidationsSDKStrings.tr("Localizable", "camera_permission_denied_title")
  /// Open Settings
  public static let cameraPermissionOpenSettings = TruoraValidationsSDKStrings.tr("Localizable", "camera_permission_open_settings")
  /// No, go back
  public static let cancelAlertCancel = TruoraValidationsSDKStrings.tr("Localizable", "cancel_alert_cancel")
  /// Yes, cancel
  public static let cancelAlertConfirm = TruoraValidationsSDKStrings.tr("Localizable", "cancel_alert_confirm")
  /// You are about to cancel your current validation
  public static let cancelAlertMessage = TruoraValidationsSDKStrings.tr("Localizable", "cancel_alert_message")
  /// Cancel validation
  public static let cancelAlertTitle = TruoraValidationsSDKStrings.tr("Localizable", "cancel_alert_title")
  /// Cancel
  public static let commonCancel = TruoraValidationsSDKStrings.tr("Localizable", "common_cancel")
  /// Close
  public static let commonClose = TruoraValidationsSDKStrings.tr("Localizable", "common_close")
  /// Error
  public static let commonError = TruoraValidationsSDKStrings.tr("Localizable", "common_error")
  /// Go to Settings
  public static let commonGoToSettings = TruoraValidationsSDKStrings.tr("Localizable", "common_go_to_settings")
  /// OK
  public static let commonOk = TruoraValidationsSDKStrings.tr("Localizable", "common_ok")
  /// Verification performed on %@
  public static func completedResultDescription(_ p1: Any) -> String {
    return TruoraValidationsSDKStrings.tr("Localizable", "completed_result_description",String(describing: p1))
  }
  /// We have completed your verification
  public static let completedResultTitle = TruoraValidationsSDKStrings.tr("Localizable", "completed_result_title")
  /// All
  public static let countryAll = TruoraValidationsSDKStrings.tr("Localizable", "country_all")
  /// Argentina
  public static let countryAr = TruoraValidationsSDKStrings.tr("Localizable", "country_ar")
  /// Bolivia
  public static let countryBo = TruoraValidationsSDKStrings.tr("Localizable", "country_bo")
  /// Brazil
  public static let countryBr = TruoraValidationsSDKStrings.tr("Localizable", "country_br")
  /// Chile
  public static let countryCl = TruoraValidationsSDKStrings.tr("Localizable", "country_cl")
  /// Colombia
  public static let countryCo = TruoraValidationsSDKStrings.tr("Localizable", "country_co")
  /// Costa Rica
  public static let countryCr = TruoraValidationsSDKStrings.tr("Localizable", "country_cr")
  /// Ecuador
  public static let countryEc = TruoraValidationsSDKStrings.tr("Localizable", "country_ec")
  /// Mexico
  public static let countryMx = TruoraValidationsSDKStrings.tr("Localizable", "country_mx")
  /// Peru
  public static let countryPe = TruoraValidationsSDKStrings.tr("Localizable", "country_pe")
  /// El Salvador
  public static let countrySv = TruoraValidationsSDKStrings.tr("Localizable", "country_sv")
  /// Venezuela
  public static let countryVe = TruoraValidationsSDKStrings.tr("Localizable", "country_ve")
  /// Valid and issued in Chile
  public static let descClForeignId = TruoraValidationsSDKStrings.tr("Localizable", "desc_cl_foreign_id")
  /// From Chile, valid and current
  public static let descClPassport = TruoraValidationsSDKStrings.tr("Localizable", "desc_cl_passport")
  /// From Colombia, valid and current
  public static let descCoPassport = TruoraValidationsSDKStrings.tr("Localizable", "desc_co_passport")
  /// PPT (Temporal Protection Permit)
  public static let descCoPtp = TruoraValidationsSDKStrings.tr("Localizable", "desc_co_ptp")
  /// Tax identification number
  public static let descCoTaxpayerId = TruoraValidationsSDKStrings.tr("Localizable", "desc_co_taxpayer_id")
  /// Temporary National ID
  public static let descCoTempId = TruoraValidationsSDKStrings.tr("Localizable", "desc_co_temp_id")
  /// Valid and issued in Colombia
  public static let descCoValidIssued = TruoraValidationsSDKStrings.tr("Localizable", "desc_co_valid_issued")
  /// Mexican, valid and current
  public static let descMxPassport = TruoraValidationsSDKStrings.tr("Localizable", "desc_mx_passport")
  /// Valid and current
  public static let descOriginalValid = TruoraValidationsSDKStrings.tr("Localizable", "desc_original_valid")
  /// Original and in physical format
  public static let descPhysicalOriginal = TruoraValidationsSDKStrings.tr("Localizable", "desc_physical_original")
  /// Keep your original document handy
  public static let descSvKeepHand = TruoraValidationsSDKStrings.tr("Localizable", "desc_sv_keep_hand")
  /// Taxpayer ID
  public static let descTaxpayerId = TruoraValidationsSDKStrings.tr("Localizable", "desc_taxpayer_id")
  /// National Identity Document
  public static let docArNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_ar_national_id")
  /// National ID
  public static let docBoNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_bo_national_id")
  /// CNH
  public static let docBrCnh = TruoraValidationsSDKStrings.tr("Localizable", "doc_br_cnh")
  /// General Registry
  public static let docBrGeneralReg = TruoraValidationsSDKStrings.tr("Localizable", "doc_br_general_reg")
  /// ID Card (CPF)
  public static let docBrNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_br_national_id")
  /// CNPJ
  public static let docBrTaxId = TruoraValidationsSDKStrings.tr("Localizable", "doc_br_tax_id")
  /// Identity Card
  public static let docClNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_cl_national_id")
  /// Foreign ID
  public static let docCoForeignId = TruoraValidationsSDKStrings.tr("Localizable", "doc_co_foreign_id")
  /// National ID
  public static let docCoNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_co_national_id")
  /// PPT (Temporal Protection Permit)
  public static let docCoPpt = TruoraValidationsSDKStrings.tr("Localizable", "doc_co_ppt")
  /// PPT (VEN)
  public static let docCoPtp = TruoraValidationsSDKStrings.tr("Localizable", "doc_co_ptp")
  /// NIT
  public static let docCoTaxId = TruoraValidationsSDKStrings.tr("Localizable", "doc_co_tax_id")
  /// Temporary ID
  public static let docCoTempId = TruoraValidationsSDKStrings.tr("Localizable", "doc_co_temp_id")
  /// Foreign ID
  public static let docCrForeignId = TruoraValidationsSDKStrings.tr("Localizable", "doc_cr_foreign_id")
  /// National ID
  public static let docCrNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_cr_national_id")
  /// National ID
  public static let docEcNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_ec_national_id")
  /// Permanent/temporary residence
  public static let docMxForeignId = TruoraValidationsSDKStrings.tr("Localizable", "doc_mx_foreign_id")
  /// INE/IFE (CURP)
  public static let docMxNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_mx_national_id")
  /// RFC
  public static let docMxTaxId = TruoraValidationsSDKStrings.tr("Localizable", "doc_mx_tax_id")
  /// Foreigner ID
  public static let docPeForeignId = TruoraValidationsSDKStrings.tr("Localizable", "doc_pe_foreign_id")
  /// National Identity Document
  public static let docPeNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_pe_national_id")
  /// Temporary Stay Permit
  public static let docPePtp = TruoraValidationsSDKStrings.tr("Localizable", "doc_pe_ptp")
  /// RUC
  public static let docPeTaxId = TruoraValidationsSDKStrings.tr("Localizable", "doc_pe_tax_id")
  /// Residency card
  public static let docSvForeignId = TruoraValidationsSDKStrings.tr("Localizable", "doc_sv_foreign_id")
  /// Unique Identity Document (DUI)
  public static let docSvNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_sv_national_id")
  /// Identity Card
  public static let docVeNationalId = TruoraValidationsSDKStrings.tr("Localizable", "doc_ve_national_id")
  /// Verifying
  public static let documentAutocaptureLoadingVerifying = TruoraValidationsSDKStrings.tr("Localizable", "document_autocapture_loading_verifying")
  /// We are verifying the information\nThis may take a few seconds
  public static let documentAutocaptureLoadingVerifyingDescription = TruoraValidationsSDKStrings.tr("Localizable", "document_autocapture_loading_verifying_description")
  /// Place the back of the document inside the frame
  public static let documentCaptureBackInstruction = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_back_instruction")
  /// Back
  public static let documentCaptureBackLabel = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_back_label")
  /// Back side
  public static let documentCaptureBackSide = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_back_side")
  /// Capturing...
  public static let documentCaptureCapturing = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_capturing")
  /// Capture failed
  public static let documentCaptureError = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_error")
  /// Center your document
  public static let documentCaptureFeedbackCenter = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_feedback_center")
  /// Move closer
  public static let documentCaptureFeedbackCloser = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_feedback_closer")
  /// Move further
  public static let documentCaptureFeedbackFurther = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_feedback_further")
  /// Place your document in the frame
  public static let documentCaptureFeedbackLocate = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_feedback_locate")
  /// Only one document allowed
  public static let documentCaptureFeedbackMultiple = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_feedback_multiple")
  /// Turn the document over
  public static let documentCaptureFeedbackRotate = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_feedback_rotate")
  /// Place the front of the document inside the frame
  public static let documentCaptureFrontInstruction = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_front_instruction")
  /// Front
  public static let documentCaptureFrontLabel = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_front_label")
  /// Front side
  public static let documentCaptureFrontSide = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_front_side")
  /// Got it
  public static let documentCaptureHelpDismiss = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_help_dismiss")
  /// Place the document on a dark and flat surface.
  public static let documentCaptureHelpTip1 = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_help_tip1")
  /// Avoid placing the document on top of the keyboard.
  public static let documentCaptureHelpTip2 = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_help_tip2")
  /// Place yourself in a well-lit area.
  public static let documentCaptureHelpTip3 = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_help_tip3")
  /// Avoid bright lights or shadows that cover the information.
  public static let documentCaptureHelpTip4 = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_help_tip4")
  /// Tips for a better capture
  public static let documentCaptureHelpTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_help_title")
  /// Hold still
  public static let documentCaptureHold = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_hold")
  /// Take picture manually
  public static let documentCaptureManualButton = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_manual_button")
  /// Turn the document over to scan the back
  public static let documentCaptureRotateInstruction = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_rotate_instruction")
  /// Don't move!\nScanning...
  public static let documentCaptureScanning = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_scanning")
  /// Position your document
  public static let documentCaptureScanningManual = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_scanning_manual")
  /// Document captured
  public static let documentCaptureSuccess = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_success")
  /// Take photo
  public static let documentCaptureTakePhoto = TruoraValidationsSDKStrings.tr("Localizable", "document_capture_take_photo")
  /// Flip your document and take a picture of the back.
  public static let documentFeedbackBackNotFoundDescription = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_back_not_found_description")
  /// The back of your ID is missing
  public static let documentFeedbackBackNotFoundTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_back_not_found_title")
  /// Make sure the text and numbers are easy to read.
  public static let documentFeedbackBlurryDescription = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_blurry_description")
  /// Blurry image, we can't read the details
  public static let documentFeedbackBlurryTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_blurry_title")
  /// There was a problem with the photo, try again
  public static let documentFeedbackDefaultTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_default_title")
  /// There may be glare covering your face or your document is too far from the camera.
  public static let documentFeedbackFaceNotFoundDescription = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_face_not_found_description")
  /// Your face is not clearly seen
  public static let documentFeedbackFaceNotFoundTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_face_not_found_title")
  /// Flip your document and take a picture of the front.
  public static let documentFeedbackFrontNotFoundDescription = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_front_not_found_description")
  /// The front of your ID is missing
  public static let documentFeedbackFrontNotFoundTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_front_not_found_title")
  /// Ensure that the light does not illuminate your document directly.
  public static let documentFeedbackGlareDescription = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_glare_description")
  /// There are sparkles and holograms that don't let us see the details
  public static let documentFeedbackGlareTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_glare_title")
  /// Try again, take a picture of your document.
  public static let documentFeedbackNoDocumentDescription = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_no_document_description")
  /// We did not detect your document
  public static let documentFeedbackNoDocumentTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_no_document_title")
  /// Retries available %@
  public static func documentFeedbackRetriesLeft(_ p1: Any) -> String {
    return TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_retries_left",String(describing: p1))
  }
  /// Take another photo
  public static let documentFeedbackRetry = TruoraValidationsSDKStrings.tr("Localizable", "document_feedback_retry")
  /// Have your physical document on hand
  public static let documentFirstSuggestion = TruoraValidationsSDKStrings.tr("Localizable", "document_first_suggestion")
  /// Before scanning:
  public static let documentFixedSubtitle = TruoraValidationsSDKStrings.tr("Localizable", "document_fixed_subtitle")
  /// Creating validation...
  public static let documentIntroCreatingValidation = TruoraValidationsSDKStrings.tr("Localizable", "document_intro_creating_validation")
  /// Your information is protected.
  public static let documentIntroSecurityTip = TruoraValidationsSDKStrings.tr("Localizable", "document_intro_security_tip")
  /// Scan document
  public static let documentIntroStartCapture = TruoraValidationsSDKStrings.tr("Localizable", "document_intro_start_capture")
  /// Scan ID
  public static let documentIntroStartCaptureCoNationalId = TruoraValidationsSDKStrings.tr("Localizable", "document_intro_start_capture_co_national_id")
  /// Don't move, the document will be scanned automatically.
  public static let documentIntroSubtitle = TruoraValidationsSDKStrings.tr("Localizable", "document_intro_subtitle")
  /// Prepare to scan your identity document
  public static let documentIntroTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_intro_title")
  /// Clean your device's camera
  public static let documentSecondSuggestion = TruoraValidationsSDKStrings.tr("Localizable", "document_second_suggestion")
  /// Accepted documents:
  public static let documentSelectionAcceptedDocuments = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_accepted_documents")
  /// Continue
  public static let documentSelectionContinue = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_continue")
  /// Please select a country
  public static let documentSelectionCountryError = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_country_error")
  /// Country of your document:
  public static let documentSelectionCountryLabel = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_country_label")
  /// Select a country
  public static let documentSelectionCountryPlaceholder = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_country_placeholder")
  /// Please select a document type
  public static let documentSelectionDocumentError = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_document_error")
  /// Identity document type:
  public static let documentSelectionDocumentLabel = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_document_label")
  /// Select an option
  public static let documentSelectionDocumentPlaceholder = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_document_placeholder")
  /// Loading...
  public static let documentSelectionLoading = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_loading")
  /// Prepare your document
  public static let documentSelectionLockedTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_locked_title")
  /// Prepare your ID
  public static let documentSelectionLockedTitleCoNationalId = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_locked_title_co_national_id")
  /// Choose your document type
  public static let documentSelectionTitle = TruoraValidationsSDKStrings.tr("Localizable", "document_selection_title")
  /// Driver License
  public static let documentTypeDriverLicense = TruoraValidationsSDKStrings.tr("Localizable", "document_type_driver_license")
  /// Foreign ID
  public static let documentTypeForeignId = TruoraValidationsSDKStrings.tr("Localizable", "document_type_foreign_id")
  /// Identity Card
  public static let documentTypeIdentityCard = TruoraValidationsSDKStrings.tr("Localizable", "document_type_identity_card")
  /// Invoice
  public static let documentTypeInvoice = TruoraValidationsSDKStrings.tr("Localizable", "document_type_invoice")
  /// National ID
  public static let documentTypeNationalId = TruoraValidationsSDKStrings.tr("Localizable", "document_type_national_id")
  /// Native National ID
  public static let documentTypeNativeNationalId = TruoraValidationsSDKStrings.tr("Localizable", "document_type_native_national_id")
  /// Passport
  public static let documentTypePassport = TruoraValidationsSDKStrings.tr("Localizable", "document_type_passport")
  /// PPT
  public static let documentTypePpt = TruoraValidationsSDKStrings.tr("Localizable", "document_type_ppt")
  /// PTP
  public static let documentTypePtp = TruoraValidationsSDKStrings.tr("Localizable", "document_type_ptp")
  /// RUT
  public static let documentTypeRut = TruoraValidationsSDKStrings.tr("Localizable", "document_type_rut")
  /// Tax ID
  public static let documentTypeTaxId = TruoraValidationsSDKStrings.tr("Localizable", "document_type_tax_id")
  /// Your verification was not approved
  public static let failureResultDescription = TruoraValidationsSDKStrings.tr("Localizable", "failure_result_description")
  /// We were unable to verify your identity
  public static let failureResultTitle = TruoraValidationsSDKStrings.tr("Localizable", "failure_result_title")
  /// We couldn't record.\nPress "%@".
  public static func passiveCaptureCannotRecord(_ p1: Any) -> String {
    return TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_cannot_record",String(describing: p1))
  }
  /// Center your face in the oval
  public static let passiveCaptureFeedbackCenterFace = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_feedback_center_face")
  /// Uncover your face
  public static let passiveCaptureFeedbackHiddenFace = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_feedback_hidden_face")
  /// Look at the camera
  public static let passiveCaptureFeedbackLookForward = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_feedback_look_forward")
  /// Move back
  public static let passiveCaptureFeedbackMoveBack = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_feedback_move_back")
  /// Move closer
  public static let passiveCaptureFeedbackMoveCloser = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_feedback_move_closer")
  /// Avoid appearing with anyone else
  public static let passiveCaptureFeedbackMultiplePeople = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_feedback_multiple_people")
  /// Don't move!\nRecording
  public static let passiveCaptureFeedbackRecording = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_feedback_recording")
  /// Remove your glasses
  public static let passiveCaptureFeedbackRemoveGlasses = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_feedback_remove_glasses")
  /// Show your face
  public static let passiveCaptureFeedbackShowFace = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_feedback_show_face")
  /// Help
  public static let passiveCaptureHelp = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_help")
  /// Verifying face...
  public static let passiveCaptureLoadingTitle = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_loading_title")
  /// Record video manually
  public static let passiveCaptureManualRecording = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_manual_recording")
  /// Done!
  public static let passiveCaptureReadyTitle = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_ready_title")
  /// record video
  public static let passiveCaptureRecordVideo = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_record_video")
  /// Get ready!\nwe will record your face in
  public static let passiveCaptureStartInstruction = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_start_instruction")
  /// Find a quiet place with good lighting.
  public static let passiveCaptureTip1 = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_tip_1")
  /// Don't move or turn your head while recording.
  public static let passiveCaptureTip2 = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_tip_2")
  /// Make sure you are alone: only you should appear on camera.
  public static let passiveCaptureTip3 = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_tip_3")
  /// Avoid covering your face with your hands, hair, or objects.
  public static let passiveCaptureTip4 = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_tip_4")
  /// Tips for a better capture
  public static let passiveCaptureTipsTitle = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_tips_title")
  /// Try again
  public static let passiveCaptureTryAgain = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_try_again")
  /// Loading…
  public static let passiveCaptureUploadingTitle = TruoraValidationsSDKStrings.tr("Localizable", "passive_capture_uploading_title")
  /// Your information is secured.
  public static let passiveInstructionsSecurityTip = TruoraValidationsSDKStrings.tr("Localizable", "passive_instructions_security_tip")
  /// Start verification
  public static let passiveInstructionsStartVerification = TruoraValidationsSDKStrings.tr("Localizable", "passive_instructions_start_verification")
  /// Place your phone in front of your face
  public static let passiveInstructionsText = TruoraValidationsSDKStrings.tr("Localizable", "passive_instructions_text")
  /// To verify your identity we will record a short video of your face
  public static let passiveInstructionsTitle = TruoraValidationsSDKStrings.tr("Localizable", "passive_instructions_title")
  /// Finish verification
  public static let resultButtonLabel = TruoraValidationsSDKStrings.tr("Localizable", "result_button_label")
  /// Verification performed on %@
  public static func successResultDescription(_ p1: Any) -> String {
    return TruoraValidationsSDKStrings.tr("Localizable", "success_result_description",String(describing: p1))
  }
  /// Your identity has been successfully verified
  public static let successResultTitle = TruoraValidationsSDKStrings.tr("Localizable", "success_result_title")
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name

// MARK: - Implementation Details

extension TruoraValidationsSDKStrings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.truoraModule.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
// swiftformat:enable all
// swiftlint:enable all
