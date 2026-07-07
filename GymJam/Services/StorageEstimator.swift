//
//  StorageEstimator.swift
//  GymJam
//
//  Estimates on-device storage used by workout data (PRD "Storage Limits").
//  Text-only data means the 1 GB banner effectively never fires — the logic is
//  implemented for forward-compatibility (future cached videos/images).
//

import Foundation
import SwiftData

@MainActor
enum StorageEstimator {

    /// Warning threshold in bytes (1 GB).
    static let warningThreshold: Int = 1_073_741_824

    /// Rough byte estimate of all persisted workout text.
    static func estimatedBytes(context: ModelContext) -> Int {
        guard let cycles = try? context.fetch(FetchDescriptor<WorkoutCycle>()) else { return 0 }
        var bytes = 0
        for cycle in cycles {
            bytes += 64 // cycle metadata overhead
            for day in cycle.days {
                bytes += day.dayName.utf8.count + 48
                for segment in day.segments {
                    bytes += segment.name.utf8.count + 24
                    for ex in segment.exercises {
                        bytes += ex.name.utf8.count
                        bytes += [ex.sets, ex.reps, ex.duration, ex.rounds, ex.coachNotes]
                            .compactMap { $0?.utf8.count }
                            .reduce(0, +)
                        bytes += 24
                    }
                }
            }
        }
        return bytes
    }

    static func exceedsWarningThreshold(context: ModelContext) -> Bool {
        estimatedBytes(context: context) > warningThreshold
    }

    static func humanReadable(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
