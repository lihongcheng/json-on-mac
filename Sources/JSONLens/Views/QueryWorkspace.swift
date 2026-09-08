import SwiftUI

struct QueryWorkspace: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HSplitView {
            JSONEditorPane(
                title: "源 JSON",
                subtitle: model.currentFileURL?.path,
                text: $model.sourceText,
                issue: model.sourceIssue,
                isValid: model.isSourceValid,
                onFormat: model.formatSource,
                onOpen: model.openDocument,
                onCopy: model.copySource,
                onPaste: model.pasteFromClipboard,
                onClear: model.clearSource,
                onFileDrop: model.loadSource(from:)
            )
            .frame(minWidth: 380, idealWidth: 500)

            VStack(spacing: 0) {
                queryBar
                Divider().overlay(AppTheme.border)
                results
            }
            .background(AppTheme.panel)
            .frame(minWidth: 410, idealWidth: 590)
        }
    }

    private var queryBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            TextField("$.users[*].role", text: $model.queryExpression)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .onSubmit {
                    model.runQuery()
                }

            Menu {
                Button("$.users[*]") {
                    applyQuery("$.users[*]")
                }
                Button("$..id") {
                    applyQuery("$..id")
                }
                Button("$.project.name") {
                    applyQuery("$.project.name")
                }
                Button("$['release']['flags']") {
                    applyQuery("$['release']['flags']")
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 26)
            .help("查询示例")

            Button {
                model.runQuery()
            } label: {
                Label("运行", systemImage: "play.fill")
            }
            .buttonStyle(CommandButtonStyle(emphasized: true))
            .disabled(!model.isSourceValid)
            .opacity(model.isSourceValid ? 1 : 0.45)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(AppTheme.panel)
    }

    @ViewBuilder
    private var results: some View {
        if let issue = model.queryIssue {
            ContentUnavailableView(
                "查询表达式无效",
                systemImage: "exclamationmark.triangle",
                description: Text(issue)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !model.isSourceValid {
            ContentUnavailableView(
                "等待有效 JSON",
                systemImage: "curlybraces",
                description: Text("查询结果将在此处显示")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.queryResults.isEmpty {
            ContentUnavailableView(
                "没有匹配结果",
                systemImage: "magnifyingglass",
                description: Text(model.queryExpression)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("\(model.queryResults.count) 个结果")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Button {
                        let output = model.queryResults
                            .map { "\($0.path)\t\($0.displayValue)" }
                            .joined(separator: "\n")
                        model.copy(output, message: "已复制全部结果")
                    } label: {
                        Label("复制全部", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(CommandButtonStyle())
                }
                .padding(.horizontal, 12)
                .frame(height: 38)

                Divider().overlay(AppTheme.border)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.queryResults) { result in
                            resultRow(result)
                        }
                    }
                }
            }
        }
    }

    private func resultRow(_ result: JSONQueryResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: result.kind.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(result.kind.color)
                .frame(width: 18, height: 20)

            VStack(alignment: .leading, spacing: 5) {
                Text(result.path)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .textSelection(.enabled)
                Text(result.displayValue)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(result.kind.color.opacity(0.9))
                    .textSelection(.enabled)
                    .lineLimit(4)
            }

            Spacer(minLength: 8)

            Button {
                model.copy(result.displayValue, message: "已复制值")
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(ToolbarIconButtonStyle())
            .help("复制值")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider().overlay(AppTheme.border.opacity(0.7))
        }
    }

    private func applyQuery(_ query: String) {
        model.queryExpression = query
        model.runQuery()
    }
}
