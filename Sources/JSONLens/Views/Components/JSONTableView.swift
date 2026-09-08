import SwiftUI

struct JSONTableView: View {
    let table: JSONTable
    let onExport: () -> Void
    let onCopy: (String) -> Void

    private let rowNumberWidth: CGFloat = 44
    private let columnWidth: CGFloat = 180

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(table.rows.count) 行 × \(table.columns.count) 列")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button(action: onExport) {
                    Label("导出 CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(CommandButtonStyle())
            }
            .padding(.horizontal, 12)
            .frame(height: 42)

            Divider().overlay(AppTheme.border)

            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                            tableRow(index: index, row: row)
                        }
                    } header: {
                        tableHeader
                    }
                }
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: rowNumberWidth, alignment: .center)
            ForEach(table.columns, id: \.self) { column in
                Text(column)
                    .frame(width: columnWidth, alignment: .leading)
                    .padding(.horizontal, 10)
                    .help(column)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(AppTheme.textPrimary)
        .frame(height: 34)
        .background(AppTheme.panelRaised)
        .overlay(alignment: .bottom) {
            Divider().overlay(AppTheme.border)
        }
    }

    private func tableRow(index: Int, row: [String: String]) -> some View {
        HStack(spacing: 0) {
            Text("\(index + 1)")
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: rowNumberWidth, alignment: .center)

            ForEach(table.columns, id: \.self) { column in
                let value = row[column] ?? ""
                Text(value)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: columnWidth, alignment: .leading)
                    .padding(.horizontal, 10)
                    .help(value)
                    .contextMenu {
                        Button("复制单元格") {
                            onCopy(value)
                        }
                    }
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .frame(height: 31)
        .background(index.isMultiple(of: 2) ? Color.clear : Color.white.opacity(0.022))
        .overlay(alignment: .bottom) {
            Divider().overlay(AppTheme.border.opacity(0.6))
        }
    }
}
