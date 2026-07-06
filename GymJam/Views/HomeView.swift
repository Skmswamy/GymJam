import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WOD.date) private var allWODs: [WOD]
    let selectUpdateTab: () -> Void
    @State private var pendingCompletion: WOD?

    private var visibleWODs: [WOD] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today

        return allWODs
            .filter { !$0.isCompleted && $0.date >= startOfWeek }
            .sorted { lhs, rhs in
                let lDay = calendar.startOfDay(for: lhs.date)
                let rDay = calendar.startOfDay(for: rhs.date)
                if lDay == today { return true }
                if rDay == today { return false }
                if lDay >= today && rDay >= today { return lDay < rDay }
                if lDay < today && rDay < today { return lDay > rDay }
                return lDay >= today
            }
    }

    private var planEnded: Bool {
        guard let latest = allWODs.map(\.date).max() else { return false }
        return latest < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        List {
            if planEnded {
                Section {
                    Button("Plan ended. Add new workout.") {
                        selectUpdateTab()
                    }
                }
            }

            if visibleWODs.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text("Paste your coach's workout to create daily WOD cards.")
                )
                Button("Add your first workout") {
                    selectUpdateTab()
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
            } else {
                ForEach(visibleWODs) { wod in
                    NavigationLink {
                        WorkoutDetailView(wod: wod)
                    } label: {
                        WODCard(wod: wod, completeAction: {
                            pendingCompletion = wod
                        })
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("WODs")
        .confirmationDialog("Mark this workout complete?", isPresented: Binding(
            get: { pendingCompletion != nil },
            set: { if !$0 { pendingCompletion = nil } }
        )) {
            Button("Complete", role: .destructive) {
                pendingCompletion?.isCompleted = true
                try? modelContext.save()
                pendingCompletion = nil
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct WODCard: View {
    let wod: WOD
    let completeAction: () -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(wod.date)
    }

    private var isPast: Bool {
        wod.date < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(wod.date, format: .dateTime.month(.twoDigits).day(.twoDigits).year())
                        .font(.headline)
                        .foregroundStyle(isPast ? .red : .primary)
                    if isPast {
                        Text("Past")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
                Text("\(wod.exerciseCount)")
                    .font(.headline)
                    .accessibilityLabel("\(wod.exerciseCount) workouts")
            }

            Text(wod.segmentSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                if isToday {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.red.opacity(0.12), in: Capsule())
                }
                Spacer()
                Button(action: completeAction) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Complete workout")
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .leading) {
            if isToday {
                Rectangle()
                    .fill(.red)
                    .frame(width: 4)
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(wod.date.formatted(date: .numeric, time: .omitted)), \(wod.exerciseCount) workouts, segments \(wod.segmentSummary)")
    }
}
