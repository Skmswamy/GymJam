//
//  RootView.swift
//  GymJam
//
//  Bottom tab navigation: Home · History · Import (PRD §7 + History update).
//

import SwiftUI

struct RootView: View {
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, history, importWorkout }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(goToImport: { selection = .importWorkout })
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)

            ImportView(onImported: { selection = .home })
                .tabItem { Label("Import", systemImage: "square.and.arrow.down") }
                .tag(Tab.importWorkout)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
}
