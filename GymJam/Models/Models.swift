//
//  Models.swift
//  GymJam
//
//  SwiftData persistence models. All data is local-only (offline-first).
//  Cascade delete flows Cycle → Day → Segment → Exercise.
//  Relationship arrays in SwiftData are unordered, so every level carries an
//  explicit `displayOrder` and is sorted at read time.
//

import Foundation
import SwiftData

// MARK: - Workout Cycle

/// A single imported workout program (typically one training week).
/// Only one cycle is `isActive` at any time; older cycles are archived and
/// surfaced read-only under History.
@Model
final class WorkoutCycle {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date
    var weekNumber: Int?
    var dateImported: Date
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkoutDay.cycle)
    var days: [WorkoutDay]

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        weekNumber: Int? = nil,
        dateImported: Date = .now,
        isActive: Bool = true,
        days: [WorkoutDay] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.weekNumber = weekNumber
        self.dateImported = dateImported
        self.isActive = isActive
        self.days = days
    }

    /// Days sorted by their natural display order.
    var orderedDays: [WorkoutDay] {
        days.sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Days still visible on Home (not completed).
    var pendingDays: [WorkoutDay] {
        orderedDays.filter { !$0.isCompleted }
    }

    var completionPercentage: Int {
        guard !days.isEmpty else { return 0 }
        let done = days.filter { $0.isCompleted }.count
        return Int((Double(done) / Double(days.count) * 100.0).rounded())
    }
}

// MARK: - Workout Day

@Model
final class WorkoutDay {
    @Attribute(.unique) var id: UUID
    var date: Date
    var dayName: String
    var isCompleted: Bool
    var isRestDay: Bool
    var displayOrder: Int

    var cycle: WorkoutCycle?

    @Relationship(deleteRule: .cascade, inverse: \Segment.day)
    var segments: [Segment]

    init(
        id: UUID = UUID(),
        date: Date,
        dayName: String,
        isCompleted: Bool = false,
        isRestDay: Bool = false,
        displayOrder: Int,
        segments: [Segment] = []
    ) {
        self.id = id
        self.date = date
        self.dayName = dayName
        self.isCompleted = isCompleted
        self.isRestDay = isRestDay
        self.displayOrder = displayOrder
        self.segments = segments
    }

    var orderedSegments: [Segment] {
        segments.sorted { $0.displayOrder < $1.displayOrder }
    }

    var totalExercises: Int {
        segments.reduce(0) { $0 + $1.exercises.count }
    }

    var segmentNames: [String] {
        orderedSegments.map { $0.name }
    }
}

// MARK: - Segment

@Model
final class Segment {
    @Attribute(.unique) var id: UUID
    var name: String
    var displayOrder: Int

    var day: WorkoutDay?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.segment)
    var exercises: [Exercise]

    init(
        id: UUID = UUID(),
        name: String,
        displayOrder: Int,
        exercises: [Exercise] = []
    ) {
        self.id = id
        self.name = name
        self.displayOrder = displayOrder
        self.exercises = exercises
    }

    var orderedExercises: [Exercise] {
        exercises.sorted { $0.displayOrder < $1.displayOrder }
    }
}

// MARK: - Exercise

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    /// Stored verbatim as written by the coach — never rewritten.
    var name: String
    var sets: String?
    var reps: String?
    var duration: String?
    var rounds: String?
    var coachNotes: String?
    var displayOrder: Int

    var segment: Segment?

    init(
        id: UUID = UUID(),
        name: String,
        sets: String? = nil,
        reps: String? = nil,
        duration: String? = nil,
        rounds: String? = nil,
        coachNotes: String? = nil,
        displayOrder: Int
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.duration = duration
        self.rounds = rounds
        self.coachNotes = coachNotes
        self.displayOrder = displayOrder
    }

    /// YouTube search query per PRD: "<Exercise Name> Exercise".
    var tutorialQuery: String {
        "\(name) Exercise"
    }
}
