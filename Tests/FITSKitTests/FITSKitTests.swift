
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
        ("testRead", test ),
    ]
    
    func MONO_FORMAT(_ bitpix : BITPIX) -> vImage_CGImageFormat {
        return vImage_CGImageFormat(bitsPerComponent: bitpix.bits, bitsPerPixel: 1, colorSpace: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue))!
    }
    func RGB_FORMAT(_ bitpix : BITPIX) -> vImage_CGImageFormat {
        return vImage_CGImageFormat(bitsPerComponent: bitpix.bits, bitsPerPixel: 3, colorSpace: CGColorSpaceCreateDeviceRGB() , bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue))!
    }

    func test() {
        
    }
}
