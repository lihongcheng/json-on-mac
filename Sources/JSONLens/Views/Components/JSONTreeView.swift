import SwiftUI

struct JSONTreeView: View {
    let root: JSONNode
    let search: String
    let onCopyPath: (String) -> Void
    let onCopyValue: (String) -> Void
    @State private var isRootExpanded = true

    var body: some View {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ScrollView {
                DisclosureGroup(isExpanded: $isRootExpanded) {
                    OutlineGroup(root.children, children: \.outlineChildren) { node in
                        JSONTreeRow(
                            node: node,
                            onCopyPath: onCopyPath,
                            onCopyValue: onCopyValue
                        )
                    }
                } label: {
                    JSONTreeRow(
                        node: root,
                        onCopyPath: onCopyPath,
                        onCopyValue: onCopyValue
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        } else {
            let matches = flattenedMatches(in: root, query: search)
            if matches.isEmpty {
                ContentUnavailableView(
                    "没有匹配项",
                    systemImage: "magnifyingglass",
                    description: Text("尝试搜索字段名、路径或值")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(matches) { node in
                            JSONTreeRow(
                                node: node,
                                showsFullPath: true,
                                onCopyPath: onCopyPath,
                                onCopyValue: onCopyValue
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func flattenedMatches(in node: JSONNode, query: String) -> [JSONNode] {
        var output: [JSONNode] = []
        let needle = query.lowercased()
        if node.name.lowercased().contains(needle)
            || node.path.lowercased().contains(needle)
            || node.preview.lowercased().contains(needle) {
            output.append(node)
        }
        for child in node.children {
            output.append(contentsOf: flattenedMatches(in: child, query: query))
        }
        return output
    }
}

private struct JSONTreeRow: View {
    let node: JSONNode
    var showsFullPath = false
    let onCopyPath: (String) -> Void
    let onCopyValue: (String) -> Void

    var body: some View {
        let displayKind = node.displayKind
        HStack(spacing: 8) {
            Image(systemName: displayKind.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(displayKind.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(showsFullPath ? node.path : node.name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                if showsFullPath {
                    Text(node.preview)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            if let embeddedKind = node.embeddedJSONKind {
                Text("String → \(embeddedKind.label)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.amber)
                    .padding(.horizontal, 5)
                    .frame(height: 18)
                    .background(AppTheme.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
            }

            if !showsFullPath {
                Text(node.preview)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(node.children.isEmpty ? displayKind.color.opacity(0.9) : AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let count = node.count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 5)
                    .frame(height: 18)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .frame(minHeight: 27)
        .contentShape(Rectangle())
        .contextMenu {
            Button("复制路径") {
                onCopyPath(node.path)
            }
            Button(node.embeddedJSONKind == nil ? "复制值" : "复制原始值") {
                onCopyValue(node.copyValue)
            }
        }
    }
}

private extension JSONNode {
    var outlineChildren: [JSONNode]? {
        children.isEmpty ? nil : children
    }
}
