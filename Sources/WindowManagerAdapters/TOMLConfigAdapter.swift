import Foundation
import TOMLKit
import WindowManagerDomain

public final class TOMLConfigAdapter: ConfigPort, Sendable {
    private let configPath: String

    public init(configPath: String? = nil) {
        self.configPath = configPath
            ?? NSString("~/.config/windowmanager/config.toml").expandingTildeInPath
    }

    public func loadConfig() throws -> Config {
        guard FileManager.default.fileExists(atPath: configPath) else {
            Log.config.info("Config not found at \(self.configPath) — using defaults")
            return Self.defaultConfig
        }
        let contents = try String(contentsOfFile: configPath, encoding: .utf8)
        let raw = try TOMLDecoder().decode(RawConfig.self, from: contents)
        let config = convertConfig(raw)
        Log.config.info("Loaded \(config.bindings.count) bindings from \(self.configPath)")
        return config
    }

    public static var defaultConfig: Config { Self.makeDefaultConfig() }

    public static func keyName(for keyCode: UInt16) -> String {
        reverseKeyCodeMap[keyCode] ?? String(format: "0x%02X", keyCode)
    }

    public static func formatModifiers(_ modifiers: ModifierSet) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("ctrl") }
        if modifiers.contains(.option) { parts.append("opt") }
        if modifiers.contains(.command) { parts.append("cmd") }
        if modifiers.contains(.shift) { parts.append("shift") }
        return parts.joined(separator: "+")
    }

    private static func makeDefaultConfig() -> Config {
        let bindings = [
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x7B, action: .leftHalf),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x7C, action: .rightHalf),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x7E, action: .topHalf),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x7D, action: .bottomHalf),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x20, action: .topLeft),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x22, action: .topRight),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x26, action: .bottomLeft),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x28, action: .bottomRight),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x24, action: .maximize),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x03, action: .fullscreen),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x08, action: .center),
            HotkeyBinding(modifiers: [.control, .option, .command], keyCode: 0x7C, action: .nextDisplay),
            HotkeyBinding(modifiers: [.control, .option, .command], keyCode: 0x7B, action: .prevDisplay),
        ]
        return Config(bindings: bindings, general: GeneralConfig())
    }

    private func convertConfig(_ raw: RawConfig) -> Config {
        let general = GeneralConfig(
            padding: raw.general?.padding ?? 0,
            animationDuration: raw.general?.animationDuration ?? 0
        )

        let bindings = (raw.bindings ?? []).compactMap { rawBinding -> HotkeyBinding? in
            guard let modifiers = parseModifiers(rawBinding.modifiers),
                  let keyCode = keyNameToCode(rawBinding.key),
                  let action = WindowAction(rawValue: rawBinding.action)
            else {
                Log.config.warning("Skipping invalid binding: modifiers=\(rawBinding.modifiers), key=\(rawBinding.key), action=\(rawBinding.action)")
                return nil
            }
            return HotkeyBinding(modifiers: modifiers, keyCode: keyCode, action: action)
        }

        return Config(bindings: bindings, general: general)
    }

    private func parseModifiers(_ string: String) -> ModifierSet? {
        var result = ModifierSet()
        let parts = string.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else { return nil }

        for part in parts {
            switch part {
            case "ctrl", "control":
                result.insert(.control)
            case "opt", "option", "alt":
                result.insert(.option)
            case "cmd", "command":
                result.insert(.command)
            case "shift":
                result.insert(.shift)
            default:
                return nil
            }
        }

        return result
    }

    private func keyNameToCode(_ name: String) -> UInt16? {
        keyCodeMap[name.lowercased()]
    }
}

private struct RawConfig: Decodable {
    let general: RawGeneral?
    let bindings: [RawBinding]?

    enum CodingKeys: String, CodingKey {
        case general
        case bindings
    }
}

private struct RawGeneral: Decodable {
    let padding: CGFloat?
    let animationDuration: Double?

    enum CodingKeys: String, CodingKey {
        case padding
        case animationDuration = "animation_duration"
    }
}

private struct RawBinding: Decodable {
    let modifiers: String
    let key: String
    let action: String
}

private let canonicalKeyNames: [(UInt16, String)] = [
    (0x00, "a"), (0x01, "s"), (0x02, "d"), (0x03, "f"),
    (0x04, "h"), (0x05, "g"), (0x06, "z"), (0x07, "x"),
    (0x08, "c"), (0x09, "v"), (0x0B, "b"), (0x0C, "q"),
    (0x0D, "w"), (0x0E, "e"), (0x0F, "r"), (0x10, "y"),
    (0x11, "t"), (0x12, "1"), (0x13, "2"), (0x14, "3"),
    (0x15, "4"), (0x16, "6"), (0x17, "5"), (0x19, "9"),
    (0x1A, "7"), (0x1C, "8"), (0x1D, "0"), (0x1F, "o"),
    (0x20, "u"), (0x22, "i"), (0x23, "p"), (0x25, "l"),
    (0x26, "j"), (0x28, "k"), (0x2D, "n"), (0x2E, "m"),

    (0x24, "return"), (0x30, "tab"),
    (0x31, "space"), (0x33, "delete"), (0x35, "escape"),

    (0x7B, "left"), (0x7C, "right"), (0x7D, "down"), (0x7E, "up"),

    (0x7A, "f1"), (0x78, "f2"), (0x63, "f3"), (0x76, "f4"),
    (0x60, "f5"), (0x61, "f6"), (0x62, "f7"), (0x64, "f8"),
    (0x65, "f9"), (0x6D, "f10"), (0x67, "f11"), (0x6F, "f12"),
]

private let keyNameAliases: [(String, String)] = [
    ("enter", "return"),
    ("esc", "escape"),
]

private let reverseKeyCodeMap: [UInt16: String] =
    Dictionary(uniqueKeysWithValues: canonicalKeyNames.map { ($0.0, $0.1) })

private let keyCodeMap: [String: UInt16] = {
    var map = Dictionary(uniqueKeysWithValues: canonicalKeyNames.map { ($0.1, $0.0) })
    for (alias, canonical) in keyNameAliases {
        if let code = map[canonical] {
            map[alias] = code
        }
    }
    return map
}()
