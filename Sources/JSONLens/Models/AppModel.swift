import AppKit
import Foundation
import SwiftUI

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case inspect
    case query
    case diff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inspect: "检查"
        case .query: "查询"
        case .diff: "对比"
        }
    }

    var systemImage: String {
        switch self {
        case .inspect: "doc.text.magnifyingglass"
        case .query: "scope"
        case .diff: "arrow.left.arrow.right"
        }
    }
}

enum ResultViewMode: String, CaseIterable, Identifiable {
    case tree
    case table
    case insights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tree: "树"
        case .table: "表格"
        case .insights: "概览"
        }
    }
}

enum EditorViewMode: String, CaseIterable, Identifiable {
    case source
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .source: "源码"
        case .preview: "层级"
        }
    }

    var systemImage: String {
        switch self {
        case .source: "pencil"
        case .preview: "list.bullet.indent"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var mode: WorkspaceMode = .inspect
    @Published var resultView: ResultViewMode = .tree
    @Published var sourceEditorView: EditorViewMode = .source
    @Published var comparisonEditorView: EditorViewMode = .source
    @Published var sourceText: String {
        didSet {
            refreshSource()
        }
    }
    @Published var comparisonText: String {
        didSet {
            refreshComparison()
        }
    }
    @Published var parsed: ParsedJSON?
    @Published var comparisonParsed: ParsedJSON?
    @Published var sourceIssue: ParseIssue?
    @Published var comparisonIssue: ParseIssue?
    @Published var queryExpression = "$.users[*].role"
    @Published var queryResults: [JSONQueryResult] = []
    @Published var queryIssue: String?
    @Published var diffEntries: [JSONDiffEntry] = []
    @Published var treeSearch = ""
    @Published var history: [HistorySnapshot] = []
    @Published var currentFileURL: URL?
    @Published var statusMessage: String?
    @Published var indentSize = 2 {
        didSet {
            refreshSource()
            refreshComparison()
        }
    }

    private let historyKey = "jsonlens.history.v1"

    init() {
        let environment = ProcessInfo.processInfo.environment
        sourceText = environment["JSONLENS_INITIAL_SOURCE"] ?? Self.sampleJSON
        comparisonText = Self.comparisonSampleJSON
        if let initialQuery = environment["JSONLENS_INITIAL_QUERY"] {
            queryExpression = initialQuery
        }
        if let initialMode = environment["JSONLENS_INITIAL_MODE"],
           let workspaceMode = WorkspaceMode(rawValue: initialMode) {
            mode = workspaceMode
        }
        if environment["JSONLENS_INITIAL_EDITOR_VIEW"] == EditorViewMode.preview.rawValue {
            sourceEditorView = .preview
        }
        loadHistory()
        refreshSource()
        refreshComparison()
    }

    var documentTitle: String {
        currentFileURL?.lastPathComponent ?? "未命名.json"
    }

    var isSourceValid: Bool {
        parsed != nil
    }

    var isComparisonValid: Bool {
        comparisonParsed != nil
    }

    var availableResultViews: [ResultViewMode] {
        parsed?.table == nil ? [.tree, .insights] : ResultViewMode.allCases
    }

    func refreshSource() {
        do {
            parsed = try JSONEngine.parse(sourceText, indent: indentSize)
            sourceIssue = nil
            if resultView == .table, parsed?.table == nil {
                resultView = .tree
            }
            runQuery()
            updateDiff()
        } catch JSONEngineError.empty {
            parsed = nil
            sourceIssue = nil
            queryResults = []
            diffEntries = []
        } catch let JSONEngineError.invalid(issue) {
            parsed = nil
            sourceIssue = issue
            queryResults = []
            diffEntries = []
        } catch {
            parsed = nil
            sourceIssue = ParseIssue(message: error.localizedDescription, line: nil, column: nil)
            queryResults = []
            diffEntries = []
        }
    }

    func refreshComparison() {
        do {
            comparisonParsed = try JSONEngine.parse(comparisonText, indent: indentSize)
            comparisonIssue = nil
            updateDiff()
        } catch JSONEngineError.empty {
            comparisonParsed = nil
            comparisonIssue = nil
            diffEntries = []
        } catch let JSONEngineError.invalid(issue) {
            comparisonParsed = nil
            comparisonIssue = issue
            diffEntries = []
        } catch {
            comparisonParsed = nil
            comparisonIssue = ParseIssue(message: error.localizedDescription, line: nil, column: nil)
            diffEntries = []
        }
    }

    func formatSource() {
        guard let parsed else {
            showStatus("请先修复 JSON 格式")
            return
        }
        sourceText = parsed.formatted
        sourceEditorView = .preview
        saveSnapshot(title: documentTitle)
        let count = parsed.embeddedJSONCount
        showStatus(count > 0 ? "已缩进展示 \(count) 个内嵌 JSON，原值未改变" : "已格式化")
    }

    func minifySource() {
        guard let minified = parsed?.minified else {
            showStatus("请先修复 JSON 格式")
            return
        }
        sourceText = minified
        sourceEditorView = .source
        saveSnapshot(title: documentTitle)
        showStatus("已压缩")
    }

    func formatComparison() {
        guard let comparisonParsed else {
            showStatus("右侧 JSON 格式无效")
            return
        }
        comparisonText = comparisonParsed.formatted
        comparisonEditorView = .preview
        let count = comparisonParsed.embeddedJSONCount
        showStatus(count > 0 ? "右侧已缩进展示 \(count) 个内嵌 JSON" : "右侧已格式化")
    }

    func copySource() {
        copyToPasteboard(sourceText)
        showStatus("已复制 JSON")
    }

    func copy(_ value: String, message: String = "已复制") {
        copyToPasteboard(value)
        showStatus(message)
    }

    func pasteFromClipboard() {
        guard let value = NSPasteboard.general.string(forType: .string) else {
            showStatus("剪贴板中没有文本")
            return
        }
        sourceText = value
        sourceEditorView = .source
        currentFileURL = nil
        showStatus("已从剪贴板粘贴")
    }

    func pasteComparisonFromClipboard() {
        guard let value = NSPasteboard.general.string(forType: .string) else {
            showStatus("剪贴板中没有文本")
            return
        }
        comparisonText = value
        comparisonEditorView = .source
        showStatus("已粘贴到右侧")
    }

    func clearSource() {
        sourceText = ""
        sourceEditorView = .source
        currentFileURL = nil
        showStatus("已清空")
    }

    func clearComparison() {
        comparisonText = ""
        comparisonEditorView = .source
        showStatus("已清空右侧")
    }

    func loadSample() {
        sourceText = Self.sampleJSON
        comparisonText = Self.comparisonSampleJSON
        sourceEditorView = .source
        comparisonEditorView = .source
        currentFileURL = nil
        showStatus("已载入示例")
    }

    func runQuery() {
        guard let root = parsed?.value else {
            queryResults = []
            queryIssue = nil
            return
        }

        do {
            queryResults = try JSONEngine.query(queryExpression, in: root)
            queryIssue = nil
        } catch {
            queryResults = []
            queryIssue = error.localizedDescription
        }
    }

    func updateDiff() {
        guard let left = parsed?.value, let right = comparisonParsed?.value else {
            diffEntries = []
            return
        }
        diffEntries = JSONEngine.diff(left, right)
    }

    func swapDiffSides() {
        let oldSource = sourceText
        sourceText = comparisonText
        comparisonText = oldSource
        sourceEditorView = .source
        comparisonEditorView = .source
        currentFileURL = nil
        showStatus("已交换两侧")
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.title = "打开 JSON"
        panel.allowedContentTypes = [.json, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        loadSource(from: url)
    }

    func openComparisonDocument() {
        let panel = NSOpenPanel()
        panel.title = "选择对比 JSON"
        panel.allowedContentTypes = [.json, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        loadComparison(from: url)
    }

    func loadComparison(from url: URL) {
        do {
            comparisonText = try String(contentsOf: url, encoding: .utf8)
            comparisonEditorView = .source
            showStatus("已载入 \(url.lastPathComponent)")
        } catch {
            showStatus("读取失败：\(error.localizedDescription)")
        }
    }

    func loadSource(from url: URL) {
        do {
            sourceText = try String(contentsOf: url, encoding: .utf8)
            sourceEditorView = .source
            currentFileURL = url
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            saveSnapshot(title: url.lastPathComponent)
            showStatus("已打开 \(url.lastPathComponent)")
        } catch {
            showStatus("读取失败：\(error.localizedDescription)")
        }
    }

    func saveDocument(saveAs: Bool = false) {
        if let currentFileURL, !saveAs {
            writeSource(to: currentFileURL)
            return
        }

        let panel = NSSavePanel()
        panel.title = "保存 JSON"
        panel.nameFieldStringValue = documentTitle
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        writeSource(to: url)
    }

    func exportCSV() {
        guard let table = parsed?.table else {
            showStatus("当前 JSON 不能转换为表格")
            return
        }

        let panel = NSSavePanel()
        panel.title = "导出 CSV"
        panel.nameFieldStringValue = currentFileURL?
            .deletingPathExtension()
            .appendingPathExtension("csv")
            .lastPathComponent ?? "data.csv"
        panel.allowedContentTypes = [.commaSeparatedText]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try JSONEngine.csv(from: table).write(to: url, atomically: true, encoding: .utf8)
            showStatus("CSV 已导出")
        } catch {
            showStatus("导出失败：\(error.localizedDescription)")
        }
    }

    func restore(_ snapshot: HistorySnapshot) {
        sourceText = snapshot.content
        sourceEditorView = .source
        currentFileURL = nil
        showStatus("已恢复 \(snapshot.title)")
    }

    func removeHistory(_ snapshot: HistorySnapshot) {
        history.removeAll { $0.id == snapshot.id }
        persistHistory()
    }

    func saveSnapshot(title: String) {
        guard parsed != nil else {
            return
        }

        history.removeAll { $0.content == sourceText }
        history.insert(
            HistorySnapshot(id: UUID(), title: title, content: sourceText, createdAt: Date()),
            at: 0
        )
        history = Array(history.prefix(10))
        persistHistory()
    }

    private func writeSource(to url: URL) {
        do {
            try sourceText.write(to: url, atomically: true, encoding: .utf8)
            currentFileURL = url
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            saveSnapshot(title: url.lastPathComponent)
            showStatus("已保存 \(url.lastPathComponent)")
        } catch {
            showStatus("保存失败：\(error.localizedDescription)")
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let snapshots = try? JSONDecoder().decode([HistorySnapshot].self, from: data) else {
            history = []
            return
        }
        history = snapshots
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else {
            return
        }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }

    static let sampleJSON = """
    {
      "project": {
        "name": "Aurora Mobile",
        "owner": "Growth Platform",
        "status": "active"
      },
      "release": {
        "version": "3.8.0",
        "date": "2026-09-08",
        "flags": {
          "smartSearch": true,
          "newCheckout": false
        }
      },
      "users": [
        {
          "id": 1001,
          "name": "Mina",
          "role": "product",
          "active": true
        },
        {
          "id": 1002,
          "name": "Kai",
          "role": "engineer",
          "active": true
        },
        {
          "id": 1003,
          "name": "Rui",
          "role": "design",
          "active": false
        }
      ],
      "metrics": {
        "dailyActiveUsers": 28410,
        "conversionRate": 0.184,
        "regions": ["CN", "SG", "US"]
      },
      "notes": null
    }
    """

    static let comparisonSampleJSON = """
    {
      "project": {
        "name": "Aurora Mobile",
        "owner": "Growth Platform",
        "status": "active"
      },
      "release": {
        "version": "3.9.0",
        "date": "2026-09-15",
        "flags": {
          "smartSearch": true,
          "newCheckout": true
        }
      },
      "users": [
        {
          "id": 1001,
          "name": "Mina",
          "role": "product",
          "active": true
        },
        {
          "id": 1002,
          "name": "Kai",
          "role": "engineer",
          "active": true
        },
        {
          "id": 1004,
          "name": "Noah",
          "role": "analyst",
          "active": true
        }
      ],
      "metrics": {
        "dailyActiveUsers": 30120,
        "conversionRate": 0.196,
        "regions": ["CN", "SG", "US", "JP"]
      },
      "notes": "Ready for staged rollout"
    }
    """
}
