import Foundation

struct WorkoutParser {
    private let calendar = Calendar.current

    func parse(rawText: String, startDate: Date, endDate: Date) -> ParsedPlan {
        let cleaned = preprocess(rawText)
        let lines = cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var buckets: [DayBucket] = []
        var currentWeek = 1
        var currentDayName: String?
        var currentSegments: [WorkoutSegment] = []
        var currentNeedsReview: [String] = []
        var currentSegmentIndex: Int?
        var activeBlock: BlockExercise?

        func flushBlock() {
            guard let block = activeBlock, let index = currentSegmentIndex else { return }
            currentSegments[index].blocks.append(block)
            activeBlock = nil
        }

        func flushDay() {
            flushBlock()
            guard let dayName = currentDayName else { return }
            buckets.append(DayBucket(week: currentWeek, dayName: dayName, segments: currentSegments, needsReview: currentNeedsReview))
            currentSegments = []
            currentNeedsReview = []
            currentSegmentIndex = nil
        }

        for line in lines {
            if let week = matchWeek(line) {
                flushDay()
                currentWeek = week
                currentDayName = nil
                continue
            }

            if isDay(line) {
                flushDay()
                currentDayName = line.capitalized
                continue
            }

            if let segment = matchSegment(line, order: currentSegments.count) {
                flushBlock()
                currentSegments.append(segment)
                currentSegmentIndex = currentSegments.indices.last
                continue
            }

            if let blockType = matchBlockHeader(line) {
                flushBlock()
                if currentSegmentIndex == nil {
                    currentSegments.append(WorkoutSegment(prefix: nil, name: "Workout", order: currentSegments.count, exercises: [], blocks: []))
                    currentSegmentIndex = currentSegments.indices.last
                }
                activeBlock = BlockExercise(type: blockType.type, totalDurationMin: blockType.duration, movements: [])
                continue
            }

            guard currentDayName != nil else {
                currentNeedsReview.append(line)
                continue
            }

            if currentSegmentIndex == nil {
                currentSegments.append(WorkoutSegment(prefix: nil, name: "Workout", order: currentSegments.count, exercises: [], blocks: []))
                currentSegmentIndex = currentSegments.indices.last
            }

            let exercises = parseExerciseLine(line)
            if exercises.isEmpty {
                currentNeedsReview.append(line)
            } else if activeBlock != nil {
                activeBlock?.movements.append(contentsOf: exercises)
            } else if let index = currentSegmentIndex {
                currentSegments[index].exercises.append(contentsOf: exercises)
            }
        }
        flushDay()

        let days = buildDays(from: buckets, rawStartDate: startDate, rawEndDate: endDate)
        return ParsedPlan(days: days, sourceText: rawText)
    }

    private func preprocess(_ text: String) -> String {
        text.unicodeScalars
            .filter { scalar in
                scalar.properties.isEmojiPresentation == false || CharacterSet.whitespacesAndNewlines.contains(scalar)
            }
            .map(String.init)
            .joined()
    }

    private func buildDays(from buckets: [DayBucket], rawStartDate: Date, rawEndDate: Date) -> [WorkoutDay] {
        let startDate = calendar.startOfDay(for: rawStartDate)
        let endDate = calendar.startOfDay(for: rawEndDate)
        let lookup = Dictionary(grouping: buckets, by: { "\($0.week)-\($0.dayName.lowercased())" })
        var output: [WorkoutDay] = []
        var cursor = startDate

        while cursor <= endDate {
            let weekOffset = calendar.dateComponents([.day], from: startDate, to: cursor).day ?? 0
            let week = max(1, weekOffset / 7 + 1)
            let dayName = calendar.weekdaySymbols[calendar.component(.weekday, from: cursor) - 1].lowercased()
            let bucket = lookup["\(week)-\(dayName)"]?.first
            output.append(
                WorkoutDay(
                    date: cursor,
                    segments: bucket?.segments ?? [WorkoutSegment(prefix: nil, name: "Rest", order: 0, exercises: [], blocks: [])],
                    needsReview: bucket?.needsReview ?? []
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return output
    }

    private func matchWeek(_ line: String) -> Int? {
        let regex = try? NSRegularExpression(pattern: #"^Week[-\s#]*(\d+)"#, options: [.caseInsensitive])
        guard let match = regex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return Int(line[range])
    }

    private func isDay(_ line: String) -> Bool {
        let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        return days.contains(line.lowercased())
    }

    private func matchSegment(_ line: String, order: Int) -> WorkoutSegment? {
        let regex = try? NSRegularExpression(pattern: #"^([A-C])\s*[-–]\s*(.+)$"#, options: [.caseInsensitive])
        guard let match = regex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let prefixRange = Range(match.range(at: 1), in: line),
              let nameRange = Range(match.range(at: 2), in: line) else { return nil }
        return WorkoutSegment(prefix: String(line[prefixRange]).uppercased(), name: String(line[nameRange]), order: order, exercises: [], blocks: [])
    }

    private func matchBlockHeader(_ line: String) -> (type: BlockType, duration: Int?)? {
        let lower = line.lowercased()
        let duration = firstInt(in: line)
        if lower.contains("tabata") { return (.tabata, duration) }
        if lower.contains("amrap") { return (.amrap, duration) }
        if lower.contains("emotm") { return (.emotm, duration) }
        if lower.contains("emom") { return (.emom, duration) }
        if lower.range(of: #"every\s+\d+\s+min"#, options: .regularExpression) != nil { return (.interval, duration) }
        return nil
    }

    private func parseExerciseLine(_ line: String) -> [Exercise] {
        let cleaned = line.replacingOccurrences(of: #"^\s*[-\d]+[.)-]?\s*"#, with: "", options: .regularExpression)
        let parts = cleaned.contains("+") ? cleaned.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces) } : [cleaned]
        let supersetId = parts.count > 1 ? UUID() : nil
        return parts.compactMap { parseSingleExercise($0, original: line, supersetId: supersetId) }
    }

    private func parseSingleExercise(_ line: String, original: String, supersetId: UUID?) -> Exercise? {
        let notes = extractNotes(from: line)
        let nameWithoutNotes = line.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)

        if let match = regexMatch(#"^(.+?)\s*(\d+)\s*(?:reps?)?\s*(es)?\s*\*\s*(\d+)\s*(?:sets?)?$"#, in: nameWithoutNotes) {
            return makeExercise(name: match[1], sets: Int(match[4]), reps: match[2], eachSide: match[3].isEmpty == false, notes: notes, raw: original, confidence: 0.95, supersetId: supersetId)
        }

        if let match = regexMatch(#"^(.+?)\s*\*\s*(\d+)\s*sets?$"#, in: nameWithoutNotes) {
            return makeExercise(name: match[1], sets: Int(match[2]), reps: nil, notes: notes, raw: original, confidence: 0.75, supersetId: supersetId)
        }

        if let match = regexMatch(#"^(\d+)\s*(?:secs?)\s*(?:on)?\s*(\d+)?\s*(?:secs?)?\s*(?:off)?\s*\*\s*(\d+)\s*rounds?.*$"#, in: nameWithoutNotes) {
            return Exercise(name: "Interval", sets: nil, reps: nil, eachSide: false, durationSec: nil, intervalWork: Int(match[1]), intervalRest: Int(match[2]), rounds: Int(match[3]), supersetId: supersetId, buildToMax: false, notes: notes, rawLine: original, parsedConfidence: 0.9)
        }

        if let match = regexMatch(#"^(\d+)\s*(?:secs?)\s+(.+)$"#, in: nameWithoutNotes) {
            return Exercise(name: match[2], sets: nil, reps: nil, eachSide: false, durationSec: Int(match[1]), intervalWork: nil, intervalRest: nil, rounds: nil, supersetId: supersetId, buildToMax: false, notes: notes, rawLine: original, parsedConfidence: 0.85)
        }

        if let match = regexMatch(#"^Build to\s+(.+?)\s+(\d+)\s*reps?\s*max$"#, in: nameWithoutNotes) {
            return Exercise(name: match[1], sets: nil, reps: match[2], eachSide: false, durationSec: nil, intervalWork: nil, intervalRest: nil, rounds: nil, supersetId: supersetId, buildToMax: true, notes: notes, rawLine: original, parsedConfidence: 0.9)
        }

        if nameWithoutNotes.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil {
            return makeExercise(name: nameWithoutNotes, sets: nil, reps: nil, notes: notes, raw: original, confidence: 0.45, supersetId: supersetId)
        }

        return nil
    }

    private func makeExercise(name: String, sets: Int?, reps: String?, eachSide: Bool = false, notes: String?, raw: String, confidence: Double, supersetId: UUID?) -> Exercise {
        Exercise(name: name.trimmingCharacters(in: .whitespacesAndNewlines), sets: sets, reps: reps, eachSide: eachSide, durationSec: nil, intervalWork: nil, intervalRest: nil, rounds: nil, supersetId: supersetId, buildToMax: false, notes: notes, rawLine: raw, parsedConfidence: confidence)
    }

    private func regexMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            guard let swiftRange = Range(match.range(at: index), in: text) else { return "" }
            return String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func extractNotes(from line: String) -> String? {
        guard let match = regexMatch(#"\(([^)]*)\)"#, in: line), match.count > 1 else { return nil }
        return match[1]
    }

    private func firstInt(in text: String) -> Int? {
        guard let match = regexMatch(#"(\d+)"#, in: text), match.count > 1 else { return nil }
        return Int(match[1])
    }
}

private struct DayBucket {
    var week: Int
    var dayName: String
    var segments: [WorkoutSegment]
    var needsReview: [String]
}
