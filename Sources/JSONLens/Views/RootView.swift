import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(model: model)

            Divider().overlay(AppTheme.border)

            VStack(spacing: 0) {
                WorkspaceHeader(model: model)

                Group {
                    switch model.mode {
                    case .inspect:
                        InspectWorkspace(model: model)
                    case .query:
                        QueryWorkspace(model: model)
                    case .diff:
                        DiffWorkspace(model: model)
                    }
                }
            }
        }
        .background(AppTheme.canvas)
        .overlay(alignment: .bottomTrailing) {
            if let status = model.statusMessage {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: model.statusMessage)
        .preferredColorScheme(.dark)
        .frame(minWidth: 980, minHeight: 650)
    }
}
