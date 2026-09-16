import SwiftUI

struct WorkspaceHeader: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.documentTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(modeSubtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Menu {
                Picker("缩进", selection: $model.indentSize) {
                    Text("2 空格").tag(2)
                    Text("4 空格").tag(4)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "increase.indent")
                    Text("\(model.indentSize)")
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 56)
            .help("格式化缩进")

            Button {
                model.openDocument()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(ToolbarIconButtonStyle())
            .help("打开 JSON")

            Button {
                model.saveDocument()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(ToolbarIconButtonStyle())
            .help("保存")

            Divider()
                .frame(height: 18)
                .overlay(AppTheme.border)

            Button {
                model.minifySource()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .buttonStyle(ToolbarIconButtonStyle())
            .help("压缩 JSON")

            Button {
                model.formatSource()
            } label: {
                Label("格式化", systemImage: "wand.and.stars")
            }
            .buttonStyle(CommandButtonStyle(emphasized: true))
            .disabled(!model.isSourceValid)
            .opacity(model.isSourceValid ? 1 : 0.45)
            .help("格式化并显示递归缩进层级，原始字符串值不变")
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(AppTheme.panel)
        .overlay(alignment: .bottom) {
            Divider().overlay(AppTheme.border)
        }
    }

    private var modeSubtitle: String {
        switch model.mode {
        case .inspect:
            "编辑、浏览并理解 JSON 结构"
        case .query:
            "使用路径表达式提取目标数据"
        case .diff:
            "比较两个 JSON 的结构和值"
        }
    }
}
