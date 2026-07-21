import XCTest
@testable import MLXServerManager

final class SystemHardwareInfoProviderTests: XCTestCase {
    func testParseSystemProfilerHardwareInfoCapturesHardwareAndGPUCores() {
        let output = """
        Hardware:

            Hardware Overview:

              Model Name: Mac mini
              Model Identifier: Mac16,11
              Chip: Apple M4 Pro
              Total Number of Cores: 14 (10 performance and 4 efficiency)
              Memory: 64 GB

        Graphics/Displays:

            Apple M4 Pro:

              Chipset Model: Apple M4 Pro
              Total Number of Cores: 20
        """

        let info = SystemHardwareInfoProvider.parseSystemProfilerHardwareInfo(output)

        XCTAssertEqual(info["Model Name"], "Mac mini")
        XCTAssertEqual(info["Model Identifier"], "Mac16,11")
        XCTAssertEqual(info["Chip"], "Apple M4 Pro")
        XCTAssertEqual(info["Total Number of Cores"], "14 (10 performance and 4 efficiency)")
        XCTAssertEqual(info["GPU Cores"], "20")
        XCTAssertEqual(info["Memory"], "64 GB")
    }

    func testParseSystemProfilerHardwareInfoIgnoresUnrelatedSections() {
        let output = """
        Software:
          Model Name: Wrong
          Total Number of Cores: 99

        Hardware:
          Model Name: Mac Studio
          Total Number of Cores: 24

        Graphics/Displays:
          Total Number of Cores: 76
        """

        let info = SystemHardwareInfoProvider.parseSystemProfilerHardwareInfo(output)

        XCTAssertEqual(info["Model Name"], "Mac Studio")
        XCTAssertEqual(info["Total Number of Cores"], "24")
        XCTAssertEqual(info["GPU Cores"], "76")
    }
}
