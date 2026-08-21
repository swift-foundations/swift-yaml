extension YAML.Compose {
    public static func graph(
        from stream: YAML.Serialization.Stream,
        schema: Schema = .core,
        limits: YAML.Limits = .default
    ) throws(YAML.Compose.Error) -> YAML.Representation.Graph {
        var implementation = Implementation(events: stream.events, schema: schema, limits: limits)
        return try implementation.compose()
    }
}
