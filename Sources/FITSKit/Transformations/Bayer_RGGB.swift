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
 Color-Codes "normal" RGGB
 
 ....
 R G R G R G ...
 G B G B G B ...
 ...
 */
public struct Bayer_RGGB : Transformation {
    public typealias Parameter = Void
    
    public init(parameter: Void = ()) {
        //
    }
    
    public func perform<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>,
                                        _ width: Int,
                                        _ height: Int,
                                        _ zero: Float,
                                        _ scale : Float,
                                        _ R: inout [FITSByte_F],
                                        _ G: inout [FITSByte_F],
                                        _ B: inout [FITSByte_F])
    {
        
        let min = data.min() ?? 0
        let max = data.max() ?? 65535
        
        for y in stride(from: 0, to: height, by: 2) {
            
            for x in stride(from: 0, to: width, by: 2) {
                
                let byte = width*y + x
                let pixel = width*y + x
                
                // RED
                R[pixel+0] = data[byte+0].bigEndian.normalize(zero, scale, min, max)
                // GREEN
                G[pixel+1] = data[byte+1].bigEndian.normalize(zero, scale, min, max)
                // GREEN
                G[pixel+0+width] = data[byte+0+width].bigEndian.normalize(zero, scale, min, max)
                // BLUE
                B[pixel+1+width] = data[byte+1+width].bigEndian.normalize(zero, scale, min, max)
                
            }
        }
        
    }

    public func targetDimensions(width: Int, height: Int) -> (width: Int, height: Int) {
        return (width,height)
    }

}
