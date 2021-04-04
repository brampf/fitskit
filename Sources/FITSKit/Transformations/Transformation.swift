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

/**
 A image transformation
 */
public protocol Transformation {
    associatedtype Parameter
    
    /// Standard initiliazer allows for parametrization via `Parameter`
    init(parameter: Parameter)
    
    /** performs the transformation
     
    - Parameters:
        - data: the data to transofrm
        - width: number of pixels per row
        - height: number of pixles per colum
        - zero: normalisation factor for each value
        - scale: normalisation factor for each value
     */
    func perform<Byte: FITSByte>(_ data: UnsafeBufferPointer<Byte>,
                                 _ width: Int,
                                 _ height: Int,
                                 _ zero: Float,
                                 _ scale : Float,
                                 _ R: inout [FITSByte_F],
                                 _ G: inout [FITSByte_F],
                                 _ B: inout [FITSByte_F])
    
    /**
     Computes the target dimensions for the output imgage
     */
    func targetDimensions(width: Int, height: Int) -> (width: Int, height: Int)
}
