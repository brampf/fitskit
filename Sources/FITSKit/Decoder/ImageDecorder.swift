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

/**
 Decodes a DataUnit to a oicture
 */
public protocol ImageDecoder {
    associatedtype Out : FITSByte
    associatedtype Pixel : PixelFormat
    associatedtype Paramter
    
    init(_ parameter: Paramter, width: Int, height: Int, bscale: Float, bzero: Float, range: Float)
    
    func decode<In: FITSByte>(_ dataUnit: UnsafeBufferPointer<In>, _ out: UnsafeMutableBufferPointer<Out>)
}

extension ImageDecoder {
    
    static var cgImageFormat : vImage_CGImageFormat {
        
        
        var finfo = CGBitmapInfo(rawValue: Pixel.alpha.rawValue)
        let bitsPerComponent = Out.bits
        let bitsPerPixel = Out.bits * Pixel.channels
        
        let byte = Out.self
        switch byte {
        case is FITSByte_8.Type:
            finfo.insert(CGBitmapInfo.floatComponents)
        case is FITSByte_16.Type:
            finfo.insert(CGBitmapInfo.byteOrder16Big)
        case is FITSByte_32.Type:
            finfo.insert(CGBitmapInfo.byteOrder32Big)
        case is FITSByte_F.Type:
            finfo.insert(CGBitmapInfo.byteOrder32Little)
            finfo.insert(CGBitmapInfo.floatComponents)
        default:
            fatalError("currelnty not supported by Accelerate")
        }
        
        return vImage_CGImageFormat(bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel, colorSpace: Pixel.colorSpace, bitmapInfo: finfo)!
        
    }
}
