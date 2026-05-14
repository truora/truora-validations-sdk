//
//  ResultLoadingType.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 23/01/26.
//

import Foundation

enum ResultLoadingType {
    case face
    case document
    case invoice

    var gifName: String {
        switch self {
        case .face: "face_loading_icon"
        case .document: "document_loading_icon"
        case .invoice: "invoice_loading_icon"
        }
    }
}
