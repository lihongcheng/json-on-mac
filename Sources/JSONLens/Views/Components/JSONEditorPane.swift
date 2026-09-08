import SwiftUI
import UniformTypeIdentifiers

struct JSONEditorPane: View {
    let title: String
    let subtitle: String?
    @Binding var text: String
    let issue: ParseIssue?
    let isValid: Bool
    let onFormat: () -> Void
    let onOpen: (() -> Void)?
    let onCopy: (() -> Void)?
    let onPaste: (() -> Void)?
    let onClear: (() -> Void)?
    let onFileDrop: (URL) -> Void

    @State private var isDropTarget = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.border)
            editor
            Divider().overlay(AppTheme.border)
            footer
        }
        .background(AppTheme.panel)
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(AppTheme.accent.opacity(0.07))
                    .padding(3)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: $isDropTarget,
            perform: handleDrop(providers:)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            StatusBadge(
                isValid: isValid,
                isEmpty: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            if let onOpen {
                Button(action: onOpen) {
                    Image(systemName: "folder")
                }
                .buttonStyle(ToolbarIconButtonStyle())
                .help("打开文件")
            }

            Button(action: onFormat) {
                Image(systemName: "text.alignleft")
            }
            .buttonStyle(ToolbarIconButtonStyle())
            .help("格式化 JSON")

            if let onPaste {
                Button(action: onPaste) {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(ToolbarIconButtonStyle())
                .help("从剪贴板粘贴")
            }

            if let onCopy {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(ToolbarIconButtonStyle())
                .help("复制 JSON")
            }

            if let onClear {
                Button(action: onClear) {
                    Image(systemName: "trash")
                }
                .buttonStyle(ToolbarIconButtonStyle())
                .help("清空编辑器")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
    }

    private var editor: some View {
        TextEditor(text: $text)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundStyle(AppTheme.textPrimary)
            .scrollContentBackground(.hidden)
            .background(AppTheme.canvas)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .textEditorStyle(.plain)
            .disableAutocorrection(true)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let issue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.coral)
                Text(issueLocation(issue))
                    .foregroundStyle(AppTheme.coral)
                    .lineLimit(1)
                    .help(issue.message)
            } else if isValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("结构校验通过")
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("拖入 .json 文件或粘贴内容")
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text("\(lineCount) 行")
            Text(ByteCountFormatter.string(fromByteCount: Int64(text.utf8.count), countStyle: .file))
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 12)
        .frame(height: 30)
    }

    private var lineCount: Int {
        max(1, text.reduce(into: 1) { count, character in
            if character == "\n" {
                count += 1
            }
        })
    }

    private func issueLocation(_ issue: ParseIssue) -> String {
        if let line = issue.line, let column = issue.column {
            return "第 \(line) 行，第 \(column) 列：\(issue.message)"
        }
        return issue.message
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }

            guard let url else {
                return
            }
            Task { @MainActor in
                onFileDrop(url)
            }
        }
        return true
    }
}
