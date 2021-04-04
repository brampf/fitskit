/*
 
 Copyright (c) <2020>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 
 */
import FITS
import Foundation

import Accelerate

public struct FITSByteTool {
    
    /**
     Converts the `Data` to elements of the desired `DataLayout`
     
     */
    public static func asLittleEndian<D: FITSByte>(_ data: inout DataUnit) -> [D]{
        
        return data.withUnsafeBytes { mptr8 in
            mptr8.bindMemory(to: D.self).map{$0.littleEndian}
        }
    }
    
    /**
     Converts the `Data` to elements of the desired `DataLayout`
     
     */
    public static func asBigEndian<D: FITSByte>(_ data: inout DataUnit) -> [D]{
        
        return data.withUnsafeBytes { mptr8 in
            mptr8.bindMemory(to: D.self).map{$0.bigEndian}
        }
    }
    
    /**
     Converts the `Data` to a  sequence of `FITSByte_F`
     
     */
    @available(*, deprecated, message: "Normalisation to Float moved to FITSByte.normalize")
    public static func normalize_F(_ data: inout DataUnit, width: Int, height: Int, bscale: Float, bzero: Float, _ bitpix: BITPIX) -> [FITSByte_F]{
        
        switch bitpix {
        case .UINT8:
            return data.withUnsafeBytes { mptr8 in
                mptr8.bindMemory(to: FITSByte_8.self).map{ $0.bigEndian.normalize(bzero, bscale, .min, .max) }
            }
        case .INT16:
            return data.withUnsafeBytes { mptr8 in
                mptr8.bindMemory(to: FITSByte_16.self).map{ $0.bigEndian.normalize(bzero, bscale, .min, .max) }
            }
        case .INT32:
            return data.withUnsafeBytes { mptr8 in
                mptr8.bindMemory(to: FITSByte_32.self).map{ $0.bigEndian.normalize(bzero, bscale, .min, .max) }
            }
        case .INT64:
            return data.withUnsafeBytes { mptr8 in
                mptr8.bindMemory(to: FITSByte_64.self).map{ $0.bigEndian.normalize(bzero, bscale, .min, .max) }
            }
        case .FLOAT32:
            return data.withUnsafeBytes { mptr8 in
                mptr8.bindMemory(to: FITSByte_F.self).map{ Float(bitpix: $0.bigEndian) }
            }
        case .FLOAT64:
            return data.withUnsafeBytes { mptr8 in
                mptr8.bindMemory(to: FITSByte_D.self).map{ Float(bitpix: $0.bigEndian) }
            }
        }
    }
    
    /**
     Transforms the information form `Data`in an *three* layer, interleaved RGBA matrix in which all values are of the required`DataLayout`
     
     RRRR             RGB
     GGG      >       RGB
     BBB                 RGB
     */
    public static func RGB<D: FITSByte>(_ data: inout DataUnit, width: Int, height: Int) -> [D] {
        
        let layerSize = width * height
        
        let tmp : [D] = data.withUnsafeBytes { mptr8 in
            mptr8.bindMemory(to: D.self).map{$0.littleEndian}
        }
        var array : [D] = .init(repeating: D.min, count: tmp.count)
        for idx in stride(from: 0, to: tmp.count-3, by: 3) {
            array[idx+0] = tmp[idx/3+layerSize*0]
            array[idx+1] = tmp[idx/3+layerSize*1]
            array[idx+2] = tmp[idx/3+layerSize*2]
        }
        return array
    }
    
    /**
     Transforms the information form `Data`in an *three* layer, interleaved RGBA matrix in which all values are of `FITSByte_F`
     
     RRRR             RGB
     GGG      >       RGB
     BBB                 RGB
     */
    public static func RGBFFF(_ data: inout DataUnit, width: Int, height: Int, bscale: Float, bzero: Float, _ bitpix: BITPIX) -> [FITSByte_F] {
        
        let layerSize = width * height
        
        let tmp = normalize_F(&data, width: width, height: height, bscale: bscale, bzero: bzero, bitpix)
        
        var array : [Float] = .init(repeating: FITSByte_F.zero, count: tmp.count)
        for idx in stride(from: 0, to: tmp.count-3, by: 3) {
            array[idx+0] = tmp[idx/3+layerSize*0]
            array[idx+1] = tmp[idx/3+layerSize*1]
            array[idx+2] = tmp[idx/3+layerSize*2]
        }
        return array
    }
    
    /**
    Transforms the information form `Data`in an *four* layer, interleaved RGBA matrix in which all values are of `FITSByte_F`
     
     RRRR             RGBA
     GGG      >       RGBA
     BBB                 RGBA
     */
    public static func RGBAFFFF(_ data: inout DataUnit, width: Int, height: Int, bscale: Float, bzero: Float, _ bitpix: BITPIX) -> [FITSByte_F] {
        
        let layerSize = width * height
        
        let tmp = normalize_F(&data, width: width, height: height, bscale: bscale, bzero: bzero, bitpix)
        
        var array : [Float] = .init(repeating: FITSByte_F.zero, count: width*height*4)
        for idx in stride(from: 0, to: array.count-4, by: 4) {
            array[idx+0] = tmp[idx/4+layerSize*0]
            array[idx+1] = tmp[idx/4+layerSize*1]
            array[idx+2] = tmp[idx/4+layerSize*2]
            array[idx+3] = Float.zero
        }
        return array
    }
}

extension Float {
    
    /// initializer who accepts  `BITPIX`
    public init<D: FITSByte>(bitpix: D) {
        
        switch D.self {
        case is FITSByte_8.Type:
            self.init(bitpix as! FITSByte_8)
        case is FITSByte_16.Type:
            self.init(bitpix as! FITSByte_16)
        case is FITSByte_32.Type:
            self.init(bitpix as! FITSByte_32)
        case is FITSByte_64.Type:
            self.init(bitpix as! FITSByte_64)
        case is FITSByte_F.Type:
            self.init(bitpix as! FITSByte_F)
        case is FITSByte_D.Type:
            self.init(bitpix as! FITSByte_D)
        default:
            self.init()
        }
    }
}
