//
//  Data+KotlinByteArray.swift
//  TruoraValidationsSDK
//
//  Created by Truora on 06/01/26.
//

import Foundation
import TruoraShared

extension Data {
    func toKotlinByteArray() -> KotlinByteArray {
        let dataCount = count
        return withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) -> KotlinByteArray in
            let byteArray = KotlinByteArray(size: Int32(dataCount))
            for index in 0 ..< dataCount {
                let byte = Int8(bitPattern: bufferPointer[index])
                byteArray.set(index: Int32(index), value: byte)
            }
            return byteArray
        }
    }
}
