//
//  FrameProcessorFactory.swift
//  TruoraCamera
//
//  Created by Brayan Escobar on 11/26/25.
//

import Foundation

/// Factory for creating frame processors based on detection type
public class FrameProcessorFactory {
    public static func createProcessor(
        for type: DetectionType,
        delegate: CameraDelegate?
    ) -> FrameProcessor? {
        switch type {
        case .face:
            FaceFrameProcessor(delegate: delegate)
        case .document:
            DocumentFrameProcessor(delegate: delegate)
        case .none:
            nil
        }
    }
}
