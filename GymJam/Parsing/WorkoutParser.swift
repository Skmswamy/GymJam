//
//  WorkoutParser.swift
//  GymJam
//
//  Deterministic (no-AI) parser that converts a coach's free-text workout
//  message into structured, framework-independent value types. Kept free of
//  SwiftData/UIKit imports so it is fully unit-testable in isolation.
//
//  Contract (see README "Parser rules"):
//   • Week header:     "Week 1", "Week-13"          → cycle week number
//   • Day header:      Monday…Sunday (any case, abbrev ok); may list several
//                      days joined by "and"/"&"/"/"; "Rest"/"Recovery" marks rest
//   • Segment header:  "A- Strength", "B - Power"    (single leading letter)
//   • Exercise line:   "1- DB Press 3x8", or any non-header line
//   • Superset line:   "A 8 reps + B 15 reps *3sets" → two exercises (shared sets)
//   • Metrics parsed inline: 3x8 (sets×reps), "8 reps *4sets" (reps×sets),
//                            "12es" (each-side reps), "3 sets", "30s", "3 rounds"
//   • Keyword lines (Sets/Reps/Rounds/Duration/Notes) attach to current exercise
//   • Anything unclassified is preserved as coach notes — never discarded.
//

import Foundation

// MARK: - Parsed value types (framework-free)

struct ParsedExercise: Equatable {
    var name: String
    var sets: String?
    var reps: String?
    var duration: String?
    var rounds: String?
    var notes: String?
}

struct ParsedSegment: Equatable {
    var name: String
    var exercises: [ParsedExercise] = []
}

struct ParsedDay: Equatable {
    var dayName: String
    var isRestDay: Bool = false
    var segments: [ParsedSegment] = []
}

struct ParsedWorkout: Equatable {
    var weekNumber: Int?
    var days: [ParsedDay] = []
}

enum ParseError: Error, Equatable {
    /// Text was blank.
    case empty
    /// No recognizable workout structure (no days and no exercises).
    case unrecognized
}

// MARK: - Parser

enum WorkoutParser {

    private static let weekdayOrder: [String: Int] = [
        "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5,
        "friday": 6, "saturday": 7, "sunday": 1
    ]

    /// Full + common abbreviations → canonical display name.
    private static let weekdayAliases: [String: String] = [
        "monday": "Monday", "mon": "Monday",
        "tuesday": "Tuesday", "tue": "Tuesday", "tues": "Tuesday",
        "wednesday": "Wednesday", "wed": "Wednesday",
        "thursday": "Thursday", "thu": "Thursday", "thur": "Thursday", "thurs": "Thursday",
        "friday": "Friday", "fri": "Friday",
        "saturday": "Saturday", "sat": "Saturday",
        "sunday": "Sunday", "sun": "Sunday"
    ]

    private static let restKeywords = ["rest", "recovery", "off day", "rest day", "recovery day"]

    // MARK: Public entry point

    /// Parse coach text into a structured workout.
    /// - Throws: `ParseError.empty` or `.unrecognized` (caller must not persist partial data).
    static func parse(_ raw: String) throws -> ParsedWorkout {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ParseError.empty }

        var workout = ParsedWorkout()
        var notesMode = false // set after a bare "Notes" line

        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            // 1) Week header
            if let week = weekNumber(from: line) {
                if workout.weekNumber == nil { workout.weekNumber = week }
                notesMode = false
                continue
            }

            // 2) Day header (possibly multiple days, possibly rest)
            if let dayHeader = dayHeader(from: line) {
                notesMode = false
                for name in dayHeader.dayNames {
                    workout.days.append(ParsedDay(dayName: name, isRestDay: dayHeader.isRest))
                }
                continue
            }

            // Everything below needs a current day. If a coach starts straight
            // into exercises with no day header, create an untitled day.
            if workout.days.isEmpty {
                workout.days.append(ParsedDay(dayName: "Workout"))
            }
            let dayIndex = workout.days.count - 1

            // 3) Bare rest marker inside/under a day
            if isBareRest(line) {
                workout.days[dayIndex].isRestDay = true
                workout.days[dayIndex].segments = []
                notesMode = false
                continue
            }

            // 4) Segment header ("A- Strength")
            if let segmentName = segmentName(from: line) {
                workout.days[dayIndex].segments.append(ParsedSegment(name: segmentName))
                notesMode = false
                continue
            }

            // 5) Keyword field line ("Sets 3", "Notes", "Reps 8")
            if let field = fieldLine(from: line) {
                notesMode = attach(field: field, to: &workout, dayIndex: dayIndex)
                continue
            }

            // 6) Note continuation (immediately after a bare "Notes" line)
            if notesMode, appendNote(line, to: &workout, dayIndex: dayIndex) {
                continue
            }

            // 7) Otherwise: a new exercise line (may expand to a superset).
            let exercises = makeExercises(from: line)
            ensureSegment(in: &workout, dayIndex: dayIndex)
            let segIndex = workout.days[dayIndex].segments.count - 1
            workout.days[dayIndex].segments[segIndex].exercises.append(contentsOf: exercises)
            notesMode = false
        }

        // Drop empty segments left behind by duplicate/blank section headers
        // (e.g. a "B- Strength" line immediately followed by "B- Hypertrophy").
        for i in workout.days.indices {
            workout.days[i].segments.removeAll { $0.exercises.isEmpty }
        }

        // Empty days become rest days (PRD edge case).
        for i in workout.days.indices where
            workout.days[i].segments.allSatisfy({ $0.exercises.isEmpty }) {
            workout.days[i].isRestDay = true
            workout.days[i].segments = []
        }

        let hasContent = workout.days.contains {
            $0.isRestDay || $0.segments.contains { !$0.exercises.isEmpty }
        }
        guard hasContent else { throw ParseError.unrecognized }

        return workout
    }

    // MARK: Date mapping

    /// Assign a calendar date to each parsed day.
    /// The first day maps to `startDate`; each subsequent day advances to the
    /// next occurrence of its weekday (falling back to +1 day when unknown).
    static func mappedDates(
        for days: [ParsedDay],
        startDate: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: startDate)

        for (index, day) in days.enumerated() {
            if index == 0 {
                result.append(cursor)
                continue
            }
            let previous = result[index - 1]
            if let target = weekdayOrder[day.dayName.lowercased()] {
                cursor = nextDate(after: previous, weekday: target, calendar: calendar)
            } else {
                cursor = calendar.date(byAdding: .day, value: 1, to: previous) ?? previous
            }
            result.append(cursor)
        }
        return result
    }

    private static func nextDate(after date: Date, weekday: Int, calendar: Calendar) -> Date {
        var next = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        for _ in 0..<7 {
            if calendar.component(.weekday, from: next) == weekday { return next }
            next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
        }
        return next
    }

    // MARK: - Line classifiers

    private static func weekNumber(from line: String) -> Int? {
        guard let match = firstMatch(#"^week[\s._-]*([0-9]{1,3})\b"#, in: line.lowercased()) else {
            return nil
        }
        return Int(match)
    }

    private struct DayHeader { var dayNames: [String]; var isRest: Bool }

    /// A line is a day header when its first token is a weekday name.
    private static func dayHeader(from line: String) -> DayHeader? {
        let lower = line.lowercased()
        let firstToken = lower
            .components(separatedBy: CharacterSet(charactersIn: " \t:-–,"))
            .first(where: { !$0.isEmpty }) ?? ""
        guard weekdayAliases[firstToken] != nil else { return nil }

        // Collect every weekday mentioned, in order of appearance.
        var found: [String] = []
        let tokens = lower.components(separatedBy: CharacterSet.alphanumerics.inverted)
        for token in tokens {
            if let canonical = weekdayAliases[token], !found.contains(canonical) {
                found.append(canonical)
            }
        }
        let isRest = restKeywords.contains { lower.contains($0) }
        return DayHeader(dayNames: found.isEmpty ? [line] : found, isRest: isRest)
    }

    private static func isBareRest(_ line: String) -> Bool {
        let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
        if restKeywords.contains(lower) { return true }
        // Multi-word recovery lines, e.g. "Rest/ recovery/ walk/ Sauna/ Mobility/".
        // A rest marker starts with rest/recovery and contains no numbers
        // (so a real exercise like "Rest-pause bench 8 reps" is not swallowed).
        let hasDigit = lower.rangeOfCharacter(from: .decimalDigits) != nil
        if !hasDigit, lower.hasPrefix("rest") || lower.hasPrefix("recovery") {
            return true
        }
        return false
    }

    /// "A- Strength" / "B - Power". Single leading letter distinguishes a
    /// segment from a numbered exercise.
    private static func segmentName(from line: String) -> String? {
        guard let title = firstMatch(#"^[A-Za-z]\s*[-.):]\s*(.+)$"#, in: line) else { return nil }
        // Guard against real words like "A great warmup" — require the letter to
        // be followed directly by a separator with no other letters before it.
        return title.trimmingCharacters(in: .whitespaces)
    }

    private struct Field { var kind: Kind; var value: String
        enum Kind { case sets, reps, rounds, duration, notes } }

    private static func fieldLine(from line: String) -> Field? {
        let lower = line.lowercased()
        func value(after keyword: String) -> String {
            let stripped = line.dropFirst(keyword.count)
            return stripped
                .trimmingCharacters(in: CharacterSet(charactersIn: " :\t-–"))
        }
        if lower.hasPrefix("sets") { return Field(kind: .sets, value: value(after: "sets")) }
        if lower.hasPrefix("set ") { return Field(kind: .sets, value: value(after: "set")) }
        if lower.hasPrefix("reps") { return Field(kind: .reps, value: value(after: "reps")) }
        if lower.hasPrefix("rep ") { return Field(kind: .reps, value: value(after: "rep")) }
        if lower.hasPrefix("rounds") { return Field(kind: .rounds, value: value(after: "rounds")) }
        if lower.hasPrefix("round ") { return Field(kind: .rounds, value: value(after: "round")) }
        if lower.hasPrefix("duration") { return Field(kind: .duration, value: value(after: "duration")) }
        if lower.hasPrefix("time") { return Field(kind: .duration, value: value(after: "time")) }
        if lower.hasPrefix("notes") { return Field(kind: .notes, value: value(after: "notes")) }
        if lower.hasPrefix("note") { return Field(kind: .notes, value: value(after: "note")) }
        return nil
    }

    // MARK: - Mutators

    /// Attaches a keyword field to the last exercise; returns whether notes-mode
    /// should be enabled (a bare "Notes" line with no inline value).
    private static func attach(field: Field, to workout: inout ParsedWorkout, dayIndex: Int) -> Bool {
        guard let (segIndex, exIndex) = lastExerciseIndex(in: workout, dayIndex: dayIndex) else {
            return false
        }
        let value = field.value.isEmpty ? nil : field.value
        switch field.kind {
        case .sets: workout.days[dayIndex].segments[segIndex].exercises[exIndex].sets = value
        case .reps: workout.days[dayIndex].segments[segIndex].exercises[exIndex].reps = value
        case .rounds: workout.days[dayIndex].segments[segIndex].exercises[exIndex].rounds = value
        case .duration: workout.days[dayIndex].segments[segIndex].exercises[exIndex].duration = value
        case .notes:
            if let value {
                appendNoteText(value, at: segIndex, exIndex, in: &workout, dayIndex: dayIndex)
                return false
            }
            return true // bare "Notes" → capture following lines
        }
        return false
    }

    private static func appendNote(_ text: String, to workout: inout ParsedWorkout, dayIndex: Int) -> Bool {
        guard let (segIndex, exIndex) = lastExerciseIndex(in: workout, dayIndex: dayIndex) else {
            return false
        }
        appendNoteText(text, at: segIndex, exIndex, in: &workout, dayIndex: dayIndex)
        return true
    }

    private static func appendNoteText(_ text: String, at segIndex: Int, _ exIndex: Int,
                                       in workout: inout ParsedWorkout, dayIndex: Int) {
        let existing = workout.days[dayIndex].segments[segIndex].exercises[exIndex].notes
        workout.days[dayIndex].segments[segIndex].exercises[exIndex].notes =
            [existing, text].compactMap { $0 }.joined(separator: "\n")
    }

    private static func ensureSegment(in workout: inout ParsedWorkout, dayIndex: Int) {
        if workout.days[dayIndex].segments.isEmpty {
            // Exercises before the first labelled segment go into "General".
            workout.days[dayIndex].segments.append(ParsedSegment(name: "General"))
        }
    }

    private static func lastExerciseIndex(in workout: ParsedWorkout, dayIndex: Int) -> (Int, Int)? {
        let segments = workout.days[dayIndex].segments
        for segIndex in stride(from: segments.count - 1, through: 0, by: -1) {
            if !segments[segIndex].exercises.isEmpty {
                return (segIndex, segments[segIndex].exercises.count - 1)
            }
        }
        return nil
    }

    // MARK: - Exercise extraction

    /// A single coach line may contain a **superset** — two or more exercises
    /// joined by "+", e.g. "Box Jump 8 reps + reverse hyper 15 reps *3sets".
    /// This strips the bullet, splits into parts, parses each, and propagates a
    /// shared trailing set/round count across the whole superset.
    private static func makeExercises(from line: String) -> [ParsedExercise] {
        var body = line
        if let stripped = firstMatch(#"^[0-9]{1,3}\s*[-.)]\s*(.+)$"#, in: line) {
            body = stripped
        }

        let parts = splitSupersets(body)
        guard parts.count > 1 else { return [parseSingleExercise(from: body)] }

        var exercises = parts.map { parseSingleExercise(from: $0) }
        // A count stated once (usually on the last part) applies to the set.
        if let sharedSets = exercises.last(where: { $0.sets != nil })?.sets {
            for i in exercises.indices where exercises[i].sets == nil { exercises[i].sets = sharedSets }
        }
        if let sharedRounds = exercises.last(where: { $0.rounds != nil })?.rounds {
            for i in exercises.indices where exercises[i].rounds == nil { exercises[i].rounds = sharedRounds }
        }
        return exercises
    }

    /// Splits on " + " at paren depth 0 so notes like "(one Clock wise + …)" or
    /// "front and back" are never broken apart.
    private static func splitSupersets(_ body: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        let chars = Array(body)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "(" { depth += 1 }
            else if c == ")" { depth = max(0, depth - 1) }

            let prevIsSpace = i > 0 && chars[i - 1] == " "
            let nextIsSpace = i < chars.count - 1 && chars[i + 1] == " "
            if depth == 0, c == "+", prevIsSpace, nextIsSpace {
                parts.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                i += 1
                continue
            }
            current.append(c)
            i += 1
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { parts.append(tail) }
        let cleaned = parts.filter { !$0.isEmpty }
        return cleaned.isEmpty ? [body] : cleaned
    }

    private static func parseSingleExercise(from body: String) -> ParsedExercise {
        var reps: String?
        var sets: String?
        var rounds: String?
        var duration: String?

        // Coaches use two conventions:
        //  • "reps * sets": "8 reps *4sets", "12es*3sets", "10*4sets"
        //    (a "*"/"×" followed by an explicit "sets" ⇒ first number is reps)
        //  • "sets x reps": "3x8" (standard gym shorthand ⇒ first number is sets)
        let lower = body.lowercased()
        if let m = firstMatchGroups(#"(\d+)\s*(?:es|reps?)?\s*[*×]\s*(\d+)\s*sets?\b"#, in: lower), m.count == 2 {
            reps = m[0]; sets = m[1]
        } else if let m = firstMatchGroups(#"(\d+)\s*[xX]\s*(\d+)"#, in: body), m.count == 2 {
            sets = m[0]; reps = m[1]
        }
        if sets == nil, let v = firstMatchGroups(#"(\d+)\s*sets?\b"#, in: lower)?.first {
            sets = v
        }
        // Reps via keyword ("8 reps") or each-side shorthand ("12es", "15 es").
        if reps == nil, let v = firstMatchGroups(#"(\d+(?:\s*[-–/]\s*\d+)?)\s*(?:reps?|es)\b"#, in: lower)?.first {
            reps = v.replacingOccurrences(of: " ", with: "")
        }
        if let v = firstMatchGroups(#"(\d+)\s*(?:rounds?|rds?)\b"#, in: body.lowercased())?.first {
            rounds = v
        }
        if let v = firstMatch(#"(\d+\s*(?:seconds?|secs?|minutes?|mins?|hrs?)|\d+\s*s\b|\d+:\d{2})"#, in: body.lowercased()) {
            duration = v.trimmingCharacters(in: .whitespaces)
        }

        // Name = leading text up to the first detected metric token.
        let name = exerciseName(from: body)

        // Residual text after removing name + parsed metrics becomes notes.
        let notes = residualNotes(from: body, name: name,
                                  metrics: [sets, reps, rounds, duration])

        return ParsedExercise(
            name: name.isEmpty ? body : name,
            sets: sets, reps: reps, duration: duration, rounds: rounds,
            notes: notes
        )
    }

    private static func exerciseName(from body: String) -> String {
        // Cut at the first standalone number or a metric keyword.
        let pattern = #"^(.*?)(?=\s+\d|\s+@|\s+tempo\b|\s+notes?\b|\s+sets?\b|\s+reps?\b|$)"#
        if let name = firstMatch(pattern, in: body), !name.isEmpty {
            return name.trimmingCharacters(in: CharacterSet(charactersIn: " -–:"))
        }
        return body.trimmingCharacters(in: .whitespaces)
    }

    private static func residualNotes(from body: String, name: String, metrics: [String?]) -> String? {
        var remainder = body
        if let range = remainder.range(of: name) {
            remainder.removeSubrange(range)
        }
        let noise = CharacterSet(charactersIn: " -–:,")
        let cleaned = remainder.trimmingCharacters(in: noise)
        // Heuristic: keep as notes only if there is alphabetic content beyond
        // pure metric tokens (e.g. "tempo 3s", "use straps").
        let hasWords = cleaned.rangeOfCharacter(from: .letters) != nil
        let looksLikePureMetric = firstMatch(#"^[\dxX×*\s@/:.-]+(sets?|reps?|rounds?)?$"#, in: cleaned.lowercased()) != nil
        guard hasWords, !looksLikePureMetric, !cleaned.isEmpty else { return nil }
        return cleaned
    }

    // MARK: - Regex helpers

    /// Returns the first capture group (or whole match if no group) as String.
    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let groupIndex = match.numberOfRanges > 1 ? 1 : 0
        guard let r = Range(match.range(at: groupIndex), in: text) else { return nil }
        return String(text[r])
    }

    /// Returns all capture groups of the first match.
    private static func firstMatchGroups(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        guard match.numberOfRanges > 1 else { return [] }
        var groups: [String] = []
        for i in 1..<match.numberOfRanges {
            if let r = Range(match.range(at: i), in: text) {
                groups.append(String(text[r]))
            }
        }
        return groups
    }
}
