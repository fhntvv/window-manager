public protocol ConfigPort {
    func loadConfig() throws -> Config
}
