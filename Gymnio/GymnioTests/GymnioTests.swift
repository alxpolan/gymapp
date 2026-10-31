import Testing
@testable import Gymnio

struct PlaybookRulesTests {
    @Test func reviewPromptAfterSecondEntry() {
        #expect(AppStore.shouldRequestReview(entryCount: 2, distinctDays: 1, alreadyAsked: false))
    }

    @Test func reviewPromptStaysQuietOnFirstEntry() {
        #expect(!AppStore.shouldRequestReview(entryCount: 1, distinctDays: 1, alreadyAsked: false))
    }

    @Test func reviewPromptAskedOnlyOnce() {
        #expect(!AppStore.shouldRequestReview(entryCount: 60, distinctDays: 9, alreadyAsked: true))
    }

    @Test func workoutLimitBlocksFreeUsers() {
        #expect(PremiumManager.isWorkoutLimitReached(workoutCount: 2, limit: 2, isPro: false, suppressedRegion: false))
    }

    @Test func workoutLimitPassesBelowLimit() {
        #expect(!PremiumManager.isWorkoutLimitReached(workoutCount: 1, limit: 2, isPro: false, suppressedRegion: false))
    }

    @Test func workoutLimitPassesProUsers() {
        #expect(!PremiumManager.isWorkoutLimitReached(workoutCount: 99, limit: 2, isPro: true, suppressedRegion: false))
    }

    @Test func workoutLimitPassesSuppressedRegions() {
        #expect(!PremiumManager.isWorkoutLimitReached(workoutCount: 99, limit: 2, isPro: false, suppressedRegion: true))
    }

    @MainActor
    @Test func entriesGroupIntoWorkoutsByIdThenByDay() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86_400 * 3)
        let entries = [
            WorkoutEntry.create(exercise: "Squat", weight: 100, reps: 5, date: day1),
            WorkoutEntry.create(exercise: "Bench Press", weight: 60, reps: 8, date: day1.addingTimeInterval(600)),
            WorkoutEntry.create(exercise: "Squat", weight: 100, reps: 5, date: day2, workoutId: "w1"),
            WorkoutEntry.create(exercise: "Squat", weight: 105, reps: 3, date: day2.addingTimeInterval(300), workoutId: "w1")
        ]
        let workouts = Workout.group(entries)
        #expect(workouts.count == 2)
        #expect(workouts.first?.id == "w1")
        #expect(workouts.first?.setCount == 2)
        #expect(workouts.last?.exercises == ["Squat", "Bench Press"])
    }
}

struct SetKindTests {
    @Test func warmupsDoNotCountTowardsVolumeOrSets() {
        let entries = [
            WorkoutEntry.create(exercise: "Squat", weight: 40, reps: 10, workoutId: "w", kind: .warmup),
            WorkoutEntry.create(exercise: "Squat", weight: 100, reps: 5, workoutId: "w"),
            WorkoutEntry.create(exercise: "Squat", weight: 100, reps: 5, workoutId: "w", kind: .drop)
        ]
        let workout = Workout.group(entries)[0]
        #expect(workout.setCount == 2)
        #expect(workout.volumeKg == 1000)
        #expect(workout.entries.count == 3)
    }

    @Test func oldEntriesWithoutKindStillDecode() throws {
        let json = #"{"id":"1","exercise":"Squat","weight":100,"reps":5,"date":0}"#.data(using: .utf8)!
        let entry = try JSONDecoder().decode(WorkoutEntry.self, from: json)
        #expect(entry.kind == nil)
        #expect(!entry.isWarmup)
    }

    @Test func activeWorkoutWithoutPlannedSetsDecodes() throws {
        let json = #"{"id":"a","startedAt":0,"exercises":["Squat"]}"#.data(using: .utf8)!
        let active = try JSONDecoder().decode(ActiveWorkout.self, from: json)
        #expect(active.plannedSets.isEmpty)
    }
}
