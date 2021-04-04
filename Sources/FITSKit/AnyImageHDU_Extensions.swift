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

import Foundation
import Accelerate
import FITS

extension AnyImageHDU {
    
    
    public func apply<T: Transformation>(_ transformation: T,
                                  R: inout [Float],
                                  G: inout [Float],
                                  B: inout [Float])
    {
        
        
        guard let width = self.naxis(1), let height = self.naxis(2) , let bitpix = self.bitpix else {
            fatalError("invalid image dimensions")
        }
        
        let bzero = self.bzero ?? 0
        let bscale = self.bscale ?? 1
        
        self.dataUnit?.withUnsafeBytes{ rawPtr in
            
            switch bitpix {
            case .INT16:
                transformation.perform(rawPtr.bindMemory(to: Int16.self), width, height, bzero, bscale, &R, &G, &B)
            default:
                fatalError("Not (yet) implemented")
            }
            
        }
    }
    
    
    
    public func render<T: Transformation>(_ transformation: T) throws -> CGImage
    {
        guard let width = self.naxis(1), let height = self.naxis(2) else {
            fatalError("invalid image dimensions")
        }
        
        let targetDimensions = transformation.targetDimensions(width: width, height: height)
        let targetSize = targetDimensions.width * targetDimensions.height
        
        var A : [FITSByte_F] = .init(repeating: 0, count: targetSize)
        var R : [FITSByte_F] = .init(repeating: 0, count: targetSize)
        var G : [FITSByte_F] = .init(repeating: 0, count: targetSize)
        var B : [FITSByte_F] = .init(repeating: 0, count: targetSize)
        
        self.apply(transformation, R: &R, G: &G, B: &B)
        
        
        var finfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
        finfo.insert(CGBitmapInfo.byteOrder32Little)
        finfo.insert(CGBitmapInfo.floatComponents)
        let rgbFormatF = vImage_CGImageFormat(bitsPerComponent: 32, bitsPerPixel: 128, colorSpace: CGColorSpaceCreateDeviceRGB(), bitmapInfo: finfo)!
        
        let rgbBuffer: vImage_Buffer =
        try A.withUnsafeMutableBytes{ aptr in
            try R.withUnsafeMutableBytes{ rptr in
                try G.withUnsafeMutableBytes{ gptr in
                    try B.withUnsafeMutableBytes{ bptr in
                        
                        var alpha = vImage_Buffer(data: aptr.baseAddress, height: vImagePixelCount(targetDimensions.height), width: vImagePixelCount(targetDimensions.width), rowBytes: targetDimensions.width*4)
                        var red = vImage_Buffer(data: rptr.baseAddress, height: vImagePixelCount(targetDimensions.height), width: vImagePixelCount(targetDimensions.width), rowBytes: targetDimensions.width*4)
                        var green = vImage_Buffer(data: gptr.baseAddress, height: vImagePixelCount(targetDimensions.height), width: vImagePixelCount(targetDimensions.width), rowBytes: targetDimensions.width*4)
                        var blue = vImage_Buffer(data: bptr.baseAddress, height: vImagePixelCount(targetDimensions.height), width: vImagePixelCount(targetDimensions.width), rowBytes: targetDimensions.width*4)
                        
                        var rgbout = try vImage_Buffer(width: targetDimensions.width, height: targetDimensions.height, bitsPerPixel: 128)
                        
                        vImageConvert_PlanarFtoARGBFFFF(&alpha, &red, &green, &blue, &rgbout, 0)
                        
                        return rgbout
                        
                    }
                }
            }
        }
        return try rgbBuffer.createCGImage(format: rgbFormatF)
    }
    
}
