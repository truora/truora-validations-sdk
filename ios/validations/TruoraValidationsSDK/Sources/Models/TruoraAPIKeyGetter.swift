//
//  TruoraAPIKeyGetter.swift
//  validations
//
//  Created by Daniel Vilela on 17/11/25.
//

public protocol TruoraAPIKeyGetter {
    func getApiKeyFromSecureLocation() async throws -> String
}
