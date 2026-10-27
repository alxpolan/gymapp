import SwiftUI

// MARK: - PRO badge

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                               startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
    }
}

// MARK: - Pro lock overlay (blurs gated content + CTA)

struct ProGate<Content: View>: View {
    let titleKey: String
    let subtitleKey: String
    let source: String
    @ViewBuilder let content: () -> Content

    @EnvironmentObject var premium: PremiumManager
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    @State private var showPaywall = false

    var body: some View {
        if premium.isPro {
            content()
        } else {
            ZStack {
                content()
                    .frame(maxHeight: 220, alignment: .top)
                    .clipped()
                    .blur(radius: 9)
                    .opacity(0.55)
                    .allowsHitTesting(false)

                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                           startPoint: .leading, endPoint: .trailing))
                    Text(store.t(titleKey))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                        .multilineTextAlignment(.center)
                    Text(store.t(subtitleKey))
                        .font(.system(size: 13))
                        .secondaryText()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    if !premium.isPaywallSuppressedRegion {
                        Button { showPaywall = true } label: {
                            Text(store.t("pro.unlock"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 11)
                                .background(
                                    LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                                   startPoint: .leading, endPoint: .trailing),
                                    in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .sheet(isPresented: $showPaywall) { PaywallView(source: source) }
        }
    }
}

// MARK: - Upgrade CTA card (marketing entry point)

struct UpgradeCTACard: View {
    let source: String

    @EnvironmentObject var store: AppStore
    @EnvironmentObject var premium: PremiumManager
    @Environment(\.colorScheme) var scheme
    @State private var showPaywall = false

    var body: some View {
        Group {
            if premium.isPaywallSuppressedRegion {
                EmptyView()
            } else {
                Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(store.t("pro.cta.title"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                        ProBadge()
                    }
                    Text(store.t("pro.cta.subtitle"))
                        .font(.system(size: 13))
                        .secondaryText()
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .secondaryText()
            }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "5B8DEF").opacity(scheme == .dark ? 0.20 : 0.12),
                             Color(hex: "A06BFF").opacity(scheme == .dark ? 0.14 : 0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LinearGradient(colors: [Color(hex: "5B8DEF").opacity(0.4), Color(hex: "A06BFF").opacity(0.4)],
                                       startPoint: .leading, endPoint: .trailing), lineWidth: 1)
        )
        .sheet(isPresented: $showPaywall) { PaywallView(source: source) }
    }
}

// MARK: - Section header with optional PRO badge

struct InsightSectionHeader: View {
    let title: String
    var isPro: Bool = false
    @Environment(\.colorScheme) var scheme
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
            if isPro { ProBadge() }
            Spacer()
        }
        .padding(.top, 4)
    }
}
