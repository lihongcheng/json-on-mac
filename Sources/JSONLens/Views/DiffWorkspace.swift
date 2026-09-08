import SwiftUI

struct DiffWorkspace: View {
    @ObservedObject var model: AppModel
    @State private var filter: DiffKind?

    var body: some View {
        VSplitView {
            HSplitView {
                JSONEditorPane(
                    title: "基准",
                    subtitle: model.currentFileURL?.lastPathComponent ?? "当前文档",
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
                .frame(minWidth: 360)

                JSONEditorPane(
                    title: "对比版本",
                    subtitle: nil,
                    text: $model.comparisonText,
                    issue: model.comparisonIssue,
                    isValid: model.isComparisonValid,
                    onFormat: model.formatComparison,
                    onOpen: model.openComparisonDocument,
                    onCopy: {
                        model.copy(model.comparisonText, message: "已复制右侧 JSON")
                    },
                    onPaste: model.pasteComparisonFromClipboard,
                    onClear: model.clearComparison,
                    onFileDrop: model.loadComparison(from:)
                )
                .frame(minWidth: 360)
            }
            .frame(minHeight: 280, idealHeight: 430)

            diffResultPane
                .frame(minHeight: 190, idealHeight: 280)
        }
    }

    private var diffResultPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("差异")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                countButton(nil, title: "全部", color: AppTheme.textPrimary)
                countButton(.added, title: "新增", color: AppTheme.accent)
                countButton(.removed, title: "删除", color: AppTheme.coral)
                countButton(.modified, title: "变更", color: AppTheme.amber)

                Spacer()

                Button {
                    model.swapDiffSides()
                } label: {
                    Label("交换", systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(CommandButtonStyle())
                .help("交换基准和对比版本")
            }
            .padding(.horizontal, 12)
            .frame(height: 44)

            Divider().overlay(AppTheme.border)

            if !model.isSourceValid || !model.isComparisonValid {
                ContentUnavailableView(
                    "等待两个有效 JSON",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("差异将在两侧内容有效后显示")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredEntries.isEmpty {
                ContentUnavailableView(
                    filter == nil ? "内容完全一致" : "此类型没有差异",
                    systemImage: "checkmark.circle",
                    description: Text(filter == nil ? "两个 JSON 的结构和值相同" : "切换筛选项查看其他变更")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredEntries) { entry in
                            diffRow(entry)
                        }
                    }
                }
            }
        }
        .background(AppTheme.panel)
    }

    private var filteredEntries: [JSONDiffEntry] {
        guard let filter else {
            return model.diffEntries
        }
        return model.diffEntries.filter { $0.kind == filter }
    }

    private func countButton(_ kind: DiffKind?, title: String, color: Color) -> some View {
        let count = kind.map { selectedKind in
            model.diffEntries.filter { $0.kind == selectedKind }.count
        } ?? model.diffEntries.count
        let isSelected = filter == kind

        return Button {
            filter = kind
        } label: {
            HStack(spacing: 5) {
                Text(title)
                Text("\(count)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .frame(height: 16)
                    .background(color.opacity(isSelected ? 0.2 : 0.08), in: RoundedRectangle(cornerRadius: 3))
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(isSelected ? color : AppTheme.textSecondary)
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background(isSelected ? color.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private func diffRow(_ entry: JSONDiffEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: diffIcon(entry.kind))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(diffColor(entry.kind))
                .frame(width: 20, height: 20)
                .background(diffColor(entry.kind).opacity(0.1), in: RoundedRectangle(cornerRadius: 4))

            Text(entry.path)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(minWidth: 180, maxWidth: 270, alignment: .leading)
                .textSelection(.enabled)

            if let oldValue = entry.oldValue {
                valueBlock(oldValue, color: AppTheme.coral, prefix: "-")
            } else {
                Spacer()
                    .frame(maxWidth: .infinity)
            }

            if let newValue = entry.newValue {
                valueBlock(newValue, color: AppTheme.accent, prefix: "+")
            } else {
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider().overlay(AppTheme.border.opacity(0.7))
        }
        .contextMenu {
            Button("复制路径") {
                model.copy(entry.path, message: "已复制路径")
            }
        }
    }

    private func valueBlock(_ value: String, color: Color, prefix: String) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Text(prefix)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(value)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(3)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.system(size: 10, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func diffColor(_ kind: DiffKind) -> Color {
        switch kind {
        case .added: AppTheme.accent
        case .removed: AppTheme.coral
        case .modified: AppTheme.amber
        }
    }

    private func diffIcon(_ kind: DiffKind) -> String {
        switch kind {
        case .added: "plus"
        case .removed: "minus"
        case .modified: "pencil"
        }
    }
}
