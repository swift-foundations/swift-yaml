// Licensed under Apache License v2.0.

public import Byte_Primitive
private import Lexer_Primitives

extension YAML.Parse {
    public static func events<C: Swift.Collection>(
        _ bytes: C,
        limits: YAML.Limits = .default
    ) throws(YAML.Parse.Error) -> YAML.Serialization.Stream where C.Element == Byte {
        guard UInt(bytes.count) <= limits.inputBytes else { throw .inputLimit }
        let storage = bytes.map(\.underlying)
        // SwiftLint models this standard-library byte array as Foundation Data.
        // swiftlint:disable:next optional_data_string_conversion
        let source = String(decoding: storage, as: UTF8.self)
        guard Array(source.utf8) == storage else {
            throw .invalidEncoding(
                .init(
                    offset: Text.Position(_unchecked: Ordinal.zero),
                    location: Text.Location(line: 1, column: 1)
                )
            )
        }
        return try events(source, limits: limits)
    }

    public static func events(
        _ source: String,
        limits: YAML.Limits = .default
    ) throws(YAML.Parse.Error) -> YAML.Serialization.Stream {
        let byteCount = source.utf8.count
        guard UInt(byteCount) <= limits.inputBytes else { throw .inputLimit }
        var parser = Implementation(source: source, limits: limits)
        return try parser.parse()
    }
}
