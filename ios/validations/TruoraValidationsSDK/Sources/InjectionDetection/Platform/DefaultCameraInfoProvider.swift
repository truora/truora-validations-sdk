import AVFoundation
import Foundation

/// Production implementation of `CameraInfoProviding` using AVCaptureDevice.DiscoverySession.
///
/// Discovers built-in, external, and continuity cameras and maps them to `CameraDeviceInfo`.
/// Uses `#available` guards for iOS 17+ camera types.
struct DefaultCameraInfoProvider: CameraInfoProviding {
    func discoveredDevices() -> [CameraDeviceInfo] {
        var allDevices: [AVCaptureDevice] = []

        let builtInTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInTelephotoCamera
        ]

        let builtInSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: builtInTypes,
            mediaType: .video,
            position: .unspecified
        )
        allDevices.append(contentsOf: builtInSession.devices)

        if #available(iOS 13.0, *) {
            let ultraWideSession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInUltraWideCamera],
                mediaType: .video,
                position: .unspecified
            )
            allDevices.append(contentsOf: ultraWideSession.devices)
        }

        if #available(iOS 17.0, *) {
            let externalSession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.external],
                mediaType: .video,
                position: .unspecified
            )
            allDevices.append(contentsOf: externalSession.devices)

            let continuitySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.continuityCamera],
                mediaType: .video,
                position: .unspecified
            )
            allDevices.append(contentsOf: continuitySession.devices)
        }

        // Deduplicate by uniqueID since a device may appear in multiple sessions
        var seen = Set<String>()
        var result: [CameraDeviceInfo] = []

        for device in allDevices {
            guard !seen.contains(device.uniqueID) else { continue }
            seen.insert(device.uniqueID)
            result.append(mapDevice(device))
        }

        return result
    }

    // MARK: - Private

    private func mapDevice(_ device: AVCaptureDevice) -> CameraDeviceInfo {
        let deviceType = mapDeviceType(device.deviceType)
        let position = mapPosition(device.position)
        let lensPosition: Float? = device.isFocusModeSupported(.autoFocus) ? device.lensPosition : nil

        return CameraDeviceInfo(
            deviceType: deviceType,
            position: position,
            uniqueID: device.uniqueID,
            lensPosition: lensPosition
        )
    }

    private func mapDeviceType(_ type: AVCaptureDevice.DeviceType) -> CameraDeviceType {
        if type == .builtInWideAngleCamera {
            return .builtInWideAngle
        }
        if type == .builtInTelephotoCamera {
            return .builtInTelephoto
        }

        if #available(iOS 13.0, *), type == .builtInUltraWideCamera {
            return .builtInUltraWide
        }

        if #available(iOS 17.0, *) {
            if type == .external {
                return .external
            }
            if type == .continuityCamera {
                return .continuityCamera
            }
        }

        return .unknown
    }

    private func mapPosition(_ position: AVCaptureDevice.Position) -> String {
        switch position {
        case .back: return "back"
        case .front: return "front"
        case .unspecified: return "unspecified"
        @unknown default: return "unknown"
        }
    }
}
