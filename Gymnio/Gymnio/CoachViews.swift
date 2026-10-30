import SwiftUI

// MARK: - Placeholder + error cards

/// Neutral placeholder while the coach answer loads (and behind the Pro lock). Contains no text.
struct CoachSkeletonCard: View {
    @Environment(\.colorScheme) var scheme

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                bar(width: 140, height: 14)
                bar(width: nil, height: 11)
                bar(width: 220, height: 11)
            }
        }
    }

    private func bar(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

struct CoachUnavailableCard: View {
    let retry: () -> Void
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(store.t("coach.unavailable"))
                    .font(.system(size: 14))
                    .secondaryText()
                Button(action: retry) {
                    Label(store.t("coach.retry"), systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.tint(scheme))
                }
            }
        }
    }
}

struct CoachDisclaimer: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Text(store.t("coach.disclaimer"))
            .font(.system(size: 11))
            .secondaryText()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Weekly recap (Home + Insights)

struct WeeklyRecapCard: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var premium: PremiumManager
    @State private var insight: CoachInsight?

    var body: some View {
        Group {
            if let insight {
                CoachRecapCard(insight: insight)
            }
        }
        .task(id: "\(premium.isPro)-\(store.entries.count)-\(store.language)") { await load() }
    }

    private func load() async {
        guard premium.isPro else { insight = nil; return }
        if let result = try? await CoachService.shared.weeklyRecap(store: store) { insight = result }
    }
}

// MARK: - Insights feed (Insights tab)

struct CoachFeedSection: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var premium: PremiumManager

    private enum Phase { case loading, loaded, failed }
    @State private var phase: Phase = .loading
    @State private var items: [CoachInsight] = []

    var body: some View {
        VStack(spacing: 8) {
            switch phase {
            case .loading:
                CoachSkeletonCard()
            case .failed:
                CoachUnavailableCard { Task { await load() } }
            case .loaded:
                if items.isEmpty {
                    CoachSkeletonCard()
                } else {
                    CoachFeedCard(insights: items)
                    CoachDisclaimer()
                }
            }
        }
        .task(id: "\(premium.isPro)-\(store.entries.count)-\(store.language)") { await load() }
    }

    private func load() async {
        // Free users only see the skeleton behind the lock, so no request is made for them.
        guard premium.isPro else { phase = .loading; return }
        if items.isEmpty { phase = .loading }
        do {
            items = try await CoachService.shared.insights(store: store)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = items.isEmpty ? .failed : .loaded
        }
    }
}

// MARK: - Next-set recommendation (exercise detail)

struct NextSetCoachCard: View {
    let group: ExerciseGroup
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var premium: PremiumManager

    private enum Phase { case loading, loaded, failed }
    @State private var phase: Phase = .loading
    @State private var insight: CoachInsight?

    var body: some View {
        VStack(spacing: 8) {
            switch phase {
            case .loaded:
                if let insight {
                    CoachRecapCard(insight: insight)
                } else {
                    CoachSkeletonCard()
                }
            case .failed:
                CoachUnavailableCard { Task { await load() } }
            case .loading:
                CoachSkeletonCard()
            }
        }
        .task(id: "\(premium.isPro)-\(group.entries.last?.id ?? "")-\(store.language)") { await load() }
    }

    private func load() async {
        guard premium.isPro else { phase = .loading; return }
        phase = .loading
        do {
            insight = try await CoachService.shared.nextSet(store: store, group: group)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }
}
