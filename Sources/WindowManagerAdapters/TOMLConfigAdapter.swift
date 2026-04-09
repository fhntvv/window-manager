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
            fputs("Config not found at \(configPath), using default bindings.\n", stderr)
            return Self.defaultConfig
        }
        let contents = try String(contentsOfFile: configPath, encoding: .utf8)
        let raw = try TOMLDecoder().decode(RawConfig.self, from: contents)
        return convertConfig(raw)
    }

    public static var defaultConfig: Config { Self.makeDefaultConfig() }

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
                fputs("Warning: skipping invalid binding (modifiers=\(rawBinding.modifiers), key=\(rawBinding.key), action=\(rawBinding.action))\n", stderr)
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

private let keyCodeMap: [String: UInt16] = [
    "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03,
    "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
    "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
    "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
    "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
    "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19,
    "7": 0x1A, "8": 0x1C, "0": 0x1D, "o": 0x1F,
    "u": 0x20, "i": 0x22, "p": 0x23, "l": 0x25,
    "j": 0x26, "k": 0x28, "n": 0x2D, "m": 0x2E,

    "return": 0x24, "enter": 0x24, "tab": 0x30,
    "space": 0x31, "delete": 0x33, "escape": 0x35,
    "esc": 0x35,

    "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,

    "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76,
    "f5": 0x60, "f6": 0x61, "f7": 0x62, "f8": 0x64,
    "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F,
]
