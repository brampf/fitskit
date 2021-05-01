import XCTest

import FITSKitTests

var tests = [XCTestCaseEntry]()
tests += FITSKitTests.allTests()
tests += DecoderTests.allTests()
XCTMain(tests)
