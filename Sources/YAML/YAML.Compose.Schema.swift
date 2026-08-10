// Licensed under Apache License v2.0.

extension YAML.Compose {
    @frozen
    public struct Schema: Sendable, Equatable {
        public let identifier: YAML.Schema.Identifier

        public init(_ identifier: YAML.Schema.Identifier) {
            self.identifier = identifier
        }
    }
}

extension YAML.Compose.Schema {
    public static let failsafe = Self(.failsafe)
    public static let json = Self(.json)
    public static let core = Self(.core)
}
