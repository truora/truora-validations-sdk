//
//  DocumentCaptureView.swift
//  validations
//
//  Created by Truora on 23/12/25.
//

import SwiftUI
import TruoraCamera
import UIKit

// MARK: - View Model

/// ViewModel for the document capture screen.
/// Uses @Published properties which automatically notify SwiftUI on the main thread.
@MainActor final class DocumentCaptureViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var showError = false

    // Native state
    @Published var currentSide: DocumentCaptureSide = .front
    @Published var feedbackType: DocumentFeedbackType = .scanningManual
    @Published var showHelpDialog: Bool = false
    @Published var showRotationAnimation: Bool = false
    @Published var showLoadingScreen: Bool = false

    @Published var frontPhotoData: Data?
    @Published var frontPhotoStatus: CaptureStatus?
    @Published var backPhotoData: Data?
    @Published var backPhotoStatus: CaptureStatus?

    var presenter: DocumentCaptureViewToPresenter?
    weak var cameraViewDelegate: DocumentCaptureCameraDelegate?

    func onAppear() {
        Task { await presenter?.viewDidLoad() }
    }

    func onWillAppear() {
        Task { await presenter?.viewWillAppear() }
    }

    func onWillDisappear() {
        Task { await presenter?.viewWillDisappear() }
    }

    func cameraReady() {
        Task { await presenter?.cameraReady() }
    }

    func photoCaptured(photoData: Data) {
        Task { await presenter?.photoCaptured(photoData: photoData) }
    }

    func detectionsReceived(_ results: [DetectionResult]) {
        Task { await presenter?.detectionsReceived(results) }
    }

    /// Native event handlers
    func captureButtonTapped() {
        Task { await presenter?.manualCaptureTapped() }
    }

    func helpRequested() {
        showHelpDialog = true
    }

    func helpDismissed() {
        showHelpDialog = false
    }

    func cancelTapped() {
        Task { await presenter?.cancelTapped() }
    }

    func retryTapped() {
        Task { await presenter?.retryTapped() }
    }
}

extension DocumentCaptureViewModel: DocumentCapturePresenterToView {
    func setupCamera() {
        guard let delegate = cameraViewDelegate else {
            errorMessage = NSLocalizedString(
                "camera_error_initialization_failed", bundle: .module, comment: ""
            )
            showError = true
            return
        }
        delegate.setupCamera()
    }

    func takePicture() {
        guard let delegate = cameraViewDelegate else {
            errorMessage = NSLocalizedString(
                "camera_error_capture_failed", bundle: .module, comment: ""
            )
            showError = true
            return
        }
        delegate.takePicture()
    }

    func stopCamera() {
        cameraViewDelegate?.stopCamera()
    }

    func pauseVideo() {
        cameraViewDelegate?.pauseVideo()
    }

    func pauseCamera() {
        cameraViewDelegate?.pauseCamera()
    }

    func updateComposeUI(
        side: DocumentCaptureSide,
        feedbackType: DocumentFeedbackType,
        showHelpDialog: Bool,
        showRotationAnimation: Bool,
        showLoadingScreen: Bool,
        frontPhotoData: Data?,
        frontPhotoStatus: CaptureStatus?,
        backPhotoData: Data?,
        backPhotoStatus: CaptureStatus?,
        clearFrontPhoto: Bool,
        clearBackPhoto: Bool
    ) {
        self.currentSide = side
        self.feedbackType = feedbackType
        self.showHelpDialog = showHelpDialog
        self.showRotationAnimation = showRotationAnimation
        self.showLoadingScreen = showLoadingScreen

        if clearFrontPhoto {
            self.frontPhotoData = nil
        } else if let data = frontPhotoData {
            self.frontPhotoData = data
        }
        self.frontPhotoStatus = frontPhotoStatus

        if clearBackPhoto {
            self.backPhotoData = nil
        } else if let data = backPhotoData {
            self.backPhotoData = data
        }
        self.backPhotoStatus = backPhotoStatus
    }

    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Camera Delegate Protocol

@MainActor protocol DocumentCaptureCameraDelegate: AnyObject {
    func setupCamera()
    func takePicture()
    func stopCamera()
    func pauseCamera()
    func pauseVideo()
}

// MARK: - Camera View Wrapper

struct DocumentCameraViewWrapper: UIViewRepresentable {
    @ObservedObject var viewModel: DocumentCaptureViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> CameraView {
        let processor = FrameProcessorFactory.createProcessor(
            for: .document,
            delegate: context.coordinator
        )
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

        init(viewModel: DocumentCaptureViewModel) {
            self.viewModel = viewModel
        }

        func setupCamera() {
            guard let cameraView else {
                DispatchQueue.main.async {
                    self.viewModel.errorMessage = NSLocalizedString(
                        "camera_error_view_not_available", bundle: .module, comment: ""
                    )
                    self.viewModel.showError = true
                }
                return
            }
            cameraView.startCamera(side: .back, cameraOutputMode: .image)
        }

        func takePicture() {
            guard let cameraView else {
                DispatchQueue.main.async {
                    self.viewModel.errorMessage = NSLocalizedString(
                        "camera_error_not_ready", bundle: .module, comment: ""
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
            viewModel.showError("Camera error: \(error.localizedDescription)")
        }

        func detectionsReceived(_ results: [DetectionResult]) {
            viewModel.detectionsReceived(results)
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
            // Camera preview
            DocumentCameraViewWrapper(viewModel: viewModel)

            // Native capture overlay - matches KMP DocumentAutoCapture layout
            DocumentCaptureOverlayView(
                side: viewModel.currentSide,
                feedbackType: viewModel.feedbackType,
                showHelpDialog: viewModel.showHelpDialog,
                showRotationAnimation: viewModel.showRotationAnimation,
                frontPhotoData: viewModel.frontPhotoData,
                frontPhotoStatus: viewModel.frontPhotoStatus,
                backPhotoData: viewModel.backPhotoData,
                backPhotoStatus: viewModel.backPhotoStatus,
                onCapture: { viewModel.captureButtonTapped() },
                onHelp: { viewModel.helpRequested() },
                onHelpDismiss: { viewModel.helpDismissed() },
                onCancel: { viewModel.cancelTapped() },
                onRetry: { viewModel.retryTapped() },
                onSwitchToManual: { viewModel.captureButtonTapped() }
            )

            // Loading overlay
            if viewModel.showLoadingScreen {
                LoadingOverlayView(message: TruoraValidationsSDKStrings.documentCaptureProcessing)
            }
        }
        .environmentObject(theme)
        .navigationBarHidden(true)
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text(NSLocalizedString("common_error", bundle: .module, comment: "")),
                message: viewModel.errorMessage.map { Text($0) },
                dismissButton: .default(
                    Text(NSLocalizedString("common_ok", bundle: .module, comment: ""))
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
            viewModel.onWillDisappear()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            viewModel.onWillAppear()
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
    let frontPhotoData: Data?
    let frontPhotoStatus: CaptureStatus?
    let backPhotoData: Data?
    let backPhotoStatus: CaptureStatus?

    let onCapture: () -> Void
    let onHelp: () -> Void
    let onHelpDismiss: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onSwitchToManual: () -> Void

    @EnvironmentObject var theme: TruoraTheme

    init(
        side: DocumentCaptureSide,
        feedbackType: DocumentFeedbackType,
        showHelpDialog: Bool,
        showRotationAnimation: Bool,
        frontPhotoData: Data?,
        frontPhotoStatus: CaptureStatus?,
        backPhotoData: Data?,
        backPhotoStatus: CaptureStatus?,
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
        self.frontPhotoData = frontPhotoData
        self.frontPhotoStatus = frontPhotoStatus
        self.backPhotoData = backPhotoData
        self.backPhotoStatus = backPhotoStatus
        self.onCapture = onCapture
        self.onHelp = onHelp
        self.onHelpDismiss = onHelpDismiss
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.onSwitchToManual = onSwitchToManual
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with document icon and instructions - matches KMP DocumentAutoCaptureHeader
            DocumentCaptureHeaderView(
                side: side,
                showRotationAnimation: showRotationAnimation
            )

            // Main content area with overlay mask
            GeometryReader { geometry in
                ZStack {
                    // Overlay mask with rounded rectangle cutout
                    DocumentCaptureOverlayMask(feedbackType: feedbackType)

                    // Centered feedback message (inside the cutout area)
                    if !showRotationAnimation {
                        DocumentCaptureFeedbackMessage(feedbackType: feedbackType)
                    }

                    // Thumbnails positioned below the mask
                    DocumentCaptureThumbnails(
                        geometry: geometry,
                        frontPhotoData: frontPhotoData,
                        frontPhotoStatus: frontPhotoStatus,
                        backPhotoData: backPhotoData,
                        backPhotoStatus: backPhotoStatus
                    )
                }
            }

            // Footer with help button and manual capture
            // Hide help button when both sides are captured (both have success status)
            DocumentCaptureFooter(
                feedbackType: feedbackType,
                showHelpButton: !(frontPhotoStatus == .success && backPhotoStatus == .success),
                onHelpClick: onHelp,
                onManualCapture: onCapture
            )
        }
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
/// Colored background extending edge-to-edge, document icon + instruction text
/// Figma specs: height 180pt, icon 47x30 in 48x48 container, 16pt spacing, 18pt semibold text
private struct DocumentCaptureHeaderView: View {
    let side: DocumentCaptureSide
    let showRotationAnimation: Bool

    @EnvironmentObject var theme: TruoraTheme

    var body: some View {
        VStack(spacing: 16) {
            if showRotationAnimation {
                // Flip document instruction - two lines
                Text(TruoraValidationsSDKStrings.documentCaptureRotateInstruction)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                // Document icon from Figma - white ID card vector
                // Icon is 47x30 inside a 48x48 container
                documentIcon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 47, height: 30)
                    .frame(width: 48, height: 48)

                // Instruction text - 18sp semibold per Figma
                Text(
                    side == .front
                        ? TruoraValidationsSDKStrings.documentCaptureFrontInstruction
                        : TruoraValidationsSDKStrings.documentCaptureBackInstruction
                )
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(theme.colors.primary900)
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
        case .locate: TruoraValidationsSDKStrings.documentCaptureFeedbackLocate
        case .closer: TruoraValidationsSDKStrings.documentCaptureFeedbackCloser
        case .further: TruoraValidationsSDKStrings.documentCaptureFeedbackFurther
        case .rotate: TruoraValidationsSDKStrings.documentCaptureFeedbackRotate
        case .center: TruoraValidationsSDKStrings.documentCaptureFeedbackCenter
        case .scanning: TruoraValidationsSDKStrings.documentCaptureScanning
        case .scanningManual: TruoraValidationsSDKStrings.documentCaptureScanningManual
        case .searching: TruoraValidationsSDKStrings.documentCaptureScanning
        case .multipleDocuments: TruoraValidationsSDKStrings.documentCaptureFeedbackMultiple
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
        default: .black
        }
    }

    var body: some View {
        if shouldShow {
            Text(feedbackText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(textColor)
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
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 6, y: 6)
                    case .loading:
                        ActivityIndicator(
                            isAnimating: .constant(true), style: .medium, color: .white
                        )
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
                    title: TruoraValidationsSDKStrings.documentCaptureTakePhoto,
                    mode: .picture,
                    action: onManualCapture
                )
            }

            // Bottom bar with help button and logo
            HStack {
                // Help button - hidden when both sides captured
                if showHelpButton {
                    Button(action: onHelpClick) {
                        Text(TruoraValidationsSDKStrings.passiveCaptureHelp)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.colors.gray800)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(theme.colors.gray600, lineWidth: 1)
                            )
                    }
                }

                Spacer()

                // Truora logo
                TruoraValidationsSDKAsset.byTruoraDark.swiftUIImage
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 65, height: 20)
                    .foregroundColor(theme.colors.tint00)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 150)
        .background(theme.colors.primary900)
    }
}

// MARK: - Document Capture Tips Dialog

/// Tips dialog matching KMP GenericTipsDialog pattern
/// Same layout as PassiveCaptureTipsDialog
struct DocumentCaptureTipsDialog: View {
    let onDismiss: () -> Void
    let onManualCapture: () -> Void

    @EnvironmentObject var theme: TruoraTheme

    /// Tips for document capture - matches KMP document_autocapture_tips
    private let tips = [
        TruoraValidationsSDKStrings.documentCaptureHelpTip1,
        TruoraValidationsSDKStrings.documentCaptureHelpTip2,
        TruoraValidationsSDKStrings.documentCaptureHelpTip3,
        TruoraValidationsSDKStrings.documentCaptureHelpTip4
    ]

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .onTapGesture { onDismiss() }

            // Dialog content
            VStack(spacing: 0) {
                // Header with title and close button
                HStack {
                    Text(TruoraValidationsSDKStrings.documentCaptureHelpTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.colors.layoutGray900)

                    Spacer()

                    Button(action: onDismiss) {
                        Text("\u{2715}")
                            .font(.system(size: 16))
                            .foregroundColor(theme.colors.layoutGray900)
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
                                .font(.system(size: 16))
                                .foregroundColor(.black)

                            Text(tip)
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                                .lineSpacing(7)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                // Manual capture button
                TruoraPrimaryButton(
                    title: TruoraValidationsSDKStrings.documentCaptureManualButton,
                    isLoading: false,
                    action: onManualCapture
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color.white)
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
