/*
 
 Copyright (c) <2021>
 
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

/**
 Decodes chunked RGB to interleved
 
 RRR      RGB
 GGG -> RGB
 BBB       RGB
 
 */
public struct RGB_Decoder<Format : PixelFormat> : ImageDecoderGCD {
    
    public typealias Paramter = Void
    public typealias Pixel = Format
    public typealias Out = Float
    
    private var width1 : Int
    private var height1 : Int
    private var size1 : Int
    private var size2 : Int
    
    private var max1 : Float
    
    private var scale : Float
    
    private var add1 : Float
    
    public init<Byte: FITSByte>(_ parameter: Void, width: Int, height: Int, bscale: Float, bzero: Float, min: Byte, max: Byte) {
    
        self.width1 = width
        self.height1 = height
        self.size1 = width*height
        self.size2 = width*height*2
        
        self.scale = bscale

        self.add1 = bzero - (bzero + min.float * bscale)
        self.max1 = (bzero + max.float * bscale) - (bzero + min.float * bscale)
    }
    
    public func block<In>(for thread: Int, of: Int, _ data: UnsafeBufferPointer<In>, _ out: UnsafeMutableBufferPointer<Float>) where In : FITSByte {
        
        let cap = height1/of
        
        for y in stride(from: thread*cap, to: (thread+1)*cap, by: 1) {
            
            switch self {
            case is RGB_Decoder<RGB>:
                RGBrow(line: y, data, out)
            case is RGB_Decoder<ARGB>:
                ARGBrow(line: y, data, out)
            case is RGB_Decoder<RGBA>:
                RGBArow(line: y, data, out)
            case is RGB_Decoder<Mono>:
                GRAYrow(line: y, data, out)
            default:
                fatalError("Pixel Format not recognized")
            }
        }
    }
    
    /**
     computes average from a vertical line
     ... ... ...
     ...  x  ...
     ... ... ...
     */
    private func native<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        let sum = data[offset].bigEndian.float // top
        
        return (add1 + sum) / max1
    }
    
}

// MARK: - RGB w/o alpha
extension RGB_Decoder {
    
    public func RGBrow<Byte: FITSByte>(line y: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>) {
        
        var offset = y*width1
        var pixel = offset*3
        
        for _ in 0..<width1 {
            
            out[pixel] = native(data, offset)
            out[pixel+1] = native(data, offset+size1)
            out[pixel+2] = native(data, offset+size2)
            
            offset += 1
            pixel += 3
        }
        
    }
}

// MARK: - ARGB
extension RGB_Decoder{
    
    
    public func ARGBrow<Byte: FITSByte>(line y: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>) {
        
        var offset = y*width1
        var pixel = offset*4
        
        for _ in 0..<width1 {
            
            out[pixel+1] = native(data, offset)
            out[pixel+2] = native(data, offset+size1)
            out[pixel+3] = native(data, offset+size2)
            
            offset += 1
            pixel += 4
        }
        
    }
}

// MARK: - RGBA
extension RGB_Decoder {
    
    public func RGBArow<Byte: FITSByte>(line y: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>) {
        
        var offset = y*width1
        var pixel = offset*4
        
        for _ in 0..<width1 {
            
            out[pixel] = native(data, offset)
            out[pixel+1] = native(data, offset+size1)
            out[pixel+2] = native(data, offset+size2)
            
            offset += 1
            pixel += 4
        }
        
    }
}

// MARK: - Grayscale
extension RGB_Decoder {
    
    // Colorimetric (perceptual luminance-preserving) conversion to grayscale
    public func GRAYrow<Byte: FITSByte>(line y: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>) {
        
        var offset = y*width1
        var pixel = offset
        
        for _ in 0..<width1 {
            
            // let's assume sRGB
            out[pixel] = native(data, offset) * 0.2126
            out[pixel] += native(data, offset+size1) * 0.7152
            out[pixel] += native(data, offset+size2) * 0.0722
            
            offset += 1
            pixel += 1
        }
        
    }
}
