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


@available(iOS 13.0, *)
@available(OSX 10.15, *)
extension AnyHDU {
    
    func data(naxis : Naxis, dimension: Int) -> Data {
        
        guard let bitpix = self.bitpix , let dataUnit = self.dataUnit else {
            return Data()
        }
        
        var volume = 1
        for axis in 1..<naxis {
            let size = self.naxis(axis) ?? 0
            volume = volume * size
        }
        volume = volume * bitpix.size
        
        let offset = volume * dimension
        
        let layerData : Data = dataUnit.withUnsafeBytes{ ptr -> Data in
            switch bitpix {
            case .UINT8:
                return Data.init(bytes: ptr.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: offset), count: offset)
            case .INT16:
                return Data.init(bytes: ptr.baseAddress!.assumingMemoryBound(to: Int16.self).advanced(by: offset), count: offset)
            case .INT32:
                return Data.init(bytes: ptr.baseAddress!.assumingMemoryBound(to: Int32.self).advanced(by: offset), count: offset)
            case .INT64:
                return Data.init(bytes: ptr.baseAddress!.assumingMemoryBound(to: Int64.self).advanced(by: offset), count: offset)
            case .FLOAT32:
                return Data.init(bytes: ptr.baseAddress!.assumingMemoryBound(to: Float.self).advanced(by: offset), count: offset)
            case .FLOAT64:
                return Data.init(bytes: ptr.baseAddress!.assumingMemoryBound(to: Double.self).advanced(by: offset), count: offset)
            }
        }
        
        return layerData
    }
    
}


@available(iOS 13.0, *)
@available(OSX 10.15, *)
extension AnyHDU {
    
    public func mono(width: Naxis, height: Naxis, vector: Naxis, dimension: Int) -> CGImage? {
        
        guard
            let bitpix = self.bitpix,
            let width = self.naxis(width), width > 0,
            let height = self.naxis(height), height > 0,
            let dimensions = self.naxis(vector), dimensions >= dimension
            else {
                print("No mono image coordinates...")
                return nil
        }
        
        guard var unit = self.dataUnit  else {
            print("No image without data...")
            return nil
        }
        
        #if DEBUG
        print("-FITS-MONO----------------------")
        print("width: \(width)")
        print("height: \(height)")
        print("dimension: \(dimension)")
        print("bitpix: \(bitpix.rawValue)")
        print("--------------------------------")
        #endif
        
        switch bitpix {
        case .UINT8:
            return self.mono(dataUnit: &unit, layer: dimension, width: width, height: height, bits: bitpix.bits, type: UInt8.self)
        case .INT16:
            return self.mono(dataUnit: &unit, layer: dimension, width: width, height: height, bits: bitpix.bits, type: Int16.self)
        default:
            return nil
        }
    }
    
    private func mono<I : Numeric>(dataUnit: inout Data, layer: Int, width: Int, height: Int, bits: Int, type: I.Type) -> CGImage? {
        
        let monoChannel = layeBuffer(data: &dataUnit, layer: layer, width: width, height: height, type: type)
        
        
        var info = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        if type is UInt8.Type {
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue))
        }
        if type is Int16.Type {
            
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.order16Little.rawValue))
            info.insert(CGBitmapInfo(rawValue: CGImagePixelFormatInfo.RGB555.rawValue))
        }
        
        let format = vImage_CGImageFormat(bitsPerComponent: bits, bitsPerPixel: bits, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: info)!
        
        return try? monoChannel.createCGImage(format: format)
    }
    
    public func rgb(width: Naxis, height: Naxis, vector: Naxis, dimension red: Int, dimension  green: Int, dimension blue: Int) -> CGImage? {
        

        guard
            let bitpix = self.bitpix,
            let width = self.naxis(width), width > 0,
            let height = self.naxis(height), height > 0,
            let dimensions = self.naxis(vector)
            else {
                print("No RGB image without coordinates...")
                return nil
        }
        
        guard var unit = self.dataUnit  else {
            print("No image without data...")
            return nil
        }
        
        
        #if DEBUG
        print("-FITS-RGB------------------------")
        print("width: \(width)")
        print("height: \(height)")
        print("channels: \(dimensions)")
        print("bitpix: \(bitpix.rawValue)")
        print("--------------------------------")
        #endif
        
        switch bitpix {
        case .UINT8:
            return self.rgb(dataUnit: &unit, width: width, height: height, bits: bitpix.bits, type: UInt8.self)
        case .INT16:
            return self.rgb(dataUnit: &unit, width: width, height: height, bits: bitpix.bits, type: Int16.self)
        default:
            return nil
        }
        
    }
    
    private func rgb<I : Numeric>(dataUnit: inout Data, width: Int, height: Int, bits: Int, type: I.Type) -> CGImage {
        
        var redBuffer = layeBuffer(data: &dataUnit, layer: 0, width: width, height: height, type: type)
        var greenBuffer = layeBuffer(data: &dataUnit, layer: 1, width: width, height: height, type: type)
        var blueBuffer = layeBuffer(data: &dataUnit, layer: 2, width: width, height: height, type: type)
        
        var outputBuffer = try! vImage_Buffer(width: width, height: width, bitsPerPixel: UInt32(bits * 3))
        
        defer {
            outputBuffer.free()
        }
        
        var info = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        if type is UInt8.Type {
            vImageConvert_Planar8toRGB888(&redBuffer, &greenBuffer, &blueBuffer, &outputBuffer, vImage_Flags(kvImageNoFlags))
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue))
        }
        if type is Int16.Type {
            vImageConvert_Planar16UtoRGB16U(&redBuffer, &greenBuffer, &blueBuffer, &outputBuffer, vImage_Flags(kvImageNoFlags))
            //vImageConvert_Planar16Q12toRGB16F(&redBuffer, &greenBuffer, &blueBuffer, &outputBuffer, vImage_Flags(kvImageNoFlags))
            
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.order16Little.rawValue))
            info.insert(CGBitmapInfo(rawValue: CGImagePixelFormatInfo.RGB555.rawValue))
        }
        
        let format = vImage_CGImageFormat(bitsPerComponent: bits, bitsPerPixel: bits * 3, colorSpace: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
        
        return try! outputBuffer.createCGImage(format: format)
    }
}

@available(iOS 13.0, *)
@available(OSX 10.15, *)
extension AnyHDU {
    
    public func layeBuffer<I : Numeric>(data: inout Data, layer: Int, width: Int, height: Int, type: I.Type) -> vImage_Buffer {
        
        let rowBytes = width * MemoryLayout<I>.size
        let layerSize = width * height * MemoryLayout<I>.size
        
        print("--- Layer \(layer) ----------------")
        print("Dim.: \(width)x\(height)")
        print("Size: \(layerSize)")
        print("BpR : \(rowBytes)")
        print("----------------------------")
        
        let buffer : vImage_Buffer = data.withUnsafeMutableBytes { ptr in
            vImage_Buffer(data: ptr.baseAddress?.bindMemory(to: type, capacity: layerSize).advanced(by: width * height * layer), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
        }
        
        return buffer
    }
    
    public func mono(dataUnit: inout Data, layer: Int, width: Int, height: Int, bzero: Float, bscale: Float, bitpix: BITPIX) throws -> CGImage? {
        
        switch bitpix {
        case .UINT8:
            return self.mono8(&dataUnit, layer: layer, width: width, height: height, bitpix: bitpix)
        case .INT16:
            return self.mono16(&dataUnit, layer: layer, width: width, height: height, bzero: bzero, bscale: bscale)
        case .FLOAT32:
            return self.monoF(&dataUnit, layer: layer, width: width, height: height, bitpix: bitpix)
        default:
            throw AcceleratedFail.unsupportedFormat("BITPIX \(bitpix) not yet supported")
        }
    }
    
    func mono8(_ data: inout Data, layer: Int, width: Int, height: Int, bitpix: BITPIX) -> CGImage? {
        
        print("MONO 8")
        
        var monoChannel = layeBuffer(data: &data, layer: layer, width: width, height: height, type: UInt8.self)
        
        let info = self.bitpix(bitpix)
        return self.mono(&monoChannel, width: width, height: height, bits: 8, info: info)
    }
    
    func mono16(_ data: inout Data, layer: Int, width: Int, height: Int, bzero: Float, bscale: Float) -> CGImage? {
        
        print("MONO 16")
        
        var monoChannel = layeBuffer(data: &data, layer: layer, width: width, height: height, type: Int16.self)
        
        var monoFBuffer = try! vImage_Buffer(width: width, height: height, bitsPerPixel: UInt32(width * MemoryLayout<Float>.size))
        vImageConvert_16SToF(&monoChannel, &monoFBuffer, bzero, bscale, vImage_Flags(kvImageNoFlags))
        
        let info = self.bitpix(.FLOAT32)
        return self.mono(&monoFBuffer, width: width, height: height, bits: 32, info: info)
    }
    
    func monoF(_ data: inout Data, layer: Int, width: Int, height: Int, bitpix: BITPIX) -> CGImage? {
        
        print("MONO F")
        
        var monoChannel = layeBuffer(data: &data, layer: layer, width: width, height: height, type: Float.self)
        
        let info = self.bitpix(bitpix)
        return self.mono(&monoChannel, width: width, height: height, bits: 32, info: info)
    }
    
    public func mono(_ monoChannel: inout vImage_Buffer, width: Int, height: Int, bits: Int, info: CGBitmapInfo) -> CGImage {
        
        let format = vImage_CGImageFormat(bitsPerComponent: bits, bitsPerPixel: bits, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: info)!
        return try! monoChannel.createCGImage(format: format)
    }
    
    
    public func rgb(dataUnit: inout Data, width: Int, height: Int, bzero: Float, bscale: Float, bitpix: BITPIX) throws -> CGImage? {
        
        switch bitpix {
        case .UINT8:
            return self.rgb8(&dataUnit, width: width, height: height)
        case .INT16:
            return self.rgb16(&dataUnit, width: width, height: height, bzero: bzero, bscale: bscale)
        case .FLOAT32:
            return self.rgbF(&dataUnit, width: width, height: height)
        default:
            throw AcceleratedFail.unsupportedFormat("BITPIX \(bitpix) not yet supported")
        }
    }
    
    func rgb8(_ data: inout Data, width: Int, height: Int) -> CGImage? {
        let bits = 8
        
        print("RGB 8")
        
        var redBuffer = layeBuffer(data: &data, layer: 0, width: width, height: height, type: UInt8.self)
        var greenBuffer = layeBuffer(data: &data, layer: 1, width: width, height: height, type: UInt8.self)
        var blueBuffer = layeBuffer(data: &data, layer: 2, width: width, height: height, type: UInt8.self)
        
        var outputBuffer = try! vImage_Buffer(width: width, height: height, bitsPerPixel: UInt32(bits * 3))
        
        vImageConvert_Planar8toRGB888(&redBuffer, &greenBuffer, &blueBuffer, &outputBuffer, vImage_Flags(kvImageNoFlags))
        
        let info = self.bitpix(.UINT8)
        return rgb(&outputBuffer, width: width, height: height, bits: bits, info: info)
    }
    
    func rgb16(_ data: inout Data, width: Int, height: Int, bzero: Float, bscale: Float) -> CGImage? {
        
        print("RGB 16")
        
        var redBuffer = layeBuffer(data: &data, layer: 0, width: width, height: height, type: Int16.self)
        var greenBuffer = layeBuffer(data: &data, layer: 1, width: width, height: height, type: Int16.self)
        var blueBuffer = layeBuffer(data: &data, layer: 2, width: width, height: height, type: Int16.self)
        
        print("Converting... ")
        
        var redFBuffer = try! vImage_Buffer(width: width, height: height, bitsPerPixel: UInt32(width * MemoryLayout<Float>.size))
        vImageConvert_16SToF(&redBuffer, &redFBuffer, bzero, bscale, vImage_Flags(kvImageNoFlags))
        var greenFBuffer = try! vImage_Buffer(width: width, height: height, bitsPerPixel: UInt32(width * MemoryLayout<Float>.size))
        vImageConvert_16SToF(&greenBuffer, &greenFBuffer, bzero, bscale, vImage_Flags(kvImageNoFlags))
        var blueFBuffer = try! vImage_Buffer(width: width, height: height, bitsPerPixel: UInt32(width * MemoryLayout<Float>.size))
        vImageConvert_16SToF(&blueBuffer, &blueFBuffer, bzero, bscale, vImage_Flags(kvImageNoFlags))
        
        defer {
            redFBuffer.free()
            greenFBuffer.free()
            blueFBuffer.free()
        }
        
        var outputBuffer = try! vImage_Buffer(width: width, height: width, bitsPerPixel: UInt32(32 * 3))
        
        vImageConvert_PlanarFtoRGBFFF(&redFBuffer, &greenFBuffer, &blueFBuffer, &outputBuffer, vImage_Flags(kvImageNoFlags))
        
        let info = self.bitpix(.FLOAT32)
        return rgb(&outputBuffer, width: width, height: height, bits: 32, info: info)
    }
    
    func rgbF(_ data: inout Data, width: Int, height: Int) -> CGImage? {
        let bits = 32
        
        print("RGB F")
        
        var redBuffer = layeBuffer(data: &data, layer: 0, width: width, height: height, type: Float.self)
        var greenBuffer = layeBuffer(data: &data, layer: 1, width: width, height: height, type: Float.self)
        var blueBuffer = layeBuffer(data: &data, layer: 2, width: width, height: height, type: Float.self)
        
        var outputBuffer = try! vImage_Buffer(width: width, height: width, bitsPerPixel: UInt32(bits * 3))
        
        vImageConvert_PlanarFtoRGBFFF(&redBuffer, &greenBuffer, &blueBuffer, &outputBuffer, vImage_Flags(kvImageNoFlags))
        
        let info = self.bitpix(.FLOAT32)
        return rgb(&outputBuffer, width: width, height: height, bits: bits, info: info)
    }
    
    public func rgb(_ rgbBuffer: inout vImage_Buffer, width: Int, height: Int, bits: Int, info: CGBitmapInfo) -> CGImage {
        
        print("RGB for \(info)")
        
        defer {
            rgbBuffer.free()
        }
        
        let format = vImage_CGImageFormat(bitsPerComponent: bits, bitsPerPixel: bits * 3, colorSpace: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)!
        return try! rgbBuffer.createCGImage(format: format)
    }
    
    func bitpix(_ bitpix: BITPIX) -> CGBitmapInfo {
        
        var info = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        switch bitpix {
        case .UINT8:
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue))
        case .INT16:
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.order16Little.rawValue))
        case .INT32:
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.order32Little.rawValue))
        case .INT64:
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue))
        case .FLOAT32:
            info.insert(CGBitmapInfo(rawValue: CGImageByteOrderInfo.order32Little.rawValue))
            info.insert(.floatComponents)
        case .FLOAT64:
            info.insert(.floatComponents)
        }
        return info
        
    }
}


@available(iOS 13.0, *)
@available(OSX 10.15, *)
extension ImageHDU {
    
    public func image(onFail: (Error) -> Void) -> CGImage? {
        
        guard
            var data = self.dataUnit,
            let width = self.naxis(1),
            let height = self.naxis(2),
            let bitpix = self.bitpix,
        
            let bzero : Float = self.lookup(HDUKeyword.BZERO),
            let bscale : Float = self.lookup(HDUKeyword.BSCALE)
            
        else {
            onFail(AcceleratedFail.invalidMetadata("Cannot verify image dimensions"))
            return nil
        }
        
        do {
            return try self.mono(dataUnit: &data, layer: 0, width: width, height: height, bzero: bzero, bscale: bscale, bitpix: bitpix)
        } catch {
            onFail(error)
        }
        return nil
    }
    
}

@available(iOS 13.0, *)
@available(OSX 10.15, *)
extension PrimaryHDU {
    
    public func image(onFail: (Error) -> Void) -> CGImage? {
        
        guard var data = self.dataUnit else {
            onFail(AcceleratedFail.missingData("Unable to read anything without any data"))
            return nil
        }
        
        let layers = self.naxis(3) ?? 1
        
        guard
            let width = self.naxis(1), width > 0,
            let height = self.naxis(2), height > 0,
            let bitpix = self.bitpix,
        
            data.count == width * height * layers * bitpix.size
            
            else {
                onFail(AcceleratedFail.invalidMetadata("Cannot verify image dimensions"))
                return nil
        }
        
        let bzero : Float = self.lookup(HDUKeyword.BZERO) ?? 0.0
        let bscale : Float = self.lookup(HDUKeyword.BSCALE) ?? 1.0
        
        do {
            if layers == 1 {
                return try self.mono(dataUnit: &data, layer: 0, width: width, height: height, bzero: bzero, bscale: bscale, bitpix: bitpix)
            } else if layers == 3 {
                return try self.rgb(dataUnit: &data, width: width, height: height, bzero: bzero, bscale: bscale, bitpix: bitpix)
            } else {
                onFail(AcceleratedFail.unsupportedGeometry("\(layers) should either be 3 for RGB or 1 for mono"))
            }
        } catch {
            onFail(error)
        }
        return nil
    }
    
}
