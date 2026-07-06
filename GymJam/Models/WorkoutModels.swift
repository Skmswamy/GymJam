import Foundation
import SwiftData

@Model
final class WOD {
    @Attribute(.unique) var id: UUID
    var date: Date
    var rawText: String
    var isCompleted: Bool
    var createdAt: Date
    @Attribute(.externalStorage) private var segmentsData: Data

    init(date: Date, rawText: String, segments: [WorkoutSegment], isCompleted: Bool = false) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.rawText = rawText
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.segmentsData = (try? JSONEncoder().encode(segments)) ?? Data()
    }

    var segments: [WorkoutSegment] {
        get { (try? JSONDecoder().decode([WorkoutSegment].self, from: segmentsData)) ?? [] }
        set { segmentsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var exerciseCount: Int {
        segments.reduce(0) { total, segment in
            total + segment.exercises.count + segment.blocks.reduce(0) { $0 + $1.movements.count }
        }
    }

    var segmentSummary: String {
        let names = segments.map { segment in
            if let prefix = segment.prefix, !prefix.isEmpty {
                return "\(prefix): \(segment.name)"
            }
            return segment.name
        }
        return names.isEmpty ? "Rest" : names.joined(separator: ", ")
    }
}

struct ParsedPlan: Identifiable {
    let id = UUID()
    var days: [WorkoutDay]
    var sourceText: String
}

struct WorkoutDay: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var segments: [WorkoutSegment]
    var needsReview: [String]

    var isRest: Bool {
        segments.allSatisfy { $0.exercises.isEmpty && $0.blocks.isEmpty }
    }
}

struct WorkoutSegment: Identifiable, Codable, Hashable {
    var id = UUID()
    var prefix: String?
    var name: String
    var order: Int
    var exercises: [Exercise]
    var blocks: [BlockExercise]
}

struct Exercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var sets: Int?
    var reps: String?
    var eachSide: Bool
    var durationSec: Int?
    var intervalWork: Int?
    var intervalRest: Int?
    var rounds: Int?
    var supersetId: UUID?
    var buildToMax: Bool
    var notes: String?
    var rawLine: String
    var parsedConfidence: Double

    var detailText: String {
        if buildToMax, let reps {
            return "Build to \(reps)-rep max"
        }
        if let rounds, let intervalWork {
            let rest = intervalRest.map { " / \($0) sec off" } ?? ""
            return "\(rounds) rounds · \(intervalWork) sec on\(rest)"
        }
        if let durationSec {
            if let sets {
                return "\(sets) sets x \(durationSec) sec hold"
            }
            return "\(durationSec) sec hold"
        }
        if let sets, let reps {
            return "\(sets) sets x \(reps) reps\(eachSide ? " each side" : "")"
        }
        if let sets {
            return "\(sets) sets"
        }
        return "No sets/reps"
    }
}

struct BlockExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var type: BlockType
    var totalDurationMin: Int?
    var movements: [Exercise]
}

enum BlockType: String, Codable, Hashable {
    case emotm
    case tabata
    case amrap
    case emom
    case interval

    var title: String { rawValue.uppercased() }
}
