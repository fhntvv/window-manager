import Foundation

public struct TilingEngine: Sendable {

    public init() {}

    public func computeFrame(
        action: WindowAction,
        screen: ScreenInfo,
        currentWindow: WindowInfo,
        padding: CGFloat = 0
    ) -> CGRect {
        let vf = screen.visibleFrame
        let p = padding
        let w = vf.size.width
        let h = vf.size.height
        let ox = vf.origin.x
        let oy = vf.origin.y
        let mx = ox + w / 2
        let my = oy + h / 2

        switch action {
        case .leftHalf:
            return CGRect(
                origin: CGPoint(x: ox + p, y: oy + p),
                size: CGSize(width: w / 2 - 1.5 * p, height: h - 2 * p)
            )

        case .rightHalf:
            return CGRect(
                origin: CGPoint(x: mx + 0.5 * p, y: oy + p),
                size: CGSize(width: w / 2 - 1.5 * p, height: h - 2 * p)
            )

        case .topHalf:
            return CGRect(
                origin: CGPoint(x: ox + p, y: oy + p),
                size: CGSize(width: w - 2 * p, height: h / 2 - 1.5 * p)
            )

        case .bottomHalf:
            return CGRect(
                origin: CGPoint(x: ox + p, y: my + 0.5 * p),
                size: CGSize(width: w - 2 * p, height: h / 2 - 1.5 * p)
            )

        case .topLeft:
            return CGRect(
                origin: CGPoint(x: ox + p, y: oy + p),
                size: CGSize(width: w / 2 - 1.5 * p, height: h / 2 - 1.5 * p)
            )

        case .topRight:
            return CGRect(
                origin: CGPoint(x: mx + 0.5 * p, y: oy + p),
                size: CGSize(width: w / 2 - 1.5 * p, height: h / 2 - 1.5 * p)
            )

        case .bottomLeft:
            return CGRect(
                origin: CGPoint(x: ox + p, y: my + 0.5 * p),
                size: CGSize(width: w / 2 - 1.5 * p, height: h / 2 - 1.5 * p)
            )

        case .bottomRight:
            return CGRect(
                origin: CGPoint(x: mx + 0.5 * p, y: my + 0.5 * p),
                size: CGSize(width: w / 2 - 1.5 * p, height: h / 2 - 1.5 * p)
            )

        case .maximize:
            return CGRect(
                origin: CGPoint(x: ox + p, y: oy + p),
                size: CGSize(width: w - 2 * p, height: h - 2 * p)
            )

        case .center:
            return CGRect(
                origin: CGPoint(x: mx - currentWindow.size.width / 2, y: my - currentWindow.size.height / 2),
                size: currentWindow.size
            )

        case .nextDisplay, .prevDisplay:
            return CGRect(origin: vf.origin, size: vf.size)
        }
    }
}
