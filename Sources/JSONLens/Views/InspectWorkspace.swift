import SwiftUI

struct InspectWorkspace: View {
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
            .frame(minWidth: 390, idealWidth: 520)

            resultPane
                .frame(minWidth: 380, idealWidth: 560)
        }
    }

    private var resultPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("结构视图")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if model.resultView == .tree {
                    searchField
                        .frame(width: 190)
                }

                Picker("视图", selection: $model.resultView) {
                    ForEach(model.availableResultViews) { view in
                        Text(view.title).tag(view)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: model.parsed?.table == nil ? 128 : 185)
            }
            .padding(.horizontal, 12)
            .frame(height: 48)

            Divider().overlay(AppTheme.border)

            if let parsed = model.parsed {
                resultContent(parsed)
            } else {
                ContentUnavailableView(
                    model.sourceIssue == nil ? "等待 JSON" : "无法解析",
                    systemImage: model.sourceIssue == nil ? "curlybraces" : "exclamationmark.triangle",
                    description: Text(
                        model.sourceIssue == nil
                            ? "输入、粘贴或拖入 JSON 文件"
                            : "修复编辑器中标记的格式问题"
                    )
                )
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppTheme.panel)
    }

    @ViewBuilder
    private func resultContent(_ parsed: ParsedJSON) -> some View {
        switch model.resultView {
        case .tree:
            JSONTreeView(
                root: parsed.rootNode,
                search: model.treeSearch,
                onCopyPath: { model.copy($0, message: "已复制路径") },
                onCopyValue: { model.copy($0, message: "已复制值") }
            )
        case .table:
            if let table = parsed.table {
                JSONTableView(
                    table: table,
                    onExport: model.exportCSV,
                    onCopy: { model.copy($0, message: "已复制单元格") }
                )
            }
        case .insights:
            JSONInsightsView(
                statistics: parsed.statistics,
                root: parsed.rootNode,
                hasTable: parsed.table != nil
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
            TextField("搜索键、路径或值", text: $model.treeSearch)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textPrimary)
            if !model.treeSearch.isEmpty {
                Button {
                    model.treeSearch = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textSecondary)
                .help("清除搜索")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 27)
        .background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}
