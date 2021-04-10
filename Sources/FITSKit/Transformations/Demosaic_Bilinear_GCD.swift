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
    
    private let queue = DispatchQueue(label: "Demosaic", qos: .userInitiated, attributes: .concurrent)
    private let group = DispatchGroup()
    private let threads : Int
    
    private var pattern : CFA_Pattern
    
    private var max1 : Float
    private var max2 : Float
    private var max3 : Float
    private var max4 : Float
    
    private var scale : Float
    
    private var add1 : Float
    private var add2 : Float
    private var add3 : Float
    private var add4 : Float
    
    public init(pattern: CFA_Pattern, bscale: Float, bzero: Float, _ threads: Int = 8) {
        self.pattern = pattern
        self.scale = bscale
        
        self.add1 = bzero
        self.add2 = bzero * 2.0
        self.add3 = bzero * 3.0
        self.add4 = bzero * 4.0
        
        self.max1 = Byte.range
        self.max2 = Byte.range * 2.0
        self.max3 = Byte.range * 3.0
        self.max4 = Byte.range * 4.0
        
        self.threads = threads
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
        let cap = height/threads
        
        for idx in 0..<threads {
        
            let worker = DispatchWorkItem{
                
                switch idx {
                
                case 0:
                    head(width: width, data, out)
                    
                    for y in stride(from: 2, to: cap, by: 2) {
                        
                        middle(y: y, width: width, data, out)
                    }
                case threads-1:
                    let align = cap%2
                    
                    for y in stride(from: (threads-1)*cap+align, to:height-2 , by: 2) {
                        
                        middle(y: y, width: width, data, out)
                    }
                    tail(height: height, width: width, data, out)
                default:
                    let align = (idx*cap)%2
                    
                    for y in stride(from: idx*cap+align, to: (idx+1)*cap, by: 2) {
                        
                        middle(y: y, width: width, data, out)
                    }
                }
            }
            
            queue.async(group: group, execute: worker)
        }
        
        group.wait()
    }
    
    private func head(width: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        var offset = 0
        var pixel = 0
        let width3 = 3*width
        
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = head_start_plus(data, width, offset)
        out[pixel+2] = head_start_cross(data, width, offset)
        
        out[pixel+3] = horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = head_vertical(data, width, offset+1)
        
        out[pixel+0+width3] = vertical(data, width, offset+width)
        out[pixel+1+width3] = native(data, width, offset+width)
        out[pixel+2+width3] = start_horizontal(data, width, offset+width)
        
        out[pixel+3+width3] = cross(data,width, offset+1+width)
        out[pixel+4+width3] = plus(data, width, offset+1+width)
        out[pixel+5+width3] = native(data, width, offset+1+width)
        
        offset += 2
        pixel += 6
        
        for _ in stride(from: 2, to: width-2, by: 2) {
            
            out[pixel+0] = native(data, width, offset)
            out[pixel+1] = head_plus(data, width, offset)
            out[pixel+2] = head_cross(data, width, offset)
            
            out[pixel+3] = horizontal(data, width, offset+1)
            out[pixel+4] = native(data, width, offset+1)
            out[pixel+5] = head_vertical(data, width, offset+1)
            
            out[pixel+0+width3] = head_vertical(data, width, offset+width)
            out[pixel+1+width3] = native(data, width, offset+width)
            out[pixel+2+width3] = horizontal(data, width, offset+width)
            
            out[pixel+3+width3] = cross(data,width, offset+1+width)
            out[pixel+4+width3] = plus(data, width, offset+1+width)
            out[pixel+5+width3] = native(data, width, offset+1+width)
            
            offset += 2
            pixel += 6
        }
        
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = head_plus(data, width, offset)
        out[pixel+2] = head_cross(data, width, offset)
        
        out[pixel+3] = end_horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = head_vertical(data, width, offset+1)
        
        out[pixel+0+width3] = head_vertical(data, width, offset+width)
        out[pixel+1+width3] = native(data, width, offset+width)
        out[pixel+2+width3] = horizontal(data, width, offset+width)
        
        out[pixel+3+width3] = head_end_cross(data,width, offset+1+width)
        out[pixel+4+width3] = head_end_plus(data, width, offset+1+width)
        out[pixel+5+width3] = native(data, width, offset+1+width)
    }
    
    private func middle(y: Int, width: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        // Special treatment of the first quadrant
        var offset = y*width
        var pixel = offset * 3
        let width3 = 3*width
        
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = start_plus(data, width, offset)
        out[pixel+2] = start_cross(data, width, offset)
        
        out[pixel+3] = horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = vertical(data, width, offset+1)
        
        out[pixel+0+width3] = vertical(data, width, offset+width)
        out[pixel+1+width3] = native(data, width, offset+width)
        out[pixel+2+width3] = start_horizontal(data, width, offset+width)
        
        out[pixel+3+width3] = cross(data,width, offset+1+width)
        out[pixel+4+width3] = plus(data, width, offset+1+width)
        out[pixel+5+width3] = native(data, width, offset+1+width)
        
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
            
            out[pixel+0+width3] = vertical(data, width, offset+width)
            out[pixel+1+width3] = native(data, width, offset+width)
            out[pixel+2+width3] = horizontal(data, width, offset+width)
            
            out[pixel+3+width3] = cross(data,width, offset+1+width)
            out[pixel+4+width3] = plus(data, width, offset+1+width)
            out[pixel+5+width3] = native(data, width, offset+1+width)
            
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
        
        out[pixel+0+width3] = vertical(data, width, offset+width)
        out[pixel+1+width3] = native(data, width, offset+width)
        out[pixel+2+width3] = end_horizontal(data, width, offset+width)
        
        out[pixel+3+width3] = end_cross(data,width, offset+1+width)
        out[pixel+4+width3] = end_plus(data, width, offset+1+width)
        out[pixel+5+width3] = native(data, width, offset+1+width)
    }
    
    private func tail(height: Int, width: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        var offset = (height-2)*width
        var pixel = offset * 3
        let width3 = 3*width
        
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = tail_start_plus(data, width, offset)
        out[pixel+2] = tail_start_cross(data, width, offset)
        
        out[pixel+3] = horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = tail_vertical(data, width, offset+1)
        
        out[pixel+0+width3] = tail_vertical(data, width, offset+width)
        out[pixel+1+width3] = native(data, width, offset+width)
        out[pixel+2+width3] = start_horizontal(data, width, offset+width)
        
        out[pixel+3+width3] = tail_cross(data,width, offset+1+width)
        out[pixel+4+width3] = tail_plus(data, width, offset+1+width)
        out[pixel+5+width3] = native(data, width, offset+1+width)
        
        offset += 2
        pixel += 6
        
        for _ in stride(from: 2, to: width-2, by: 2) {
            
            out[pixel+0] = native(data, width, offset)
            out[pixel+1] = tail_plus(data, width, offset)
            out[pixel+2] = tail_cross(data, width, offset)
            
            out[pixel+3] = horizontal(data, width, offset+1)
            out[pixel+4] = native(data, width, offset+1)
            out[pixel+5] = tail_vertical(data, width, offset+1)
            
            out[pixel+0+width3] = tail_vertical(data, width, offset+width)
            out[pixel+1+width3] = native(data, width, offset+width)
            out[pixel+2+width3] = horizontal(data, width, offset+width)
            
            out[pixel+3+width3] = tail_cross(data,width, offset+1+width)
            out[pixel+4+width3] = tail_plus(data, width, offset+1+width)
            out[pixel+5+width3] = native(data, width, offset+1+width)
            
            offset += 2
            pixel += 6
        }
        
        out[pixel+0] = native(data, width, offset)
        out[pixel+1] = tail_plus(data, width, offset)
        out[pixel+2] = tail_cross(data, width, offset)
        
        out[pixel+3] = horizontal(data, width, offset+1)
        out[pixel+4] = native(data, width, offset+1)
        out[pixel+5] = tail_vertical(data, width, offset+1)
        
        out[pixel+0+width3] = tail_vertical(data, width, offset+width)
        out[pixel+1+width3] = native(data, width, offset+width)
        out[pixel+2+width3] = end_horizontal(data, width, offset+width)
        
        out[pixel+3+width3] = tail_end_cross(data,width, offset+1+width)
        out[pixel+4+width3] = tail_end_plus(data, width, offset+1+width)
        out[pixel+5+width3] = native(data, width, offset+1+width)
    }
    
    /**
     computes average from a plus pattern
     
     ... O ...
     O x O
     ... O ...
     */
    private func plus(_ data: UnsafeBufferPointer<Byte>,
              _ width: Int,
              _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+1].bigEndian.float   // right
        sum += data[offset-width].bigEndian.float // top
        sum += data[offset+width].bigEndian.float // bottom
        
        return (add4 + sum) / max4
    }
    
    /**
     computes average from a plus pattern
     
     O x O
     ... O ...
     */
    private func head_plus(_ data: UnsafeBufferPointer<Byte>,
                   _ width: Int,
                   _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+1].bigEndian.float  // right
        sum += data[offset+width].bigEndian.float // bottom
        
        return (add3 + sum) / max3
    }
    
    /**
     computes average from a plus pattern
     
     ... O ...
     O x O
     */
    private func tail_plus(_ data: UnsafeBufferPointer<Byte>,
                   _ width: Int,
                   _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+1].bigEndian.float   // right
        sum += data[offset-width].bigEndian.float // top
        
        return (add3 + sum) / max3
    }
    
    /**
     computes average from a plus pattern
     
     O ...
     x O
     O ...
     */
    private func start_plus(_ data: UnsafeBufferPointer<Byte>,
                    _ width: Int,
                    _ offset: Int) -> Float
    {
        var sum = data[offset+1].bigEndian.float   // right
        sum += data[offset-width].bigEndian.float // top
        sum += data[offset+width].bigEndian.float // bottom
        
        return (add3 + sum) / max3
    }
    
    /**
     computes average from a plus pattern
     
     ... O
     O x
     ... O.
     */
    private func end_plus(_ data: UnsafeBufferPointer<Byte>,
                  _ width: Int,
                  _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset-width].bigEndian.float // top
        sum += data[offset+width].bigEndian.float // bottom
        
        return (add3 + sum) / max3
    }
    
    /**
     computes average from a plus pattern
     
     x O
     O ...
     */
    private func head_start_plus(_ data: UnsafeBufferPointer<Byte>,
                         _ width: Int,
                         _ offset: Int) -> Float
    {
        // left
        var sum = data[offset+1].bigEndian.float   // right
        sum += data[offset+width].bigEndian.float // bottom
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a plus pattern
     
     O x
     ... O
     */
    private func head_end_plus(_ data: UnsafeBufferPointer<Byte>,
                       _ width: Int,
                       _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+width].bigEndian.float // bottom
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a plus pattern
     
     O ...
     x O
     */
    private func tail_start_plus(_ data: UnsafeBufferPointer<Byte>,
                         _ width: Int,
                         _ offset: Int) -> Float
    {
        // left
        var sum = data[offset+1].bigEndian.float   // right
        sum += data[offset-width].bigEndian.float // top
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a plus pattern
     
     ... O
     O x
     */
    private func tail_end_plus(_ data: UnsafeBufferPointer<Byte>,
                       _ width: Int,
                       _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset-width].bigEndian.float // top
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a cross pattern
     
     O ... O
     ... x ...
     O ... O
     */
    private func cross(_ data: UnsafeBufferPointer<Byte>,
               _ width: Int,
               _ offset: Int) -> Float
    {
        
        var sum = data[offset-1-width].bigEndian.float // top left
        sum += data[offset+1-width].bigEndian.float // top right
        sum += data[offset-1+width].bigEndian.float // bottom left
        sum += data[offset+1+width].bigEndian.float // bottom right
        
        return (add4 + sum) / max4
    }
    
    /**
     computes average from a cross pattern
     
     ... x ...
     O ... O
     */
    private func head_cross(_ data: UnsafeBufferPointer<Byte>,
                    _ width: Int,
                    _ offset: Int) -> Float
    {
        
        var sum = data[offset-1+width].bigEndian.float // bottom left
        sum += data[offset+1+width].bigEndian.float // bottom right
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a cross pattern
     
     O ... O
     ... x ...
     */
    private func tail_cross(_ data: UnsafeBufferPointer<Byte>,
                    _ width: Int,
                    _ offset: Int) -> Float
    {
        
        var sum = data[offset-1-width].bigEndian.float // top left
        sum += data[offset+1-width].bigEndian.float // top right
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a cross pattern
     
     ... O
     x ...
     ... O
     */
    private func start_cross(_ data: UnsafeBufferPointer<Byte>,
                     _ width: Int,
                     _ offset: Int) -> Float
    {
        
        var sum = data[offset+1-width].bigEndian.float // top right
        sum += data[offset+1+width].bigEndian.float // bottom right
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a cross pattern
     
     O ...
     ... x
     O ...
     */
    private func end_cross(_ data: UnsafeBufferPointer<Byte>,
                   _ width: Int,
                   _ offset: Int) -> Float
    {
        
        var sum = data[offset-1-width].bigEndian.float // top left
        sum += data[offset-1+width].bigEndian.float // bottom left
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a cross pattern
     
     x ...
     ... O
     */
    private func head_start_cross(_ data: UnsafeBufferPointer<Byte>,
                          _ width: Int,
                          _ offset: Int) -> Float
    {
        
        let sum = data[offset+1+width].bigEndian.float // bottom right
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a cross pattern
     
     ... x
     O ...
     */
    private func head_end_cross(_ data: UnsafeBufferPointer<Byte>,
                        _ width: Int,
                        _ offset: Int) -> Float
    {
        let sum = data[offset-1+width].bigEndian.float // bottom left
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a cross pattern
     
     ... O
     x ...
     */
    private func tail_start_cross(_ data: UnsafeBufferPointer<Byte>,
                          _ width: Int,
                          _ offset: Int) -> Float
    {
        
        let sum = data[offset+1-width].bigEndian.float // top right
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a cross pattern
     
     O ...
     ... x
     */
    private func tail_end_cross(_ data: UnsafeBufferPointer<Byte>,
                        _ width: Int,
                        _ offset: Int) -> Float
    {
        
        let sum = data[offset-1-width].bigEndian.float // top left
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a horizontal line
     
     ... ... ...
     O x O
     ... ... ...
     */
    private func horizontal(_ data: UnsafeBufferPointer<Byte>,
                    _ width: Int,
                    _ offset: Int) -> Float
    {
        
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+1].bigEndian.float // right
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a horizontal line
     
     ... ...
     x O
     ... ...
     */
    private func start_horizontal(_ data: UnsafeBufferPointer<Byte>,
                          _ width: Int,
                          _ offset: Int) -> Float
    {
        
        let sum = data[offset+1].bigEndian.float // right
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a horizontal line
     
     ... ...
     O x
     ... ...
     */
    private func end_horizontal(_ data: UnsafeBufferPointer<Byte>,
                        _ width: Int,
                        _ offset: Int) -> Float
    {
        
        let sum = data[offset+1].bigEndian.float // right
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a vertical line
     ... O ...
     ... x ...
     ... O ...
     */
    private func vertical(_ data: UnsafeBufferPointer<Byte>,
                  _ width: Int,
                  _ offset: Int) -> Float
    {
        
        var sum = data[offset-width].bigEndian.float // top
        sum += data[offset+width].bigEndian.float // bottom
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a vertical line
     ... x ...
     ... O ...
     */
    private func head_vertical(_ data: UnsafeBufferPointer<Byte>,
                       _ width: Int,
                       _ offset: Int) -> Float
    {
        
        let sum = data[offset+width].bigEndian.float // bottom
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a vertical line
     ... O ...
     ... x ...
     */
    private func tail_vertical(_ data: UnsafeBufferPointer<Byte>,
                       _ width: Int,
                       _ offset: Int) -> Float
    {
        
        let sum = data[offset-width].bigEndian.float // top
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a vertical line
     ... ... ...
     ...  x  ...
     ... ... ...
     */
    private func native(_ data: UnsafeBufferPointer<Byte>,
                _ width: Int,
                _ offset: Int) -> Float
    {
        
        let sum = data[offset].bigEndian.float // top
        
        return (add1 + sum) / max1
    }
    
    
    public func targetDimensions(width: Int, height: Int) -> (width: Int, height: Int) {
        return (width,height)
    }
}
