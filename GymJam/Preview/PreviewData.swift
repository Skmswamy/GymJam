//
//  PreviewData.swift
//  GymJam
//
//  In-memory SwiftData container seeded with a sample cycle for SwiftUI previews.
//  Not shipped in the running app's data — previews only.
//

import Foundation
import SwiftData

@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let schema = Schema([WorkoutCycle.self, WorkoutDay.self, Segment.self, Exercise.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        seed(container.mainContext)
        return container
    }()

    private static func seed(_ context: ModelContext) {
        let sample = """
        Week 14

        Monday
        A- Strength
        1- DB Push Press 3x8 use straps, pause 3 seconds
        2- Back Squat 4x5 tempo 3s down
        B- Conditioning
        1- Row 500m 3 rounds

        Tuesday
        A- Power
        1- Box Jumps 4x3
        2- Kettlebell Swings 3x12

        Wednesday
        Rest Day
        """
        try? WorkoutStore(context: context).importWorkout(
            text: sample,
            startDate: Calendar.current.startOfDay(for: .now),
            endDate: Calendar.current.date(byAdding: .day, value: 6, to: .now) ?? .now
        )
    }
}
