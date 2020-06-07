//
//  File.swift
//  
//
//  Created by May on 24.05.20.
//

import Foundation

extension Collection where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
    var uint16: UInt16 {
        return data.withUnsafeBytes { $0.load(as: UInt16.self) }
    }
    
    var uint32: UInt32 {
        return data.withUnsafeBytes { $0.load(as: UInt32.self) }
    }
}
