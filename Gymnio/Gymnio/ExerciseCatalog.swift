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
    static let all: [CatalogExercise] = [
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
