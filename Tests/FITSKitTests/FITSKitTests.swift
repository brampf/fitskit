
import XCTest
import FITS
@testable import FITSKit

import Foundation
import CoreFoundation
import Accelerate

@available(iOS 13.0, *)
@available(OSX 10.15, *)
final class FITSKitTests: XCTestCase {
    
    static var allTests = [
        ("testRead", testVector),
    ]
    
    func MONO_FORMAT(_ bitpix : BITPIX) -> vImage_CGImageFormat {
        return vImage_CGImageFormat(bitsPerComponent: bitpix.bits, bitsPerPixel: 1, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue))!
    }
    func RGB_FORMAT(_ bitpix : BITPIX) -> vImage_CGImageFormat {
        return vImage_CGImageFormat(bitsPerComponent: bitpix.bits, bitsPerPixel: 3, colorSpace: CGColorSpaceCreateDeviceRGB() , bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue))!
    }
    func testVector() {
        
        guard var data = Data(base64Encoded: Testbild), let FITS = try? FitsFile.read(from: &data) else {
            XCTFail()
            return
        }
        
        print(FITS)
        
        XCTAssertEqual(FITS.prime.naxis, 3)
        XCTAssertEqual(FITS.prime.naxis(1), 120)
        XCTAssertEqual(FITS.prime.naxis(2), 120)
        XCTAssertEqual(FITS.prime.naxis(3), 3)
        XCTAssertEqual(FITS.prime.bitpix, BITPIX.UINT8)
        
        //print(self.plot(FITS.prime.dataUnit!, width: 120))
        
        //let red = FITS.prime.vector(width: 1, height: 2, vector: 3, dimension: 1)
        
        guard
            var unit = FITS.prime.dataUnit,
            let bitpix = FITS.prime.bitpix,
            let width = FITS.prime.naxis(1),
            let height = FITS.prime.naxis(2)
            
            else {
            return XCTFail()
        }
     
        let bytes = width*height
        
        let slice : [UInt8] = unit.subdata(in: 0..<bytes).reversed()
        var reverse : [UInt8] = slice.withUnsafeBytes { ptr in
            ptr.bindMemory(to: UInt8.self).map{UInt8(bigEndian: $0)}
        }
        
        let buffer : vImage_Buffer = reverse.withUnsafeMutableBytes { ptr in
                return vImage_Buffer(data: ptr.baseAddress?.advanced(by: 0), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
        }
        
        var red : vImage_Buffer = unit.withUnsafeMutableBytes { ptr -> vImage_Buffer in
            return vImage_Buffer(data: ptr.baseAddress?.advanced(by: 0), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
        }

        
        var green : vImage_Buffer = unit.withUnsafeMutableBytes { ptr -> vImage_Buffer in
            return vImage_Buffer(data: ptr.baseAddress?.advanced(by: bytes), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
        }
        
        var blue : vImage_Buffer = unit.withUnsafeMutableBytes { ptr -> vImage_Buffer in
            return vImage_Buffer(data: ptr.baseAddress?.advanced(by: bytes*2), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
        }
        
        
        let format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 1, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue))!
        
        let newImage = try? buffer.createCGImage(format: format)
        store(newImage, "buffer")
        
        let redImage = try? red.createCGImage(format: format)
        store(redImage, "red")
        let greenImage = try? green.createCGImage(format: format)
        store(greenImage, "green")
        let blueImage = try? blue.createCGImage(format: format)
        store(blueImage, "blue")
 
        guard var destinationBuffer = try? vImage_Buffer(width: width,
                                                         height: height,
                                                         bitsPerPixel: UInt32(bitpix.rawValue * 3))
            else {
                print("No RGB image without buffer...")
                return XCTFail()
        }
        
        defer {
            destinationBuffer.free()
        }
        
        switch bitpix{
        case .UINT8 :
            vImageConvert_Planar8toRGB888(&red, &green, &blue, &destinationBuffer, vImage_Flags(kvImageNoFlags))
        case .INT16 :
            vImageConvert_Planar16UtoRGB16U(&red, &green, &blue, &destinationBuffer, vImage_Flags(kvImageNoFlags))
        default :
            fatalError("Not yet implemented")
        }
        
        
        
        let image = try? destinationBuffer.createCGImage(format: RGB_FORMAT(.UINT8))
        store(image, "RGB")
    }
    
    func clone<T>(data : Data, offset: Int, lenght: Int, type: T.Type) -> Data {

        let new = data.withUnsafeBytes { ptr -> Data in
            return Data(buffer: ptr.bindMemory(to: type))
        }
        return new
    }
    
    func buffer(data: Data, bitpix: BITPIX, offset: Int, length: Int) -> vImage_Buffer {
        
        //var clone = self.clone(data: data, offset: offset, lenght: length, type: UInt8.self)
        var clone = data.subdata(in: offset..<offset+length)
        
        return clone.withUnsafeMutableBytes { ptr in
            vImage_Buffer(data: ptr.baseAddress, height: 120, width: 120, rowBytes: 120)
        }
    }
    
    func plot(_ data : Data, width: Int) -> String{
        
        var index = 0
        return data.reduce(into: "") { output, byte in
            index += 1
            output.append(String(format: "%3d ", byte))
            if index % width == 0 { output.append("\n") }
        }
    }

    func store(_ cgImage: CGImage?, _ name: String){
        
        if let image = cgImage {
            let desktop = try? FileManager.default.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let file = desktop?.appendingPathComponent(name).appendingPathExtension("png")
            #if !os(macOS)
            try? UIImage(cgImage: image).pngData()?.write(to: file!)
            #endif
        }
        
    }
    
    
    func testWrite() {
        
        let data = Data(base64Encoded: PATTERN)!
        
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        
        let hdu = PrimaryHDU(cgImage: image)
        hdu.set(HDUKeyword.COMMENT, value: nil, comment: "FITSCore & FITSKit united!")
        
        let fitsFile = FitsFile(prime: hdu)
        
        for header in hdu.headerUnit {
            print(header.description)
        }
        
    
        let desktop = try! FileManager.default.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let file = desktop.appendingPathComponent("NEW_FITS").appendingPathExtension("fits")
        
        
        fitsFile.write(to: file, onError: { error in
            print(error)
        }) {
            print("DONE")
        }
    }
    
    func testImage() {
        
        let data = Data(base64Encoded: PATTERN)!
        
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        
        let hdu = PrimaryHDU(cgImage: image)
        hdu.set(HDUKeyword.COMMENT, value: nil, comment: "FITSCore & FITSKit united!")
        
        let fitsFile = FitsFile(prime: hdu)
        
        for header in hdu.headerUnit {
            print(header.description)
        }
        
        // crates core image reference
        let cgimage = fitsFile.prime.image { error in
            // print error messages
            print(error)
        }
    }
    
}
