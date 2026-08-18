//
//  MLLifecycleLoggerAdapter.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 06/02/26.
//

import Foundation
import TruoraCamera

/// Bridges TruoraCamera's MLLifecycleLogger protocol to TruoraLogger.
/// All log calls are fire-and-forget using Task to avoid blocking
/// the synchronous frame processing pipeline.
final class MLLifecycleLoggerAdapter: MLLifecycleLogger {
    private let logger: TruoraLogger

    init(logger: TruoraLogger) {
        self.logger = logger
    }

    func logModelLoadSucceeded(modelName: String) {
        Task {
            await logger.logML(
                eventName: "model_load_succeeded",
                level: .info,
                errorMessage: nil,
                retention: .oneWeek,
                metadata: ["name": modelName]
            )
        }
    }

    func logModelLoadFailed(modelName: String, errorMessage: String) {
        Task {
            await logger.logML(
                eventName: "model_load_failed",
                level: .error,
                errorMessage: errorMessage,
                retention: .oneWeek,
                metadata: ["name": modelName]
            )
        }
    }

    func logModelInitSucceeded(modelName: String) {
        Task {
            await logger.logML(
                eventName: "model_init_succeeded",
                level: .info,
                errorMessage: nil,
                retention: .oneWeek,
                metadata: ["name": modelName]
            )
        }
    }

    func logModelInitFailed(modelName: String, errorMessage: String) {
        Task {
            await logger.logML(
                eventName: "model_init_failed",
                level: .error,
                errorMessage: errorMessage,
                retention: .oneWeek,
                metadata: ["name": modelName]
            )
        }
    }

    func logModelPredictionFinished(modelName: String) {
        Task {
            await logger.logML(
                eventName: "model_prediction_finished",
                level: .info,
                errorMessage: nil,
                retention: .oneWeek,
                metadata: ["name": modelName]
            )
        }
    }

    func logModelPredictionFailed(modelName: String, errorMessage: String) {
        Task {
            await logger.logML(
                eventName: "model_prediction_failed",
                level: .error,
                errorMessage: errorMessage,
                retention: .oneWeek,
                metadata: ["name": modelName]
            )
        }
    }

    func logFaceDetectionInferenceFailed(errorMessage: String) {
        Task {
            await logger.logML(
                eventName: "face_detection_inference_failed",
                level: .error,
                errorMessage: errorMessage,
                retention: .oneWeek,
                metadata: ["name": "face_detector"]
            )
        }
    }
}
