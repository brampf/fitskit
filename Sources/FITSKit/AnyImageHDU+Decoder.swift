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
    
    /**
     Autoselects an approriate decoder for the dataUnit based on the metadata proficed in the headerUnit
     - Returns: a rendered `CGImage`
     */
    public func decode() throws -> CGImage {
        
        return try self.decode { buffer, format in
            try buffer.createCGImage(format: format)
        }
    }
        
    /**
     Autoselects an approriate decoder for the dataUnit based on the metadata proficed in the headerUnit
    
     - Parameter resultHandler: handler to process the `vImage_Buffer` and `vImage_CGImageFormat`
     - Returns: the result of the resultHandler
     */
    public func decode<R>( _ resultHandler: (inout vImage_Buffer, vImage_CGImageFormat) throws -> R) throws -> R {
        
        if let pat : String = self.headerUnit["BAYERPAT"], pat.lowercased().contains("rggb") {
            return try self.decode(BayerDecoder.self, .RGGB){ buffer in
                try resultHandler(&buffer, BayerDecoder.cgImageFormat)
            }
        } else if self.naxis == 3 {
            return try self.decode(RGB_Decoder<ARGB>.self, Void()){ buffer in
                try resultHandler(&buffer, RGB_Decoder<ARGB>.cgImageFormat)
            }
        } else if self.naxis == 2 {
            return try self.decode(GrayscaleDecoder.self, Void()){ buffer in
                try resultHandler(&buffer, GrayscaleDecoder.cgImageFormat)
            }
        }
        
        throw FITSKitFail.unsupportedFormat("format not detected")
    }
    
    /**
     Renders the `DataUnit` into an `vImage_Buffer` by using the provieded `Decoder`
     - Parameter decoder: the `ImageDecoder` to use
     - Parameter resultHandler:
     */
    public func decode<Decoder: ImageDecoder, R>(_ decoder: Decoder.Type, _ parameter: Decoder.Paramter, _ resultHandler: (inout vImage_Buffer) throws -> R) throws -> R {
        
        guard let width = self.naxis(1), let height = self.naxis(2) else {
            fatalError("invalid image dimensions")
        }
        let bscale : Float = self.bscale ?? 1
        let bzero : Float = self.bzero ?? 0
        
        var out : [Decoder.Out] = .init(repeating: Decoder.Out.zero, count: Decoder.Pixel.channels * width * height)
        
        guard let data = self.dataUnit else {
            fatalError("There is no dataUnit to decode!")
        }
        
        return try data.withUnsafeBytes{ dataPtr -> R in
           try out.withUnsafeMutableBufferPointer{ outPtr -> R in
                
                switch self.bitpix {
                case .UINT8:
                    let decoder = Decoder.init(parameter, width: width, height: height, bscale: bscale, bzero: bzero, min: UInt8.min.float ,max: UInt8.max.float)
                    decoder.decode(dataPtr.bindMemory(to: UInt8.self), outPtr)
                case .INT16:
                    let decoder = Decoder.init(parameter, width: width, height: height, bscale: bscale, bzero: bzero, min: Int16.min.float ,max: Int16.max.float)
                    decoder.decode(dataPtr.bindMemory(to: Int16.self), outPtr)
                case .INT32:
                    let decoder = Decoder.init(parameter, width: width, height: height, bscale: bscale, bzero: bzero, min: Int32.min.float ,max: Int32.max.float)
                    decoder.decode(dataPtr.bindMemory(to: Int32.self), outPtr)
                case .INT64:
                    let decoder = Decoder.init(parameter, width: width, height: height, bscale: bscale, bzero: bzero, min: Int64.min.float ,max: Int64.max.float)
                    decoder.decode(dataPtr.bindMemory(to: Int64.self), outPtr)
                case .FLOAT32:
                    let decoder = Decoder.init(parameter, width: width, height: height, bscale: bscale, bzero: bzero, min: 0.0, max: 1.0)
                    decoder.decode(dataPtr.bindMemory(to: Float.self), outPtr)
                case .FLOAT64:
                    let decoder = Decoder.init(parameter, width: width, height: height, bscale: bscale, bzero: bzero, min: 0.0, max: 1.0)
                    decoder.decode(dataPtr.bindMemory(to: Double.self), outPtr)
                case .none:
                    fatalError("Bitpix must be present")
                }
            
            var buffer = vImage_Buffer(data: outPtr.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: Decoder.Out.bytes * Decoder.Pixel.channels * width)
        
            return try resultHandler(&buffer)
            
           }
        }
    }
    
    /**
     Renders the `DataUnit` into an `CGImage` by using the provieded `Decoder`
        - Parameter decoder: the `ImageDecoder` to use
     */
    public func decode<Decoder: ImageDecoder>(_ decoder: Decoder.Type, _ parameter: Decoder.Paramter) throws -> CGImage {
        
        try self.decode(decoder, parameter) { buffer in
            
            return try buffer.createCGImage(format: decoder.cgImageFormat)
        }
        
    }

}
