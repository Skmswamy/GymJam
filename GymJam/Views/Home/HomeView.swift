//
//  HomeView.swift
//  GymJam
//
//  Screen 1 — chronological list of the active cycle's pending workout days.
//  Ordering priority: Today → Future → Past (PRD §8). Past dates are styled red
//  with reduced opacity but never auto-deleted.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    var goToImport: () -> Void

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WorkoutCycle> { $0.isActive == true })
    private var activeCycles: [WorkoutCycle]

    @State private var dayToComplete: WorkoutDay?
    @State private var showStorageBanner = false

    private var days: [WorkoutDay] {
        let all = activeCycles.flatMap { $0.pendingDays }
        return all.sorted(by: Self.homeOrder)
    }

    var body: some View {
        NavigationStack {
            Group {
                if days.isEmpty {
                    EmptyStateView(
                        title: "No workouts yet.",
                        message: "Import your first workout using the Import tab.",
                        actionTitle: "Go to Import",
                        action: goToImport
                    )
                } else {
                    List {
                        if showStorageBanner {
                            StorageBanner(onManage: {}, onDismiss: { showStorageBanner = false })
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        ForEach(days) { day in
                            ZStack {
                                NavigationLink(value: day) { EmptyView() }.opacity(0)
                                WorkoutCardView(day: day) { dayToComplete = day }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: WorkoutDay.self) { day in
                WorkoutDetailView(day: day, isReadOnly: false)
            }
            .confirmationDialog(
                "Complete this workout?",
                isPresented: Binding(
                    get: { dayToComplete != nil },
                    set: { if !$0 { dayToComplete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Complete") {
                    if let day = dayToComplete {
                        WorkoutStore(context: context).completeDay(day)
                    }
                    dayToComplete = nil
                }
                Button("Cancel", role: .cancel) { dayToComplete = nil }
            }
            .onAppear {
                showStorageBanner = StorageEstimator.exceedsWarningThreshold(context: context)
            }
        }
    }

    // MARK: Ordering

    /// Today first, then soonest upcoming, then most-recent past.
    static func homeOrder(_ a: WorkoutDay, _ b: WorkoutDay) -> Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func rank(_ d: WorkoutDay) -> Int {
            let day = cal.startOfDay(for: d.date)
            if day == today { return 0 }
            return day > today ? 1 : 2
        }
        let ra = rank(a), rb = rank(b)
        if ra != rb { return ra < rb }
        // Within future: ascending. Within past: descending. Today: ascending.
        if ra == 2 { return a.date > b.date }
        return a.date < b.date
    }
}

// MARK: - Storage banner (PRD Storage Limits)

private struct StorageBanner: View {
    var onManage: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacingM) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Text("Workout history is using over 1 GB of local storage. Consider deleting older workout history if you no longer need it.")
                    .font(.footnote)
                Button("Manage Storage", action: onManage)
                    .font(.footnote.bold())
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(Theme.spacingM)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

#Preview {
    HomeView(goToImport: {})
        .modelContainer(PreviewData.container)
}
