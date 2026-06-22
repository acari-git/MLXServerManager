import XCTest
@testable import MLXServerManager

final class LaunchCommandBuilderTests: XCTestCase {
    func testCommandContainsCoreArguments() {
        let model = ModelConfig(
            modelID: "model-name",
            displayName: "Local",
            family: "Local",
            quantization: "4bit",
            localName: "model-name",
            host: "127.0.0.1",
            serverPort: 8080,
            enableThinking: true,
            notes: ""
        )

        let command = LaunchCommandBuilder.command(
            executablePath: "mlx_lm.server",
            model: model
        )

        XCTAssertTrue(command.contains("'mlx_lm.server'"))
        XCTAssertTrue(command.contains("--model 'model-name'"))
        XCTAssertTrue(command.contains("--host '127.0.0.1'"))
        XCTAssertTrue(command.contains("--port 8080"))
        XCTAssertTrue(command.contains("--enable-thinking"))
    }
}
