import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject var premium: PremiumManager
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Package?

    private let features: [(String, String)] = [
        ("chart.line.uptrend.xyaxis", "paywall.feature.metrics"),
        ("sparkles",                  "paywall.feature.coach"),
        ("chart.pie.fill",            "paywall.feature.muscle"),
        ("trophy.fill",               "paywall.feature.records"),
        ("square.and.arrow.up",       "paywall.feature.export"),
        ("infinity",                  "paywall.feature.future"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: gymGradientColors(scheme), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if premium.isPro {
                proActiveState
            } else {
                purchaseState
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                            .padding(16)
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            if selected == nil { selected = premium.annual ?? premium.packages.first }
            Task { await premium.loadOfferings() }
        }
        .onChange(of: premium.packages.count) { _, _ in
            if selected == nil { selected = premium.annual ?? premium.packages.first }
        }
    }

    // MARK: - Already Pro

    private var proActiveState: some View {
        VStack(spacing: 18) {
            Spacer()
            heroIcon
            Text(store.t("pro.active.title"))
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
            Text(store.t("pro.active.subtitle"))
                .font(.system(size: 15))
                .secondaryText()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            GlassBtn(store.t("common.done"), prominent: true) { dismiss() }
                .padding(.bottom, 30)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Purchase flow

    private var purchaseState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                heroIcon.padding(.top, 44)

                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(store.t("paywall.title"))
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                        ProBadge()
                    }
                    Text(store.t("paywall.subtitle"))
                        .font(.system(size: 15))
                        .secondaryText()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(features, id: \.1) { icon, key in
                        HStack(spacing: 12) {
                            Image(systemName: icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                                                startPoint: .leading, endPoint: .trailing))
                                .frame(width: 26)
                            Text(store.t(key))
                                .font(.system(size: 15))
                                .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if premium.packages.isEmpty {
                    ProgressView().padding(.vertical, 30)
                } else {
                    VStack(spacing: 10) {
                        ForEach(premium.packages, id: \.identifier) { pkg in
                            PlanRow(
                                package: pkg,
                                isSelected: selected?.identifier == pkg.identifier,
                                title: planTitle(pkg),
                                subtitle: planSubtitle(pkg),
                                badge: planBadge(pkg)
                            ) { selected = pkg }
                        }
                    }
                }

                Button { purchase() } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                                 startPoint: .leading, endPoint: .trailing))
                        if premium.purchaseInFlight {
                            ProgressView().tint(.white)
                        } else {
                            Text(ctaLabel)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 54)
                }
                .buttonStyle(.plain)
                .disabled(selected == nil || premium.purchaseInFlight)
                .opacity(selected == nil ? 0.6 : 1)

                HStack(spacing: 18) {
                    Button(store.t("paywall.restore")) { Task { await premium.restore() } }
                    Link(store.t("settings.terms"),
                         destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Link(store.t("settings.privacy"),
                         destination: URL(string: "https://gymnio.fringelo.com/privacy-policy/")!)
                }
                .font(.system(size: 12))
                .secondaryText()

                Text(store.t("paywall.disclaimer"))
                    .font(.system(size: 11))
                    .secondaryText()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 84, height: 84)
                .shadow(color: Color(hex: "5B8DEF").opacity(0.4), radius: 18, y: 8)
            Image(systemName: "bolt.fill")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Plan helpers

    private func planTitle(_ pkg: Package) -> String {
        switch pkg.packageType {
        case .annual:   return store.t("paywall.plan.annual")
        case .monthly:  return store.t("paywall.plan.monthly")
        case .lifetime: return store.t("paywall.plan.lifetime")
        default:        return pkg.storeProduct.localizedTitle
        }
    }

    private func planSubtitle(_ pkg: Package) -> String {
        let price = pkg.storeProduct.localizedPriceString
        switch pkg.packageType {
        case .annual:
            if let perMonth = premium.monthlyEquivalentString(for: pkg) {
                return String(format: store.t("paywall.perMonthYear"), price, perMonth)
            }
            return price
        case .monthly:
            return String(format: store.t("paywall.perMonth"), price)
        case .lifetime:
            return "\(price) · \(store.t("paywall.lifetimeNote"))"
        default:
            return price
        }
    }

    private func planBadge(_ pkg: Package) -> String? {
        if pkg.packageType == .annual, let pct = premium.annualSavingPercent {
            return String(format: store.t("paywall.save"), pct)
        }
        if pkg.packageType == .lifetime { return store.t("paywall.bestValue") }
        return nil
    }

    private var ctaLabel: String {
        if let sel = selected, hasFreeTrial(sel) { return store.t("paywall.cta.trial") }
        if selected?.packageType == .lifetime { return store.t("paywall.cta.lifetime") }
        return store.t("paywall.cta.continue")
    }

    private func hasFreeTrial(_ pkg: Package) -> Bool {
        pkg.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
    }

    private func purchase() {
        guard let pkg = selected else { return }
        Task {
            await premium.purchase(pkg)
            if premium.isPro { dismiss() }
        }
    }
}

// MARK: - Plan row

private struct PlanRow: View {
    let package: Package
    let isSelected: Bool
    let title: String
    let subtitle: String
    let badge: String?
    let action: () -> Void
    @Environment(\.colorScheme) var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected
                                     ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                                                    startPoint: .leading, endPoint: .trailing))
                                     : AnyShapeStyle(Color.secondary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .secondaryText()
                }
                Spacer(minLength: 0)
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "34C759"), in: Capsule())
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                                           startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.secondary.opacity(0.2)),
                            lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
