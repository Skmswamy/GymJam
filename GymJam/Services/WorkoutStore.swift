//
//  WorkoutStore.swift
//  GymJam
//
//  Owns all write transactions against SwiftData so views stay declarative.
//  Import runs atomically: parse first, and only persist on success so no
//  partial data is ever saved (PRD §11 "Do not save partial data").
//

import Foundation
import SwiftData

@MainActor
struct WorkoutStore {

    let context: ModelContext
    private let analytics = AnalyticsService.shared

    // MARK: - Import

    enum ImportError: LocalizedError {
        case parse(ParseError)

        var errorDescription: String? {
            // Single user-facing message per PRD §11.
            "Unable to understand workout.\nPlease verify formatting."
        }
    }

    /// Parses `text`, archives the current active cycle, and inserts the new one.
    /// Nothing is written unless parsing succeeds.
    @discardableResult
    func importWorkout(text: String, startDate: Date, endDate: Date) throws -> WorkoutCycle {
        let parsed: ParsedWorkout
        do {
            parsed = try WorkoutParser.parse(text)
        } catch let error as ParseError {
            analytics.track(.parserFailed, ["reason": String(describing: error)])
            analytics.track(.importFailed)
            throw ImportError.parse(error)
        }

        // Archive existing active cycle(s).
        archiveActiveCycles()

        // Build the new cycle graph.
        let cycle = WorkoutCycle(
            startDate: startDate,
            endDate: endDate,
            weekNumber: parsed.weekNumber,
            isActive: true
        )
        context.insert(cycle)

        let dates = WorkoutParser.mappedDates(for: parsed.days, startDate: startDate)
        for (dayIndex, parsedDay) in parsed.days.enumerated() {
            let day = WorkoutDay(
                date: dates[dayIndex],
                dayName: parsedDay.dayName,
                isRestDay: parsedDay.isRestDay,
                displayOrder: dayIndex
            )
            day.cycle = cycle
            context.insert(day)

            for (segIndex, parsedSeg) in parsedDay.segments.enumerated() {
                let segment = Segment(name: parsedSeg.name, displayOrder: segIndex)
                segment.day = day
                context.insert(segment)

                for (exIndex, parsedEx) in parsedSeg.exercises.enumerated() {
                    let exercise = Exercise(
                        name: parsedEx.name,
                        sets: parsedEx.sets,
                        reps: parsedEx.reps,
                        duration: parsedEx.duration,
                        rounds: parsedEx.rounds,
                        coachNotes: parsedEx.notes,
                        displayOrder: exIndex
                    )
                    exercise.segment = segment
                    context.insert(exercise)
                }
            }
        }

        try context.save()
        analytics.track(.workoutImported, [
            "days": String(parsed.days.count),
            "week": parsed.weekNumber.map(String.init) ?? "none"
        ])
        return cycle
    }

    // MARK: - Completion

    func completeDay(_ day: WorkoutDay) {
        day.isCompleted = true
        try? context.save()
        analytics.track(.workoutCompleted, ["day": day.dayName])
    }

    // MARK: - Archiving

    private func archiveActiveCycles() {
        let descriptor = FetchDescriptor<WorkoutCycle>(
            predicate: #Predicate { $0.isActive == true }
        )
        if let active = try? context.fetch(descriptor) {
            for cycle in active { cycle.isActive = false }
        }
    }
}
