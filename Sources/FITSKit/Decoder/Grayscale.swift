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
import Foundation
import FITS

public struct Grayscale : ImageDecoder {
    public typealias Out = Float
    public typealias Pixel = Mono
    public typealias Paramter = Void

    private let width : Int
    private let height : Int
    private let bscale : Float
    private let bzero : Float
    private let range : Float
    
    public init(_ parameter: Void, width: Int, height: Int, bscale: Float, bzero: Float, range: Float) {
        self.width = width
        self.height = height
        self.bscale = bscale
        self.bzero = bzero
        self.range = range
    }
    
    public func decode<In: FITSByte>(_ dataUnit: UnsafeBufferPointer<In>, _ out: UnsafeMutableBufferPointer<Float>) {
        
        for offset in 0..<dataUnit.count {
            
            out[offset] = dataUnit[offset].bigEndian.normalize(bzero, bscale, .min, .max)
        }
        
    }
    
}
