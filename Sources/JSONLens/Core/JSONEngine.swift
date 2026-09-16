import CoreFoundation
import Foundation

struct ParsedJSON {
    let value: Any
    let formatted: String
    let minified: String
    let rootNode: JSONNode
    let statistics: JSONStatistics
    let table: JSONTable?
}

enum JSONEngineError: LocalizedError, Equatable {
    case empty
    case invalid(ParseIssue)
    case invalidQuery(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            "请输入 JSON 内容"
        case let .invalid(issue):
            issue.message
        case let .invalidQuery(message):
            message
        }
    }
}

enum JSONEngine {
    static func parse(_ text: String, indent: Int = 2) throws -> ParsedJSON {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JSONEngineError.empty
        }

        let data = Data(text.utf8)
        let value: Any

        do {
            value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw JSONEngineError.invalid(parseIssue(from: error, source: text))
        }

        let formatted = try serialize(value, pretty: true, indent: indent)
        let minified = try serialize(value, pretty: false, indent: indent)
        var statistics = JSONStatistics()
        statistics.byteCount = data.count
        collectStatistics(value, depth: 1, result: &statistics)

        return ParsedJSON(
            value: value,
            formatted: formatted,
            minified: minified,
            rootNode: makeNode(value: value, name: "root", path: "$"),
            statistics: statistics,
            table: makeTable(from: value)
        )
    }

    static func serialize(_ value: Any, pretty: Bool, indent: Int = 2) throws -> String {
        var options: JSONSerialization.WritingOptions = [
            .fragmentsAllowed,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        if pretty {
            options.insert(.prettyPrinted)
        }
        let data = try JSONSerialization.data(withJSONObject: value, options: options)
        let output = String(decoding: data, as: UTF8.self)

        guard pretty, indent != 2 else {
            return output
        }

        return output
            .components(separatedBy: "\n")
            .map { line in
                let spaceCount = line.prefix(while: { $0 == " " }).count
                let level = spaceCount / 2
                return String(repeating: " ", count: level * indent) + line.dropFirst(spaceCount)
            }
            .joined(separator: "\n")
    }

    static func query(_ expression: String, in root: Any) throws -> [JSONQueryResult] {
        let tokens = try parseQuery(expression)
        var matches: [(String, Any)] = [("$", root)]

        for token in tokens {
            var next: [(String, Any)] = []
            for (path, value) in matches {
                let traversableValue = embeddedJSONValue(from: value) ?? value
                switch token {
                case let .field(key):
                    if let object = traversableValue as? [String: Any], let child = object[key] {
                        next.append((append(key: key, to: path), child))
                    }
                case let .index(index):
                    if let array = traversableValue as? [Any], array.indices.contains(index) {
                        next.append(("\(path)[\(index)]", array[index]))
                    }
                case .wildcard:
                    if let object = traversableValue as? [String: Any] {
                        for key in object.keys.sorted() {
                            next.append((append(key: key, to: path), object[key] as Any))
                        }
                    } else if let array = traversableValue as? [Any] {
                        next.append(contentsOf: array.enumerated().map { ("\((path))[\($0.offset)]", $0.element) })
                    }
                case let .recursive(key):
                    collectRecursiveMatches(key: key, value: traversableValue, path: path, result: &next)
                }
            }
            matches = next
        }

        return matches.map { path, value in
            let presentation = presentationDescription(value)
            return JSONQueryResult(
                path: path,
                kind: kind(of: value),
                displayKind: presentation.displayKind,
                displayValue: presentation.text,
                copyValue: copyDescription(value),
                isEmbeddedJSON: presentation.isEmbeddedJSON,
                rawValue: value
            )
        }
    }

    static func diff(_ left: Any, _ right: Any) -> [JSONDiffEntry] {
        var entries: [JSONDiffEntry] = []
        collectDiff(left: left, right: right, path: "$", result: &entries)
        return entries
    }

    static func csv(from table: JSONTable) -> String {
        let header = table.columns.map(csvCell).joined(separator: ",")
        let body = table.rows.map { row in
            table.columns.map { csvCell(row[$0] ?? "") }.joined(separator: ",")
        }
        return ([header] + body).joined(separator: "\n")
    }

    static func compactDescription(_ value: Any, limit: Int = 100) -> String {
        let output: String
        if value is NSNull {
            output = "null"
        } else if let string = value as? String {
            output = "\"\(string)\""
        } else if let number = value as? NSNumber {
            output = isBoolean(number) ? (number.boolValue ? "true" : "false") : number.stringValue
        } else if JSONSerialization.isValidJSONObject(value),
                  let data = try? JSONSerialization.data(
                    withJSONObject: value,
                    options: [.sortedKeys, .withoutEscapingSlashes]
                  ) {
            output = String(decoding: data, as: UTF8.self)
        } else {
            output = String(describing: value)
        }

        guard output.count > limit else {
            return output
        }
        return String(output.prefix(max(0, limit - 1))) + "..."
    }

    static func kind(of value: Any) -> JSONKind {
        if value is NSNull {
            return .null
        }
        if value is [String: Any] {
            return .object
        }
        if value is [Any] {
            return .array
        }
        if value is String {
            return .string
        }
        if let number = value as? NSNumber {
            return isBoolean(number) ? .boolean : .number
        }
        return .string
    }

    private enum QueryToken: Equatable {
        case field(String)
        case index(Int)
        case wildcard
        case recursive(String)
    }

    private static func parseQuery(_ rawExpression: String) throws -> [QueryToken] {
        let expression = rawExpression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expression.isEmpty else {
            throw JSONEngineError.invalidQuery("请输入查询表达式，例如 $.users[0].name")
        }

        let characters = Array(expression)
        var index = 0
        var tokens: [QueryToken] = []

        if characters.first == "$" {
            index += 1
        }

        while index < characters.count {
            let character = characters[index]

            if character == "." {
                let isRecursive = index + 1 < characters.count && characters[index + 1] == "."
                index += isRecursive ? 2 : 1
                guard index < characters.count else {
                    throw JSONEngineError.invalidQuery("点号后缺少字段名")
                }
                if characters[index] == "*" {
                    tokens.append(.wildcard)
                    index += 1
                    continue
                }
                let key = readBareKey(characters, index: &index)
                guard !key.isEmpty else {
                    throw JSONEngineError.invalidQuery("字段名不能为空")
                }
                tokens.append(isRecursive ? .recursive(key) : .field(key))
                continue
            }

            if character == "[" {
                index += 1
                guard index < characters.count else {
                    throw JSONEngineError.invalidQuery("缺少右方括号")
                }

                if characters[index] == "*" {
                    index += 1
                    try consumeClosingBracket(characters, index: &index)
                    tokens.append(.wildcard)
                    continue
                }

                if characters[index] == "\"" || characters[index] == "'" {
                    let quote = characters[index]
                    index += 1
                    var key = ""
                    var escaped = false
                    while index < characters.count {
                        let current = characters[index]
                        index += 1
                        if escaped {
                            key.append(current)
                            escaped = false
                        } else if current == "\\" {
                            escaped = true
                        } else if current == quote {
                            break
                        } else {
                            key.append(current)
                        }
                    }
                    try consumeClosingBracket(characters, index: &index)
                    tokens.append(.field(key))
                    continue
                }

                let start = index
                while index < characters.count, characters[index].isNumber {
                    index += 1
                }
                guard start != index, let arrayIndex = Int(String(characters[start..<index])) else {
                    throw JSONEngineError.invalidQuery("数组下标必须是非负整数")
                }
                try consumeClosingBracket(characters, index: &index)
                tokens.append(.index(arrayIndex))
                continue
            }

            let key = readBareKey(characters, index: &index)
            guard !key.isEmpty else {
                throw JSONEngineError.invalidQuery("无法解析查询表达式")
            }
            tokens.append(.field(key))
        }

        return tokens
    }

    private static func readBareKey(_ characters: [Character], index: inout Int) -> String {
        let start = index
        while index < characters.count, characters[index] != ".", characters[index] != "[" {
            index += 1
        }
        return String(characters[start..<index])
    }

    private static func consumeClosingBracket(_ characters: [Character], index: inout Int) throws {
        guard index < characters.count, characters[index] == "]" else {
            throw JSONEngineError.invalidQuery("缺少右方括号")
        }
        index += 1
    }

    private static func collectRecursiveMatches(
        key: String,
        value: Any,
        path: String,
        result: inout [(String, Any)]
    ) {
        let traversableValue = embeddedJSONValue(from: value) ?? value
        if let object = traversableValue as? [String: Any] {
            for childKey in object.keys.sorted() {
                guard let child = object[childKey] else {
                    continue
                }
                let childPath = append(key: childKey, to: path)
                if childKey == key {
                    result.append((childPath, child))
                }
                collectRecursiveMatches(key: key, value: child, path: childPath, result: &result)
            }
        } else if let array = traversableValue as? [Any] {
            for (arrayIndex, child) in array.enumerated() {
                collectRecursiveMatches(
                    key: key,
                    value: child,
                    path: "\(path)[\(arrayIndex)]",
                    result: &result
                )
            }
        }
    }

    private static func collectDiff(
        left: Any,
        right: Any,
        path: String,
        result: inout [JSONDiffEntry]
    ) {
        if let leftObject = left as? [String: Any], let rightObject = right as? [String: Any] {
            for key in Set(leftObject.keys).union(rightObject.keys).sorted() {
                let childPath = append(key: key, to: path)
                switch (leftObject[key], rightObject[key]) {
                case let (.some(old), .some(new)):
                    collectDiff(left: old, right: new, path: childPath, result: &result)
                case let (.some(old), .none):
                    result.append(
                        JSONDiffEntry(
                            path: childPath,
                            kind: .removed,
                            oldValue: compactDescription(old),
                            newValue: nil
                        )
                    )
                case let (.none, .some(new)):
                    result.append(
                        JSONDiffEntry(
                            path: childPath,
                            kind: .added,
                            oldValue: nil,
                            newValue: compactDescription(new)
                        )
                    )
                case (.none, .none):
                    break
                }
            }
            return
        }

        if let leftArray = left as? [Any], let rightArray = right as? [Any] {
            let upperBound = max(leftArray.count, rightArray.count)
            for arrayIndex in 0..<upperBound {
                let childPath = "\(path)[\(arrayIndex)]"
                if arrayIndex >= leftArray.count {
                    result.append(
                        JSONDiffEntry(
                            path: childPath,
                            kind: .added,
                            oldValue: nil,
                            newValue: compactDescription(rightArray[arrayIndex])
                        )
                    )
                } else if arrayIndex >= rightArray.count {
                    result.append(
                        JSONDiffEntry(
                            path: childPath,
                            kind: .removed,
                            oldValue: compactDescription(leftArray[arrayIndex]),
                            newValue: nil
                        )
                    )
                } else {
                    collectDiff(
                        left: leftArray[arrayIndex],
                        right: rightArray[arrayIndex],
                        path: childPath,
                        result: &result
                    )
                }
            }
            return
        }

        if !equal(left, right) {
            result.append(
                JSONDiffEntry(
                    path: path,
                    kind: .modified,
                    oldValue: compactDescription(left),
                    newValue: compactDescription(right)
                )
            )
        }
    }

    private static func equal(_ left: Any, _ right: Any) -> Bool {
        let leftKind = kind(of: left)
        let rightKind = kind(of: right)
        guard leftKind == rightKind else {
            return false
        }

        switch leftKind {
        case .null:
            return true
        case .string:
            return (left as? String) == (right as? String)
        case .number:
            return (left as? NSNumber)?.decimalValue == (right as? NSNumber)?.decimalValue
        case .boolean:
            return (left as? NSNumber)?.boolValue == (right as? NSNumber)?.boolValue
        case .object, .array:
            guard let leftData = try? JSONSerialization.data(withJSONObject: left, options: [.sortedKeys]),
                  let rightData = try? JSONSerialization.data(withJSONObject: right, options: [.sortedKeys]) else {
                return false
            }
            return leftData == rightData
        }
    }

    private static func collectStatistics(_ value: Any, depth: Int, result: inout JSONStatistics) {
        result.maxDepth = max(result.maxDepth, depth)

        if let object = value as? [String: Any] {
            result.objects += 1
            result.keys += object.count
            for child in object.values {
                collectStatistics(child, depth: depth + 1, result: &result)
            }
        } else if let array = value as? [Any] {
            result.arrays += 1
            for child in array {
                collectStatistics(child, depth: depth + 1, result: &result)
            }
        } else if value is String {
            result.strings += 1
        } else if let number = value as? NSNumber {
            if isBoolean(number) {
                result.booleans += 1
            } else {
                result.numbers += 1
            }
        } else if value is NSNull {
            result.nulls += 1
        }
    }

    private static func presentationDescription(
        _ value: Any,
        indent: Int = 2
    ) -> (text: String, isEmbeddedJSON: Bool, displayKind: JSONKind) {
        var embeddedCount = 0
        let presentationValue = recursivelyExpandEmbeddedJSON(
            in: value,
            embeddedDepth: 0,
            count: &embeddedCount
        )

        if presentationValue is [String: Any] || presentationValue is [Any],
           let formatted = try? serialize(presentationValue, pretty: true, indent: indent) {
            return (formatted, embeddedCount > 0, kind(of: presentationValue))
        }
        return (compactDescription(value, limit: 240), false, kind(of: value))
    }

    private static func copyDescription(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if (value is [String: Any] || value is [Any]),
           let serialized = try? serialize(value, pretty: false) {
            return serialized
        }
        return compactDescription(value, limit: .max)
    }

    private static func recursivelyExpandEmbeddedJSON(
        in value: Any,
        embeddedDepth: Int,
        count: inout Int
    ) -> Any {
        if let object = value as? [String: Any] {
            return object.mapValues {
                recursivelyExpandEmbeddedJSON(
                    in: $0,
                    embeddedDepth: embeddedDepth,
                    count: &count
                )
            }
        }

        if let array = value as? [Any] {
            return array.map {
                recursivelyExpandEmbeddedJSON(
                    in: $0,
                    embeddedDepth: embeddedDepth,
                    count: &count
                )
            }
        }

        guard embeddedDepth < 32,
              let embeddedValue = embeddedJSONValue(from: value) else {
            return value
        }

        count += 1
        return recursivelyExpandEmbeddedJSON(
            in: embeddedValue,
            embeddedDepth: embeddedDepth + 1,
            count: &count
        )
    }

    private static func embeddedJSONValue(from value: Any) -> Any? {
        guard let string = value as? String, looksLikeJSONContainer(string) else {
            return nil
        }
        let data = Data(string.utf8)
        guard let embeddedValue = try? JSONSerialization.jsonObject(with: data),
              embeddedValue is [String: Any] || embeddedValue is [Any] else {
            return nil
        }
        return embeddedValue
    }

    private static func looksLikeJSONContainer(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, let last = trimmed.last else {
            return false
        }
        return (first == "{" && last == "}") || (first == "[" && last == "]")
    }

    private static func makeNode(
        value: Any,
        name: String,
        path: String,
        embeddedDepth: Int = 0
    ) -> JSONNode {
        let valueKind = kind(of: value)
        let children: [JSONNode]
        let preview: String
        let embeddedJSONKind: JSONKind?

        if embeddedDepth < 32, let embeddedValue = embeddedJSONValue(from: value) {
            let embeddedKind = kind(of: embeddedValue)
            embeddedJSONKind = embeddedKind
            if let object = embeddedValue as? [String: Any] {
                children = object.keys.sorted().compactMap { key in
                    guard let child = object[key] else {
                        return nil
                    }
                    return makeNode(
                        value: child,
                        name: key,
                        path: append(key: key, to: path),
                        embeddedDepth: embeddedDepth + 1
                    )
                }
                preview = "JSON 字符串 · \(object.count) 个字段"
            } else if let array = embeddedValue as? [Any] {
                children = array.enumerated().map { index, child in
                    makeNode(
                        value: child,
                        name: "\(index)",
                        path: "\(path)[\(index)]",
                        embeddedDepth: embeddedDepth + 1
                    )
                }
                preview = "JSON 字符串 · \(array.count) 项"
            } else {
                children = []
                preview = compactDescription(value)
            }
        } else if let object = value as? [String: Any] {
            embeddedJSONKind = nil
            children = object.keys.sorted().compactMap { key in
                guard let child = object[key] else {
                    return nil
                }
                return makeNode(
                    value: child,
                    name: key,
                    path: append(key: key, to: path),
                    embeddedDepth: embeddedDepth
                )
            }
            preview = "\(object.count) 个字段"
        } else if let array = value as? [Any] {
            embeddedJSONKind = nil
            children = array.enumerated().map { index, child in
                makeNode(
                    value: child,
                    name: "\(index)",
                    path: "\(path)[\(index)]",
                    embeddedDepth: embeddedDepth
                )
            }
            preview = "\(array.count) 项"
        } else {
            embeddedJSONKind = nil
            children = []
            preview = compactDescription(value)
        }

        return JSONNode(
            id: path,
            name: name,
            path: path,
            kind: valueKind,
            preview: preview,
            copyValue: copyDescription(value),
            children: children,
            embeddedJSONKind: embeddedJSONKind
        )
    }

    private static func makeTable(from value: Any) -> JSONTable? {
        guard let array = value as? [Any], !array.isEmpty else {
            return nil
        }

        let objects = array.compactMap { $0 as? [String: Any] }
        guard objects.count == array.count else {
            return nil
        }

        var columns: [String] = []
        var knownColumns = Set<String>()
        for object in objects {
            for key in object.keys.sorted() where knownColumns.insert(key).inserted {
                columns.append(key)
            }
        }

        let rows = objects.map { object in
            Dictionary(uniqueKeysWithValues: columns.map { key in
                (key, object[key].map { compactDescription($0, limit: 500) } ?? "")
            })
        }

        return JSONTable(columns: columns, rows: rows)
    }

    private static func parseIssue(from error: Error, source: String) -> ParseIssue {
        let nsError = error as NSError
        let rawMessage = (nsError.userInfo["NSDebugDescription"] as? String) ?? nsError.localizedDescription
        let message = rawMessage
            .replacingOccurrences(of: "JSON text did not start with array or object and option to allow fragments not set.", with: "JSON 根节点无效")
            .replacingOccurrences(of: "The data couldn’t be read because it isn’t in the correct format.", with: "JSON 格式不正确")

        if let index = nsError.userInfo["NSJSONSerializationErrorIndex"] as? Int {
            let location = lineAndColumn(in: source, utf8Offset: index)
            return ParseIssue(message: message, line: location.line, column: location.column)
        }

        let pattern = #"line\s+(\d+),\s*column\s+(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(
            in: rawMessage,
            range: NSRange(rawMessage.startIndex..., in: rawMessage)
           ),
           let lineRange = Range(match.range(at: 1), in: rawMessage),
           let columnRange = Range(match.range(at: 2), in: rawMessage) {
            return ParseIssue(
                message: message,
                line: Int(rawMessage[lineRange]),
                column: Int(rawMessage[columnRange])
            )
        }

        return ParseIssue(message: message, line: nil, column: nil)
    }

    private static func lineAndColumn(in source: String, utf8Offset: Int) -> (line: Int, column: Int) {
        let prefix = source.utf8.prefix(max(0, min(utf8Offset, source.utf8.count)))
        let text = String(decoding: prefix, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return (max(1, lines.count), (lines.last?.count ?? 0) + 1)
    }

    private static func append(key: String, to path: String) -> String {
        let simpleKey = key.first?.isLetter == true
            && key.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
        if simpleKey {
            return "\(path).\(key)"
        }
        let escaped = key.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return "\(path)['\(escaped)']"
    }

    private static func csvCell(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
