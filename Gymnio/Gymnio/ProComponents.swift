import SwiftUI

// MARK: - PRO badge

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(.gymOnAccent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Color.gymAccent,
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
                            Color.gymAccent)
                    Text(store.t(titleKey))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.gymText)
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
                                .foregroundColor(.gymOnAccent)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 11)
                                .background(
                                    Color.gymAccent,
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
                        .fill(Color.gymAccent)
                        .frame(width: 46, height: 46)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gymOnAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(store.t("pro.cta.title"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.gymText)
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
                .fill(Color.gymAccent.opacity(scheme == .dark ? 0.20 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.gymAccent.opacity(0.4), lineWidth: 1)
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
                .foregroundColor(Color.gymText)
            if isPro { ProBadge() }
            Spacer()
        }
        .padding(.top, 4)
    }
}
