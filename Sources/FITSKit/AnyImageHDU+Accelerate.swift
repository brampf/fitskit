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
    
    func vMONO(_ data: inout Data,  width: Int, height: Int, bscale: Float, bzero: Float, _ bitpix: BITPIX) -> CGImage? {
        
        var converted = FITSByteTool.normalize_F(&data, width: width, height: height, bscale: bscale, bzero: bzero, bitpix)
        
        let layerBytes = width * height * FITSByte_F.bytes
        let rowBytes = width * FITSByte_F.bytes
        
        let gray = converted.withUnsafeMutableBytes{ mptr8 in
            vImage_Buffer(data: mptr8.baseAddress?.advanced(by: layerBytes * 0).bindMemory(to: FITSByte_F.self, capacity: width * height), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
        }
        var finfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        finfo.insert(CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue))
        finfo.insert(CGBitmapInfo(rawValue: CGBitmapInfo.floatComponents.rawValue))
        let format = vImage_CGImageFormat(bitsPerComponent: FITSByte_F.bits, bitsPerPixel: FITSByte_F.bits, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: finfo)!
        
        return try? gray.createCGImage(format: format)
    }
    
    func vRGB(_ data: inout Data, layer: (Int,Int,Int) = (0,1,2),  width: Int, height: Int, bscale: Float, bzero: Float, _ bitpix: BITPIX) -> CGImage? {
        
        var converted = FITSByteTool.normalize_F(&data, width: width, height: height, bscale: bscale, bzero: bzero, bitpix)
        
        let layerBytes = width * height * FITSByte_F.bytes
        let rowBytes = width * FITSByte_F.bytes
        
        var red = converted.withUnsafeMutableBytes{ mptr8 in
            vImage_Buffer(data: mptr8.baseAddress?.advanced(by: layerBytes * layer.0).bindMemory(to: FITSByte_F.self, capacity: width * height), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
        }
        
        var green = converted.withUnsafeMutableBytes{ mptr8 in
            vImage_Buffer(data: mptr8.baseAddress?.advanced(by: layerBytes * layer.1).bindMemory(to: FITSByte_F.self, capacity: width * height), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
        }
        
        var blue = converted.withUnsafeMutableBytes{ mptr8 in
            vImage_Buffer(data: mptr8.baseAddress?.advanced(by: layerBytes * layer.2).bindMemory(to: FITSByte_F.self, capacity: width * height), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
        }
        
        var outBuffer = try! vImage_Buffer(width: width, height: height, bitsPerPixel: UInt32(FITSByte_F.bits * 3))
        defer{
            outBuffer.free()
        }
        
        vImageConvert_PlanarFtoRGBFFF(&red, &green, &blue, &outBuffer, vImage_Flags(kvImageNoFlags))
        
        var finfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        finfo.insert(CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue))
        finfo.insert(CGBitmapInfo(rawValue: CGBitmapInfo.floatComponents.rawValue))
        let rgbFormat = vImage_CGImageFormat(bitsPerComponent: FITSByte_F.bits, bitsPerPixel: FITSByte_F.bits * 3, colorSpace: CGColorSpaceCreateDeviceRGB(), bitmapInfo: finfo)!
        
        return try? outBuffer.createCGImage(format: rgbFormat)
    }
    
    public func v_cgimage(onError: ((Error) -> Void)?, onCompletion: @escaping (CGImage) -> Void) {
        
        guard let bitpix = bitpix else {
            onError?(AcceleratedFail.invalidMetadata("Missing BITPIX information"))
            return
        }
        
        guard let channels = naxis, let width = naxis(1), let height = naxis(2) else {
            onError?(AcceleratedFail.invalidMetadata("Missing NAXIS information"))
            return
        }
        
        
        let bscale : Float = self.lookup(HDUKeyword.BSCALE) ?? 1
        let bzero : Float = self.lookup(HDUKeyword.BZERO) ?? 0
        
        guard var dat = self.dataUnit else {
            onError?(AcceleratedFail.missingData("DataUnit Empty"))
            return
        }
        
        
        var image : CGImage?
        if channels == 2 {
            image = vMONO(&dat, width: width, height: height, bscale: bscale, bzero: bzero, bitpix)
            
        } else  if channels == 3 {
            image = vRGB(&dat, width: width, height: height, bscale: bscale, bzero: bzero, bitpix)
        }
        
        if let image = image{
            onCompletion(image)
        } else {
            onError?(AcceleratedFail.unsupportedFormat("Unable to crate image"))
        }
    }
}
