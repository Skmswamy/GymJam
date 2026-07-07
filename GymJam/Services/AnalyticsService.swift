//
//  AnalyticsService.swift
//  GymJam
//
//  Local-only, in-memory analytics. No network, no third-party SDKs (PRD §19).
//  Events are printed in DEBUG and retained in a bounded ring buffer so a future
//  build could surface them; nothing ever leaves the device.
//

import Foundation

enum AnalyticsEvent: String {
    case workoutImported = "workout_imported"
    case workoutOpened = "workout_opened"
    case tutorialOpened = "tutorial_opened"
    case workoutCompleted = "workout_completed"
    case importFailed = "import_failed"
    case parserFailed = "parser_failed"
}

@Observable
final class AnalyticsService {
    static let shared = AnalyticsService()

    struct Record: Identifiable {
        let id = UUID()
        let event: AnalyticsEvent
        let timestamp: Date
        let properties: [String: String]
    }

    private(set) var records: [Record] = []
    private let maxRecords = 500

    private init() {}

    func track(_ event: AnalyticsEvent, _ properties: [String: String] = [:]) {
        let record = Record(event: event, timestamp: .now, properties: properties)
        records.append(record)
        if records.count > maxRecords { records.removeFirst(records.count - maxRecords) }
        #if DEBUG
        print("📊 [GymJam] \(event.rawValue) \(properties)")
        #endif
    }
}
