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
 Demosaics the picture according to the bayer filter provided as `Parameter`
 
 *Note*: Only implements RGGB and BGGR at the moment
 */
public struct BayerDecoder : ImageDecoderGCD {
    
    public typealias Paramter = CFA_Pattern
    public typealias Pixel = ARGB
    public typealias Out = Float

    private var pattern : CFA_Pattern
    
    internal var height1 : Int
    
    internal var width1 : Int
    private var width1p1 : Int
    private var width1m1 : Int
    
    private var width4 : Int
    private var width4p1 : Int
    private var width4p2 : Int
    private var width4p3 : Int
    private var width4p4 : Int
    private var width4p5 : Int
    private var width4p6 : Int
    private var width4p7 : Int
    
    private var max1 : Float
    private var max2 : Float
    private var max3 : Float
    private var max4 : Float
    
    private var scale : Float
    
    private var add1 : Float
    private var add2 : Float
    private var add3 : Float
    private var add4 : Float
    
    public init<Byte: FITSByte>(_ parameter: CFA_Pattern, width: Int, height: Int, bscale: Float, bzero: Float, min: Byte, max: Byte) {
        self.pattern = parameter

        self.height1 = height
        
        self.width1 = width
        self.width1p1 = width + 1
        self.width1m1 = width - 1
        
        self.width4 = width * 4
        self.width4p1 = width4+1
        self.width4p2 = width4+2
        self.width4p3 = width4+3
        self.width4p4 = width4+4
        self.width4p5 = width4+5
        self.width4p6 = width4+6
        self.width4p7 = width4+7
        
        self.scale = bscale
        
        self.add1 = bzero - (bzero + min.float * bscale)
        self.max1 = (bzero + max.float * bscale) - (bzero + min.float * bscale)
        
        self.add2 = add1 * 2.0
        self.add3 = add1 * 3.0
        self.add4 = add1 * 4.0
        
        self.max2 = max1 * 2.0
        self.max3 = max1 * 3.0
        self.max4 = max1 * 4.0
    }
    
    public func block<In: FITSByte>(for thread: Int, of: Int,
                      _ data: UnsafeBufferPointer<In>,
                      _ out: UnsafeMutableBufferPointer<Float>){
        
        let cap = height1/of
        
        switch thread {
        
        case 0:
            XGGYhead(data, out)
            
            for y in stride(from: 2, to: cap, by: 2) {
                
                XGGYmiddle(y: y, data, out)
            }
        case of-1:
            let align = cap%2
            
            for y in stride(from: (of-1)*cap+align, to:height1-2 , by: 2) {
                
                XGGYmiddle(y: y, data, out)
            }
            XGGYtail(data, out)
        default:
            let align = (thread*cap)%2
            
            for y in stride(from: thread*cap+align, to: (thread+1)*cap, by: 2) {
                
                XGGYmiddle(y: y, data, out)
            }
        }
        
    }
    
    
    public func targetDimensions(width: Int, height: Int) -> (width: Int, height: Int) {
        return (width,height)
    }
    
}

extension BayerDecoder {
    
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

extension BayerDecoder {
    
    private func head<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
    }
    
    private func middle<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
    }
    
    private func end<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
    }
}



//MARK:- Decode RGGB
extension BayerDecoder {
    
    private func XGGYhead<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        var offset = 0
        var pixel = 0
        
        out[pixel+1] = native(data, offset)
        out[pixel+2] = head_start_plus(data, offset)
        out[pixel+3] = head_start_cross(data, offset)
        
        out[pixel+5] = horizontal(data, offset+1)
        out[pixel+6] = native(data, offset+1)
        out[pixel+7] = head_vertical(data, offset+1)
        
        out[pixel+width4p1] = vertical(data, offset+width1)
        out[pixel+width4p2] = native(data, offset+width1)
        out[pixel+width4p3] = start_horizontal(data, offset+width1)
        
        out[pixel+width4p5] = cross(data, offset+width1p1)
        out[pixel+width4p6] = plus(data, offset+width1p1)
        out[pixel+width4p7] = native(data, offset+width1p1)
        
        offset += 2
        pixel += 8
        
        for _ in stride(from: 2, to: width1-2, by: 2) {
            
            out[pixel+1] = native(data, offset)
            out[pixel+2] = head_plus(data, offset)
            out[pixel+3] = head_cross(data, offset)
            
            out[pixel+5] = horizontal(data, offset+1)
            out[pixel+6] = native(data, offset+1)
            out[pixel+7] = head_vertical(data, offset+1)
            
            out[pixel+width4p1] = head_vertical(data, offset+width1)
            out[pixel+width4p2] = native(data, offset+width1)
            out[pixel+width4p3] = horizontal(data, offset+width1)
            
            out[pixel+width4p5] = cross(data, offset+width1p1)
            out[pixel+width4p6] = plus(data, offset+width1p1)
            out[pixel+width4p7] = native(data, offset+width1p1)
            
            offset += 2
            pixel += 8
        }
        
        out[pixel+1] = native(data, offset)
        out[pixel+2] = head_plus(data, offset)
        out[pixel+3] = head_cross(data, offset)
        
        out[pixel+5] = end_horizontal(data, offset+1)
        out[pixel+6] = native(data, offset+1)
        out[pixel+7] = head_vertical(data, offset+1)
        
        out[pixel+width4p1] = head_vertical(data, offset+width1)
        out[pixel+width4p2] = native(data, offset+width1)
        out[pixel+width4p3] = horizontal(data, offset+width1)
        
        out[pixel+width4p4] = head_end_cross(data, offset+width1p1)
        out[pixel+width4p5] = head_end_plus(data, offset+width1p1)
        out[pixel+width4p6] = native(data, offset+width1p1)
    }
    
    private func XGGYmiddle<Byte: FITSByte>(y: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        // Special treatment of the first quadrant
        var offset = y*width1
        var pixel = offset * 4
        
        out[pixel+1] = native(data, offset)
        out[pixel+2] = start_plus(data, offset)
        out[pixel+3] = start_cross(data, offset)
        
        out[pixel+5] = horizontal(data, offset+1)
        out[pixel+5] = native(data, offset+1)
        out[pixel+7] = vertical(data, offset+1)
        
        out[pixel+width4p1] = vertical(data, offset+width1)
        out[pixel+width4p2] = native(data, offset+width1)
        out[pixel+width4p3] = start_horizontal(data, offset+width1)
        
        out[pixel+width4p5] = cross(data, offset+width1p1)
        out[pixel+width4p6] = plus(data, offset+width1p1)
        out[pixel+width4p7] = native(data, offset+width1p1)
        
        offset += 2
        pixel += 8
        
        // run unchecked for all other elements of the row
        for _ in stride(from: 2, to: width1-2, by: 2) {
            
            out[pixel+1] = native(data, offset)
            out[pixel+2] = plus(data, offset)
            out[pixel+3] = cross(data, offset)
            
            out[pixel+5] = horizontal(data, offset+1)
            out[pixel+6] = native(data, offset+1)
            out[pixel+7] = vertical(data, offset+1)
            
            out[pixel+width4p1] = vertical(data, offset+width1)
            out[pixel+width4p2] = native(data, offset+width1)
            out[pixel+width4p3] = horizontal(data, offset+width1)
            
            out[pixel+width4p5] = cross(data, offset+width1p1)
            out[pixel+width4p6] = plus(data, offset+width1p1)
            out[pixel+width4p7] = native(data, offset+width1p1)
            
            offset += 2
            pixel += 8
            
        }
        
        // Special treatment of the last quadrant
        out[pixel+1] = native(data, offset)
        out[pixel+2] = plus(data, offset)
        out[pixel+3] = cross(data, offset)
        
        out[pixel+5] = end_horizontal(data, offset+1)
        out[pixel+6] = native(data, offset+1)
        out[pixel+7] = vertical(data, offset+1)
        
        out[pixel+width4p1] = vertical(data, offset+width1)
        out[pixel+width4p2] = native(data, offset+width1)
        out[pixel+width4p3] = end_horizontal(data, offset+width1)
        
        out[pixel+width4p5] = end_cross(data, offset+width1p1)
        out[pixel+width4p6] = end_plus(data, offset+width1p1)
        out[pixel+width4p7] = native(data, offset+width1p1)
    }
    
    private func XGGYtail<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        var offset = (height1-2)*width1
        var pixel = offset * 4
        
        out[pixel+1] = native(data, offset)
        out[pixel+2] = tail_start_plus(data, offset)
        out[pixel+3] = tail_start_cross(data, offset)
        
        out[pixel+5] = horizontal(data, offset+1)
        out[pixel+6] = native(data, offset+1)
        out[pixel+7] = tail_vertical(data, offset+1)
        
        out[pixel+width4p1] = tail_vertical(data, offset+width1)
        out[pixel+width4p2] = native(data, offset+width1)
        out[pixel+width4p3] = start_horizontal(data, offset+width1)
        
        out[pixel+width4p5] = tail_cross(data, offset+width1p1)
        out[pixel+width4p6] = tail_plus(data, offset+width1p1)
        out[pixel+width4p7] = native(data, offset+width1p1)
        
        offset += 2
        pixel += 8
        
        for _ in stride(from: 2, to: width1-2, by: 2) {
            
            out[pixel+1] = native(data, offset)
            out[pixel+2] = tail_plus(data, offset)
            out[pixel+3] = tail_cross(data, offset)
            
            out[pixel+4] = horizontal(data, offset+1)
            out[pixel+5] = native(data, offset+1)
            out[pixel+6] = tail_vertical(data, offset+1)
            
            out[pixel+width4p1] = tail_vertical(data, offset+width1)
            out[pixel+width4p2] = native(data, offset+width1)
            out[pixel+width4p3] = horizontal(data, offset+width1)
        
            out[pixel+width4p5] = tail_cross(data, offset+width1p1)
            out[pixel+width4p6] = tail_plus(data, offset+width1p1)
            out[pixel+width4p7] = native(data, offset+width1p1)
            
            offset += 2
            pixel += 8
        }
        
        out[pixel+1] = native(data, offset)
        out[pixel+2] = tail_plus(data, offset)
        out[pixel+3] = tail_cross(data, offset)
        
        out[pixel+4] = horizontal(data, offset+1)
        out[pixel+5] = native(data, offset+1)
        out[pixel+6] = tail_vertical(data, offset+1)
        
        out[pixel+width4p1] = tail_vertical(data, offset+width1)
        out[pixel+width4p2] = native(data, offset+width1)
        out[pixel+width4p3] = end_horizontal(data, offset+width1)
        
        out[pixel+width4p5] = tail_end_cross(data, offset+width1p1)
        out[pixel+width4p6] = tail_end_plus(data, offset+width1p1)
        out[pixel+width4p7] = native(data, offset+width1p1)
    }
    
}

//MARK:- Decode GRBG
extension BayerDecoder {
    
    private func GXYGhead<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        var offset = 0
        var pixel = 0
        
        out[pixel+1] = start_horizontal(data, offset)
        out[pixel+2] = native(data, offset)
        out[pixel+3] = head_vertical(data, offset)
        
        out[pixel+5] = native(data, offset+1)
        out[pixel+6] = head_plus(data, offset+1)
        out[pixel+7] = head_cross(data, offset+1)
        
        out[pixel+width4p1] = start_cross(data, offset+width1)
        out[pixel+width4p2] = start_plus(data, offset+width1)
        out[pixel+width4p3] = native(data, offset+width1)
        
        out[pixel+width4p5] = vertical(data, offset+width1p1)
        out[pixel+width4p6] = native(data, offset+width1p1)
        out[pixel+width4p7] = horizontal(data, offset+width1p1)
        
        offset += 2
        pixel += 8
        
        for _ in stride(from: 2, to: width1-2, by: 2) {
            
            out[pixel+1] = horizontal(data, offset)
            out[pixel+2] = native(data, offset)
            out[pixel+3] = head_vertical(data, offset)
            
            out[pixel+5] = native(data, offset+1)
            out[pixel+6] = head_plus(data, offset+1)
            out[pixel+7] = head_cross(data, offset+1)
            
            out[pixel+width4p1] = cross(data, offset+width1)
            out[pixel+width4p2] = plus(data, offset+width1)
            out[pixel+width4p3] = native(data, offset+width1)
            
            out[pixel+width4p5] = vertical(data, offset+width1p1)
            out[pixel+width4p6] = native(data, offset+width1p1)
            out[pixel+width4p7] = horizontal(data, offset+width1p1)
            
            offset += 2
            pixel += 8
        }
        
        out[pixel+1] = horizontal(data, offset)
        out[pixel+2] = native(data, offset)
        out[pixel+3] = head_vertical(data, offset)
        
        out[pixel+5] = native(data, offset+1)
        out[pixel+6] = head_end_plus(data, offset+1)
        out[pixel+7] = head_end_cross(data, offset+1)
        
        out[pixel+width4p1] = cross(data, offset+width1)
        out[pixel+width4p2] = plus(data, offset+width1)
        out[pixel+width4p3] = native(data, offset+width1)
        
        out[pixel+width4p4] = vertical(data, offset+width1p1)
        out[pixel+width4p5] = native(data, offset+width1p1)
        out[pixel+width4p6] = end_horizontal(data, offset+width1p1)
    }
    
    private func GXYGmiddle<Byte: FITSByte>(y: Int, _ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        // Special treatment of the first quadrant
        var offset = y*width1
        var pixel = offset * 4
        
        out[pixel+1] = start_horizontal(data, offset)
        out[pixel+2] = native(data, offset)
        out[pixel+3] = vertical(data, offset)
        
        out[pixel+5] = native(data, offset+1)
        out[pixel+6] = plus(data, offset+1)
        out[pixel+7] = cross(data, offset+1)
        
        out[pixel+width4p1] = start_cross(data, offset+width1)
        out[pixel+width4p2] = start_plus(data, offset+width1)
        out[pixel+width4p3] = native(data, offset+width1)
        
        out[pixel+width4p5] = vertical(data, offset+width1p1)
        out[pixel+width4p6] = native(data, offset+width1p1)
        out[pixel+width4p7] = horizontal(data, offset+width1p1)
        
        offset += 2
        pixel += 8
        
        // run unchecked for all other elements of the row
        for _ in stride(from: 2, to: width1-2, by: 2) {
            
            out[pixel+1] = horizontal(data, offset)
            out[pixel+2] = native(data, offset)
            out[pixel+3] = vertical(data, offset)
            
            out[pixel+5] = native(data, offset+1)
            out[pixel+6] = plus(data, offset+1)
            out[pixel+7] = cross(data, offset+1)
            
            out[pixel+width4p1] = cross(data, offset+width1)
            out[pixel+width4p2] = plus(data, offset+width1)
            out[pixel+width4p3] = native(data, offset+width1)
            
            out[pixel+width4p5] = vertical(data, offset+width1p1)
            out[pixel+width4p6] = native(data, offset+width1p1)
            out[pixel+width4p7] = horizontal(data, offset+width1p1)
            
            offset += 2
            pixel += 8
            
        }
        
        // Special treatment of the last quadrant
        out[pixel+1] = horizontal(data, offset)
        out[pixel+2] = native(data, offset)
        out[pixel+3] = vertical(data, offset)
        
        out[pixel+5] = native(data, offset+1)
        out[pixel+6] = end_plus(data, offset+1)
        out[pixel+7] = end_cross(data, offset+1)
        
        out[pixel+width4p1] = cross(data, offset+width1)
        out[pixel+width4p2] = plus(data, offset+width1)
        out[pixel+width4p3] = native(data, offset+width1)
        
        out[pixel+width4p4] = vertical(data, offset+width1p1)
        out[pixel+width4p5] = native(data, offset+width1p1)
        out[pixel+width4p6] = end_horizontal(data, offset+width1p1)
    }
    
    private func GXYGtail<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>, _ out: UnsafeMutableBufferPointer<Float>){
        
        var offset = (height1-2)*width1
        var pixel = offset * 4
        
        out[pixel+1] = start_horizontal(data, offset)
        out[pixel+2] = native(data, offset)
        out[pixel+3] = vertical(data, offset)
        
        out[pixel+5] = native(data, offset+1)
        out[pixel+6] = tail_start_plus(data, offset+1)
        out[pixel+7] = tail_start_cross(data, offset+1)
        
        out[pixel+width4p1] = tail_cross(data, offset+width1)
        out[pixel+width4p2] = tail_plus(data, offset+width1)
        out[pixel+width4p3] = native(data, offset+width1)
        
        out[pixel+width4p5] = tail_vertical(data, offset+width1p1)
        out[pixel+width4p6] = native(data, offset+width1p1)
        out[pixel+width4p7] = horizontal(data, offset+width1p1)
        
        offset += 2
        pixel += 8
        
        for _ in stride(from: 2, to: width1-2, by: 2) {
            
            out[pixel+1] = horizontal(data, offset)
            out[pixel+2] = native(data, offset)
            out[pixel+3] = vertical(data, offset)
            
            out[pixel+5] = native(data, offset+1)
            out[pixel+6] = plus(data, offset+1)
            out[pixel+7] = cross(data, offset+1)
            
            out[pixel+width4p1] = tail_cross(data, offset+width1)
            out[pixel+width4p2] = tail_plus(data, offset+width1)
            out[pixel+width4p3] = native(data, offset+width1)
            
            out[pixel+width4p5] = tail_vertical(data, offset+width1p1)
            out[pixel+width4p6] = native(data, offset+width1p1)
            out[pixel+width4p7] = horizontal(data, offset+width1p1)
            
            offset += 2
            pixel += 8
        }
        
        out[pixel+1] = horizontal(data, offset)
        out[pixel+2] = native(data, offset)
        out[pixel+3] = vertical(data, offset)
        
        out[pixel+5] = native(data, offset+1)
        out[pixel+6] = end_plus(data, offset+1)
        out[pixel+7] = end_cross(data, offset+1)
        
        out[pixel+width4p1] = tail_end_cross(data, offset+width1)
        out[pixel+width4p2] = tail_end_plus(data, offset+width1)
        out[pixel+width4p3] = native(data, offset+width1)
        
        out[pixel+width4p5] = tail_vertical(data, offset+width1p1)
        out[pixel+width4p6] = native(data, offset+width1p1)
        out[pixel+width4p7] = end_horizontal(data, offset+width1p1)
    }
    
}

