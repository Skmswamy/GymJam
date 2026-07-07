//
//  HistoryView.swift
//  GymJam
//
//  Read-only archive of previous cycles, grouped Month → Week → Day, newest
//  first (PRD "Workout History"). Users may browse, read, and watch tutorials
//  but cannot edit, delete, reorder, or complete.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<WorkoutCycle> { $0.isActive == false },
        sort: \WorkoutCycle.startDate, order: .reverse
    )
    private var archivedCycles: [WorkoutCycle]

    /// Cycles grouped by "Month Year", newest month first.
    private var groups: [(title: String, cycles: [WorkoutCycle])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: archivedCycles) { cycle -> DateComponents in
            cal.dateComponents([.year, .month], from: cycle.startDate)
        }
        return grouped
            .sorted { lhs, rhs in
                (lhs.key.year ?? 0, lhs.key.month ?? 0) > (rhs.key.year ?? 0, rhs.key.month ?? 0)
            }
            .map { key, cycles in
                let date = cal.date(from: key) ?? .now
                return (date.formatted(.dateTime.month(.wide).year()),
                        cycles.sorted { $0.startDate > $1.startDate })
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if archivedCycles.isEmpty {
                    EmptyStateView(
                        title: "No history yet.",
                        message: "Once you import a new workout, your previous one will appear here.",
                        systemImage: "clock.arrow.circlepath"
                    )
                } else {
                    List {
                        ForEach(groups, id: \.title) { group in
                            Section(group.title) {
                                ForEach(group.cycles) { cycle in
                                    NavigationLink(value: cycle) {
                                        HistoryWeekCard(cycle: cycle)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: WorkoutCycle.self) { cycle in
                HistoryWeekDetailView(cycle: cycle)
            }
            .navigationDestination(for: WorkoutDay.self) { day in
                WorkoutDetailView(day: day, isReadOnly: true)
            }
        }
    }
}

// MARK: - Week card

private struct HistoryWeekCard: View {
    let cycle: WorkoutCycle

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Text(cycle.weekNumber.map { "Week \($0)" } ?? "Workout Week")
                .font(.headline)
            Text("\(cycle.startDate.formatted(.dateTime.month().day())) – \(cycle.endDate.formatted(.dateTime.month().day()))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: Theme.spacingS) {
                Text("\(cycle.days.count) Workout Day\(cycle.days.count == 1 ? "" : "s")")
                Text("·")
                Text("\(cycle.completionPercentage)% Completed")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.spacingXS)
    }
}

// MARK: - Week detail (list of days)

private struct HistoryWeekDetailView: View {
    let cycle: WorkoutCycle

    var body: some View {
        List(cycle.orderedDays) { day in
            NavigationLink(value: day) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.dayName).font(.headline)
                        Text(day.isRestDay ? "Rest Day"
                             : "\(day.segmentNames.joined(separator: " · ")) · \(day.totalExercises) exercises")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if day.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Completed")
                    }
                }
            }
        }
        .navigationTitle(cycle.weekNumber.map { "Week \($0)" } ?? "Week")
    }
}
