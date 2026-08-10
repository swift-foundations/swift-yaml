import Byte_Primitive
import Byte_Protocol_Primitives
import Testing
import YAML

extension YAML {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}

        @Test func `parse keeps scalar resolution in compose`() throws {
            let stream = try YAML.Parse.events("[on, true, 42, \"42\"]")
            let graph = try YAML.Compose.graph(from: stream, schema: .core)
            guard case .sequence(let children) = graph[graph.root]?.kind else {
                Issue.record("Expected sequence root")
                return
            }
            #expect(graph[children[0]]?.tag == .string)
            #expect(graph[children[1]]?.tag == .boolean)
            #expect(graph[children[2]]?.tag == .integer)
            #expect(graph[children[3]]?.tag == .string)
        }

        @Test func `compose preserves alias identity and cycles`() throws {
            let stream = try YAML.Parse.events("&root [*root]")
            let graph = try YAML.Compose.graph(from: stream)
            guard case .sequence(let children) = graph[graph.root]?.kind else {
                Issue.record("Expected sequence root")
                return
            }
            #expect(children == [graph.root])
        }

        @Test func `byte input rejects malformed UTF 8`() {
            let bytes: [Byte] = [0xC3, 0x28]
            #expect(throws: YAML.Parse.Error.self) {
                _ = try YAML.Parse.events(bytes)
            }
        }

        @Test func `failsafe schema keeps plain scalars as strings`() throws {
            let stream = try YAML.Parse.events("true")
            let graph = try YAML.Compose.graph(from: stream, schema: .failsafe)
            #expect(graph[graph.root]?.tag == .string)
        }
    }
}
