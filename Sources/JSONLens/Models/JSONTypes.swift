import Foundation

enum JSONKind: String, CaseIterable {
    case object
    case array
    case string
    case number
    case boolean
    case null

    var label: String {
        switch self {
        case .object: "Object"
        case .array: "Array"
        case .string: "String"
        case .number: "Number"
        case .boolean: "Boolean"
        case .null: "Null"
        }
    }
}

struct JSONNode: Identifiable {
    let id: String
    let name: String
    let path: String
    let kind: JSONKind
    let preview: String
    let copyValue: String
    let children: [JSONNode]
    let embeddedJSONKind: JSONKind?

    var count: Int? {
        if embeddedJSONKind != nil {
            return children.count
        }
        switch kind {
        case .object, .array:
            return children.count
        default:
            return nil
        }
    }

    var displayKind: JSONKind {
        embeddedJSONKind ?? kind
    }
}

struct JSONStatistics {
    var objects = 0
    var arrays = 0
    var keys = 0
    var strings = 0
    var numbers = 0
    var booleans = 0
    var nulls = 0
    var maxDepth = 0
    var byteCount = 0

    var values: Int {
        strings + numbers + booleans + nulls
    }

    var totalNodes: Int {
        objects + arrays + values
    }
}

struct ParseIssue: Equatable {
    let message: String
    let line: Int?
    let column: Int?
}

struct JSONQueryResult: Identifiable {
    let id = UUID()
    let path: String
    let kind: JSONKind
    let displayKind: JSONKind
    let displayValue: String
    let copyValue: String
    let isEmbeddedJSON: Bool
    let rawValue: Any
}

enum DiffKind: String, CaseIterable {
    case added
    case removed
    case modified

    var label: String {
        switch self {
        case .added: "新增"
        case .removed: "删除"
        case .modified: "变更"
        }
    }
}

struct JSONDiffEntry: Identifiable {
    let id = UUID()
    let path: String
    let kind: DiffKind
    let oldValue: String?
    let newValue: String?
}

struct JSONTable {
    let columns: [String]
    let rows: [[String: String]]
}

struct HistorySnapshot: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    let content: String
    let createdAt: Date
}
