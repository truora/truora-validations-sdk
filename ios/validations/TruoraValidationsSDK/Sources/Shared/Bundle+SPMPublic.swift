//
//  Bundle+SPMPublic.swift
//  TruoraValidationsSDK
//
//  Provides public access to the SDK resource bundle when building with SPM.
//  SPM generates Bundle.module as internal, so we find the bundle by name at runtime.
//

#if SWIFT_PACKAGE
import Foundation

private class BundleFinder {}

public extension Bundle {
    /// Public accessor for the SDK resource bundle when built as Swift Package.
    /// Locates the resource bundle by name since SPM's Bundle.module is internal.
    static var truoraModule: Bundle {
        // SPM resource bundle naming convention: {PackageName}_{TargetName}
        let bundleName = "TruoraValidationsSDK_TruoraValidationsSDK"
        let bundleNameWithExtension = bundleName + ".bundle"

        // Get the bundle containing our code (BundleFinder class)
        let containingBundle = Bundle(for: BundleFinder.self)

        // Build list of candidate base URLs to search
        var candidates: [URL] = []

        // Main app bundle (most common location for SPM resource bundles)
        if let url = Bundle.main.resourceURL {
            candidates.append(url)
        }
        candidates.append(Bundle.main.bundleURL)

        // Bundle containing our compiled code
        if let url = containingBundle.resourceURL {
            candidates.append(url)
        }
        candidates.append(containingBundle.bundleURL)

        // Parent directories (for framework/plugin scenarios)
        candidates.append(containingBundle.bundleURL.deletingLastPathComponent())
        if let url = containingBundle.resourceURL {
            candidates.append(url.deletingLastPathComponent())
        }

        // Search in each candidate location
        for base in candidates {
            let bundleURL = base.appendingPathComponent(bundleNameWithExtension)
            if let bundle = Bundle(url: bundleURL) {
                return bundle
            }
        }

        // Search all loaded bundles for one matching our name
        let matchingBundle = Bundle.allBundles.first { bundle in
            let path = bundle.bundlePath
            return path.hasSuffix(bundleNameWithExtension) || path.contains(bundleName)
        }
        if let bundle = matchingBundle {
            return bundle
        }

        // Search all frameworks
        if let framework = Bundle.allFrameworks.first(where: { $0.bundlePath.contains(bundleName) }) {
            return framework
        }

        // Search for any bundle that contains our localization files
        let allBundles = Bundle.allBundles + Bundle.allFrameworks
        let testKey = "passive_instructions_title"
        for bundle in allBundles where bundle.url(
            forResource: "Localizable",
            withExtension: "strings",
            subdirectory: nil,
            localization: "es"
        ) != nil {
            let value = bundle.localizedString(forKey: testKey, value: testKey, table: nil)
            if value != testKey {
                return bundle
            }
        }

        // If main bundle has our resources (static linking scenario)
        let mainValue = Bundle.main.localizedString(forKey: testKey, value: testKey, table: nil)
        if mainValue != testKey {
            return Bundle.main
        }

        // Fallback
        return Bundle.main
    }
}
#endif
