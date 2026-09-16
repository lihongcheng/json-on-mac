import Foundation
import SwiftUI

struct JSONHierarchyPreview: View {
    let root: JSONNode
    let indentSize: Int

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                JSONHierarchyNodeView(
                    node: root,
                    depth: 0,
                    isArrayElement: false,
                    trailingComma: false,
                    indentSize: indentSize
                )
                .textSelection(.enabled)
                .frame(
                    minWidth: max(0, geometry.size.width - 20),
                    minHeight: max(0, geometry.size.height - 18),
                    alignment: .topLeading
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
        }
        .background(AppTheme.canvas)
    }
}

private struct JSONHierarchyNodeView: View {
    let node: JSONNode
    let depth: Int
    let isArrayElement: Bool
    let trailingComma: Bool
    let indentSize: Int

    @State private var isExpanded = true

    var body: some View {
        if isContainer {
            container
        } else {
            codeLine(scalarText)
        }
    }

    @ViewBuilder
    private var container: some View {
        if node.children.isEmpty {
            codeLine(indentation + memberPrefix + openingBracket + closingBracket + comma)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 14, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? "折叠" : "展开")

                    Text(
                        indentation
                            + memberPrefix
                            + openingBracket
                            + (isExpanded ? "" : " … \(closingBracket)\(comma)")
                    )
                    .font(codeFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .frame(height: 20)

                if isExpanded {
                    ForEach(Array(node.children.enumerated()), id: \.element.id) { index, child in
                        JSONHierarchyNodeView(
                            node: child,
                            depth: depth + 1,
                            isArrayElement: node.displayKind == .array,
                            trailingComma: index < node.children.count - 1,
                            indentSize: indentSize
                        )
                    }
                    codeLine(indentation + closingBracket + comma)
                }
            }
        }
    }

    private func codeLine(_ text: String) -> some View {
        HStack(spacing: 4) {
            Color.clear
                .frame(width: 14, height: 20)
            Text(text)
                .font(codeFont)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 20)
    }

    private var isContainer: Bool {
        node.displayKind == .object || node.displayKind == .array
    }

    private var openingBracket: String {
        node.displayKind == .array ? "[" : "{"
    }

    private var closingBracket: String {
        node.displayKind == .array ? "]" : "}"
    }

    private var memberPrefix: String {
        guard depth > 0, !isArrayElement else {
            return ""
        }
        return "\(quoted(node.name)) : "
    }

    private var scalarText: String {
        indentation + memberPrefix + scalarLiteral + comma
    }

    private var scalarLiteral: String {
        guard node.kind == .string else {
            return node.copyValue
        }
        return quoted(node.copyValue)
    }

    private var indentation: String {
        String(repeating: " ", count: depth * indentSize)
    }

    private var comma: String {
        trailingComma ? "," : ""
    }

    private var codeFont: Font {
        .system(size: 13, weight: .regular, design: .monospaced)
    }

    private func quoted(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: value,
            options: [.fragmentsAllowed, .withoutEscapingSlashes]
        ) else {
            return "\"\(value)\""
        }
        return String(decoding: data, as: UTF8.self)
    }
}
