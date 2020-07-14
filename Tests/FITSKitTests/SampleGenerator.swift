//
//  File.swift
//  
//
//  Created by May on 10.06.20.
//
import FITS
import Foundation

public struct Sample {
    
    enum Channel : Int {
        case red = 0
        case green = 1
        case blue = 2
    }
    
    func rgb<D: FITSByte>(_ bitpix : D.Type, blockSize: Int) -> FitsFile {
        
        let red : [D] = imageData(.red, blockSize: blockSize)
        let green : [D] = imageData(.green, blockSize: blockSize)
        let blue : [D] = imageData(.blue, blockSize: blockSize)
        
        let prime = PrimaryHDU(width: blockSize * 3, height: blockSize * 3, vectors: red, green, blue)
        //prime.header(HDUKeyword.COMMENT, value: nil, comment: "FITSKit \(D.bitpix) SAMPLE")
        
        return FitsFile(prime: prime)
    }
    
    func imageData<F: FITSByte>(_ channel: Channel, blockSize: Int) -> [F] {
        
        let min = F.min.bigEndian
        let max = F.max.bigEndian
        let size = blockSize
        
        var array : [F] = .init()
        let one : [F] = .init(repeating: max, count: size)
        let zero : [F] = .init(repeating: min, count: 2*size)
        
        var partial : [F] = .init()
        partial.append(contentsOf: one)
        partial.append(contentsOf: zero)
        let filled : [F] = .init(repeating: max, count: 3*size)
        
        for _ in 0..<size{
            if channel == .red {
                array.append(contentsOf: filled)
            } else {
                array.append(contentsOf: partial)
            }
        }
        for _ in 0..<size{
            if channel == .blue {
                array.append(contentsOf: filled)
            } else {
                array.append(contentsOf: partial)
            }
        }
        for _ in 0..<size{
            if channel == .green {
                array.append(contentsOf: filled)
            } else {
                array.append(contentsOf: partial)
            }
        }
        return array
    }
    
}
