//
//  ImportView.swift
//  GymJam
//
//  Screen 3 — import a new workout cycle. Start/End date pickers (End ≥ Start),
//  a large multiline paste field, and a Submit that stays disabled until valid.
//  Importing replaces (archives) the current active cycle after confirmation.
//

import SwiftUI
import SwiftData

struct ImportView: View {
    var onImported: () -> Void

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WorkoutCycle> { $0.isActive == true })
    private var activeCycles: [WorkoutCycle]

    @State private var startDate = Calendar.current.startOfDay(for: .now)
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 6, to: .now) ?? .now
    @State private var workoutText = ""

    @State private var showReplaceConfirm = false
    @State private var errorMessage: String?
    @FocusState private var textFocused: Bool

    private var datesValid: Bool { endDate >= startDate }
    private var canSubmit: Bool {
        datesValid && !workoutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    if !datesValid {
                        Text("End date must be on or after the start date.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Workout") {
                    ZStack(alignment: .topLeading) {
                        if workoutText.isEmpty {
                            Text("Paste workout here...")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $workoutText)
                            .frame(minHeight: 220)
                            .focused($textFocused)
                            .scrollContentBackground(.hidden)
                    }
                }

                Section {
                    Button {
                        textFocused = false
                        if activeCycles.isEmpty { performImport() }
                        else { showReplaceConfirm = true }
                    } label: {
                        Text("Import Workout")
                            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Import")
            .confirmationDialog(
                "Replace current workout?",
                isPresented: $showReplaceConfirm,
                titleVisibility: .visible
            ) {
                Button("Replace") { performImport() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current workout will be moved to History and this new one will become active.")
            }
            .alert(
                "Import Failed",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func performImport() {
        do {
            try WorkoutStore(context: context).importWorkout(
                text: workoutText, startDate: startDate, endDate: endDate
            )
            workoutText = ""
            onImported()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Unable to understand workout.\nPlease verify formatting."
        }
    }
}

#Preview {
    ImportView(onImported: {})
        .modelContainer(PreviewData.container)
}
