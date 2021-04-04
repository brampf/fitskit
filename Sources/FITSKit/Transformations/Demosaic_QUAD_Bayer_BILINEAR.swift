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
public struct Demosaic_QUAD_BAYER_BILINEAR : Transformation {
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
            self.XGGY(data, width, height, zero, scale, &R, &G, &B)
        case .BGGR:
            self.XGGY(data, width, height, zero, scale, &B, &G, &R)
        default:
            fatalError("\(pattern) not (yet) implemented")
        }
        
    }
    
    func XGGY<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>,
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
            
            for x in stride(from: 0, to: width, by: 8) {
                
                let offset = width*y + x
                
                // ...
                // r00 r01 r02 r03 g04 g05 g06 g07 | r08 r09 r10 r11 g12 g13 g14 g15
                // g10 g11 g12 g13 b14 b15 b16 b17 | g18 g19 g20 g21 b22 b23 b24 b25
                // ..
                
                // v   v   v   v   v   v   v   v
                // ..
                // r00 g04 r01 g05 r02 g06 r03 g07 | r08 g12 r09 g13 r10 g14 r11 g15
                // g10 b14 g11 b15 g12 b16 g13 b17 | g19 b22 g19 b23 g20 b24 g32 b25
                
                
                // native pixels
                let r00 = data[offset+0].bigEndian.normalize(zero, scale, .min, .max)
                let r01 = data[offset+1].bigEndian.normalize(zero, scale, .min, .max)
                let r02 = data[offset+2].bigEndian.normalize(zero, scale, .min, .max)
                let r03 = data[offset+3].bigEndian.normalize(zero, scale, .min, .max)
                
                let g04 = data[offset+4].bigEndian.normalize(zero, scale, .min, .max)
                let g05 = data[offset+5].bigEndian.normalize(zero, scale, .min, .max)
                let g06 = data[offset+6].bigEndian.normalize(zero, scale, .min, .max)
                let g07 = data[offset+7].bigEndian.normalize(zero, scale, .min, .max)
                
                let g10 = data[offset+0+width].bigEndian.normalize(zero, scale, .min, .max)
                let g11 = data[offset+1+width].bigEndian.normalize(zero, scale, .min, .max)
                let g12 = data[offset+2+width].bigEndian.normalize(zero, scale, .min, .max)
                let g13 = data[offset+3+width].bigEndian.normalize(zero, scale, .min, .max)
                
                let b14 = data[offset+4+width].bigEndian.normalize(zero, scale, .min, .max)
                let b15 = data[offset+5+width].bigEndian.normalize(zero, scale, .min, .max)
                let b16 = data[offset+6+width].bigEndian.normalize(zero, scale, .min, .max)
                let b17 = data[offset+7+width].bigEndian.normalize(zero, scale, .min, .max)
                
                
                // interpolated green pixels for top left red : plus pattern
                let g00 = plus(data, x+0, y, width, height, offset+0, scale, zero)
                let g01 = plus(data, x+1, y, width, height, offset+1, scale, zero)
                let g02 = plus(data, x+2, y, width, height, offset+2, scale, zero)
                let g03 = plus(data, x+3, y, width, height, offset+3, scale, zero)
                
                // interpolated blue pixels for top left red : cross pattern
                let b00 = cross(data, x+0, y, width, height, offset+0, scale, zero)
                let b01 = cross(data, x+1, y, width, height, offset+1, scale, zero)
                let b02 = cross(data, x+2, y, width, height, offset+2, scale, zero)
                let b03 = cross(data, x+3, y, width, height, offset+3, scale, zero)
                
                // interpolated red pixels for top right green : horizontal pattern
                let r04 = horizontal(data, x+4, y, width, height, offset+4, scale, zero)
                let r05 = horizontal(data, x+5, y, width, height, offset+5, scale, zero)
                let r06 = horizontal(data, x+6, y, width, height, offset+6, scale, zero)
                let r07 = horizontal(data, x+7, y, width, height, offset+7, scale, zero)
                
                // interpolated blue pixels for top right green : cross pattern
                let b04 = cross(data, x+4, y, width, height, offset+4, scale, zero)
                let b05 = cross(data, x+5, y, width, height, offset+5, scale, zero)
                let b06 = cross(data, x+6, y, width, height, offset+6, scale, zero)
                let b07 = cross(data, x+7, y, width, height, offset+7, scale, zero)
                
                // interpolated red pixeld for bottom left green : vertical pattern
                let r10 = vertical(data, x+0, y+1, width, height, offset+0+width, scale, zero)
                let r11 = vertical(data, x+1, y+1, width, height, offset+1+width, scale, zero)
                let r12 = vertical(data, x+2, y+1, width, height, offset+2+width, scale, zero)
                let r13 = vertical(data, x+3, y+1, width, height, offset+3+width, scale, zero)
                
                // interpolated blue pixeld for bottom left green : cross pattern
                let b10 = cross(data, x+0, y+1, width, height, offset+0+width, scale, zero)
                let b11 = cross(data, x+1, y+1, width, height, offset+1+width, scale, zero)
                let b12 = cross(data, x+2, y+1, width, height, offset+2+width, scale, zero)
                let b13 = cross(data, x+3, y+1, width, height, offset+3+width, scale, zero)
                
                // interpolated red pixels for bottom right blue : cross pattern
                let r14 = cross(data, x+4, y+1, width, height, offset+4+width, scale, zero)
                let r15 = cross(data, x+5, y+1, width, height, offset+5+width, scale, zero)
                let r16 = cross(data, x+6, y+1, width, height, offset+6+width, scale, zero)
                let r17 = cross(data, x+7, y+1, width, height, offset+7+width, scale, zero)
                
                // interpolated green pixels for bottom right blue : plus pattern
                let g14 = plus(data, x+4, y+1, width, height, offset+4+width, scale, zero)
                let g15 = plus(data, x+5, y+1, width, height, offset+5+width, scale, zero)
                let g16 = plus(data, x+6, y+1, width, height, offset+6+width, scale, zero)
                let g17 = plus(data, x+7, y+1, width, height, offset+7+width, scale, zero)
                
                // top row
                X[offset+0] = r00
                G[offset+0] = g00
                Y[offset+0] = b00
                
                X[offset+1] = r01
                G[offset+2] = g01
                Y[offset+2] = b01
                
                X[offset+4] = r02
                G[offset+4] = g02
                Y[offset+4] = b02
                
                X[offset+6] = r03
                G[offset+6] = g03
                Y[offset+6] = b03
                
                X[offset+1] = r04
                G[offset+1] = g04
                Y[offset+1] = b04
                
                X[offset+3] = r05
                G[offset+3] = g05
                Y[offset+3] = b05
                
                X[offset+5] = r06
                G[offset+5] = g06
                Y[offset+5] = b06
                
                X[offset+7] = r07
                G[offset+7] = g07
                Y[offset+7] = b07
                
                // bottom row
                X[offset+0+width] = r10
                G[offset+0+width] = g10
                Y[offset+0+width] = b10
                
                X[offset+2+width] = r11
                G[offset+2+width] = g11
                Y[offset+2+width] = b11
                
                X[offset+4+width] = r12
                G[offset+4+width] = g12
                Y[offset+4+width] = b12
                
                X[offset+6+width] = r13
                G[offset+6+width] = g13
                Y[offset+6+width] = b13
                
                X[offset+1+width] = r14
                G[offset+1+width] = g14
                Y[offset+1+width] = b14
                
                X[offset+3+width] = r15
                G[offset+3+width] = g15
                Y[offset+3+width] = b15
                
                X[offset+5+width] = r16
                G[offset+5+width] = g16
                Y[offset+5+width] = b16
                
                X[offset+7+width] = r17
                G[offset+7+width] = g17
                Y[offset+7+width] = b17
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
            if x % 8 == 0 {
                sum += data[offset-4].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            } else {
                sum += data[offset-1].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            }
        }
        
        if x < width-5 {
            // right
            if x % 8 == 3 {
                sum += data[offset+4].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            } else {
                sum += data[offset+1].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            }
        }
        
        if y > 0 {
            // left
            sum += data[offset-width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if y < height-2 {
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
        
        if x > 3 && y > 0 {
            // top left
            sum += data[offset-4-width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if x < width-3 && y > 0 {
            // top right
            sum += data[offset+4-width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if x > 3 && y < height-3 {
            // bottom left
            sum += data[offset-4+width].bigEndian.normalize(zero, scale, .min, .max)
            div += 1
        }
        
        if x < width-3 && y < height-3 {
            // bottom right
            sum += data[offset+4+width].bigEndian.normalize(zero, scale, .min, .max)
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
            if x % 8 == 0 {
                sum += data[offset-4].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            } else {
                sum += data[offset-1].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            }
        }
        
        if x < width-2 {
            // right
            if x % 8 == 3 {
                sum += data[offset+4].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            } else {
                sum += data[offset+1].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            }
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
        
        if y < height-2 {
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
