//
//  DocumentCaptureView.swift
//  validations
//
//  Created by Truora on 23/12/25.
//

import SwiftUI
import TruoraCamera
import TruoraShared

final class DocumentCaptureViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var composeUIState: ComposeUIState = .initial

    var presenter: DocumentCaptureViewToPresenter?
    weak var cameraViewDelegate: DocumentCaptureCameraDelegate?

    struct ComposeUIState: Hashable {
        var side: DocumentCaptureSide
        var feedbackType: DocumentFeedbackType
        var showHelpDialog: Bool
        var showRotationAnimation: Bool
        var showLoadingScreen: Bool

        // We keep Data in the VM for easy bridging and for VC recreation keys.
        var frontPhotoData: Data?
        var frontPhotoStatus: CaptureStatus?
        var backPhotoData: Data?
        var backPhotoStatus: CaptureStatus?

        // Versions force VC recreation when bytes change (Data is not included in equality).
        var frontPhotoVersion: Int
        var backPhotoVersion: Int

        static let initial = ComposeUIState(
            side: .front,
            feedbackType: .scanningManual,
            showHelpDialog: false,
            showRotationAnimation: false,
            showLoadingScreen: false,
            frontPhotoData: nil,
            frontPhotoStatus: nil,
            backPhotoData: nil,
            backPhotoStatus: nil,
            frontPhotoVersion: 0,
            backPhotoVersion: 0
        )

        static func == (lhs: ComposeUIState, rhs: ComposeUIState) -> Bool {
            lhs.side == rhs.side &&
                lhs.feedbackType == rhs.feedbackType &&
                lhs.showHelpDialog == rhs.showHelpDialog &&
                lhs.showRotationAnimation == rhs.showRotationAnimation &&
                lhs.showLoadingScreen == rhs.showLoadingScreen &&
                lhs.frontPhotoStatus == rhs.frontPhotoStatus &&
                lhs.backPhotoStatus == rhs.backPhotoStatus &&
                lhs.frontPhotoVersion == rhs.frontPhotoVersion &&
                lhs.backPhotoVersion == rhs.backPhotoVersion
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(side)
            hasher.combine(feedbackType)
            hasher.combine(showHelpDialog)
            hasher.combine(showRotationAnimation)
            hasher.combine(showLoadingScreen)
            hasher.combine(frontPhotoStatus)
            hasher.combine(backPhotoStatus)
            hasher.combine(frontPhotoVersion)
            hasher.combine(backPhotoVersion)
        }
    }

    func onAppear() {
        presenter?.viewDidLoad()
    }

    func onWillAppear() {
        presenter?.viewWillAppear()
    }

    func onWillDisappear() {
        presenter?.viewWillDisappear()
    }

    func handleCaptureEvent(_ event: DocumentAutoCaptureEvent) {
        presenter?.handleCaptureEvent(event)
    }

    func cameraReady() {
        presenter?.cameraReady()
    }

    func photoCaptured(photoData: Data) {
        presenter?.photoCaptured(photoData: photoData)
    }

    func detectionsReceived(_ results: [DetectionResult]) {
        presenter?.detectionsReceived(results)
    }

    func footerHeightDidChange(pixels: CGFloat) {
        // DocumentAutoCapture currently doesn't expose footer height to iOS.
        // We keep this stub for future parity with PassiveCapture cropping support.
        _ = pixels
    }
}

extension DocumentCaptureViewModel: DocumentCapturePresenterToView {
    func setupCamera() {
        guard let delegate = cameraViewDelegate else {
            DispatchQueue.main.async {
                self.errorMessage = "Camera initialization failed. Please try again."
                self.showError = true
            }
            return
        }
        delegate.setupCamera()
    }

    func takePicture() {
        guard let delegate = cameraViewDelegate else {
            DispatchQueue.main.async {
                self.errorMessage = "Unable to take picture. Please try again."
                self.showError = true
            }
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
        backPhotoStatus: CaptureStatus?
    ) {
        DispatchQueue.main.async {
            var nextState = self.composeUIState
            nextState.side = side
            nextState.feedbackType = feedbackType
            nextState.showHelpDialog = showHelpDialog
            nextState.showRotationAnimation = showRotationAnimation
            nextState.showLoadingScreen = showLoadingScreen

            if let frontPhotoData {
                nextState.frontPhotoData = frontPhotoData
                nextState.frontPhotoVersion += 1
            }
            nextState.frontPhotoStatus = frontPhotoStatus

            if let backPhotoData {
                nextState.backPhotoData = backPhotoData
                nextState.backPhotoVersion += 1
            }
            nextState.backPhotoStatus = backPhotoStatus

            self.composeUIState = nextState
        }
    }

    func showError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
}

protocol DocumentCaptureCameraDelegate: AnyObject {
    func setupCamera()
    func takePicture()
    func stopCamera()
    func pauseCamera()
    func pauseVideo()
}

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
        cameraView.orientation = .vertical // Document capture uses portrait orientation
        context.coordinator.cameraView = cameraView
        viewModel.cameraViewDelegate = context.coordinator
        return cameraView
    }

    func updateUIView(_: CameraView, context _: Context) {}

    final class Coordinator: NSObject, CameraDelegate, DocumentCaptureCameraDelegate {
        let viewModel: DocumentCaptureViewModel
        weak var cameraView: CameraView?

        init(viewModel: DocumentCaptureViewModel) {
            self.viewModel = viewModel
        }

        func setupCamera() {
            guard let cameraView else {
                DispatchQueue.main.async {
                    self.viewModel.errorMessage = "Camera view not available. Please restart the validation."
                    self.viewModel.showError = true
                }
                return
            }
            cameraView.startCamera(side: .back, cameraOutputMode: .image)
        }

        func takePicture() {
            guard let cameraView else {
                DispatchQueue.main.async {
                    self.viewModel.errorMessage = "Camera not ready. Please try again."
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

struct DocumentComposeUIViewWrapper: UIViewControllerRepresentable {
    let side: DocumentCaptureSide
    let feedbackType: DocumentFeedbackType
    let showHelpDialog: Bool
    let showRotationAnimation: Bool
    let showLoadingScreen: Bool
    let frontPhotoData: Data?
    let frontPhotoStatus: CaptureStatus?
    let backPhotoData: Data?
    let backPhotoStatus: CaptureStatus?
    let onEvent: (DocumentAutoCaptureEvent) -> Void
    let composeConfig: TruoraUIConfig

    // Container pattern retained for high-frequency state updates during auto-capture.
    // Enables future optimization via stateful Kotlin controllers without breaking changes.
    // Current Kotlin layer is stateless, so VC is still recreated on each state change.
    func makeUIViewController(context _: Context) -> UIViewController {
        let containerVC = UIViewController()
        let composeVC = createViewController()
        embedChild(composeVC, in: containerVC)
        return containerVC
    }

    func updateUIViewController(_: UIViewController, context _: Context) {}

    private func createViewController() -> UIViewController {
        TruoraUIExportsKt.createDocumentCaptureViewController(
            side: side,
            feedbackType: feedbackType,
            showHelpDialog: showHelpDialog,
            showRotationAnimation: showRotationAnimation,
            frontPhotoData: frontPhotoData?.toKotlinByteArray(),
            frontPhotoStatus: frontPhotoStatus,
            backPhotoData: backPhotoData?.toKotlinByteArray(),
            backPhotoStatus: backPhotoStatus,
            showLoadingScreen: showLoadingScreen,
            loadingType: LoadingType.document,
            onEvent: onEvent,
            config: composeConfig
        )
    }

    private func embedChild(_ child: UIViewController, in parent: UIViewController) {
        parent.addChild(child)
        guard let childView = child.view else { return }
        guard let parentView = parent.view else { return }
        childView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(childView)
        NSLayoutConstraint.activate([
            childView.topAnchor.constraint(equalTo: parentView.topAnchor),
            childView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            childView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
        ])
        child.didMove(toParent: parent)
    }
}

struct DocumentCaptureView: View {
    @ObservedObject var viewModel: DocumentCaptureViewModel
    let composeConfig: TruoraUIConfig

    var body: some View {
        ZStack {
            DocumentCameraViewWrapper(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)

            DocumentComposeUIViewWrapper(
                side: viewModel.composeUIState.side,
                feedbackType: viewModel.composeUIState.feedbackType,
                showHelpDialog: viewModel.composeUIState.showHelpDialog,
                showRotationAnimation: viewModel.composeUIState.showRotationAnimation,
                showLoadingScreen: viewModel.composeUIState.showLoadingScreen,
                frontPhotoData: viewModel.composeUIState.frontPhotoData,
                frontPhotoStatus: viewModel.composeUIState.frontPhotoStatus,
                backPhotoData: viewModel.composeUIState.backPhotoData,
                backPhotoStatus: viewModel.composeUIState.backPhotoStatus,
                onEvent: { event in
                    viewModel.handleCaptureEvent(event)
                },
                composeConfig: composeConfig
            )
            .id(viewModel.composeUIState)
            .edgesIgnoringSafeArea(.all)
            .background(Color.clear)
        }
        .navigationBarHidden(true)
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: viewModel.errorMessage.map { Text($0) },
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            viewModel.onAppear()
            viewModel.onWillAppear()
        }
        .onDisappear {
            viewModel.onWillDisappear()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            viewModel.onWillDisappear()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.onWillAppear()
        }
    }
}
