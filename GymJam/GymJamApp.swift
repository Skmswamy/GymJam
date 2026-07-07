//
//  GymJamApp.swift
//  GymJam
//
//  App entry point. Configures the local SwiftData container and the root
//  tab navigation. Offline-first: no networking, no account.
//

import SwiftUI
import SwiftData

@main
struct GymJamApp: App {

    /// Local, on-device SwiftData container for the full workout graph.
    let container: ModelContainer = {
        let schema = Schema([
            WorkoutCycle.self,
            WorkoutDay.self,
            Segment.self,
            Exercise.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
