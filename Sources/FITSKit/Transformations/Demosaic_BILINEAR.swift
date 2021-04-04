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

public struct Demosaic_BILINEAR : Transformation {
    public typealias Parameter = CFA_Pattern
    
    
    var pattern : CFA_Pattern
    
    public init(parameter: Parameter) {
        self.pattern = parameter
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
        
        switch pattern {
        case .RGGB:
            self.opXGGY(data, width, height, zero, scale, &R, &G, &B)
        case .BGGR:
            self.opXGGY(data, width, height, zero, scale, &B, &G, &R)
        default:
            fatalError("\(pattern) not (yet) implemented")
        }

    }
    
    func opXGGY<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>,
                                          _ width: Int,
                                          _ height: Int,
                                          _ zero: Float,
                                          _ scale : Float,
                                          _ X: inout [FITSByte_F],
                                          _ G: inout [FITSByte_F],
                                          _ Y: inout [FITSByte_F])
    {
     
        //let min : Byte = data.min() ?? .min
        //let max : Byte = data.max() ?? .max
        
        for y in stride(from: 0, to: height, by: 2) {
            
            for x in stride(from: 0, to: width, by: 2) {
                
                let offset = width*y + x
                
                // native Pixels
                let tl_X = data[offset].bigEndian
                let tr_G = data[offset+1].bigEndian
                
                let bl_G = data[offset+width].bigEndian
                let br_Y = data[offset+1+width].bigEndian
                
                
                var tl_G : [Byte] = [] // plus
                var tl_Y : [Byte] = [] // cross
                
                var tr_X : [Byte] = [] // horizontal
                var tr_Y : [Byte] = [] // cross
                
                var bl_X : [Byte] = [] // vertical
                var bl_Y : [Byte] = [] // cross
                
                var br_X : [Byte] = [] // cross
                var br_G : [Byte] = [] // plus
                
                
                tl_Y.append(br_Y)
                
                tl_G.append(tr_G)
                tl_G.append(bl_G)
                
                tr_X.append(tl_X)
                tr_Y.append(br_Y)
                
                bl_X.append(tl_X)
                bl_Y.append(br_Y)
                
                br_X.append(tl_X)
                
                br_G.append(tr_G)
                br_G.append(bl_G)
                
                if(x>0 && y>0){
                    // predecessor at top left
                    /**
                     O ... ... ...
                     ... X G ...
                     ... G Y ...
                     ... ... ... ...
                     */
                    tl_Y.append(data[offset-1-width])
                }
                
                if(x < width-3 && y < height-2) {
                    // successor at bottom right
                    /**
                     ... ... ... ...
                     ... X G ...
                     ... G Y ...
                     ... ... ... O
                     */
                    
                    br_X.append(data[offset+1+width])
                }
                
                if ( x > 0){
                    // predecessor at the left
                    /**
                     ... ... ... ...
                     O X G ...
                     ... G Y ...
                     ... ... ... ...
                     */
                    
                    tl_G.append(data[offset-1])
                    tl_Y.append(data[offset-1+width])
                    bl_Y.append(data[offset-1+width])
                }
                
                if (x < width-3){
                    // successor at the right
                    /**
                     ... ... ... ...
                     ... X G O
                     ... G Y ...
                     ... ... ... ...
                     */
                    
                    tr_X.append(data[offset+2])
                    br_G.append(data[offset+2+width])
                    br_X.append(data[offset+2])
                }
                
                if(y>0){
                    // successor above
                    /**
                     ... O ... ...
                     ... X G ...
                     ... G Y ...
                     ... ... ... ...
                     */
                    tl_G.append(data[offset-width])
                    tl_Y.append(data[offset+1-width])
                    tr_Y.append(data[offset+1-width])
                }

                if(y < height-3){
                    // successor below
                    /**
                     ... ... ... ...
                     ... X G ...
                     ... G Y ...
                     ... O ... ...
                     */
                    bl_X.append(data[offset+width+width])
                    br_G.append(data[offset+1+width+width])
                    br_X.append(data[offset+width+width])
                }
                
                X[offset] = tl_X.normalize(zero, scale, .min, .max)
                G[offset] = tl_G.normalize(zero, scale, .min, .max)
                Y[offset] = tl_Y.normalize(zero, scale, .min, .max)
                
                X[offset+1] = tr_X.normalize(zero, scale, .min, .max)
                G[offset+1] = tr_G.normalize(zero, scale, .min, .max)
                Y[offset+1] = tr_Y.normalize(zero, scale, .min, .max)
                
                X[offset+width] = bl_X.normalize(zero, scale, .min, .max)
                G[offset+width] = bl_G.normalize(zero, scale, .min, .max)
                Y[offset+width] = bl_Y.normalize(zero, scale, .min, .max)
                
                X[offset+1+width] = br_X.normalize(zero, scale, .min, .max)
                G[offset+1+width] = br_G.normalize(zero, scale, .min, .max)
                Y[offset+1+width] = br_Y.normalize(zero, scale, .min, .max)
                
            }
        }
    }

    public func targetDimensions(width: Int, height: Int) -> (width: Int, height: Int) {
        return (width,height)
    }
}
