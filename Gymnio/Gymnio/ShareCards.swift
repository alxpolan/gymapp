import SwiftUI
import PostHog

// MARK: - "New record" card, rendered to an image for sharing

struct RecordShareCard: View {
    let exercise: String
    let weightText: String
    let reps: Int
    let repsLabel: String
    let badge: String
    let dateText: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                    Text(badge.uppercased())
                        .font(.system(size: 15, weight: .heavy))
                        .tracking(1.2)
                }
                .foregroundColor(Color.white.opacity(0.9))

                Spacer()

                Text(exercise)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                Text(weightText)
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("× \(reps) \(repsLabel)")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.9))

                Spacer()

                HStack {
                    Text(dateText)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.8))
                    Spacer()
                    Text("Gymnio")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.white)
                }
            }
            .padding(28)
        }
        .frame(width: 360, height: 450)
    }

    @MainActor
    static func render(_ card: RecordShareCard) -> UIImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }
}

// MARK: - Share button for a personal-best entry

struct RecordShareButton: View {
    let entry: WorkoutEntry
    @EnvironmentObject var store: AppStore
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: Image(uiImage: image),
                          preview: SharePreview(entry.exercise, image: Image(uiImage: image))) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17))
                        .foregroundColor(Color.tint(.light))
                        .padding(8)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    PostHogSDK.shared.capture("record_share_tapped", properties: ["exercise": entry.exercise])
                })
            }
        }
        .task(id: entry.id) {
            let formatter = DateFormatter()
            formatter.locale = store.locale
            formatter.dateStyle = .medium
            let card = RecordShareCard(
                exercise: entry.exercise,
                weightText: "\(formatWeightValue(store.displayWeight(entry.weight))) \(store.unitLabel)",
                reps: entry.reps,
                repsLabel: store.t("common.reps"),
                badge: store.t("detail.pb"),
                dateText: formatter.string(from: entry.date))
            image = RecordShareCard.render(card)
        }
    }
}
