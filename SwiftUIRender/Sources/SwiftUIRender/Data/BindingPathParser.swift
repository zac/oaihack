import Foundation

enum BindingPathParser {
    static func parse(_ raw: String) throws -> BindingPath {
        if raw.hasPrefix("/") {
            return try parseJSONPointer(raw)
        }

        if raw.hasPrefix("$data") {
            return try parseDataPath(raw)
        }

        throw BindingPathError.invalidPath(raw)
    }

    private static func parseJSONPointer(_ path: String) throws -> BindingPath {
        if path == "/" {
            return BindingPath(tokens: [])
        }

        guard path.hasPrefix("/") else {
            throw BindingPathError.invalidPath(path)
        }

        let rawTokens = path.dropFirst().split(separator: "/", omittingEmptySubsequences: false)
        let tokens = rawTokens.map { token in
            token
                .replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
        }

        return BindingPath(tokens: tokens)
    }

    private static func parseDataPath(_ raw: String) throws -> BindingPath {
        if raw == "$data" {
            return BindingPath(tokens: [])
        }

        if raw.hasPrefix("$data/") {
            return try parseJSONPointer(String(raw.dropFirst("$data".count)))
        }

        var remainder = String(raw.dropFirst("$data".count))
        if remainder.hasPrefix(".") {
            remainder.removeFirst()
        }

        var tokens: [String] = []
        var index = remainder.startIndex

        while index < remainder.endIndex {
            let char = remainder[index]

            if char == "." {
                remainder.formIndex(after: &index)
                continue
            }

            if char == "[" {
                guard let endIndex = remainder[index...].firstIndex(of: "]") else {
                    throw BindingPathError.invalidPath(raw)
                }
                let numberStart = remainder.index(after: index)
                let number = String(remainder[numberStart..<endIndex])
                guard Int(number) != nil else {
                    throw BindingPathError.invalidArrayIndex(number)
                }
                tokens.append(number)
                index = remainder.index(after: endIndex)
                continue
            }

            var end = index
            while end < remainder.endIndex {
                let next = remainder[end]
                if next == "." || next == "[" {
                    break
                }
                remainder.formIndex(after: &end)
            }

            let token = String(remainder[index..<end])
            if token.isEmpty {
                throw BindingPathError.invalidPath(raw)
            }
            tokens.append(token)
            index = end
        }

        return BindingPath(tokens: tokens)
    }
}
