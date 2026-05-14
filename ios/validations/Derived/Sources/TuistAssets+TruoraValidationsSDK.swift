// swiftlint:disable:this file_name
// swiftlint:disable all
// swift-format-ignore-file
// swiftformat:disable all
// Generated using tuist — https://github.com/tuist/tuist



#if os(macOS)
#if hasFeature(InternalImportsByDefault)
public import AppKit
#else
import AppKit
#endif
#else
#if hasFeature(InternalImportsByDefault)
public import UIKit
#else
import UIKit
#endif
#endif

#if canImport(SwiftUI)
#if hasFeature(InternalImportsByDefault)
public import SwiftUI
#else
import SwiftUI
#endif
#endif

// MARK: - Asset Catalogs

public enum TruoraValidationsSDKAsset: Sendable {
  public static let all = TruoraValidationsSDKImages(name: "all")
  public static let ar = TruoraValidationsSDKImages(name: "ar")
  public static let bo = TruoraValidationsSDKImages(name: "bo")
  public static let br = TruoraValidationsSDKImages(name: "br")
  public static let byTruora = TruoraValidationsSDKImages(name: "by_truora")
  public static let cl = TruoraValidationsSDKImages(name: "cl")
  public static let co = TruoraValidationsSDKImages(name: "co")
  public static let coInvoiceAlcanosFront = TruoraValidationsSDKImages(name: "co_invoice_alcanos_front")
  public static let coInvoiceAlcanosLogo = TruoraValidationsSDKImages(name: "co_invoice_alcanos_logo")
  public static let coInvoiceGasesOrienteFront = TruoraValidationsSDKImages(name: "co_invoice_gases_oriente_front")
  public static let coInvoiceGasesOrienteLogo = TruoraValidationsSDKImages(name: "co_invoice_gases_oriente_logo")
  public static let coInvoiceMetrogasFront = TruoraValidationsSDKImages(name: "co_invoice_metrogas_front")
  public static let coInvoiceMetrogasLogo = TruoraValidationsSDKImages(name: "co_invoice_metrogas_logo")
  public static let cr = TruoraValidationsSDKImages(name: "cr")
  public static let documentBack = TruoraValidationsSDKImages(name: "document_back")
  public static let documentFront = TruoraValidationsSDKImages(name: "document_front")
  public static let documentIntro = TruoraValidationsSDKImages(name: "document_intro")
  public static let ec = TruoraValidationsSDKImages(name: "ec")
  public static let iconLock = TruoraValidationsSDKImages(name: "icon_lock")
  public static let invoiceIcon = TruoraValidationsSDKImages(name: "invoice_icon")
  public static let invoiceInstructions = TruoraValidationsSDKImages(name: "invoice_instructions")
  public static let invoiceTipIllustration = TruoraValidationsSDKImages(name: "invoice_tip_illustration")
  public static let logoTruora = TruoraValidationsSDKImages(name: "logo_truora")
  public static let mx = TruoraValidationsSDKImages(name: "mx")
  public static let mxInvoiceCfeFront = TruoraValidationsSDKImages(name: "mx_invoice_cfe_front")
  public static let mxInvoiceCfeLogo = TruoraValidationsSDKImages(name: "mx_invoice_cfe_logo")
  public static let mxInvoiceTelmexFront = TruoraValidationsSDKImages(name: "mx_invoice_telmex_front")
  public static let mxInvoiceTelmexLogo = TruoraValidationsSDKImages(name: "mx_invoice_telmex_logo")
  public static let mxInvoiceTotalplayFront = TruoraValidationsSDKImages(name: "mx_invoice_totalplay_front")
  public static let mxInvoiceTotalplayLogo = TruoraValidationsSDKImages(name: "mx_invoice_totalplay_logo")
  public static let passiveIntro = TruoraValidationsSDKImages(name: "passive_intro")
  public static let pe = TruoraValidationsSDKImages(name: "pe")
  public static let resultCompleted = TruoraValidationsSDKImages(name: "result_completed")
  public static let resultFailure = TruoraValidationsSDKImages(name: "result_failure")
  public static let resultSuccess = TruoraValidationsSDKImages(name: "result_success")
  public static let sv = TruoraValidationsSDKImages(name: "sv")
  public static let ve = TruoraValidationsSDKImages(name: "ve")
}

// MARK: - Implementation Details

public struct TruoraValidationsSDKImages: Sendable {
  public let name: String

  #if os(macOS)
  public typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  public typealias Image = UIImage
  #endif

  public var image: Image {
    let bundle = Bundle.module
    #if os(iOS) || os(tvOS) || os(visionOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let image = bundle.image(forResource: NSImage.Name(name))
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
  public var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
public extension SwiftUI.Image {
  init(asset: TruoraValidationsSDKImages) {
    let bundle = Bundle.module
    self.init(asset.name, bundle: bundle)
  }

  init(asset: TruoraValidationsSDKImages, label: Text) {
    let bundle = Bundle.module
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: TruoraValidationsSDKImages) {
    let bundle = Bundle.module
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftformat:enable all
// swiftlint:enable all
