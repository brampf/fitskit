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

import Accelerate


public protocol PixelFormat {
    
    static var channels : Int { get }
    static var alpha: CGImageAlphaInfo {get}
    static var colorSpace : CGColorSpace {get}
    
}

public struct Mono : PixelFormat {
    public static let channels: Int = 1
    public static let alpha: CGImageAlphaInfo = .none
    public static let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceGray()
}

public struct RGB : PixelFormat {
    public static let channels: Int = 3
    public static let alpha: CGImageAlphaInfo = .none
    public static let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
}

public struct ARGB : PixelFormat {
    public static let channels: Int = 4
    public static let alpha: CGImageAlphaInfo = .noneSkipFirst
    public static let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
}

public struct RGBA : PixelFormat {
    public static let channels: Int = 4
    public static let alpha: CGImageAlphaInfo = .noneSkipLast
    public static let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
}
