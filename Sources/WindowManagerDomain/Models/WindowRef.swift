import Foundation

public struct WindowRef: Equatable, Hashable, Sendable {
    public let id: Int

    public init(id: Int) {
        self.id = id
    }
}
