//
//  FaceValidationConfig.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 17/11/25.
//

import Foundation

// MARK: - Face Validation Configuration

/// Configuration for Face Capture validation.
/// Use the builder pattern to configure face validation parameters.
public class Face {
    private var _referenceFace: ReferenceFace?
    private var _similarityThreshold: Float = 0.8
    private var _shouldWaitForResults: Bool = true
    private var _useAutocapture: Bool = true
    private var _timeoutSeconds: Int = 60

    public required init() {}

    public var referenceFace: ReferenceFace? {
        _referenceFace
    }

    public var similarityThreshold: Float {
        _similarityThreshold
    }

    public var shouldWaitForResults: Bool {
        _shouldWaitForResults
    }

    public var useAutocapture: Bool {
        _useAutocapture
    }

    public var timeoutSeconds: Int {
        _timeoutSeconds
    }

    /// Sets the reference face image to compare against.
    ///
    /// - Parameter referenceFace: The reference face image source
    /// - Returns: This Face for method chaining
    @discardableResult
    public func useReferenceFace(_ referenceFace: ReferenceFace) -> Face {
        _referenceFace = referenceFace
        return self
    }

    /// Sets the similarity threshold for face comparison.
    /// Values outside the valid range (0.0 to 1.0) will be clamped automatically.
    ///
    /// - Parameter threshold: A value between 0.0 and 1.0 representing the required similarity
    /// - Returns: This Face for method chaining
    @discardableResult
    public func setSimilarityThreshold(_ threshold: Float) -> Face {
        _similarityThreshold = min(max(threshold, 0.0), 1.0)
        return self
    }

    /// Sets whether to wait and show the validation results to the user.
    ///
    /// - Parameter enabled: true to show results view, false to skip it (default: true)
    /// - Returns: This Face for method chaining
    @discardableResult
    public func enableWaitForResults(_ enabled: Bool) -> Face {
        _shouldWaitForResults = enabled
        return self
    }

    /// Sets whether to enable auto-detect and auto-capture of the face.
    ///
    /// - Parameter enabled: true to enable auto-capture, false for manual capture (default: true)
    /// - Returns: This Face for method chaining
    @discardableResult
    public func enableAutocapture(_ enabled: Bool) -> Face {
        _useAutocapture = enabled
        return self
    }

    /// Sets the timeout in seconds for completing the validation.
    /// Negative values will be clamped to 0.
    ///
    /// - Parameter seconds: The timeout duration in seconds (default: 60)
    /// - Returns: This Face for method chaining
    @discardableResult
    public func setTimeout(_ seconds: Int) -> Face {
        _timeoutSeconds = max(seconds, 0)
        return self
    }
}
