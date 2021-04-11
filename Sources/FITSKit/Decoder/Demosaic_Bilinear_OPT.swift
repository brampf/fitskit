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
public struct Demosaic_Bilinear_OPT : ImageDecoder {
    public typealias Paramter = CFA_Pattern
    public typealias Out = Float
    public typealias Pixel = RGB
    
    private var pattern : CFA_Pattern

    private var height1 : Int
    
    internal var width1 : Int
    private var width1p1 : Int
    private var width1m1 : Int
    private var width3 : Int
    
    private var max1 : Float
    private var max2 : Float
    private var max3 : Float
    private var max4 : Float
    
    private var scale : Float
    
    private var add1 : Float
    private var add2 : Float
    private var add3 : Float
    private var add4 : Float
    
    public init(_ parameter: CFA_Pattern, width: Int, height: Int, bscale: Float, bzero: Float, range: Float) {
        self.pattern = parameter
        
        self.height1 = height
        
        self.width1 = width
        self.width3 = width * 3
        self.width1p1 = width + 1
        self.width1m1 = width - 1
        
        self.scale = bscale
        
        self.add1 = bzero
        self.add2 = bzero * 2.0
        self.add3 = bzero * 3.0
        self.add4 = bzero * 4.0
        
        self.max1 = range
        self.max2 = range * 2.0
        self.max3 = range * 3.0
        self.max4 = range * 4.0
    }
    
    public func decode<Byte: FITSByte>(_ dataUnit: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>) {
        
        switch pattern {
        case .RGGB:
            self.XGGY(dataUnit, out)
        case .BGGR:
            self.XGGY(dataUnit, out)
        default:
            fatalError("Not implemented")
        }
        
    }
    
    func XGGY<Byte: FITSByte>(  _ data: UnsafeBufferPointer<Byte>,
                _ out: UnsafeMutableBufferPointer<Float>)
    {
        
        head(data, out)
        for y in stride(from: 2, to: height1-2, by: 2) {
            
            middle(y: y, data, out)
        }
        tail(data, out)
        
    }
    
    public func targetDimensions(width: Int, height: Int) -> (width: Int, height: Int) {
        return (width,height)
    }
}

extension Demosaic_Bilinear_OPT {
    
    /**
     computes average from a plus pattern
     
     ... O ...
     O x O
     ... O ...
     */
    private func plus<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+1].bigEndian.float   // right
        sum += data[offset-width1].bigEndian.float // top
        sum += data[offset+width1].bigEndian.float // bottom
        
        return (add4 + sum) / max4
    }
    
    /**
     computes average from a plus pattern
     
     O x O
     ... O ...
     */
    private func head_plus<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+1].bigEndian.float  // right
        sum += data[offset+width1].bigEndian.float // bottom
        
        return (add3 + sum) / max3
    }
    
    /**
     computes average from a plus pattern
     
     ... O ...
     O x O
     */
    private func tail_plus<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+1].bigEndian.float   // right
        sum += data[offset-width1].bigEndian.float // top
        
        return (add3 + sum) / max3
    }
    
    /**
     computes average from a plus pattern
     
     O ...
     x O
     O ...
     */
    private func start_plus<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        var sum = data[offset+1].bigEndian.float   // right
        sum += data[offset-width1].bigEndian.float // top
        sum += data[offset+width1].bigEndian.float // bottom
        
        return (add3 + sum) / max3
    }
    
    /**
     computes average from a plus pattern
     
     ... O
     O x
     ... O.
     */
    private func end_plus<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset-width1].bigEndian.float // top
        sum += data[offset+width1].bigEndian.float // bottom
        
        return (add3 + sum) / max3
    }
    
    /**
     computes average from a plus pattern
     
     x O
     O ...
     */
    private func head_start_plus<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        // left
        var sum = data[offset+1].bigEndian.float   // right
        sum += data[offset+width1].bigEndian.float // bottom
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a plus pattern
     
     O x
     ... O
     */
    private func head_end_plus<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset+width1].bigEndian.float // bottom
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a plus pattern
     
     O ...
     x O
     */
    private func tail_start_plus<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        // left
        var sum = data[offset+1].bigEndian.float   // right
        sum += data[offset-width1].bigEndian.float // top
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a plus pattern
     
     ... O
     O x
     */
    private func tail_end_plus<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        // left
        var sum = data[offset-1].bigEndian.float // left
        sum += data[offset-width1].bigEndian.float // top
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a cross pattern
     
     O ... O
     ... x ...
     O ... O
     */
    private func cross<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        var sum = data[offset-1-width1].bigEndian.float // top left
        sum += data[offset+1-width1].bigEndian.float // top right
        sum += data[offset-1+width1].bigEndian.float // bottom left
        sum += data[offset+1+width1].bigEndian.float // bottom right
        
        return (add4 + sum) / max4
    }
    
    /**
     computes average from a cross pattern
     
     ... x ...
     O ... O
     */
    private func head_cross<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        var sum = data[offset-1+width1].bigEndian.float // bottom left
        sum += data[offset+1+width1].bigEndian.float // bottom right
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a cross pattern
     
     O ... O
     ... x ...
     */
    private func tail_cross<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        var sum = data[offset-1-width1].bigEndian.float // top left
        sum += data[offset+1-width1].bigEndian.float // top right
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a cross pattern
     
     ... O
     x ...
     ... O
     */
    private func start_cross<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        var sum = data[offset+1-width1].bigEndian.float // top right
        sum += data[offset+1+width1].bigEndian.float // bottom right
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a cross pattern
     
     O ...
     ... x
     O ...
     */
    private func end_cross<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        var sum = data[offset-1-width1].bigEndian.float // top left
        sum += data[offset-1+width1].bigEndian.float // bottom left
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a cross pattern
     
     x ...
     ... O
     */
    private func head_start_cross<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        let sum = data[offset+1+width1].bigEndian.float // bottom right
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a cross pattern
     
     ... x
     O ...
     */
    private func head_end_cross<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        let sum = data[offset-1+width1].bigEndian.float // bottom left
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a cross pattern
     
     ... O
     x ...
     */
    private func tail_start_cross<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        let sum = data[offset+1-width1].bigEndian.float // top right
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a cross pattern
     
     O ...
     ... x
     */
    private func tail_end_cross<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        let sum = data[offset-1-width1].bigEndian.float // top left
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a horizontal line
     
     ... ... ...
     O x O
     ... ... ...
     */
    private func horizontal<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
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
    private func start_horizontal<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
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
    private func end_horizontal<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
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
    private func vertical<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        var sum = data[offset-width1].bigEndian.float // top
        sum += data[offset+width1].bigEndian.float // bottom
        
        return (add2 + sum) / max2
    }
    
    /**
     computes average from a vertical line
     ... x ...
     ... O ...
     */
    private func head_vertical<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        let sum = data[offset+width1].bigEndian.float // bottom
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a vertical line
     ... O ...
     ... x ...
     */
    private func tail_vertical<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        let sum = data[offset-width1].bigEndian.float // top
        
        return (add1 + sum) / max1
    }
    
    /**
     computes average from a vertical line
     ... ... ...
     ...  x  ...
     ... ... ...
     */
    private func native<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ offset: Int) -> Float
    {
        
        let sum = data[offset].bigEndian.float // top
        
        return (add1 + sum) / max1
    }
    
    
}

extension Demosaic_Bilinear_OPT {
    
    private func head<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        var offset = 0
        var pixel = 0
        
        out[pixel+0] = native(data, offset)
        out[pixel+1] = head_start_plus(data, offset)
        out[pixel+2] = head_start_cross(data, offset)
        
        out[pixel+3] = horizontal(data, offset+1)
        out[pixel+4] = native(data, offset+1)
        out[pixel+5] = head_vertical(data, offset+1)
        
        out[pixel+0+width3] = vertical(data, offset+width1)
        out[pixel+1+width3] = native(data, offset+width1)
        out[pixel+2+width3] = start_horizontal(data, offset+width1)
        
        out[pixel+3+width3] = cross(data, offset+width1p1)
        out[pixel+4+width3] = plus(data, offset+width1p1)
        out[pixel+5+width3] = native(data, offset+width1p1)
        
        offset += 2
        pixel += 6
        
        for _ in stride(from: 2, to: width1-2, by: 2) {
            
            out[pixel+0] = native(data, offset)
            out[pixel+1] = head_plus(data, offset)
            out[pixel+2] = head_cross(data, offset)
            
            out[pixel+3] = horizontal(data, offset+1)
            out[pixel+4] = native(data, offset+1)
            out[pixel+5] = head_vertical(data, offset+1)
            
            out[pixel+0+width3] = head_vertical(data, offset+width1)
            out[pixel+1+width3] = native(data, offset+width1)
            out[pixel+2+width3] = horizontal(data, offset+width1)
            
            out[pixel+3+width3] = cross(data, offset+width1p1)
            out[pixel+4+width3] = plus(data, offset+width1p1)
            out[pixel+5+width3] = native(data, offset+width1p1)
            
            offset += 2
            pixel += 6
        }
        
        out[pixel+0] = native(data, offset)
        out[pixel+1] = head_plus(data, offset)
        out[pixel+2] = head_cross(data, offset)
        
        out[pixel+3] = end_horizontal(data, offset+1)
        out[pixel+4] = native(data, offset+1)
        out[pixel+5] = head_vertical(data, offset+1)
        
        out[pixel+0+width3] = head_vertical(data, offset+width1)
        out[pixel+1+width3] = native(data, offset+width1)
        out[pixel+2+width3] = horizontal(data, offset+width1)
        
        out[pixel+3+width3] = head_end_cross(data, offset+width1p1)
        out[pixel+4+width3] = head_end_plus(data, offset+width1p1)
        out[pixel+5+width3] = native(data, offset+width1p1)
    }
    
    private func middle<Byte: FITSByte>(y: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        // Special treatment of the first quadrant
        var offset = y*width1
        var pixel = offset * 3
        
        out[pixel+0] = native(data, offset)
        out[pixel+1] = start_plus(data, offset)
        out[pixel+2] = start_cross(data, offset)
        
        out[pixel+3] = horizontal(data, offset+1)
        out[pixel+4] = native(data, offset+1)
        out[pixel+5] = vertical(data, offset+1)
        
        out[pixel+0+width3] = vertical(data, offset+width1)
        out[pixel+1+width3] = native(data, offset+width1)
        out[pixel+2+width3] = start_horizontal(data, offset+width1)
        
        out[pixel+3+width3] = cross(data, offset+width1p1)
        out[pixel+4+width3] = plus(data, offset+width1p1)
        out[pixel+5+width3] = native(data, offset+width1p1)
        
        offset += 2
        pixel += 6
        
        // run unchecked for all other elements of the row
        for _ in stride(from: 2, to: width1-2, by: 2) {
            
            out[pixel+0] = native(data, offset)
            out[pixel+1] = plus(data, offset)
            out[pixel+2] = cross(data, offset)
            
            out[pixel+3] = horizontal(data, offset+1)
            out[pixel+4] = native(data, offset+1)
            out[pixel+5] = vertical(data, offset+1)
            
            out[pixel+0+width3] = vertical(data, offset+width1)
            out[pixel+1+width3] = native(data, offset+width1)
            out[pixel+2+width3] = horizontal(data, offset+width1)
            
            out[pixel+3+width3] = cross(data, offset+width1p1)
            out[pixel+4+width3] = plus(data, offset+width1p1)
            out[pixel+5+width3] = native(data, offset+width1p1)
            
            offset += 2
            pixel += 6
            
        }
        
        // Special treatment of the last quadrant
        out[pixel+0] = native(data, offset)
        out[pixel+1] = plus(data, offset)
        out[pixel+2] = cross(data, offset)
        
        out[pixel+3] = end_horizontal(data, offset+1)
        out[pixel+4] = native(data, offset+1)
        out[pixel+5] = vertical(data, offset+1)
        
        out[pixel+0+width3] = vertical(data, offset+width1)
        out[pixel+1+width3] = native(data, offset+width1)
        out[pixel+2+width3] = end_horizontal(data, offset+width1)
        
        out[pixel+3+width3] = end_cross(data, offset+width1p1)
        out[pixel+4+width3] = end_plus(data, offset+width1p1)
        out[pixel+5+width3] = native(data, offset+width1p1)
    }
    
    private func tail<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        var offset = (height1-2)*width1
        var pixel = offset * 3
        
        out[pixel+0] = native(data, offset)
        out[pixel+1] = tail_start_plus(data, offset)
        out[pixel+2] = tail_start_cross(data, offset)
        
        out[pixel+3] = horizontal(data, offset+1)
        out[pixel+4] = native(data, offset+1)
        out[pixel+5] = tail_vertical(data, offset+1)
        
        out[pixel+0+width3] = tail_vertical(data, offset+width1)
        out[pixel+1+width3] = native(data, offset+width1)
        out[pixel+2+width3] = start_horizontal(data, offset+width1)
        
        out[pixel+3+width3] = tail_cross(data, offset+width1p1)
        out[pixel+4+width3] = tail_plus(data, offset+width1p1)
        out[pixel+5+width3] = native(data, offset+width1p1)
        
        offset += 2
        pixel += 6
        
        for _ in stride(from: 2, to: width1-2, by: 2) {
            
            out[pixel+0] = native(data, offset)
            out[pixel+1] = tail_plus(data, offset)
            out[pixel+2] = tail_cross(data, offset)
            
            out[pixel+3] = horizontal(data, offset+1)
            out[pixel+4] = native(data, offset+1)
            out[pixel+5] = tail_vertical(data, offset+1)
            
            out[pixel+0+width3] = tail_vertical(data, offset+width1)
            out[pixel+1+width3] = native(data, offset+width1)
            out[pixel+2+width3] = horizontal(data, offset+width1)
            
            out[pixel+3+width3] = tail_cross(data, offset+width1p1)
            out[pixel+4+width3] = tail_plus(data, offset+width1p1)
            out[pixel+5+width3] = native(data, offset+width1p1)
            
            offset += 2
            pixel += 6
        }
        
        out[pixel+0] = native(data, offset)
        out[pixel+1] = tail_plus(data, offset)
        out[pixel+2] = tail_cross(data, offset)
        
        out[pixel+3] = horizontal(data, offset+1)
        out[pixel+4] = native(data, offset+1)
        out[pixel+5] = tail_vertical(data, offset+1)
        
        out[pixel+0+width3] = tail_vertical(data, offset+width1)
        out[pixel+1+width3] = native(data, offset+width1)
        out[pixel+2+width3] = end_horizontal(data, offset+width1)
        
        out[pixel+3+width3] = tail_end_cross(data, offset+width1p1)
        out[pixel+4+width3] = tail_end_plus(data, offset+width1p1)
        out[pixel+5+width3] = native(data, offset+width1p1)
    }
    
}
