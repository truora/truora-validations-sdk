//
//  DocumentCaptureView.swift
//  validations
//
//  Created by Truora on 23/12/25.
//

import AVFoundation
import SwiftUI
import TruoraCamera
import UIKit

// MARK: - Camera Delegate Protocol

@MainActor protocol DocumentCaptureCameraDelegate: AnyObject {
    func setupCamera()
    func configureSessionPreset(_ preset: AVCaptureSession.Preset)
    func setInferenceLatencyCallback(_ callback: ((TimeInterval) -> Void)?)
    func takePicture()
    func stopCamera()
    func pauseCamera()
    func resumeCamera()
    func pauseVideo()
}

// MARK: - Camera View Wrapper

struct DocumentCameraViewWrapper: UIViewRepresentable {
    @ObservedObject var viewModel: DocumentCaptureViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> CameraView {
        let detectionType: DetectionType = viewModel.useAutocapture ? .document : .none
        let mlLogger: MLLifecycleLogger? = {
            guard let logger = try? TruoraLoggerImplementation.shared else {
                return nil
            }
            return MLLifecycleLoggerAdapter(logger: logger)
        }()
        var processor = FrameProcessorFactory.createProcessor(
            for: detectionType,
            delegate: context.coordinator,
            logger: mlLogger,
            tfliteThreadCount: viewModel.tfliteThreadCount
        )
        // Wire inference latency tracking if the presenter set a callback
        processor?.onInferenceLatency = context.coordinator.inferenceLatencyCallback
        let cameraView = CameraView(frameProcessor: processor)
        cameraView.backgroundColor = .clear
        cameraView.delegate = context.coordinator
        cameraView.orientation = .vertical
        context.coordinator.cameraView = cameraView
        viewModel.cameraViewDelegate = context.coordinator
        return cameraView
    }

    func updateUIView(_: CameraView, context _: Context) {}

    @MainActor final class Coordinator: NSObject, @preconcurrency CameraDelegate, DocumentCaptureCameraDelegate {
        let viewModel: DocumentCaptureViewModel
        weak var cameraView: CameraView?

        /// Callback for inference latency reporting, set by the presenter
        /// to feed into the performance advisor's inference tracker.
        var inferenceLatencyCallback: ((TimeInterval) -> Void)?

        init(viewModel: DocumentCaptureViewModel) {
            self.viewModel = viewModel
        }

        func setupCamera() {
            guard let cameraView else {
                DispatchQueue.main.async {
                    self.viewModel.errorMessage = TruoraLocalization.string(
                        forKey: LocalizationKeys.cameraErrorViewNotAvailable
                    )
                    self.viewModel.showError = true
                }
                return
            }
            cameraView.startCamera(side: .back, cameraOutputMode: .image)
        }

        func configureSessionPreset(_ preset: AVCaptureSession.Preset) {
            cameraView?.sessionPresetOverride = preset
        }

        func setInferenceLatencyCallback(_ callback: ((TimeInterval) -> Void)?) {
            inferenceLatencyCallback = callback
        }

        func takePicture() {
            guard let cameraView else {
                DispatchQueue.main.async {
                    self.viewModel.errorMessage = TruoraLocalization.string(
                        forKey: LocalizationKeys.cameraErrorNotReady
                    )
                    self.viewModel.showError = true
                }
                return
            }
            cameraView.takePicture()
        }

        func stopCamera() {
            cameraView?.stopCamera()
        }

        func pauseCamera() {
            cameraView?.pauseCamera()
        }

        func resumeCamera() {
            cameraView?.resumeCamera()
        }

        func pauseVideo() {
            cameraView?.stopVideoRecording(skipMediaNotification: true)
        }

        func cameraReady() {
            viewModel.cameraReady()
        }

        func mediaReady(media: Data) {
            viewModel.photoCaptured(photoData: media)
        }

        func lastFrameCaptured(frameData _: Data) {
            // Not used for still capture
        }

        func reportError(error: CameraError) {
            if case .permissionDenied = error {
                Task { await viewModel.presenter?.cameraPermissionDenied() }
            } else {
                let errorMessage = error.localizedDescription
                Task { await viewModel.presenter?.cameraError(errorMessage) }
                viewModel.showError("Camera error: \(errorMessage)")
            }
        }

        func detectionsReceived(_ results: [DetectionResult]) {
            viewModel.detectionsReceived(results)
        }

        func autocaptureUnavailable(error: Error?) {
            // Model failed to load - switch to manual capture mode silently
            if let error {
                debugLog("⚠️ DocumentCapture: Autocapture unavailable - \(error.localizedDescription)")
            }
            viewModel.autocaptureUnavailable()
        }
    }
}

// MARK: - Native Document Capture View

struct DocumentCaptureView: View {
    @ObservedObject var viewModel: DocumentCaptureViewModel
    @ObservedObject private var theme: TruoraTheme

    init(viewModel: DocumentCaptureViewModel, config: UIConfig?) {
        self.viewModel = viewModel
        self.theme = TruoraTheme(config: config)
    }

    var body: some View {
        ZStack {
            DocumentCameraViewWrapper(viewModel: viewModel)
                .extendingIntoSafeArea()

            // Native capture overlay - matches KMP DocumentAutoCapture layout
            DocumentCaptureOverlayView(
                side: viewModel.currentSide,
                feedbackType: viewModel.feedbackType,
                showHelpDialog: viewModel.showHelpDialog,
                showRotationAnimation: viewModel.showRotationAnimation,
                uploadState: viewModel.uploadState,
                frontPhotoData: viewModel.frontPhotoData,
                frontPhotoStatus: viewModel.frontPhotoStatus,
                backPhotoData: viewModel.backPhotoData,
                backPhotoStatus: viewModel.backPhotoStatus,
                isCaptureEnabled: !viewModel.isCaptureInProgress && !viewModel.showLoadingScreen,
                onCapture: { viewModel.captureButtonTapped() },
                onHelp: { viewModel.helpRequested() },
                onHelpDismiss: { viewModel.helpDismissed() },
                onCancel: { viewModel.cancelTapped() },
                onRetry: { viewModel.retryTapped() },
                onSwitchToManual: { viewModel.userRequestedManualMode() }
            )

            #if DEBUG
            if let advisor = viewModel.performanceAdvisor {
                PerformanceDebugOverlay(advisor: advisor)
            }
            #endif
        }
        .environmentObject(theme)
        .navigationBarHidden(true)
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text(TruoraLocalization.string(forKey: LocalizationKeys.commonError)),
                message: viewModel.errorMessage.map { Text($0) },
                dismissButton: .default(
                    Text(TruoraLocalization.string(forKey: LocalizationKeys.commonOk))
                )
            )
        }
        .onAppear {
            viewModel.onAppear()
            viewModel.onWillAppear()
        }
        .onDisappear {
            viewModel.onWillDisappear()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
        ) { _ in
            viewModel.onAppWillResignActive()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            viewModel.onAppDidBecomeActive()
        }
    }
}

// MARK: - Document Capture Overlay View

/// Document capture overlay matching KMP DocumentAutoCapture layout:
/// - Header with document icon and instructions (colored background)
/// - Full-screen mask with rounded rectangle cutout (86.6% width, 1.51 aspect ratio)
/// - Centered feedback messages
/// - Thumbnails below the mask
/// - Footer with help button and manual capture
struct DocumentCaptureOverlayView: View {
    let side: DocumentCaptureSide
    let feedbackType: DocumentFeedbackType
    let showHelpDialog: Bool
    let showRotationAnimation: Bool
    let uploadState: UploadState
    let frontPhotoData: Data?
    let frontPhotoStatus: CaptureStatus?
    let backPhotoData: Data?
    let backPhotoStatus: CaptureStatus?
    let isCaptureEnabled: Bool

    let onCapture: () -> Void
    let onHelp: () -> Void
    let onHelpDismiss: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onSwitchToManual: () -> Void

    @EnvironmentObject var theme: TruoraTheme

    // Keeps header text clear of the Dynamic Island
    private let headerBaseTopPadding: CGFloat = 16
    private let headerMinTopPadding: CGFloat = 60

    init(
        side: DocumentCaptureSide,
        feedbackType: DocumentFeedbackType,
        showHelpDialog: Bool,
        showRotationAnimation: Bool,
        uploadState: UploadState = .none,
        frontPhotoData: Data?,
        frontPhotoStatus: CaptureStatus?,
        backPhotoData: Data?,
        backPhotoStatus: CaptureStatus?,
        isCaptureEnabled: Bool = true,
        onCapture: @escaping () -> Void,
        onHelp: @escaping () -> Void,
        onHelpDismiss: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onSwitchToManual: @escaping () -> Void = {}
    ) {
        self.side = side
        self.feedbackType = feedbackType
        self.showHelpDialog = showHelpDialog
        self.showRotationAnimation = showRotationAnimation
        self.uploadState = uploadState
        self.frontPhotoData = frontPhotoData
        self.frontPhotoStatus = frontPhotoStatus
        self.backPhotoData = backPhotoData
        self.backPhotoStatus = backPhotoStatus
        self.isCaptureEnabled = isCaptureEnabled
        self.onCapture = onCapture
        self.onHelp = onHelp
        self.onHelpDismiss = onHelpDismiss
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.onSwitchToManual = onSwitchToManual
    }

    private var shouldShowFeedback: Bool {
        !showRotationAnimation && uploadState != .uploading && uploadState != .success
    }

    private var showHelpButton: Bool {
        !(frontPhotoStatus == .success && backPhotoStatus == .success)
            && uploadState == .none
            && !showRotationAnimation
    }

    var body: some View {
        GeometryReader { geometry in
            let headerTopPadding = max(headerBaseTopPadding + geometry.safeAreaInsets.top, headerMinTopPadding)

            ZStack {
                DocumentCaptureOverlayMask(feedbackType: feedbackType)

                if showRotationAnimation {
                    AnimatedGIFView(gifName: "rotate_document", size: CGSize(width: 250, height: 250))
                        .frame(width: 250, height: 250)
                        .transition(.opacity)
                } else if shouldShowFeedback {
                    DocumentCaptureFeedbackMessage(feedbackType: feedbackType)
                        .transition(.opacity)
                }

                // Thumbnails positioned below the mask
                DocumentCaptureThumbnails(
                    geometry: geometry,
                    frontPhotoData: frontPhotoData,
                    frontPhotoStatus: frontPhotoStatus,
                    backPhotoData: backPhotoData,
                    backPhotoStatus: backPhotoStatus
                )

                // Floats directly over the camera feed
                VStack(spacing: 0) {
                    DocumentCaptureHeaderView(
                        side: side,
                        showRotationAnimation: showRotationAnimation,
                        uploadState: uploadState
                    )
                    .padding(.top, headerTopPadding)
                    Spacer()
                }

                // Floats directly over the camera feed
                VStack(spacing: 0) {
                    Spacer()
                    DocumentCaptureFooter(
                        feedbackType: feedbackType,
                        showHelpButton: showHelpButton,
                        isCaptureEnabled: isCaptureEnabled,
                        onHelpClick: onHelp,
                        onManualCapture: onCapture
                    )
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 16))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: showRotationAnimation)
        }
        .extendingIntoSafeArea()
        .overlay(
            // Help dialog overlay
            Group {
                if showHelpDialog {
                    DocumentCaptureTipsDialog(
                        onDismiss: onHelpDismiss,
                        onManualCapture: onSwitchToManual
                    )
                }
            }
        )
    }
}

// MARK: - Document Capture Header View

/// Header section matching KMP/Figma DocumentAutoCaptureHeader
private struct DocumentCaptureHeaderView: View {
    let side: DocumentCaptureSide
    let showRotationAnimation: Bool
    let uploadState: UploadState

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        VStack(spacing: 16) {
            if uploadState == .uploading || uploadState == .success {
                PassiveCaptureUploadHeaderView(uploadState: uploadState)
            } else if showRotationAnimation {
                Text(TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureRotateInstruction))
                    .font(theme.typography.titleMedium)
                    .foregroundColor(theme.colors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                // Document icon from Figma - white ID card vector
                // Icon is 47x30 inside a 48x48 container
                documentIcon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 47, height: 30)
                    .frame(width: 48, height: 48)

                // Instruction text - 18sp semibold per Figma
                Text(
                    side == .front
                        ? TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureFrontInstruction)
                        : TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureBackInstruction)
                )
                .font(theme.typography.titleMedium)
                .foregroundColor(theme.colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Returns the appropriate document icon based on side
    private var documentIcon: SwiftUI.Image {
        side == .front
            ? TruoraValidationsSDKAsset.documentFront.swiftUIImage
            : TruoraValidationsSDKAsset.documentBack.swiftUIImage
    }
}

// MARK: - Document Capture Overlay Mask

/// Full-screen mask with rounded rectangle cutout
/// Matches KMP DocumentAutoCaptureOverlayMask: 86.6% width, 1.51 aspect ratio
/// Uses compositingGroup + blendMode for iOS 13 compatibility
private struct DocumentCaptureOverlayMask: View {
    let feedbackType: DocumentFeedbackType

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        GeometryReader { geometry in
            let maskWidth = geometry.size.width * 0.866
            let maskHeight = maskWidth / 1.51
            let cornerRadius: CGFloat = 16

            let center = CGPoint(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )

            let borderColor =
                feedbackType == .scanning
                    ? theme.colors.layoutSuccess
                    : Color.white

            ZStack {
                // Semi-transparent scrim
                Color.black.opacity(0.7)

                // Rounded rectangle cutout (clear)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .frame(width: maskWidth, height: maskHeight)
                    .position(center)
                    .blendMode(.destinationOut)

                // Border around the cutout
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 3)
                    .frame(width: maskWidth, height: maskHeight)
                    .position(center)
            }
            .compositingGroup()
        }
    }
}

// MARK: - Document Capture Feedback Message

/// Centered feedback message matching KMP DocumentAutoCaptureFeedbackMessage
private struct DocumentCaptureFeedbackMessage: View {
    let feedbackType: DocumentFeedbackType

    @EnvironmentObject var theme: TruoraTheme

    /// Don't show anything for NONE feedback type
    var shouldShow: Bool {
        feedbackType != .none
    }

    var feedbackText: String {
        switch feedbackType {
        case .none: ""
        case .locate: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureFeedbackLocate)
        case .closer: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureFeedbackCloser)
        case .further: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureFeedbackFurther)
        case .rotate: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureFeedbackRotate)
        case .center: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureFeedbackCenter)
        case .scanning: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureScanning)
        case .scanningManual: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureScanningManual)
        case .searching: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureScanning)
        case .multipleDocuments: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureFeedbackMultiple)
        }
    }

    var backgroundColor: Color {
        switch feedbackType {
        case .none: .clear
        case .locate, .closer, .further, .rotate, .center: theme.colors.layoutWarning
        case .scanning: theme.colors.layoutSuccess
        case .scanningManual, .searching: theme.colors.layoutGray900
        case .multipleDocuments: theme.colors.layoutRed700
        }
    }

    var textColor: Color {
        switch feedbackType {
        case .scanning, .scanningManual, .searching, .multipleDocuments: .white
        default: theme.colors.tint
        }
    }

    var body: some View {
        if shouldShow {
            Text(feedbackText)
                .font(theme.typography.bodyMedium)
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(backgroundColor)
                .cornerRadius(8)
                .opacity(0.9)
        }
    }
}

// MARK: - Document Capture Thumbnails

/// Thumbnails positioned below the mask, matching KMP DocumentAutoCaptureThumbnails
private struct DocumentCaptureThumbnails: View {
    let geometry: GeometryProxy
    let frontPhotoData: Data?
    let frontPhotoStatus: CaptureStatus?
    let backPhotoData: Data?
    let backPhotoStatus: CaptureStatus?

    var body: some View {
        let maskWidth = geometry.size.width * 0.866
        let maskHeight = maskWidth / 1.51
        let maskLeft = (geometry.size.width - maskWidth) / 2
        let maskTop = (geometry.size.height - maskHeight) / 2
        let maskBottom = maskTop + maskHeight

        HStack(spacing: 8) {
            if let status = frontPhotoStatus {
                DocumentPhotoThumbnail(
                    photoData: frontPhotoData,
                    status: status
                )
            }

            if let status = backPhotoStatus {
                DocumentPhotoThumbnail(
                    photoData: backPhotoData,
                    status: status
                )
            }
        }
        .padding(.leading, maskLeft + 8)
        .padding(.top, maskBottom + 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Document Photo Thumbnail

/// Individual photo thumbnail matching KMP/Figma GenericPhotoThumbnail
/// Shows captured document image with loading spinner or green checkmark overlay
private struct DocumentPhotoThumbnail: View {
    let photoData: Data?
    let status: CaptureStatus

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        ZStack {
            // Background placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.3))
                .frame(width: 60, height: 40)

            // Captured image
            if let data = photoData, let uiImage = UIImage(data: data) {
                SwiftUI.Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 40)
                    .cornerRadius(4)
                    .clipped()
            }

            // Status indicator overlay - positioned at bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    switch status {
                    case .success:
                        // Green circle with white checkmark - matching Figma
                        ZStack {
                            Circle()
                                .fill(theme.colors.layoutSuccess)
                                .frame(width: 20, height: 20)
                            SwiftUI.Image(systemName: "checkmark")
                                .font(theme.typography.bodySmall)
                                .foregroundColor(.white)
                        }
                        .offset(x: 6, y: 6)
                    case .loading:
                        CircularSpinnerView(size: 20, lineWidth: 2.5, color: .white)
                    }
                }
            }
        }
        .frame(width: 60, height: 40)
    }
}

// MARK: - Document Capture Footer

/// Footer matching KMP/Figma GenericCaptureFooter
/// Contains help button and manual capture button
private struct DocumentCaptureFooter: View {
    let feedbackType: DocumentFeedbackType
    let showHelpButton: Bool
    let isCaptureEnabled: Bool
    let onHelpClick: () -> Void
    let onManualCapture: () -> Void

    @EnvironmentObject var theme: TruoraTheme

    /// Show manual capture button only when in scanning manual mode
    var showManualButton: Bool {
        feedbackType == .scanningManual
    }

    var body: some View {
        VStack(spacing: 16) {
            // Manual capture button (if applicable)
            if showManualButton {
                ManualCaptureButton(
                    title: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureTakePhoto),
                    mode: .picture,
                    isEnabled: isCaptureEnabled,
                    action: onManualCapture
                )
            }

            // Bottom bar with help button and logo
            HStack {
                // Help button - hidden when both sides captured
                if showHelpButton {
                    Button(action: onHelpClick) {
                        Text(TruoraLocalization.string(forKey: LocalizationKeys.passiveCaptureHelp))
                            .font(theme.typography.bodySmall)
                            .foregroundColor(theme.colors.onSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.colors.secondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(theme.colors.gray600, lineWidth: 1)
                            )
                    }
                }

                Spacer()

                // Truora logo
                TruoraValidationsSDKAsset.byTruora.swiftUIImage
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 65, height: 20)
                    .foregroundColor(theme.colors.onSurfaceVariant)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Document Capture Tips Dialog

/// Tips dialog matching KMP GenericTipsDialog pattern
/// Same layout as PassiveCaptureTipsDialog
struct DocumentCaptureTipsDialog: View {
    let onDismiss: () -> Void
    let onManualCapture: () -> Void

    @EnvironmentObject var theme: TruoraTheme

    /// Tips for document capture - matches KMP document_autocapture_tips.
    /// Computed so strings update if locale changes at runtime.
    private var tips: [String] {
        [
            TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureHelpTip1),
            TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureHelpTip2),
            TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureHelpTip3),
            TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureHelpTip4)
        ]
    }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .extendingIntoSafeArea()
                .onTapGesture { onDismiss() }

            // Dialog content
            VStack(spacing: 0) {
                // Header with title and close button
                HStack {
                    Text(TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureHelpTitle))
                        .font(theme.typography.titleMedium)
                        .foregroundColor(theme.colors.onSurface)

                    Spacer()

                    Button(action: onDismiss) {
                        Text("\u{2715}")
                            .font(theme.typography.bodyLarge)
                            .foregroundColor(theme.colors.onSurface)
                    }
                    .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                // Divider
                Rectangle()
                    .fill(theme.colors.layoutGray200)
                    .frame(height: 1)

                // Tips list with bullet points
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\u{2022}")
                                .font(theme.typography.bodyLarge)
                                .foregroundColor(theme.colors.onSurface)

                            Text(tip)
                                .font(theme.typography.bodyMedium)
                                .foregroundColor(theme.colors.onSurface)
                                .lineSpacing(7)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                // Manual capture button
                TruoraPrimaryButton(
                    title: TruoraLocalization.string(forKey: LocalizationKeys.documentCaptureManualButton),
                    isLoading: false,
                    action: onManualCapture
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(theme.colors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.colors.layoutGray200, lineWidth: 1)
            )
            .frame(width: 320)
        }
    }
}

// MARK: - Previews

#Preview("Document Capture Overlay") {
    ZStack {
        Color.gray
        DocumentCaptureOverlayView(
            side: .front,
            feedbackType: .scanningManual,
            showHelpDialog: false,
            showRotationAnimation: false,
            frontPhotoData: nil,
            frontPhotoStatus: nil,
            backPhotoData: nil,
            backPhotoStatus: nil,
            onCapture: {},
            onHelp: {},
            onHelpDismiss: {},
            onCancel: {},
            onRetry: {},
            onSwitchToManual: {}
        )
    }
    .environmentObject(TruoraTheme(config: nil))
}

#Preview("Document Capture Tips Dialog") {
    DocumentCaptureTipsDialog(
        onDismiss: {},
        onManualCapture: {}
    )
    .environmentObject(TruoraTheme(config: nil))
}
