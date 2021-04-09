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
public struct Demosaic_Bilinear_GCD<Byte: FITSByte> : _Transformation {
    
    public typealias Parameter = CFA_Pattern
    
    var pattern : CFA_Pattern
    
    public init(parameter: Parameter) {
        self.pattern = parameter
    }
    
    public func perform(_ data: UnsafeBufferPointer<Byte>,
                        _ width: Int,
                        _ height: Int,
                        _ out: UnsafeMutableBufferPointer<Float>)
    {
        
        switch pattern {
        case .RGGB:
            self.XGGY(data, width, height, out)
        case .BGGR:
            self.XGGY(data, width, height, out)
        default:
            fatalError("Not implemented")
        }
        
    }
    
    func XGGY(_ data: UnsafeBufferPointer<Byte>,
              _ width: Int,
              _ height: Int,
              _ out: UnsafeMutableBufferPointer<Float>)
    {
        
        // a1 a2 | b1 b2 | c1 c2
        // a3 a4 | b3 b4 | c3 c4
        // ------|-------|------
        // d1 d2 | tl tr | e1 e2
        // d3 d4 | bl br | e3 e4
        // ------|-------|------
        // f1 f2 | g1 g2 | h1 h2
        // f3 f4 | g3 g4 | h3 h4
        
        let group = DispatchGroup()
        
        let queue = DispatchQueue(label: "Demosaic", qos: .userInitiated, attributes: .concurrent)
        
        let item1 = DispatchWorkItem{
            
            head(width: width, data, out)
            
            for y in stride(from: 2, to: (height/4), by: 2) {
                
                middle(y: y, width: width, data, out)
            }
        }
        
        let item2 = DispatchWorkItem{
            
            for y in stride(from: (height/4)+1, to: height/2, by: 2) {
                
                middle(y: y, width: width, data, out)
            }
        }
        
        let item3 = DispatchWorkItem{
            
            for y in stride(from: height/2+1, to: 3*height/4, by: 2) {
                
                middle(y: y, width: width, data, out)
            }
        }
        
        let item4 = DispatchWorkItem{
            
            for y in stride(from: (3*height/4), to: height-2, by: 2) {
                
                middle(y: y, width: width, data, out)
            }
            tail(height: height, width: width, data, out)
        }
        
        queue.async(group: group, execute: item1)
        queue.async(group: group, execute: item2)
        queue.async(group: group, execute: item3)
        queue.async(group: group, execute: item4)
        
        group.wait()
    }
    
    @inlinable
    func head(width: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        var offset = 0
        var pixel = 0
        
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = head_start_plus(data, width, offset)
        out[pixel+2] = head_start_cross(data, width, offset)
        
        out[pixel+3] = horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = head_vertical(data, width, offset+1)
        
        out[pixel+0+3*width] = vertical(data, width, offset+width)
        out[pixel+1+3*width] = native(data, width, offset+width)
        out[pixel+2+3*width] = start_horizontal(data, width, offset+width)
        
        out[pixel+3+3*width] = cross(data,width, offset+1+width)
        out[pixel+4+3*width] = plus(data, width, offset+1+width)
        out[pixel+5+3*width] = native(data, width, offset+1+width)
        
        offset += 2
        pixel += 6
        
        for _ in stride(from: 2, to: width-2, by: 2) {
            
            out[pixel+0] = native(data, width, offset)
            out[pixel+1] = head_plus(data, width, offset)
            out[pixel+2] = head_cross(data, width, offset)
            
            out[pixel+3] = horizontal(data, width, offset+1)
            out[pixel+4] = native(data, width, offset+1)
            out[pixel+5] = head_vertical(data, width, offset+1)
            
            out[pixel+0+3*width] = head_vertical(data, width, offset+width)
            out[pixel+1+3*width] = native(data, width, offset+width)
            out[pixel+2+3*width] = horizontal(data, width, offset+width)
            
            out[pixel+3+3*width] = cross(data,width, offset+1+width)
            out[pixel+4+3*width] = plus(data, width, offset+1+width)
            out[pixel+5+3*width] = native(data, width, offset+1+width)
            
            offset += 2
            pixel += 6
        }
        
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = head_plus(data, width, offset)
        out[pixel+2] = head_cross(data, width, offset)
        
        out[pixel+3] = end_horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = head_vertical(data, width, offset+1)
        
        out[pixel+0+3*width] = head_vertical(data, width, offset+width)
        out[pixel+1+3*width] = native(data, width, offset+width)
        out[pixel+2+3*width] = horizontal(data, width, offset+width)
        
        out[pixel+3+3*width] = head_end_cross(data,width, offset+1+width)
        out[pixel+4+3*width] = head_end_plus(data, width, offset+1+width)
        out[pixel+5+3*width] = native(data, width, offset+1+width)
    }
    
    @inlinable
    func middle(y: Int, width: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        // Special treatment of the first quadrant
        var offset = y*width
        var pixel = offset * 3
        
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = start_plus(data, width, offset)
        out[pixel+2] = start_cross(data, width, offset)
        
        out[pixel+3] = horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = vertical(data, width, offset+1)
        
        out[pixel+0+3*width] = vertical(data, width, offset+width)
        out[pixel+1+3*width] = native(data, width, offset+width)
        out[pixel+2+3*width] = start_horizontal(data, width, offset+width)
        
        out[pixel+3+3*width] = cross(data,width, offset+1+width)
        out[pixel+4+3*width] = plus(data, width, offset+1+width)
        out[pixel+5+3*width] = native(data, width, offset+1+width)
        
        offset += 2
        pixel += 6
        
        // run unchecked for all other elements of the row
        for _ in stride(from: 2, to: width-2, by: 2) {
            
            out[pixel+0] = native(data, width, offset)
            out[pixel+1] = plus(data, width, offset)
            out[pixel+2] = cross(data, width, offset)
            
            out[pixel+3] = horizontal(data, width, offset+1)
            out[pixel+4] = native(data, width, offset+1)
            out[pixel+5] = vertical(data, width, offset+1)
            
            out[pixel+0+3*width] = vertical(data, width, offset+width)
            out[pixel+1+3*width] = native(data, width, offset+width)
            out[pixel+2+3*width] = horizontal(data, width, offset+width)
            
            out[pixel+3+3*width] = cross(data,width, offset+1+width)
            out[pixel+4+3*width] = plus(data, width, offset+1+width)
            out[pixel+5+3*width] = native(data, width, offset+1+width)
            
            offset += 2
            pixel += 6
            
        }
        
        // Special treatment of the last quadrant
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = plus(data, width, offset)
        out[pixel+2] = cross(data, width, offset)
        
        out[pixel+3] = end_horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = vertical(data, width, offset+1)
        
        out[pixel+0+3*width] = vertical(data, width, offset+width)
        out[pixel+1+3*width] = native(data, width, offset+width)
        out[pixel+2+3*width] = end_horizontal(data, width, offset+width)
        
        out[pixel+3+3*width] = end_cross(data,width, offset+1+width)
        out[pixel+4+3*width] = end_plus(data, width, offset+1+width)
        out[pixel+5+3*width] = native(data, width, offset+1+width)
    }
    
    @inlinable
    func tail(height: Int, width: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        var offset = (height-2)*width
        var pixel = offset * 3
        
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = tail_start_plus(data, width, offset)
        out[pixel+2] = tail_start_cross(data, width, offset)
        
        out[pixel+3] = horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = tail_vertical(data, width, offset+1)
        
        out[pixel+0+3*width] = tail_vertical(data, width, offset+width)
        out[pixel+1+3*width] = native(data, width, offset+width)
        out[pixel+2+3*width] = start_horizontal(data, width, offset+width)
        
        out[pixel+3+3*width] = tail_cross(data,width, offset+1+width)
        out[pixel+4+3*width] = tail_plus(data, width, offset+1+width)
        out[pixel+5+3*width] = native(data, width, offset+1+width)
        
        offset += 2
        pixel += 6
        
        for _ in stride(from: 2, to: width-2, by: 2) {
            
            out[pixel+0] = native(data, width, offset)
            out[pixel+1] = tail_plus(data, width, offset)
            out[pixel+2] = tail_cross(data, width, offset)
            
            out[pixel+3] = horizontal(data, width, offset+1)
            out[pixel+4] = native(data, width, offset+1)
            out[pixel+5] = tail_vertical(data, width, offset+1)
            
            out[pixel+0+3*width] = tail_vertical(data, width, offset+width)
            out[pixel+1+3*width] = native(data, width, offset+width)
            out[pixel+2+3*width] = horizontal(data, width, offset+width)
            
            out[pixel+3+3*width] = tail_cross(data,width, offset+1+width)
            out[pixel+4+3*width] = tail_plus(data, width, offset+1+width)
            out[pixel+5+3*width] = native(data, width, offset+1+width)
            
            offset += 2
            pixel += 6
        }
        
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = tail_plus(data, width, offset)
        out[pixel+2] = tail_cross(data, width, offset)
        
        out[pixel+3] = horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = tail_vertical(data, width, offset+1)
        
        out[pixel+0+3*width] = tail_vertical(data, width, offset+width)
        out[pixel+1+3*width] = native(data, width, offset+width)
        out[pixel+2+3*width] = end_horizontal(data, width, offset+width)
        
        out[pixel+3+3*width] = tail_end_cross(data,width, offset+1+width)
        out[pixel+4+3*width] = tail_end_plus(data, width, offset+1+width)
        out[pixel+5+3*width] = native(data, width, offset+1+width)
    }
    
    /**
     computes average from a plus pattern
     
     ... O ...
     O x O
     ... O ...
     */
    @inlinable
    func plus(_ data: UnsafeBufferPointer<Byte>,
              _ width: Int,
              _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+1].bigEndian.float   // right
        sum += data[offset-width].bigEndian.float // top
        sum += data[offset+width].bigEndian.float // bottom
        
        return (4.0 * 32768.0 + sum) / 4.0 / 65536.0
    }
    
    /**
     computes average from a plus pattern
     
     O x O
     ... O ...
     */
    @inlinable
    func head_plus(_ data: UnsafeBufferPointer<Byte>,
                   _ width: Int,
                   _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.floatnorm // left
        sum += data[offset+1].bigEndian.floatnorm   // right
        sum += data[offset+width].bigEndian.floatnorm // bottom
        
        return (3.0 * 32768.0 + sum) / 3.0 / 65536.0
    }
    
    /**
     computes average from a plus pattern
     
     ... O ...
     O x O
     */
    @inlinable
    func tail_plus(_ data: UnsafeBufferPointer<Byte>,
                   _ width: Int,
                   _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+1].bigEndian.float   // right
        sum += data[offset-width].bigEndian.float // top
        
        return (3.0 * 32768.0 + sum) / 3.0 / 65536.0
    }
    
    /**
     computes average from a plus pattern
     
     O ...
     x O
     O ...
     */
    @inlinable
    func start_plus(_ data: UnsafeBufferPointer<Byte>,
                    _ width: Int,
                    _ offset: Int) -> Float
    {
        var sum = data[offset+1].bigEndian.float   // right
        sum += data[offset-width].bigEndian.float // top
        sum += data[offset+width].bigEndian.float // bottom
        
        return (3.0 * 32768.0 + sum) / 3.0 / 65536.0
    }
    
    /**
     computes average from a plus pattern
     
     ... O
     O x
     ... O.
     */
    @inlinable
    func end_plus(_ data: UnsafeBufferPointer<Byte>,
                  _ width: Int,
                  _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset-width].bigEndian.float // top
        sum += data[offset+width].bigEndian.float // bottom
        
        return (3.0 * 32768.0 + sum) / 3.0 / 65536.0
    }
    
    /**
     computes average from a plus pattern
     
     x O
     O ...
     */
    @inlinable
    func head_start_plus(_ data: UnsafeBufferPointer<Byte>,
                         _ width: Int,
                         _ offset: Int) -> Float
    {
        // left
        var sum = data[offset+1].bigEndian.float   // right
        sum += data[offset+width].bigEndian.float // bottom
        
        return (2.0 * 32768.0 + sum) / 2.0 / 65536.0
    }
    
    /**
     computes average from a plus pattern
     
     O x
     ... O
     */
    @inlinable
    func head_end_plus(_ data: UnsafeBufferPointer<Byte>,
                       _ width: Int,
                       _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+width].bigEndian.float // bottom
        
        return (2.0 * 32768.0 + sum) / 2.0 / 65536.0
    }
    
    /**
     computes average from a plus pattern
     
     O ...
     x O
     */
    @inlinable
    func tail_start_plus(_ data: UnsafeBufferPointer<Byte>,
                         _ width: Int,
                         _ offset: Int) -> Float
    {
        // left
        var sum = data[offset+1].bigEndian.float   // right
        sum += data[offset-width].bigEndian.float // top
        
        return (2.0 * 32768.0 + sum) / 2.0 / 65536.0
    }
    
    /**
     computes average from a plus pattern
     
     ... O
     O x
     */
    @inlinable
    func tail_end_plus(_ data: UnsafeBufferPointer<Byte>,
                       _ width: Int,
                       _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset-width].bigEndian.float // top
        
        return (2.0 * 32768.0 + sum) / 2.0 / 65536.0
    }
    
    /**
     computes average from a cross pattern
     
     O ... O
     ... x ...
     O ... O
     */
    @inlinable
    func cross(_ data: UnsafeBufferPointer<Byte>,
               _ width: Int,
               _ offset: Int) -> Float
    {
        
        var sum = data[offset-1-width].bigEndian.float // top left
        sum += data[offset+1-width].bigEndian.float // top right
        sum += data[offset-1+width].bigEndian.float // bottom left
        sum += data[offset+1+width].bigEndian.float // bottom right
        
        return (4.0 * 32768.0 + sum) / 4.0 / 65536.0
    }
    
    /**
     computes average from a cross pattern
     
     ... x ...
     O ... O
     */
    @inlinable
    func head_cross(_ data: UnsafeBufferPointer<Byte>,
                    _ width: Int,
                    _ offset: Int) -> Float
    {
        
        var sum = data[offset-1+width].bigEndian.float // bottom left
        sum += data[offset+1+width].bigEndian.float // bottom right
        
        return (2.0 * 32768.0 + sum) / 2.0 / 65536.0
    }
    
    /**
     computes average from a cross pattern
     
     O ... O
     ... x ...
     */
    @inlinable
    func tail_cross(_ data: UnsafeBufferPointer<Byte>,
                    _ width: Int,
                    _ offset: Int) -> Float
    {
        
        var sum = data[offset-1-width].bigEndian.float // top left
        sum += data[offset+1-width].bigEndian.float // top right
        
        return (2.0 * 32768.0 + sum) / 2.0 / 65536.0
    }
    
    /**
     computes average from a cross pattern
     
     ... O
     x ...
     ... O
     */
    @inlinable
    func start_cross(_ data: UnsafeBufferPointer<Byte>,
                     _ width: Int,
                     _ offset: Int) -> Float
    {
        
        var sum = data[offset+1-width].bigEndian.float // top right
        sum += data[offset+1+width].bigEndian.float // bottom right
        
        return (2.0 * 32768.0 + sum) / 2.0 / 65536.0
    }
    
    /**
     computes average from a cross pattern
     
     O ...
     ... x
     O ...
     */
    @inlinable
    func end_cross(_ data: UnsafeBufferPointer<Byte>,
                   _ width: Int,
                   _ offset: Int) -> Float
    {
        
        var sum = data[offset-1-width].bigEndian.float // top left
        sum += data[offset-1+width].bigEndian.float // bottom left
        
        return (2.0 * 32768.0 + sum) / 2.0 / 65536.0
    }
    
    /**
     computes average from a cross pattern
     
     x ...
     ... O
     */
    @inlinable
    func head_start_cross(_ data: UnsafeBufferPointer<Byte>,
                          _ width: Int,
                          _ offset: Int) -> Float
    {
        
        return data[offset+1+width].bigEndian.floatnorm // bottom right
    }
    
    /**
     computes average from a cross pattern
     
     ... x
     O ...
     */
    @inlinable
    func head_end_cross(_ data: UnsafeBufferPointer<Byte>,
                        _ width: Int,
                        _ offset: Int) -> Float
    {
        return data[offset-1+width].bigEndian.floatnorm // bottom left
    }
    
    /**
     computes average from a cross pattern
     
     ... O
     x ...
     */
    @inlinable
    func tail_start_cross(_ data: UnsafeBufferPointer<Byte>,
                          _ width: Int,
                          _ offset: Int) -> Float
    {
        
        return data[offset+1-width].bigEndian.floatnorm // top right
    }
    
    /**
     computes average from a cross pattern
     
     O ...
     ... x
     */
    @inlinable
    func tail_end_cross(_ data: UnsafeBufferPointer<Byte>,
                        _ width: Int,
                        _ offset: Int) -> Float
    {
        
        return data[offset-1-width].bigEndian.floatnorm // top left
    }
    
    /**
     computes average from a horizontal line
     
     ... ... ...
     O x O
     ... ... ...
     */
    @inlinable
    func horizontal(_ data: UnsafeBufferPointer<Byte>,
                    _ width: Int,
                    _ offset: Int) -> Float
    {
        
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+1].bigEndian.float // right
        
        return (2.0 * 32768.0 + sum) / 2.0 / 65536.0
    }
    
    /**
     computes average from a horizontal line
     
     ... ...
     x O
     ... ...
     */
    @inlinable
    func start_horizontal(_ data: UnsafeBufferPointer<Byte>,
                          _ width: Int,
                          _ offset: Int) -> Float
    {
        
        return data[offset+1].bigEndian.floatnorm // right
    }
    
    /**
     computes average from a horizontal line
     
     ... ...
     O x
     ... ...
     */
    @inlinable
    func end_horizontal(_ data: UnsafeBufferPointer<Byte>,
                        _ width: Int,
                        _ offset: Int) -> Float
    {
        
        return data[offset+1].bigEndian.floatnorm // right
    }
    
    /**
     computes average from a vertical line
     ... O ...
     ... x ...
     ... O ...
     */
    @inlinable
    func vertical(_ data: UnsafeBufferPointer<Byte>,
                  _ width: Int,
                  _ offset: Int) -> Float
    {
        
        var sum = data[offset-width].bigEndian.float // top
        sum += data[offset+width].bigEndian.float // bottom
        
        return (2.0 * 32768.0 + sum) / 2.0 / 65536.0
    }
    
    /**
     computes average from a vertical line
     ... x ...
     ... O ...
     */
    @inlinable
    func head_vertical(_ data: UnsafeBufferPointer<Byte>,
                       _ width: Int,
                       _ offset: Int) -> Float
    {
        
        return data[offset+width].bigEndian.floatnorm // bottom
    }
    
    /**
     computes average from a vertical line
     ... O ...
     ... x ...
     */
    @inlinable
    func tail_vertical(_ data: UnsafeBufferPointer<Byte>,
                       _ width: Int,
                       _ offset: Int) -> Float
    {
        
        return data[offset-width].bigEndian.floatnorm // top
    }
    
    /**
     computes average from a vertical line
     ... ... ...
     ...  x  ...
     ... ... ...
     */
    @inlinable
    func native(_ data: UnsafeBufferPointer<Byte>,
                _ width: Int,
                _ offset: Int) -> Float
    {
        
        return data[offset].bigEndian.floatnorm // top
    }
    
    
    public func targetDimensions(width: Int, height: Int) -> (width: Int, height: Int) {
        return (width,height)
    }
}
