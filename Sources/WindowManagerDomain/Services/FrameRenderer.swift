import Foundation

public struct FrameRenderer: Sendable {

    public init() {}

    public func render(
        screens: [ScreenInfo],
        windows: [(label: String, frame: CGRect, screenID: Int)],
        scale: CGFloat = 20
    ) -> String {
        guard !screens.isEmpty else { return "" }

        let allFrames = screens.map(\.frame)
        let minX = allFrames.map(\.origin.x).min()!
        let minY = allFrames.map(\.origin.y).min()!
        let maxX = allFrames.map { $0.origin.x + $0.size.width }.max()!
        let maxY = allFrames.map { $0.origin.y + $0.size.height }.max()!

        let cols = Int(ceil((maxX - minX) / scale)) + 1
        let rows = Int(ceil((maxY - minY) / scale)) + 1

        var grid = Array(repeating: Array(repeating: Character(" "), count: cols), count: rows)

        for screen in screens {
            drawRect(
                grid: &grid,
                rect: screen.frame,
                offsetX: minX, offsetY: minY,
                scale: scale,
                border: "#",
                fill: "."
            )
        }

        for window in windows {
            drawRect(
                grid: &grid,
                rect: window.frame,
                offsetX: minX, offsetY: minY,
                scale: scale,
                border: "+",
                fill: nil
            )
            placeLabel(grid: &grid, rect: window.frame, label: window.label, offsetX: minX, offsetY: minY, scale: scale)
        }

        return grid.map { String($0) }.joined(separator: "\n")
    }

    private func drawRect(
        grid: inout [[Character]],
        rect: CGRect,
        offsetX: CGFloat, offsetY: CGFloat,
        scale: CGFloat,
        border: Character,
        fill: Character?
    ) {
        let r0 = Int((rect.origin.y - offsetY) / scale)
        let r1 = Int((rect.origin.y + rect.size.height - offsetY) / scale)
        let c0 = Int((rect.origin.x - offsetX) / scale)
        let c1 = Int((rect.origin.x + rect.size.width - offsetX) / scale)

        let rows = grid.count
        let cols = grid[0].count

        for r in r0...r1 where r >= 0 && r < rows {
            for c in c0...c1 where c >= 0 && c < cols {
                let isBorder = r == r0 || r == r1 || c == c0 || c == c1
                if isBorder {
                    grid[r][c] = border
                } else if let fill = fill {
                    grid[r][c] = fill
                }
            }
        }
    }

    private func placeLabel(
        grid: inout [[Character]],
        rect: CGRect,
        label: String,
        offsetX: CGFloat, offsetY: CGFloat,
        scale: CGFloat
    ) {
        let rMinY = rect.origin.y
        let rMaxY = rect.origin.y + rect.size.height
        let rMinX = rect.origin.x
        let rMaxX = rect.origin.x + rect.size.width
        let midR = Int(((rMinY + rMaxY) / 2 - offsetY) / scale)
        let midC = Int(((rMinX + rMaxX) / 2 - offsetX) / scale)

        let rows = grid.count
        let cols = grid[0].count

        let startC = midC - label.count / 2
        for (i, ch) in label.enumerated() {
            let c = startC + i
            if midR >= 0 && midR < rows && c >= 0 && c < cols {
                grid[midR][c] = ch
            }
        }
    }
}
