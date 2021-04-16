import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(FITSKitTests.allTests),
        testCase(DecoderTests.allTests),
    ]
}
#endif
