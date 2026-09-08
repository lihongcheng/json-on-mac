import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.075, green: 0.078, blue: 0.082)
    static let sidebar = Color(red: 0.095, green: 0.098, blue: 0.104)
    static let panel = Color(red: 0.115, green: 0.118, blue: 0.124)
    static let panelRaised = Color(red: 0.145, green: 0.149, blue: 0.157)
    static let border = Color.white.opacity(0.09)
    static let textPrimary = Color(red: 0.93, green: 0.94, blue: 0.93)
    static let textSecondary = Color(red: 0.61, green: 0.63, blue: 0.62)
    static let accent = Color(red: 0.31, green: 0.82, blue: 0.59)
    static let amber = Color(red: 0.96, green: 0.70, blue: 0.28)
    static let coral = Color(red: 0.95, green: 0.40, blue: 0.36)
    static let cyan = Color(red: 0.30, green: 0.73, blue: 0.82)
    static let violet = Color(red: 0.69, green: 0.55, blue: 0.91)
}

extension JSONKind {
    var color: Color {
        switch self {
        case .object: AppTheme.accent
        case .array: AppTheme.cyan
        case .string: AppTheme.amber
        case .number: AppTheme.violet
        case .boolean: Color(red: 0.95, green: 0.49, blue: 0.58)
        case .null: AppTheme.textSecondary
        }
    }

    var systemImage: String {
        switch self {
        case .object: "curlybraces"
        case .array: "list.number"
        case .string: "textformat"
        case .number: "number"
        case .boolean: "switch.2"
        case .null: "nosign"
        }
    }
}

struct ToolbarIconButtonStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(active ? Color.black : AppTheme.textPrimary)
            .frame(width: 30, height: 28)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        active
                            ? AppTheme.accent
                            : (configuration.isPressed ? Color.white.opacity(0.12) : Color.clear)
                    )
            }
            .contentShape(Rectangle())
    }
}

struct CommandButtonStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(emphasized ? Color.black : AppTheme.textPrimary)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        emphasized
                            ? AppTheme.accent.opacity(configuration.isPressed ? 0.75 : 1)
                            : Color.white.opacity(configuration.isPressed ? 0.13 : 0.07)
                    )
            }
            .overlay {
                if !emphasized {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
            }
    }
}

struct StatusBadge: View {
    let isValid: Bool
    let isEmpty: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(isEmpty ? AppTheme.textSecondary : color)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(color.opacity(isEmpty ? 0.04 : 0.1), in: RoundedRectangle(cornerRadius: 4))
    }

    private var label: String {
        if isEmpty {
            return "等待输入"
        }
        return isValid ? "有效 JSON" : "格式错误"
    }

    private var color: Color {
        if isEmpty {
            return AppTheme.textSecondary
        }
        return isValid ? AppTheme.accent : AppTheme.coral
    }
}
