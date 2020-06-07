//
//  File.swift
//  
//
//  Created by May on 07.06.20.
//
import FITS
import Accelerate

extension AnyImageHDU {
    
    convenience init(cgImage: CGImage){
        
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
        var tmp = try! vImage_Buffer(width: Int(buffer.width), height: Int(buffer.height), bitsPerPixel: format.bitsPerComponent * format.bitsPerPixel)
        
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
        
        self.set(width: Int(buffer.width), height: Int(buffer.height), layers: 3, dataLayout: .UINT8, data: data)
    }
    
}
