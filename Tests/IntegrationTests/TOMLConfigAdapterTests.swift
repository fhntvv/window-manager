import Testing
import Foundation
@testable import WindowManagerAdapters
@testable import WindowManagerDomain

@Suite("TOMLConfigAdapter")
struct TOMLConfigAdapterTests {

    private func repoConfigPath() -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("config.toml")
            .path
    }

    @Test func loadValidConfig() throws {
        let adapter = TOMLConfigAdapter(configPath: repoConfigPath())
        let config = try adapter.loadConfig()

        #expect(!config.bindings.isEmpty)
        #expect(config.bindings.count == 13)

        let leftHalf = config.bindings.first { $0.action == .leftHalf }
        #expect(leftHalf != nil)
        #expect(leftHalf?.modifiers == [.control, .option])
        #expect(leftHalf?.keyCode == 0x7B)
    }

    @Test func missingFileReturnsDefaults() throws {
        let adapter = TOMLConfigAdapter(configPath: "/nonexistent/path/config.toml")
        let config = try adapter.loadConfig()
        #expect(config.bindings.count == 13)
    }

    @Test func configGeneralSettings() throws {
        let adapter = TOMLConfigAdapter(configPath: repoConfigPath())
        let config = try adapter.loadConfig()

        #expect(config.general.padding == 0)
        #expect(config.general.animationDuration == 0)
    }

    @Test func nextDisplayBinding() throws {
        let adapter = TOMLConfigAdapter(configPath: repoConfigPath())
        let config = try adapter.loadConfig()

        let nextDisplay = config.bindings.first { $0.action == .nextDisplay }
        #expect(nextDisplay != nil)
        #expect(nextDisplay?.modifiers == [.control, .option, .command])
    }
}
