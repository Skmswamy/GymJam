import SwiftData
import SwiftUI

@main
struct GymJamApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: WOD.self)
    }
}
