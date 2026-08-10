// Licensed under Apache License v2.0.

public import Lexer_Primitives

extension YAML.Parse {
    @frozen
    public enum Error: Swift.Error, Sendable, Equatable {
        case inputLimit
        case eventLimit
        case depthLimit
        case scalarLimit
        case invalidEncoding(Lexer.Position)
        case unexpectedCharacter(Character, Lexer.Position)
        case unexpectedEnd(Lexer.Position)
        case trailingContent(Lexer.Position)
        case unsupportedBlockStructure(Lexer.Position)
    }
}
