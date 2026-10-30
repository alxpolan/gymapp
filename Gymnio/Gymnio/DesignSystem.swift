import SwiftUI

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }

    /// Adaptive color without needing the color scheme at the call site.
    static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }
}

// MARK: - Gymnio design language: "iron and chalk"
//
// Graphite surfaces (warm paper in light mode), chalk-white text, ONE accent (signal orange) that is only
// used for the primary action, the selected state and records. Numbers are the hero. Cards are flat with a
// hairline, no gradients and no blur. Liquid Glass is left to system bars and floating controls.

extension Color {
    static let gymBackground    = Color.dynamic(light: "F4F1EA", dark: "0E0E10")
    static let gymSurface       = Color.dynamic(light: "FFFFFF", dark: "1A1A1D")
    static let gymSurfaceRaised = Color.dynamic(light: "ECE8DE", dark: "26262A")
    static let gymLine          = Color.dynamic(light: "DAD5C8", dark: "2E2E33")
    static let gymText          = Color.dynamic(light: "151515", dark: "F2F0EB")
    static let gymTextSecondary = Color.dynamic(light: "6B675E", dark: "9A978F")
    static let gymAccent        = Color.dynamic(light: "E8431A", dark: "FF5B2E")
    /// Text and icons on top of the accent color.
    static let gymOnAccent      = Color(hex: "141414")
    static let gymPositive      = Color.dynamic(light: "1E9E62", dark: "4CC38A")
    static let gymWarning       = Color.dynamic(light: "B7791F", dark: "F5A524")

    // Legacy names used across older screens, mapped onto the new palette.
    static let statBlue       = Color.gymAccent
    static let statBlueDark   = Color.gymAccent
    static let statRed        = Color.dynamic(light: "D6403F", dark: "E5484D")
    static let statTeal       = Color.gymPositive
    static let goldColor      = Color.gymWarning
    static let gymDestructive = Color(hex: "FF3B30")

    static func tint(_ scheme: ColorScheme) -> Color { .gymAccent }
}

// MARK: - Background

func gymGradientColors(_ scheme: ColorScheme) -> [Color] {
    [Color.gymBackground, Color.gymBackground]
}

// MARK: - Typography

extension View {
    /// Big tabular numbers for weights, reps and stats.
    func gymNumber(_ size: CGFloat, weight: Font.Weight = .heavy) -> some View {
        self.font(.system(size: size, weight: weight).monospacedDigit())
    }
}

// MARK: - Surfaces

extension View {
    /// Flat surface: solid fill with a hairline border.
    func flatSurface<S: Shape>(_ shape: S, fill: Color = .gymSurface, selected: Bool = false) -> some View {
        self
            .background(shape.fill(fill))
            .overlay(shape.stroke(selected ? Color.gymAccent : Color.gymLine, lineWidth: selected ? 1.5 : 1))
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    var leftAccent: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .flatSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .leading) {
                if leftAccent {
                    Capsule()
                        .fill(Color.gymAccent)
                        .frame(width: 3)
                        .padding(.vertical, 10)
                        .padding(.leading, 1)
                }
            }
    }
}

/// Old name, kept so existing screens compile while they are rebuilt.
typealias GlassCard<Content: View> = Card<Content>

// MARK: - Screen Title

struct ScreenTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 32, weight: .heavy))
            .tracking(-0.5)
            .foregroundColor(.gymText)
    }
}

// MARK: - Secondary Text

struct SecondaryText: ViewModifier {
    func body(content: Content) -> some View {
        content.foregroundColor(.gymTextSecondary)
    }
}
extension View { func secondaryText() -> some View { modifier(SecondaryText()) } }

// MARK: - Section header (small caps label)

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundColor(.gymTextSecondary)
            .padding(.horizontal, 2)
    }
}

// MARK: - Stat (big number + small label)

struct StatNumber: View {
    let value: String
    let label: String
    var emphasized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .gymNumber(26)
                .foregroundColor(emphasized ? .gymAccent : .gymText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gymTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Record badge

struct RecordBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "trophy.fill").font(.system(size: 9, weight: .bold))
            Text("PR").font(.system(size: 10, weight: .heavy))
        }
        .foregroundColor(.gymOnAccent)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.gymAccent))
    }
}

// MARK: - Circle button (toolbar actions)

struct GlassCircleButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.gymText)
                .frame(width: 40, height: 40)
                .flatSurface(Circle())
        }
    }
}

// MARK: - Primary button

struct AccentButton: View {
    let label: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.gymOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.gymAccent.opacity(disabled ? 0.4 : 1)))
        }
        .disabled(disabled)
    }
}

// MARK: - Secondary / prominent button

struct GlassBtn: View {
    let label: String
    let prominent: Bool
    let action: () -> Void

    init(_ label: String, prominent: Bool = false, action: @escaping () -> Void) {
        self.label = label; self.prominent = prominent; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(prominent ? .gymOnAccent : .gymText)
                .padding(.vertical, 13)
                .padding(.horizontal, 22)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(prominent ? Color.gymAccent : Color.gymSurfaceRaised))
        }
    }
}

// MARK: - Pagination Dots

struct PaginationDots: View {
    let total: Int
    let current: Int
    @Environment(\.colorScheme) var scheme
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.gymAccent : Color.gymLine)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Settings helpers

struct SettingsSectionTitle: View {
    let title: String
    @Environment(\.colorScheme) var scheme
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.gymTextSecondary)
            .tracking(0.6)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }
}

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let label: String
    @ViewBuilder let trailing: () -> Trailing
    @Environment(\.colorScheme) var scheme
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gymSurfaceRaised)
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(.gymAccent))
            Text(label)
                .font(.system(size: 17))
                .foregroundColor(.gymText)
            Spacer()
            trailing()
        }
        .padding(.vertical, 10)
    }
}

struct SettingsLinkRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let url: String
    var body: some View {
        Link(destination: URL(string: url)!) {
            SettingsRow(icon: icon, iconColor: iconColor, label: label) {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
