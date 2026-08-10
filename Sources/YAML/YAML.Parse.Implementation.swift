// Licensed under Apache License v2.0.

private import Lexer_Primitives

extension YAML.Parse {
    struct Implementation {
        private let characters: [Character]
        private let limits: YAML.Limits
        private var position: Int
        private var line: Int
        private var column: Int
        private var output: [YAML.Serialization.Event]

        init(source: String, limits: YAML.Limits) {
            characters = Array(source)
            self.limits = limits
            position = 0
            line = 0
            column = 0
            output = []
        }
    }
}

extension YAML.Parse.Implementation {
    mutating func parse() throws(YAML.Parse.Error) -> YAML.Serialization.Stream {
        append(.streamStart(mark()))
        skipSpaceAndComments()
        let documentMark = mark()
        if consume("---") { skipSpaceAndComments() }
        append(
            .documentStart(
                explicit: mark().offset > documentMark.offset,
                directives: [],
                mark: documentMark
            )
        )
        try parseNode(depth: 0)
        skipSpaceAndComments()
        let explicitEnd = consume("...")
        skipSpaceAndComments()
        guard isAtEnd else { throw .trailingContent(mark()) }
        append(.documentEnd(explicit: explicitEnd, mark: mark()))
        append(.streamEnd(mark()))
        return .init(events: output)
    }

    private mutating func parseNode(depth: Int) throws(YAML.Parse.Error) {
        guard UInt(depth) <= limits.depth else { throw .depthLimit }
        skipSpaceAndComments()
        guard let character = peek() else { throw .unexpectedEnd(mark()) }
        switch character {
        case "[": try parseSequence(depth: depth)
        case "{": try parseMapping(depth: depth)
        case "\"", "'": try parseQuoted()
        case "*": try parseAlias()
        case "&": try parseAnchored(depth: depth)
        default: try parsePlain()
        }
    }

    private mutating func parseSequence(depth: Int) throws(YAML.Parse.Error) {
        let start = mark()
        advance()
        append(.sequenceStart(anchor: nil, tag: .nonSpecific, style: .flow, mark: start))
        skipSpaceAndComments()
        if consume("]") {
            append(.sequenceEnd(mark()))
            return
        }
        while true {
            try parseNode(depth: depth + 1)
            skipSpaceAndComments()
            if consume("]") { break }
            guard consume(",") else { throw unexpected() }
            skipSpaceAndComments()
        }
        append(.sequenceEnd(mark()))
    }

    private mutating func parseMapping(depth: Int) throws(YAML.Parse.Error) {
        let start = mark()
        advance()
        append(.mappingStart(anchor: nil, tag: .nonSpecific, style: .flow, mark: start))
        skipSpaceAndComments()
        if consume("}") {
            append(.mappingEnd(mark()))
            return
        }
        while true {
            try parseNode(depth: depth + 1)
            skipSpaceAndComments()
            guard consume(":") else { throw unexpected() }
            try parseNode(depth: depth + 1)
            skipSpaceAndComments()
            if consume("}") { break }
            guard consume(",") else { throw unexpected() }
            skipSpaceAndComments()
        }
        append(.mappingEnd(mark()))
    }

    private mutating func parseQuoted() throws(YAML.Parse.Error) {
        let start = mark()
        guard let quote = peek() else { throw .unexpectedEnd(start) }
        advance()
        var content = ""
        while let character = peek(), character != quote {
            if quote == "\"" && character == "\\" {
                advance()
                guard let escaped = peek() else { throw .unexpectedEnd(mark()) }
                content.append(try escape(escaped))
                advance()
            } else {
                content.append(character)
                advance()
            }
            guard UInt(content.count) <= limits.scalarLength else { throw .scalarLimit }
        }
        guard consume(String(quote)) else { throw .unexpectedEnd(mark()) }
        append(
            .scalar(
                content: content,
                anchor: nil,
                tag: .string,
                style: quote == "\"" ? .doubleQuoted : .singleQuoted,
                mark: start
            )
        )
    }

    private func escape(_ character: Character) throws(YAML.Parse.Error) -> Character {
        switch character {
        case "n": "\n"
        case "r": "\r"
        case "t": "\t"
        case "\"", "\\", "/": character
        default: throw .unexpectedCharacter(character, mark())
        }
    }

    private mutating func parsePlain() throws(YAML.Parse.Error) {
        let start = mark()
        var content = ""
        while let character = peek(), !character.isWhitespace, !",]}:{#".contains(character) {
            content.append(character)
            advance()
            guard UInt(content.count) <= limits.scalarLength else { throw .scalarLimit }
        }
        guard !content.isEmpty else { throw unexpected() }
        append(.scalar(content: content, anchor: nil, tag: .nonSpecific, style: .plain, mark: start))
    }

    private mutating func parseAlias() throws(YAML.Parse.Error) {
        let start = mark()
        advance()
        let name = try parseName()
        append(.alias(.init(name), start))
    }

    private mutating func parseAnchored(depth: Int) throws(YAML.Parse.Error) {
        let start = mark()
        advance()
        let anchor = YAML.Serialization.Anchor(try parseName())
        skipSpaceAndComments()
        let outputPosition = output.count
        try parseNode(depth: depth + 1)
        switch output[outputPosition] {
        case .scalar(let content, _, let tag, let style, let mark):
            output[outputPosition] = .scalar(content: content, anchor: anchor, tag: tag, style: style, mark: mark)

        case .sequenceStart(_, let tag, let style, let mark):
            output[outputPosition] = .sequenceStart(anchor: anchor, tag: tag, style: style, mark: mark)

        case .mappingStart(_, let tag, let style, let mark):
            output[outputPosition] = .mappingStart(anchor: anchor, tag: tag, style: style, mark: mark)

        default:
            throw .unexpectedCharacter("&", start)
        }
    }

    private mutating func parseName() throws(YAML.Parse.Error) -> String {
        var name = ""
        while let character = peek(),
            character.isLetter || character.isNumber || character == "_" || character == "-"
        {
            name.append(character)
            advance()
        }
        guard !name.isEmpty else { throw unexpected() }
        return name
    }

    private mutating func append(_ event: YAML.Serialization.Event) {
        output.append(event)
    }

    private mutating func skipSpaceAndComments() {
        while true {
            while let character = peek(), character.isWhitespace { advance() }
            guard peek() == "#" else { return }
            while let character = peek(), character != "\n" { advance() }
        }
    }

    private var isAtEnd: Bool { position == characters.count }
    private func peek() -> Character? { isAtEnd ? nil : characters[position] }
    private func mark() -> Lexer.Position {
        .init(
            offset: Text.Position(_unchecked: Ordinal(UInt(position))),
            location: Text.Location(
                line: Text.Line.Number(UInt(line + 1)),
                column: Text.Line.Column(_unchecked: Cardinal(UInt(column + 1)))
            )
        )
    }
    private func unexpected() -> YAML.Parse.Error {
        peek().map { .unexpectedCharacter($0, mark()) } ?? .unexpectedEnd(mark())
    }

    private mutating func consume(_ token: String) -> Bool {
        let expected = Array(token)
        guard position + expected.count <= characters.count else { return false }
        guard Array(characters[position..<(position + expected.count)]) == expected else { return false }
        for _ in expected { advance() }
        return true
    }

    private mutating func advance() {
        let character = characters[position]
        position += 1
        if character == "\n" {
            line += 1
            column = 0
        } else {
            column += 1
        }
    }
}
