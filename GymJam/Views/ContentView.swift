import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(selectUpdateTab: { selectedTab = 1 })
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)

            NavigationStack {
                UpdateView(onSaved: { selectedTab = 0 })
            }
            .tabItem { Label("WOD", systemImage: "square.and.pencil") }
            .tag(1)
        }
        .tint(.red)
    }
}
