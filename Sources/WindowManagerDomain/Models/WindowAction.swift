public enum WindowAction: String, CaseIterable, Equatable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case maximize
    case fullscreen
    case center
    case nextDisplay
    case prevDisplay
}
