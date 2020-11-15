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
import CoreImage
import Foundation

extension AnyImageHDU {

    public func cgimage(onError: ((Error) -> Void)?, onCompletion: @escaping (CGImage) -> Void) {
     
        guard let bitpix = bitpix else {
            onError?(AcceleratedFail.invalidMetadata("Missing BITPIX information"))
            return
        }
        
        guard let channels = naxis, let width = naxis(1), let height = naxis(2) else {
            onError?(AcceleratedFail.invalidMetadata("Missing NAXIS information"))
            return
        }
        
        
        let bscale : Float = self.bscale ?? 1
        let bzero : Float = self.bzero ?? 0
        
        guard var dat = self.dataUnit else {
            onError?(AcceleratedFail.missingData("DataUnit Empty"))
            return
        }
        
        
        var rgbF : [FITSByte_F]
        var context : CGContext?
        if channels == 2 {
            var finfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            finfo.insert(CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue))
            finfo.insert(CGBitmapInfo(rawValue: CGBitmapInfo.floatComponents.rawValue))
            
            rgbF = FITSByteTool.normalize_F(&dat, width: width, height: height, bscale: bscale, bzero: bzero, bitpix)
            context = CGContext(data: &rgbF, width: width, height: height, bitsPerComponent: FITSByte_F.bits, bytesPerRow: width * FITSByte_F.bytes, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: finfo.rawValue)
            
        } else  if channels == 3 {
            var finfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
            finfo.insert(CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue))
            finfo.insert(CGBitmapInfo(rawValue: CGBitmapInfo.floatComponents.rawValue))
            
            rgbF = FITSByteTool.RGBAFFFF(&dat, width: width, height: height, bscale: bscale, bzero: bzero, bitpix)
            context = CGContext(data: &rgbF, width: width, height: height, bitsPerComponent: FITSByte_F.bits, bytesPerRow: width * 4 * FITSByte_F.bytes, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: finfo.rawValue)
            
        }
        
        if let image = context?.makeImage(){
            onCompletion(image)
        } else {
            onError?(AcceleratedFail.unsupportedFormat("Unable to crate image"))
        }
    }

}

