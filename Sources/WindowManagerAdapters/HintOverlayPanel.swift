import AppKit
import WindowManagerDomain

@MainActor
public final class HintOverlayPanel {
    private var panel: NSPanel?

    public init() {}

    public func toggle(bindings: [HotkeyBinding]) {
        if let existing = panel, existing.isVisible {
            existing.orderOut(nil)
            return
        }
        showPanel(bindings: bindings)
    }

    private func showPanel(bindings: [HotkeyBinding]) {
        let text = formatBindings(bindings)

        let textField = NSTextField(labelWithString: text)
        textField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textField.textColor = .labelColor
        textField.alignment = .left
        textField.translatesAutoresizingMaskIntoConstraints = false

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12

        effect.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: effect.topAnchor, constant: 16),
            textField.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -16),
            textField.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),
        ])

        let contentSize = textField.intrinsicContentSize
        let panelWidth = contentSize.width + 40
        let panelHeight = contentSize.height + 32

        guard let screenFrame = NSScreen.main?.visibleFrame else { return }
        let panelX = screenFrame.midX - panelWidth / 2
        let panelY = screenFrame.midY - panelHeight / 2
        let panelRect = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)

        let p = NSPanel(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = effect
        p.makeKeyAndOrderFront(nil)

        self.panel = p
    }

    private func formatBindings(_ bindings: [HotkeyBinding]) -> String {
        let lines = bindings
            .filter { $0.action != .showHints }
            .map { binding in
                let mods = TOMLConfigAdapter.formatModifiers(binding.modifiers)
                let key = TOMLConfigAdapter.keyName(for: binding.keyCode)
                let shortcut = "\(mods)+\(key)"
                return (shortcut, binding.action.rawValue)
            }

        let maxShortcutLen = lines.map(\.0.count).max() ?? 0

        return lines.map { shortcut, action in
            let padded = shortcut.padding(toLength: maxShortcutLen, withPad: " ", startingAt: 0)
            return "\(padded)    \(action)"
        }.joined(separator: "\n")
    }
}
