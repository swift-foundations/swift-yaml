// Licensed under Apache License v2.0.

extension YAML {
    @frozen
    public struct Limits: Sendable, Equatable {
        // swift-linter:disable:next compound identifier
        // REASON: This is one domain term with no sibling input limit namespace.
        public let inputBytes: UInt
        public let events: UInt
        public let depth: UInt
        // swift-linter:disable:next compound identifier
        // REASON: This is one domain term with no sibling scalar limit namespace.
        public let scalarLength: UInt
        public let nodes: UInt
        public let aliases: UInt

        public init(
            inputBytes: UInt = 16 * 1024 * 1024,
            events: UInt = 1_000_000,
            depth: UInt = 128,
            scalarLength: UInt = 4 * 1024 * 1024,
            nodes: UInt = 1_000_000,
            aliases: UInt = 100_000
        ) {
            self.inputBytes = inputBytes
            self.events = events
            self.depth = depth
            self.scalarLength = scalarLength
            self.nodes = nodes
            self.aliases = aliases
        }
    }
}

extension YAML.Limits {
    public static let `default` = Self()
}
