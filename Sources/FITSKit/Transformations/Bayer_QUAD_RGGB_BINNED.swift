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

public struct Bayer_QUAD_RGGB_BINNED : Transformation {
    public typealias Parameter = Void
    
    public init(parameter: Void) {
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
            
            for x in stride(from: 0, to: width, by: 4) {
                
                let byte = width*y + x
                let pixel = width*y + x
                
                R[pixel+0] = data[byte+0].bigEndian.normalize(zero, scale, min, max)
                R[pixel+2] = data[byte+1].bigEndian.normalize(zero, scale, min, max)
                R[pixel+4] = data[byte+2].bigEndian.normalize(zero, scale, min, max)
                R[pixel+6] = data[byte+3].bigEndian.normalize(zero, scale, min, max)
                
                G[pixel+1] = data[byte+4].bigEndian.normalize(zero, scale, min, max)
                G[pixel+3] = data[byte+5].bigEndian.normalize(zero, scale, min, max)
                G[pixel+5] = data[byte+6].bigEndian.normalize(zero, scale, min, max)
                G[pixel+7] = data[byte+7].bigEndian.normalize(zero, scale, min, max)
                
                G[pixel+0+width] = data[byte+0+width].bigEndian.normalize(zero, scale, min, max)
                G[pixel+2+width] = data[byte+1+width].bigEndian.normalize(zero, scale, min, max)
                G[pixel+4+width] = data[byte+2+width].bigEndian.normalize(zero, scale, min, max)
                G[pixel+6+width] = data[byte+3+width].bigEndian.normalize(zero, scale, min, max)
                
                B[pixel+1+width] = data[byte+4+width].bigEndian.normalize(zero, scale, min, max)
                B[pixel+3+width] = data[byte+5+width].bigEndian.normalize(zero, scale, min, max)
                B[pixel+5+width] = data[byte+6+width].bigEndian.normalize(zero, scale, min, max)
                B[pixel+7+width] = data[byte+7+width].bigEndian.normalize(zero, scale, min, max)
                
            }
        }
        
    }
    
    public func targetDimensions(width: Int, height: Int) -> (width: Int, height: Int) {
        return (width,height)
    }
    
}
