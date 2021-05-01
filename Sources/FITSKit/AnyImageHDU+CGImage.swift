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
import Accelerate

extension AnyImageHDU {
    
    convenience public init(cgImage: CGImage){
        
        self.init()
        
        var buffer = try! vImage_Buffer(cgImage: cgImage)
        
        defer {
            buffer.free()
        }
        
        let format = vImage_CGImageFormat(cgImage: cgImage)!
        
        print(format)
        
        var alpha =  try! vImage_Buffer(width: Int(buffer.width), height: Int(buffer.height), bitsPerPixel: format.bitsPerPixel)
        var red = try! vImage_Buffer(width: Int(buffer.width), height: Int(buffer.height), bitsPerPixel: format.bitsPerPixel)
        var green = try! vImage_Buffer(width: Int(buffer.width), height: Int(buffer.height), bitsPerPixel: format.bitsPerPixel)
        var blue = try! vImage_Buffer(width: Int(buffer.width), height: Int(buffer.height), bitsPerPixel: format.bitsPerPixel)
        let tmp = try! vImage_Buffer(width: Int(buffer.width), height: Int(buffer.height), bitsPerPixel: format.bitsPerComponent * format.bitsPerPixel)
        
        defer {
            alpha.free()
            red.free()
            green.free()
            blue.free()
            tmp.free()
        }
        
        //vImageConvert_RGBA8888toRGB888(&buffer, &tmp, vImage_Flags(kvImageNoFlags))
        //vImageConvert_RGB888toPlanar8(&tmp, &red, &green, &blue, vImage_Flags(kvImageNoFlags))
        
        vImageConvert_ARGB8888toPlanar8(&buffer, &alpha, &red, &green, &blue, vImage_Flags(kvImageNoFlags))
        
        let redData = Data(bytes: red.data, count: Int(buffer.width * buffer.height))
        let greenData = Data(bytes: green.data, count: Int(buffer.width * buffer.height))
        let blueData = Data(bytes: blue.data, count: Int(buffer.width * buffer.height))
        //let alphaData = Data(bytes: alpha.data, count: Int(buffer.width * buffer.height))
        
        var data = Data()
        data.append(redData)
        data.append(greenData)
        data.append(blueData)
        //data.append(alphaData)
        
        self.set(dimensions: Int(buffer.width), Int(buffer.height), dataLayout: .UINT8, data: data)
    }
    
    
    
}
