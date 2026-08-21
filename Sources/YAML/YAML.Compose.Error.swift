extension YAML.Compose {
    @frozen
    public enum Error: Swift.Error, Sendable, Equatable {
        case invalidEvent
        case undefinedAnchor(YAML.Serialization.Anchor)
        case duplicateAnchor(YAML.Serialization.Anchor)
        case nodeLimit
        case aliasLimit
        case graph(YAML.Representation.Graph.Error)
    }
}
