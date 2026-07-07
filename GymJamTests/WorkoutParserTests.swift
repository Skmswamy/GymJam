//
//  WorkoutParserTests.swift
//  GymJamTests
//
//  QA persona: risk-based unit coverage of the deterministic parser — the
//  highest-risk component. Uses the modern Swift Testing framework.
//

import Testing
import Foundation
@testable import GymJam

struct WorkoutParserTests {

    // MARK: Failure paths

    @Test func emptyInputThrows() {
        #expect(throws: ParseError.empty) { try WorkoutParser.parse("   \n  ") }
    }

    // MARK: Week / day detection

    @Test func detectsWeekNumber() throws {
        let w = try WorkoutParser.parse("Week-14\nMonday\n1- Squat 3x8")
        #expect(w.weekNumber == 14)
    }

    @Test func detectsWeekWithSpace() throws {
        let w = try WorkoutParser.parse("Week 3\nMonday\nSquat")
        #expect(w.weekNumber == 3)
    }

    @Test func detectsDayHeaders() throws {
        let w = try WorkoutParser.parse("Monday\n1- Squat\nTuesday\n1- Bench")
        #expect(w.days.count == 2)
        #expect(w.days[0].dayName == "Monday")
        #expect(w.days[1].dayName == "Tuesday")
    }

    @Test func supportsWeekendRestOnOneLine() throws {
        let w = try WorkoutParser.parse("Saturday and Sunday\nRest Day")
        #expect(w.days.count == 2)
        #expect(w.days.allSatisfy { $0.isRestDay })
    }

    // MARK: Segments

    @Test func detectsSegments() throws {
        let w = try WorkoutParser.parse("Monday\nA- Strength\n1- Squat 3x8\nB- Power\n1- Jump 4x3")
        #expect(w.days[0].segments.count == 2)
        #expect(w.days[0].segments[0].name == "Strength")
        #expect(w.days[0].segments[1].name == "Power")
    }

    @Test func exercisesBeforeSegmentGoToGeneral() throws {
        let w = try WorkoutParser.parse("Monday\n1- Squat 3x8\n2- Bench 3x5")
        #expect(w.days[0].segments.first?.name == "General")
        #expect(w.days[0].segments.first?.exercises.count == 2)
    }

    // MARK: Exercise + metric extraction

    @Test func parsesSetsAndRepsFromCombined() throws {
        let w = try WorkoutParser.parse("Monday\nA- Strength\n1- DB Push Press 3x8")
        let ex = try #require(w.days[0].segments[0].exercises.first)
        #expect(ex.name == "DB Push Press")
        #expect(ex.sets == "3")
        #expect(ex.reps == "8")
    }

    @Test func parsesRoundsAndDuration() throws {
        let w = try WorkoutParser.parse("Monday\nB- Conditioning\n1- Row 500m 3 rounds 30s")
        let ex = try #require(w.days[0].segments[0].exercises.first)
        #expect(ex.rounds == "3")
        #expect(ex.duration != nil)
    }

    @Test func preservesNotes() throws {
        let w = try WorkoutParser.parse("Monday\nA- Strength\n1- Squat 3x8 use straps pause 3 seconds")
        let ex = try #require(w.days[0].segments[0].exercises.first)
        #expect(ex.notes?.contains("straps") == true)
    }

    @Test func keywordLinesAttachToExercise() throws {
        let text = """
        Monday
        A- Strength
        DB Push Press
        Sets 3
        Reps 8
        Notes
        Use straps
        """
        let w = try WorkoutParser.parse(text)
        let ex = try #require(w.days[0].segments[0].exercises.first)
        #expect(ex.name == "DB Push Press")
        #expect(ex.sets == "3")
        #expect(ex.reps == "8")
        #expect(ex.notes?.contains("Use straps") == true)
    }

    @Test func toleratesInconsistentNumbering() throws {
        let w = try WorkoutParser.parse("Monday\nA- Strength\n3- Squat\n3- Bench\nDeadlift")
        #expect(w.days[0].segments[0].exercises.count == 3)
    }

    // MARK: Rest days

    @Test func detectsRestDay() throws {
        let w = try WorkoutParser.parse("Wednesday\nRest")
        #expect(w.days[0].isRestDay)
        #expect(w.days[0].segments.isEmpty)
    }

    @Test func emptyDayBecomesRest() throws {
        let w = try WorkoutParser.parse("Monday\n1- Squat 3x8\nThursday")
        #expect(w.days[1].isRestDay)
    }

    // MARK: Real-world coach formats (validated against live samples)

    @Test func parsesRepsFirstConvention() throws {
        // Coach writes reps * sets, e.g. "8 reps *4sets".
        let w = try WorkoutParser.parse("Monday\nB- Accessory\n2- Pendulum Squat 8 reps *4sets")
        let ex = try #require(w.days[0].segments[0].exercises.first)
        #expect(ex.reps == "8")
        #expect(ex.sets == "4")
    }

    @Test func parsesEachSideShorthand() throws {
        // "12es*3sets" => 12 reps (each side), 3 sets.
        let w = try WorkoutParser.parse("Monday\nB- Accessory\n1- Db walking lunges 12 es*3sets")
        let ex = try #require(w.days[0].segments[0].exercises.first)
        #expect(ex.reps == "12")
        #expect(ex.sets == "3")
        #expect(ex.name == "Db walking lunges")
    }

    @Test func setsFirstShorthandStillWorks() throws {
        // Standard "3x8" remains sets x reps.
        let w = try WorkoutParser.parse("Monday\nA- Strength\n1- Bench 3x8")
        let ex = try #require(w.days[0].segments[0].exercises.first)
        #expect(ex.sets == "3")
        #expect(ex.reps == "8")
    }

    @Test func multiWordRecoveryLineIsRest() throws {
        let w = try WorkoutParser.parse("Thursday\nRest/ recovery/ walk/ Sauna/ Mobility/")
        #expect(w.days[0].isRestDay)
        #expect(w.days[0].segments.isEmpty)
    }

    @Test func multiDayRestOnOneHeader() throws {
        let w = try WorkoutParser.parse("Saturday And Sunday\nRest day")
        #expect(w.days.count == 2)
        #expect(w.days.allSatisfy { $0.isRestDay })
    }

    @Test func dropsEmptyDuplicateSegmentHeaders() throws {
        // "B- Strength" immediately followed by "B- hypertrophy" — the empty one is dropped.
        let w = try WorkoutParser.parse("Wednesday\nB- Strength\nB- hypertrophy\n1- Press 8 reps *3sets")
        #expect(w.days[0].segments.count == 1)
        #expect(w.days[0].segments[0].name == "hypertrophy")
    }

    @Test func onlyPresentWeekdaysBecomeDays() throws {
        // A Mon/Wed/Fri week yields exactly three days.
        let text = "Week-14\nMonday\n1- Squat 3x8\nWednesday\n1- Press 3x8\nFriday\n1- Pull 3x8"
        let w = try WorkoutParser.parse(text)
        #expect(w.days.count == 3)
        #expect(w.days.map { $0.dayName } == ["Monday", "Wednesday", "Friday"])
    }

    // MARK: Supersets (combined exercises joined by "+")

    @Test func splitsSupersetIntoTwoExercises() throws {
        let w = try WorkoutParser.parse(
            "Friday\nA- Strength\n8- Cyclist Squat to failure reps  + Bear crawl front and back 15reps  *2sets"
        )
        let exs = w.days[0].segments[0].exercises
        #expect(exs.count == 2)
        #expect(exs[0].name.hasPrefix("Cyclist Squat"))
        #expect(exs[1].name.hasPrefix("Bear crawl"))
        // Shared trailing set count applies to both.
        #expect(exs[0].sets == "2")
        #expect(exs[1].sets == "2")
        #expect(exs[1].reps == "15")
    }

    @Test func supersetPropagatesSetsAndKeepsPerPartReps() throws {
        let w = try WorkoutParser.parse(
            "Monday\nA- Power\n1- Box Jump 8 reps + reverse hyper 15 reps *3sets"
        )
        let exs = w.days[0].segments[0].exercises
        #expect(exs.count == 2)
        #expect(exs[0].reps == "8")
        #expect(exs[1].reps == "15")
        #expect(exs[0].sets == "3")
        #expect(exs[1].sets == "3")
    }

    @Test func doesNotSplitPlusInsideParentheses() throws {
        let w = try WorkoutParser.parse(
            "Monday\nA- Trunk\n45 secs Swiss ball (one clock wise + one anti clock wise)"
        )
        #expect(w.days[0].segments[0].exercises.count == 1)
    }

    // MARK: Date mapping

    @Test func firstDayMapsToStartDate() {
        let start = Calendar.current.startOfDay(for: .now)
        let days = [ParsedDay(dayName: "Wednesday"), ParsedDay(dayName: "Thursday")]
        let dates = WorkoutParser.mappedDates(for: days, startDate: start)
        #expect(dates.first == start)
        #expect(dates[1] > dates[0])
    }
}
