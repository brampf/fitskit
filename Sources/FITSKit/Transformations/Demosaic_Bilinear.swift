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
public struct Demosaic_Bilinear : Transformation {
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
        case .GBRG:
            self.GXYG(data, width, height, zero, scale, &B, &G, &R)
        case .GRBG:
            self.GXYG(data, width, height, zero, scale, &R, &G, &B)
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
                let tr_Y = vertical(data, x+1, y, width, height, offset+1, scale, zero)
                
                let bl_X = vertical(data, x, y+1, width, height, offset+width, scale, zero)
                let bl_Y = horizontal(data, x, y+1, width, height, offset+width, scale, zero)
                
                let br_X = cross(data, x+1, y+1, width, height, offset+1+width, scale, zero)
                let br_G = plus(data, x+1, y+1, width, height, offset+1+width, scale, zero)

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
    
    func GXYG<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>,
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
                let tl_G = data[offset].bigEndian.normalize(zero, scale, .min, .max)
                let tr_X = data[offset+1].bigEndian.normalize(zero, scale, .min, .max)
                
                let bl_Y = data[offset+width].bigEndian.normalize(zero, scale, .min, .max)
                let br_G = data[offset+1+width].bigEndian.normalize(zero, scale, .min, .max)
                
                // interpolated pixels
                let tl_X = horizontal(data, x, y, width, height, offset, scale, zero)
                let tl_Y = cross(data, x, y, width, height, offset, scale, zero)
                
                let tr_G = plus(data, x+1, y, width, height, offset+1, scale, zero)
                let tr_Y = cross(data, x+1, y, width, height, offset+1, scale, zero)
                
                let bl_X = cross(data, x, y+1, width, height, offset+width, scale, zero)
                let bl_G = plus(data, x, y+1, width, height, offset+width, scale, zero)
                
                let br_X = vertical(data, x+1, y+1, width, height, offset+1+width, scale, zero)
                let br_Y = plus(data, x+1, y+1, width, height, offset+1+width, scale, zero)
                
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
    @inlinable
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
    @inlinable
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
        
        
        if y > 0 {
            
            if x > 0 {
                // top left
                sum += data[offset-1-width].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            }
            
            if x < width-1 {
                // top right
                sum += data[offset+1-width].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            }
            
        }
        
        if y < height-1 {
            
            if x > 0 {
                // bottom left
                sum += data[offset-1+width].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            }
            
            if x < width-1 {
                // bottom right
                sum += data[offset+1+width].bigEndian.normalize(zero, scale, .min, .max)
                div += 1
            }
        }
        
        return (sum / div)
    }
    
    /**
     computes average from a horizontal line
     
     ... ... ...
     O x O
     ... ... ...
     */
    @inlinable
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
    @inlinable
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
        
        if y < height-1 {
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
