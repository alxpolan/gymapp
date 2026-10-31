import Foundation
import SwiftUI
import AVKit
import AVFoundation

// MARK: - Exercise catalog

struct CatalogExercise: Identifiable {
    let fileBase: String
    let displayName: String
    var id: String { fileBase }
}

enum ExerciseCatalog {
    /// Every exercise with a demo video: the names listed here plus any other `*.mp4` found in the app bundle,
    /// so dropping `pull_ups.mp4` into the ExerciseVideos folder is enough to add "Pull Ups".
    static let all: [CatalogExercise] = {
        var result = listed
        var seen = Set(result.map { normalize($0.fileBase) })
        let urls = (Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: "ExerciseVideos") ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil) ?? [])
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let base = url.deletingPathExtension().lastPathComponent
            guard seen.insert(normalize(base)).inserted else { continue }
            let name = base.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
            result.append(CatalogExercise(fileBase: base, displayName: name))
        }
        return result
    }()

    private static let listed: [CatalogExercise] = [
        CatalogExercise(fileBase: "bench_press", displayName: "Bench Press"),
        CatalogExercise(fileBase: "bulgarian_split_squat", displayName: "Bulgarian Split Squat"),
        CatalogExercise(fileBase: "cable_crossover", displayName: "Cable Crossover"),
        CatalogExercise(fileBase: "chest_press_machine", displayName: "Chest Press Machine"),
        CatalogExercise(fileBase: "dips", displayName: "Dips"),
        CatalogExercise(fileBase: "dumbbell_fly", displayName: "Dumbbell Fly"),
        CatalogExercise(fileBase: "good_mornings", displayName: "Good Mornings"),
        CatalogExercise(fileBase: "hip_thrust", displayName: "Hip Thrust"),
        CatalogExercise(fileBase: "incline_dumbbell_press", displayName: "Incline Dumbbell Press"),
        CatalogExercise(fileBase: "leg_extension", displayName: "Leg Extension"),
        CatalogExercise(fileBase: "leg_press", displayName: "Leg Press"),
        CatalogExercise(fileBase: "lunges", displayName: "Lunges"),
        CatalogExercise(fileBase: "lying_leg_curl", displayName: "Lying Leg Curl"),
        CatalogExercise(fileBase: "pushups", displayName: "Push-Ups"),
        CatalogExercise(fileBase: "romanian_deadlift", displayName: "Romanian Deadlift"),
        CatalogExercise(fileBase: "seated_calf_raise", displayName: "Seated Calf Raise"),
        CatalogExercise(fileBase: "squat", displayName: "Squat"),
        CatalogExercise(fileBase: "standing_calf_raise", displayName: "Standing Calf Raise"),
        CatalogExercise(fileBase: "step_ups", displayName: "Step-Ups"),
        CatalogExercise(fileBase: "sumo_deadlift", displayName: "Sumo Deadlift"),
    ]

    static func videoURL(for exerciseName: String) -> URL? {
        let key = normalize(exerciseName)
        guard let match = all.first(where: { normalize($0.displayName) == key || normalize($0.fileBase) == key }) else { return nil }
        if let url = Bundle.main.url(forResource: match.fileBase, withExtension: "mp4", subdirectory: "ExerciseVideos") { return url }
        return Bundle.main.url(forResource: match.fileBase, withExtension: "mp4")
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

// MARK: - Exercise video

struct ExerciseVideoView: View {
    let url: URL

    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VideoPlayer(player: player)
            .frame(height: 220)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 0.5)
            )
            .onAppear {
                let item = AVPlayerItem(url: url)
                let queue = AVQueuePlayer(playerItem: item)
                looper = AVPlayerLooper(player: queue, templateItem: item)
                player = queue
                queue.play()
            }
            .onDisappear {
                player?.pause()
                looper = nil
                player = nil
            }
    }
}

// MARK: - Exercise picture (first frame of the demo video)

@MainActor
final class ExerciseThumbCache {
    static let shared = ExerciseThumbCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for exercise: String) async -> UIImage? {
        guard let url = ExerciseCatalog.videoURL(for: exercise) else { return nil }
        let key = url.lastPathComponent as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 360, height: 360)
        guard let result = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)) else { return nil }
        let image = UIImage(cgImage: result.image)
        cache.setObject(image, forKey: key)
        return image
    }
}

/// Square picture of an exercise; without a video it shows the muscle group icon.
struct ExerciseThumb: View {
    let name: String
    var size: CGFloat = 52
    @State private var image: UIImage?
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        ZStack {
            shape.fill(Color.gymSurfaceRaised)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: store.muscleGroup(for: name).systemImage)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.gymTextSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.stroke(Color.gymLine.opacity(0.5), lineWidth: 0.5))
        .task(id: "\(name)|\(store.exerciseMeta[name]?.photo ?? "")") {
            if let own = store.photo(for: name) { image = own } else { image = await ExerciseThumbCache.shared.image(for: name) }
        }
    }
}
