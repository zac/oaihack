import Foundation

enum JSONValueCodableBridge {
    static func decode<T: Decodable>(_ value: JSONValue, as type: T.Type) throws -> T {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(value)
        return try decoder.decode(T.self, from: data)
    }

    static func encode<T: Encodable>(_ value: T) throws -> JSONValue {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(value)
        return try decoder.decode(JSONValue.self, from: data)
    }
}
