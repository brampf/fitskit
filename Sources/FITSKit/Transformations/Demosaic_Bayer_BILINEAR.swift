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

/**
 Demosaics the picture according to the bayer filter provided as `Parameter`
 
*Note*: Only implements RGGB and BGGR at the moment
 */
public struct Demosaic_Bayer_BILINEAR : Transformation {
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
                
                // native pixels
                let tl_X = data[offset].bigEndian.normalize(zero, scale, .min, .max)
                let tr_G = data[offset+1].bigEndian.normalize(zero, scale, .min, .max)
                
                let bl_G = data[offset+width].bigEndian.normalize(zero, scale, .min, .max)
                let br_Y = data[offset+1+width].bigEndian.normalize(zero, scale, .min, .max)
                
                // interpolated pixels
                let tl_G = plus(data, x, y, width, height, offset, scale, zero)
                let tl_Y = cross(data, x, y, width, height, offset, scale, zero)
                
                let tr_X = horizontal(data, x+1, y, width, height, offset+1, scale, zero)
                let tr_Y = cross(data, x+1, y, width, height, offset+1, scale, zero)
                
                let bl_X = vertical(data, x, y+1, width, height, offset+width, scale, zero)
                let bl_Y = cross(data, x, y+1, width, height, offset+width, scale, zero)
                
                let br_X = cross(data, x+1, y+1, width, height, offset+1+width, scale, zero)
                let br_G = plus(data, x+1, y+1, width, height, offset+1+width, scale, zero)
                
                
                /*
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
                    */

                X[offset] = tl_X
                G[offset] = tl_G
                Y[offset] = tl_Y
                
                X[offset+1] = tr_X
                G[offset+1] = tr_G
                Y[offset+1] = tr_Y
                
                X[offset+width] = bl_X
                G[offset+width] = bl_G
                Y[offset+width] = bl_Y
                
                X[offset+1+width] = br_X
                G[offset+1+width] = br_G
                Y[offset+1+width] = br_Y
                
            }
        }
    }
    
    /**
     computes average from a plus pattern
     
     ... O ...
     O x O
     ... O ...
     */
    func plus<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>,
              _ x: Int,
              _ y: Int,
              _ width: Int,
              _ height: Int,
              _ offset: Int,
              _ scale: Float,
              _ zero: Float) -> Float
    {
        
        var sum : Float = 0
        var div : Float = 0
        
        if x > 0 {
            // left
            sum += data[offset-1].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if x < width-3 {
            // right
            sum += data[offset+1].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if y > 0 {
            // left
            sum += data[offset-width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if y < height-3 {
            // right
            sum += data[offset+width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        return (sum / div)
    }
    
    /**
     computes average from a cross pattern
     
     O ... O
     ... x ...
     O ... O
     */
    func cross<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>,
              _ x: Int,
              _ y: Int,
              _ width: Int,
              _ height: Int,
              _ offset: Int,
              _ scale: Float,
              _ zero: Float) -> Float
    {
        
        var sum : Float = 0
        var div : Float = 0
        
        if x > 0 && y > 0 {
            // top left
            sum += data[offset-1-width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if x < width-3 && y > 0 {
            // top right
            sum += data[offset+1-width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if x > 0 && y < height-3 {
            // bottom left
            sum += data[offset-1+width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if x < width-3 && y < height-1 {
            // bottom right
            sum += data[offset+1+width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        return (sum / div)
    }
    
    /**
     computes average from a horizontal line
     
     ... ... ...
     O x O
     ... ... ...
     */
    func horizontal<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>,
                                    _ x: Int,
                                    _ y: Int,
                                    _ width: Int,
                                    _ height: Int,
                                    _ offset: Int,
                                    _ scale: Float,
                                    _ zero: Float) -> Float
    {
        
        var sum : Float = 0
        var div : Float = 0
        
        if x > 0 {
            // left
            sum += data[offset-1].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if x < width-3 {
            // right
            sum += data[offset+1].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        return (sum / div)
    }
    
    /**
     computes average from a vertical line
     ... O ...
     ... x ...
     ... O ...
     */
    func vertical<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>,
                                    _ x: Int,
                                    _ y: Int,
                                    _ width: Int,
                                    _ height: Int,
                                    _ offset: Int,
                                    _ scale: Float,
                                    _ zero: Float) -> Float
    {
        
        var sum : Float = 0
        var div : Float = 0
        
        if y > 0 {
            // left
            sum += data[offset-width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if y < height-3 {
            // right
            sum += data[offset+width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        return (sum / div)
    }

    public func targetDimensions(width: Int, height: Int) -> (width: Int, height: Int) {
        return (width,height)
    }
}
