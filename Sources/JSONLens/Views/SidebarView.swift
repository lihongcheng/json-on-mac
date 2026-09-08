import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand

            VStack(spacing: 4) {
                ForEach(WorkspaceMode.allCases) { mode in
                    modeButton(mode)
                }
            }
            .padding(.horizontal, 10)

            Divider()
                .overlay(AppTheme.border)
                .padding(.vertical, 14)

            HStack {
                Text("最近")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(model.history.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 7)

            if model.history.isEmpty {
                Text("格式化或保存后显示快照")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(model.history) { snapshot in
                            historyRow(snapshot)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            Spacer(minLength: 12)

            Button {
                model.loadSample()
            } label: {
                Label("载入示例", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 9)
                    .frame(height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.textSecondary)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
            .padding(10)
            .help("恢复内置示例数据")
        }
        .frame(width: 194)
        .background(AppTheme.sidebar)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.accent)
                    .frame(width: 30, height: 30)
                Image(systemName: "curlybraces")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("JSON Lens")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("LOCAL WORKSPACE")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
    }

    private func modeButton(_ mode: WorkspaceMode) -> some View {
        Button {
            model.mode = mode
        } label: {
            HStack(spacing: 9) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 18)
                Text(mode.title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .foregroundStyle(model.mode == mode ? Color.black : AppTheme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(model.mode == mode ? AppTheme.accent : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func historyRow(_ snapshot: HistorySnapshot) -> some View {
        Button {
            model.restore(snapshot)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Text(snapshot.createdAt, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("恢复") {
                model.restore(snapshot)
            }
            Divider()
            Button("删除", role: .destructive) {
                model.removeHistory(snapshot)
            }
        }
    }
}
