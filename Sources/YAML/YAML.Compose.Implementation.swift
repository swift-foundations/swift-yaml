// Licensed under Apache License v2.0.

extension YAML.Compose {
    struct Implementation {
        private let events: [YAML.Serialization.Event]
        private let schema: Schema
        private let limits: YAML.Limits
        private var position = 0
        private var aliases = 0
        private var anchors: [YAML.Serialization.Anchor: YAML.Representation.Node.Identifier] = [:]
        private var builder = YAML.Representation.Graph.Builder()
        private var builderCount: Int

        init(events: [YAML.Serialization.Event], schema: Schema, limits: YAML.Limits) {
            self.events = events
            self.schema = schema
            self.limits = limits
            builderCount = 0
        }
    }
}

extension YAML.Compose.Implementation {
    mutating func compose() throws(YAML.Compose.Error) -> YAML.Representation.Graph {
        guard consumeStreamStart(), consumeDocumentStart() else { throw .invalidEvent }
        let root = try composeNode()
        guard consumeDocumentEnd(), consumeStreamEnd(), position == events.count else {
            throw .invalidEvent
        }
        do throws(YAML.Representation.Graph.Error) {
            return try builder.finalize(root: root)
        } catch let error {
            throw .graph(error)
        }
    }

    private mutating func composeNode() throws(YAML.Compose.Error)
        -> YAML.Representation.Node.Identifier
    {
        guard position < events.count else { throw .invalidEvent }
        switch events[position] {
        case .scalar(let content, let anchor, let tag, let style, _):
            position += 1
            let identifier = try reserve(anchor: anchor)
            let resolved = resolve(content: content, tag: tag, style: style)
            try define(identifier, node: .init(tag: resolved.tag, kind: .scalar(resolved.content)))
            return identifier

        case .alias(let anchor, _):
            position += 1
            aliases += 1
            guard UInt(aliases) <= limits.aliases else { throw .aliasLimit }
            guard let identifier = anchors[anchor] else { throw .undefinedAnchor(anchor) }
            return identifier

        case .sequenceStart(let anchor, let tag, _, _):
            return try composeSequence(anchor: anchor, tag: tag)

        case .mappingStart(let anchor, let tag, _, _):
            return try composeMapping(anchor: anchor, tag: tag)

        default:
            throw .invalidEvent
        }
    }

    private mutating func composeSequence(
        anchor: YAML.Serialization.Anchor?,
        tag: YAML.Tag
    ) throws(YAML.Compose.Error) -> YAML.Representation.Node.Identifier {
        position += 1
        let identifier = try reserve(anchor: anchor)
        var children: [YAML.Representation.Node.Identifier] = []
        while position < events.count {
            if case .sequenceEnd = events[position] {
                position += 1
                let resolvedTag: YAML.Tag = tag == .nonSpecific ? .sequence : tag
                try define(
                    identifier,
                    node: .init(tag: resolvedTag, kind: .sequence(children))
                )
                return identifier
            }
            children.append(try composeNode())
        }
        throw .invalidEvent
    }

    private mutating func composeMapping(
        anchor: YAML.Serialization.Anchor?,
        tag: YAML.Tag
    ) throws(YAML.Compose.Error) -> YAML.Representation.Node.Identifier {
        position += 1
        let identifier = try reserve(anchor: anchor)
        var entries: [YAML.Representation.Mapping.Entry] = []
        while position < events.count {
            if case .mappingEnd = events[position] {
                position += 1
                let resolvedTag: YAML.Tag = tag == .nonSpecific ? .mapping : tag
                try define(
                    identifier,
                    node: .init(tag: resolvedTag, kind: .mapping(entries))
                )
                return identifier
            }
            let key = try composeNode()
            let value = try composeNode()
            entries.append(.init(key: key, value: value))
        }
        throw .invalidEvent
    }

    private mutating func reserve(
        anchor: YAML.Serialization.Anchor?
    ) throws(YAML.Compose.Error) -> YAML.Representation.Node.Identifier {
        guard UInt(builderCount) < limits.nodes else { throw .nodeLimit }
        let identifier = builder.reserve()
        builderCount += 1
        if let anchor {
            guard anchors[anchor] == nil else { throw .duplicateAnchor(anchor) }
            anchors[anchor] = identifier
        }
        return identifier
    }

    private mutating func define(
        _ identifier: YAML.Representation.Node.Identifier,
        node: YAML.Representation.Node
    ) throws(YAML.Compose.Error) {
        do throws(YAML.Representation.Graph.Error) {
            try builder.define(identifier, as: node)
        } catch let error {
            throw .graph(error)
        }
    }

    private func resolve(
        content: String,
        tag: YAML.Tag,
        style: YAML.Presentation.Style
    ) -> (tag: YAML.Tag, content: String) {
        guard tag == .nonSpecific && style == .plain else {
            return (tag == .nonSpecific ? .string : tag, content)
        }
        switch schema.identifier {
        case .failsafe:
            return (.string, content)

        case .json, .core:
            let lower = content.lowercased()
            if lower == "null" || content == "~" { return (.null, "null") }
            if lower == "true" { return (.boolean, "true") }
            if lower == "false" { return (.boolean, "false") }
            if let integer = Int(content) { return (.integer, String(integer)) }
            if let floating = Double(content), content.contains(".") || lower.contains("e") {
                return (.floating, String(floating))
            }
            return (.string, content)
        }
    }

    private mutating func consumeStreamStart() -> Bool {
        guard position < events.count, case .streamStart = events[position] else { return false }
        position += 1
        return true
    }

    private mutating func consumeDocumentStart() -> Bool {
        guard position < events.count, case .documentStart = events[position] else { return false }
        position += 1
        return true
    }

    private mutating func consumeDocumentEnd() -> Bool {
        guard position < events.count, case .documentEnd = events[position] else { return false }
        position += 1
        return true
    }

    private mutating func consumeStreamEnd() -> Bool {
        guard position < events.count, case .streamEnd = events[position] else { return false }
        position += 1
        return true
    }
}
