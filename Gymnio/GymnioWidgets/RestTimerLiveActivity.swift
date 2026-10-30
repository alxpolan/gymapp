import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            RestTimerLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.07, green: 0.09, blue: 0.14))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.restLabel, systemImage: "timer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.36, green: 0.55, blue: 0.94))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestCountdown(context: context, size: 28)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.attributes.exerciseName)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(1)
                        RestProgress(context: context)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(Color(red: 0.36, green: 0.55, blue: 0.94))
            } compactTrailing: {
                RestCountdown(context: context, size: 14)
                    .frame(width: 46)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(Color(red: 0.36, green: 0.55, blue: 0.94))
            }
        }
    }
}

// MARK: - Lock screen

struct RestTimerLockScreenView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.restLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.36, green: 0.55, blue: 0.94))
                    Text(context.attributes.exerciseName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer()
                RestCountdown(context: context, size: 34)
            }
            RestProgress(context: context)
        }
        .padding(16)
    }
}

// MARK: - Pieces

/// Counts down on its own (rendered by the system), shows the "over" label once it ran out or went stale.
struct RestCountdown: View {
    let context: ActivityViewContext<RestTimerAttributes>
    let size: CGFloat

    var body: some View {
        Group {
            if context.isStale || context.state.endDate <= Date() {
                Text(context.attributes.overLabel)
                    .font(.system(size: size * 0.5, weight: .bold))
                    .multilineTextAlignment(.trailing)
            } else {
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .font(.system(size: size, weight: .bold).monospacedDigit())
                    .multilineTextAlignment(.trailing)
            }
        }
        .foregroundColor(.white)
    }
}

struct RestProgress: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        if context.isStale || context.state.endDate <= Date() {
            ProgressView(value: 1)
                .tint(Color(red: 0.31, green: 0.80, blue: 0.77))
        } else {
            ProgressView(timerInterval: context.state.startDate...context.state.endDate, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(Color(red: 0.36, green: 0.55, blue: 0.94))
        }
    }
}
