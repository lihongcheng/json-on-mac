import SwiftUI

struct JSONInsightsView: View {
    let statistics: JSONStatistics
    let root: JSONNode
    let hasTable: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 118, maximum: 180), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    metric("节点", value: statistics.totalNodes, icon: "point.3.connected.trianglepath.dotted")
                    metric("字段", value: statistics.keys, icon: "key.horizontal")
                    metric("最大深度", value: statistics.maxDepth, icon: "arrow.down.to.line")
                    metric(
                        "原始大小",
                        value: ByteCountFormatter.string(
                            fromByteCount: Int64(statistics.byteCount),
                            countStyle: .file
                        ),
                        icon: "internaldrive"
                    )
                }

                sectionTitle("类型分布")

                VStack(spacing: 9) {
                    distributionRow("对象", count: statistics.objects, color: JSONKind.object.color)
                    distributionRow("数组", count: statistics.arrays, color: JSONKind.array.color)
                    distributionRow("字符串", count: statistics.strings, color: JSONKind.string.color)
                    distributionRow("数字", count: statistics.numbers, color: JSONKind.number.color)
                    distributionRow("布尔值", count: statistics.booleans, color: JSONKind.boolean.color)
                    distributionRow("空值", count: statistics.nulls, color: JSONKind.null.color)
                }

                sectionTitle("根节点结构")

                VStack(spacing: 0) {
                    ForEach(root.children.prefix(20)) { node in
                        HStack(spacing: 9) {
                            Image(systemName: node.kind.systemImage)
                                .foregroundStyle(node.kind.color)
                                .frame(width: 18)
                            Text(node.name)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(node.kind.label)
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(node.preview)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                                .frame(maxWidth: 180, alignment: .trailing)
                        }
                        .frame(height: 31)
                        .overlay(alignment: .bottom) {
                            Divider().overlay(AppTheme.border.opacity(0.7))
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: hasTable ? "tablecells.fill" : "tablecells")
                        .foregroundStyle(hasTable ? AppTheme.accent : AppTheme.textSecondary)
                    Text(hasTable ? "根数组可直接转换为表格并导出 CSV" : "表格视图适用于对象数组")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 12)
            }
            .padding(16)
        }
    }

    private func metric(_ title: String, value: Int, icon: String) -> some View {
        metric(title, value: NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal), icon: icon)
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24, height: 24)
                .background(AppTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .textCase(.uppercase)
    }

    private func distributionRow(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 48, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth(for: count, available: proxy.size.width))
                }
            }
            .frame(height: 5)

            Text("\(count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 38, alignment: .trailing)
        }
        .frame(height: 20)
    }

    private func barWidth(for count: Int, available: CGFloat) -> CGFloat {
        let maximum = max(
            statistics.objects,
            statistics.arrays,
            statistics.strings,
            statistics.numbers,
            statistics.booleans,
            statistics.nulls,
            1
        )
        return available * CGFloat(count) / CGFloat(maximum)
    }
}
