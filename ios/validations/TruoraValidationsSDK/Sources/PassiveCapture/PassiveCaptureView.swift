//
//  PassiveCaptureView.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 30/10/25.
//

import SwiftUI
import TruoraCamera
import TruoraShared

class PassiveCaptureViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var composeUIState: ComposeUIState = .init(
        state: .countdown,
        feedback: .none,
        countdown: 3,
        showHelpDialog: false,
        showSettingsPrompt: false,
        lastFrameData: nil,
        uploadState: .none
    )

    var presenter: PassiveCaptureViewToPresenter?
    weak var cameraViewDelegate: CameraViewDelegate?

    struct ComposeUIState: Hashable {
        var state: PassiveCaptureState
        var feedback: FeedbackType
        var countdown: Int32
        var showHelpDialog: Bool
        var showSettingsPrompt: Bool
        var lastFrameData: KotlinByteArray?
        var uploadState: UploadState

        static func == (lhs: ComposeUIState, rhs: ComposeUIState) -> Bool {
            lhs.state == rhs.state &&
                lhs.feedback == rhs.feedback &&
                lhs.countdown == rhs.countdown &&
                lhs.showHelpDialog == rhs.showHelpDialog &&
                lhs.showSettingsPrompt == rhs.showSettingsPrompt &&
                lhs.uploadState == rhs.uploadState
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(state)
            hasher.combine(feedback)
            hasher.combine(countdown)
            hasher.combine(showHelpDialog)
            hasher.combine(showSettingsPrompt)
            hasher.combine(uploadState)
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

    func handleCaptureEvent(_ event: PassiveCaptureEvent) {
        presenter?.handleCaptureEvent(event)
    }

    func cameraReady() {
        presenter?.cameraReady()
    }

    func cameraPermissionDenied() {
        presenter?.cameraPermissionDenied()
    }

    func videoRecordingCompleted(videoData: Data) {
        presenter?.videoRecordingCompleted(videoData: videoData)
    }

    func lastFrameCaptured(frameData: Data) {
        presenter?.lastFrameCaptured(frameData: frameData)
    }

    func detectionsReceived(_ results: [DetectionResult]) {
        presenter?.detectionsReceived(results)
    }

    func footerHeightDidChange(pixels: CGFloat) {
        guard let delegate = cameraViewDelegate else {
            print("⚠️ footerHeightDidChange failed - delegate is nil")
            return
        }
        let points = pixels / UIScreen.main.scale
        delegate.setVisibleViewport(bottomInset: points)
    }
}

extension PassiveCaptureViewModel: PassiveCapturePresenterToView {
    func setupCamera() {
        print("🟢 Setting up camera")
        guard let delegate = cameraViewDelegate else {
            print("⚠️ setupCamera() failed - delegate is nil")
            DispatchQueue.main.async {
                self.errorMessage = "Camera initialization failed. Please try again."
                self.showError = true
            }
            return
        }
        delegate.setupCamera()
    }

    func startRecording() {
        print("🟢 PassiveCaptureViewModel: Starting recording")
        guard let delegate = cameraViewDelegate else {
            print("⚠️ startRecording() failed - delegate is nil")
            DispatchQueue.main.async {
                self.errorMessage = "Unable to start recording. Please try again."
                self.showError = true
            }
            return
        }
        delegate.startRecording()
    }

    func stopRecording() {
        print("🟢 Stopping recording")
        guard let delegate = cameraViewDelegate else {
            print("⚠️ stopRecording() failed - delegate is nil")
            DispatchQueue.main.async {
                let message = "Unable to stop recording properly. The camera may still be in use."
                self.errorMessage = message
                self.showError = true
            }
            return
        }
        delegate.stopRecording(skipMediaNotification: false)
    }

    func stopCamera() {
        print("🟢 Stopping camera")
        guard let delegate = cameraViewDelegate else {
            print("⚠️ stopCamera() failed - delegate is nil")
            return
        }
        delegate.stopCamera()
    }

    func pauseCamera() {
        print("🟢 PassiveCaptureViewModel: Pausing camera")
        guard let delegate = cameraViewDelegate else {
            print("⚠️ PassiveCaptureViewModel: pauseCamera() called but delegate is nil")
            return
        }
        delegate.pauseCamera()
    }

    func pauseVideo() {
        print("🟢 PassiveCaptureViewModel: Pausing video")
        guard let delegate = cameraViewDelegate else {
            print("⚠️ PassiveCaptureViewModel: pauseVideo() called but delegate is nil")
            return
        }
        delegate.stopRecording(skipMediaNotification: true)
    }

    func resumeVideo() {
        startRecording()
    }

    func updateComposeUI(
        state: PassiveCaptureState,
        feedback: FeedbackType,
        countdown: Int32,
        showHelpDialog: Bool,
        showSettingsPrompt: Bool,
        lastFrameData: Data?,
        uploadState: UploadState
    ) {
        DispatchQueue.main.async {
            var kotlinBytes: KotlinByteArray?
            if let frameData = lastFrameData {
                kotlinBytes = frameData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> KotlinByteArray in
                    let byteArray = KotlinByteArray(size: Int32(frameData.count))
                    for index in 0 ..< frameData.count {
                        let byte = Int8(bitPattern: buffer[index])
                        byteArray.set(index: Int32(index), value: byte)
                    }
                    return byteArray
                }
            }

            self.composeUIState = ComposeUIState(
                state: state,
                feedback: feedback,
                countdown: countdown,
                showHelpDialog: showHelpDialog,
                showSettingsPrompt: showSettingsPrompt,
                lastFrameData: kotlinBytes,
                uploadState: uploadState
            )
        }
    }

    func showError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
}

protocol CameraViewDelegate: AnyObject {
    func setupCamera()
    func startRecording()
    func stopRecording(skipMediaNotification: Bool)
    func stopCamera()
    func pauseCamera()
    func setVisibleViewport(bottomInset: CGFloat)
}

// MARK: AL-180 Decide the type dynamically as .face or .none when config is available

struct CameraViewWrapper: UIViewRepresentable {
    @ObservedObject var viewModel: PassiveCaptureViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> CameraView {
        let processor = FrameProcessorFactory.createProcessor(
            for: .face,
            delegate: context.coordinator
        )
        let cameraView = CameraView(frameProcessor: processor)
        cameraView.backgroundColor = .clear
        cameraView.delegate = context.coordinator
        context.coordinator.cameraView = cameraView
        viewModel.cameraViewDelegate = context.coordinator
        return cameraView
    }

    func updateUIView(_: CameraView, context _: Context) {}

    class Coordinator: NSObject, CameraDelegate, CameraViewDelegate {
        let viewModel: PassiveCaptureViewModel
        weak var cameraView: CameraView?

        init(viewModel: PassiveCaptureViewModel) {
            self.viewModel = viewModel
        }

        func setupCamera() {
            guard let cameraView else {
                print("⚠️ setupCamera() failed - cameraView is nil")
                DispatchQueue.main.async {
                    let message = "Camera view not available. Please restart the validation."
                    self.viewModel.errorMessage = message
                    self.viewModel.showError = true
                }
                return
            }
            // Passive capture always uses front camera only - camera switching is not supported
            cameraView.startCamera(side: .front, cameraOutputMode: .video)
        }

        func startRecording() {
            guard let cameraView else {
                print("⚠️ CameraViewDelegate: startRecording() called but cameraView is nil")
                DispatchQueue.main.async {
                    self.viewModel.errorMessage = "Camera not ready to record. Please try again."
                    self.viewModel.showError = true
                }
                return
            }
            cameraView.startRecordingVideo()
        }

        func stopRecording(skipMediaNotification: Bool) {
            guard let cameraView else {
                print("⚠️ CameraViewDelegate: stopRecording() called but cameraView is nil")
                DispatchQueue.main.async {
                    self.viewModel.errorMessage = "Unable to stop recording. " +
                        "Camera resources may not be released properly."
                    self.viewModel.showError = true
                }
                return
            }
            cameraView.stopVideoRecording(skipMediaNotification: skipMediaNotification)
        }

        func stopCamera() {
            guard let cameraView else {
                print("⚠️ CameraViewDelegate: stopCamera() called but cameraView is nil")
                return
            }
            cameraView.stopCamera()
        }

        func pauseCamera() {
            guard let cameraView else {
                print("⚠️ CameraViewDelegate: pauseCamera() called but cameraView is nil")
                return
            }
            cameraView.pauseCamera()
        }

        func setVisibleViewport(bottomInset: CGFloat) {
            guard let cameraView else {
                print("⚠️ setVisibleViewport() failed - cameraView is nil")
                return
            }
            print("🟢 visible viewport bottom inset: \(bottomInset) points")
            cameraView.setVisibleViewport(bottomInset: bottomInset)
        }

        func cameraReady() {
            print("🟢 CameraViewWrapper: Camera ready callback")
            viewModel.cameraReady()
        }

        func mediaReady(media: Data) {
            print("🟢 CameraViewWrapper: Video recording completed, \(media.count) bytes")
            viewModel.videoRecordingCompleted(videoData: media)
        }

        func lastFrameCaptured(frameData: Data) {
            print("🟢 CameraViewWrapper: Last frame captured, \(frameData.count) bytes")
            viewModel.lastFrameCaptured(frameData: frameData)
        }

        func reportError(error: CameraError) {
            print("❌ CameraViewWrapper: Camera error: \(error)")

            if case .permissionDenied = error {
                viewModel.cameraPermissionDenied()
            } else {
                viewModel.showError("Camera error: \(error.localizedDescription)")
            }
        }

        func detectionsReceived(_ results: [DetectionResult]) {
            viewModel.detectionsReceived(results)
        }
    }
}

struct ComposeUIViewWrapper: UIViewControllerRepresentable {
    let state: PassiveCaptureState
    let feedback: FeedbackType
    let countdown: Int32
    let showHelpDialog: Bool
    let showSettingsPrompt: Bool
    let lastFrameData: KotlinByteArray?
    let uploadState: UploadState
    let onEvent: (PassiveCaptureEvent) -> Void
    let onViewportChanged: ((KotlinInt) -> Void)?
    let composeConfig: TruoraUIConfig

    // Container pattern retained for high-frequency state updates during face capture.
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
        TruoraUIExportsKt.createPassiveCaptureViewController(
            state: state,
            feedback: feedback,
            countdown: countdown,
            showHelpDialog: showHelpDialog,
            showSettingsPrompt: showSettingsPrompt,
            config: composeConfig,
            lastFrameData: lastFrameData,
            uploadState: uploadState,
            onEvent: onEvent,
            onViewportChanged: onViewportChanged
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

struct PassiveCaptureView: View {
    @ObservedObject var viewModel: PassiveCaptureViewModel
    let composeConfig: TruoraUIConfig

    var body: some View {
        ZStack {
            CameraViewWrapper(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)

            ComposeUIViewWrapper(
                state: viewModel.composeUIState.state,
                feedback: viewModel.composeUIState.feedback,
                countdown: viewModel.composeUIState.countdown,
                showHelpDialog: viewModel.composeUIState.showHelpDialog,
                showSettingsPrompt: viewModel.composeUIState.showSettingsPrompt,
                lastFrameData: viewModel.composeUIState.lastFrameData,
                uploadState: viewModel.composeUIState.uploadState,
                onEvent: { event in
                    viewModel.handleCaptureEvent(event)
                },
                onViewportChanged: { footerHeightPixels in
                    viewModel.footerHeightDidChange(pixels: CGFloat(footerHeightPixels))
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
