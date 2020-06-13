
import XCTest
@testable import FITS
@testable import FITSKit

import Foundation
import CoreFoundation
import Accelerate

@available(iOS 13.0, *)
@available(OSX 10.15, *)
final class FITSKitTests: XCTestCase {
    
    static var allTests = [
        ("testLargeCoreImage", testLargeCoreImage ),
        ("testLargeAccelerate", testLargeAccelerate )
    ]
    
    func MONO_FORMAT(_ bitpix : BITPIX) -> vImage_CGImageFormat {
        return vImage_CGImageFormat(bitsPerComponent: bitpix.bits, bitsPerPixel: 1, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue))!
    }
    func RGB_FORMAT(_ bitpix : BITPIX) -> vImage_CGImageFormat {
        return vImage_CGImageFormat(bitsPerComponent: bitpix.bits, bitsPerPixel: 3, colorSpace: CGColorSpaceCreateDeviceRGB() , bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue))!
    }
    
    func testLargeCoreImage() throws {
        
        let bigSample = Sample().rgb(FITSByte_F.self, blockSize: 1000)
        
        measure {
            print("Render Image : CORE IMAGE")
            bigSample.prime.cgimage(onError: { print($0) }) { image in
                XCTAssertEqual(image.width, 3000)
                XCTAssertEqual(image.width, 3000)
            }
            print("Done")
        }
    }
    
    func testLargeAccelerate() throws {
        
        let bigSample = Sample().rgb(FITSByte_F.self, blockSize: 1000)
        
        measure {
            print("Render Image : Accelerate")
            bigSample.prime.v_cgimage(onError: { print($0) }) { image in
                XCTAssertEqual(image.width, 3000)
                XCTAssertEqual(image.width, 3000)
            }
            print("Done")
        }
    }
    
}
