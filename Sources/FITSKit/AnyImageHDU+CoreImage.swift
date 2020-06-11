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
import Accelerate
import Foundation

extension AnyImageHDU {
    
    public var mono : CGImage? {
        
        guard
            var data = self.dataUnit,
            let width = self.naxis(1),
            let height = self.naxis(2),
            let bitpix = self.bitpix
        else {
            return nil
        }
        
        let buffer = self.monoBuffer(&data, width: width, height: height, bitpix: bitpix)
        
        let info = self.bitmapInfo(bitpix)
        let format = vImage_CGImageFormat(bitsPerComponent: bitpix.bits, bitsPerPixel: bitpix.bits, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: info)!
        
        return try? buffer.createCGImage(format: format)
    }
    
    public var rgb : CGImage? {
        
        guard
            var data = self.dataUnit,
            let width = self.naxis(1),
            let height = self.naxis(2),
            let bitpix = self.bitpix
            else {
                return nil
        }
        
        let buffer = self.rgbBuffer(&data, width: width, height: height, bitpix: bitpix)
        
        let info = self.bitmapInfo(bitpix)
        let format = vImage_CGImageFormat(bitsPerComponent: bitpix.bits, bitsPerPixel: bitpix.bits * 3, colorSpace: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
        
        return try? buffer.createCGImage(format: format)
    }
    
    public func convert<D: DataLayout>(_ data: inout Data, width: Int, height: Int) -> [D]{
        
        return data.withUnsafeMutableBytes { mptr8 in
            mptr8.bindMemory(to: D.self).map{$0.littleEndian}
        }
    }

    public func copynvert<D: DataLayout>(_ data: inout Data, width: Int, height: Int) -> [D] {
        
        let layerSize = width * height
        
        let tmp : [D] = data.withUnsafeMutableBytes { mptr8 in
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
    
    public func monoBuffer(_ data: inout Data, width: Int, height: Int, bitpix: BITPIX) -> vImage_Buffer {
        
        switch bitpix {
        case .UINT8:
            var  raw : [BITPIX_8] =  convert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * bitpix.size )
            }
        case .INT16:
            var  raw : [BITPIX_16] =  convert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * bitpix.size )
            }
        case .INT32:
            var  raw : [BITPIX_32] =  convert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * bitpix.size )
            }
        case .INT64:
            var  raw : [BITPIX_64] =  convert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * bitpix.size )
            }
        case .FLOAT32:
            var  raw : [BITPIX_F] =  convert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * bitpix.size )
            }
        case .FLOAT64:
            var  raw : [BITPIX_D] =  convert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * bitpix.size )
            }
        }
        
    }
    
    public func rgbBuffer(_ data: inout Data, width: Int, height: Int, bitpix: BITPIX) -> vImage_Buffer {
        
        switch bitpix {
        case .UINT8:
            var  raw : [BITPIX_8] =  copynvert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 3 * bitpix.size )
            }
        case .INT16:
            var  raw : [BITPIX_16] =  copynvert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 3 * bitpix.size )
            }
        case .INT32:
            var  raw : [BITPIX_32] =  copynvert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 3 * bitpix.size )
            }
        case .INT64:
            var  raw : [BITPIX_64] =  copynvert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 3 * bitpix.size )
            }
        case .FLOAT32:
            var  raw : [BITPIX_F] =  copynvert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 3 * bitpix.size )
            }
        case .FLOAT64:
            var  raw : [BITPIX_D] =  copynvert(&data, width: width, height: height)
            return raw.withUnsafeMutableBytes { ptr in
                vImage_Buffer(data: ptr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 3 * bitpix.size )
            }
        }
        
    }
    
    public func bitmapInfo(_ bitpix : BITPIX) -> CGBitmapInfo {
        
        var info = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        switch bitpix {
        case .UINT8:
            //info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue))
            break
        case .INT16:
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.order16Little.rawValue))
            break
        case .INT32:
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.order32Little.rawValue))
            break
        case .INT64:
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue))
            break
        case .FLOAT32:
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.order32Big.rawValue))
            info.insert(.floatComponents)
            break
        case .FLOAT64:
            info.insert(.floatComponents)
            break
        }
        return info
        
    }
    
}
