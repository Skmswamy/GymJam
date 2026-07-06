import SwiftData
import SwiftUI

struct UpdateView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WOD.date) private var existingWODs: [WOD]

    let onSaved: () -> Void

    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var rawText = ""
    @State private var parsedPlan: ParsedPlan?
    @State private var pendingPlan: ParsedPlan?
    @State private var showOverlapDialog = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        rawText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 && endDate >= Calendar.current.startOfDay(for: startDate)
    }

    var body: some View {
        Form {
            Section("Dates") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                DatePicker("End", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                if endDate < Calendar.current.startOfDay(for: startDate) {
                    Text("End date must be on or after start date.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Workout") {
                TextEditor(text: $rawText)
                    .frame(minHeight: 220)
                    .overlay(alignment: .topLeading) {
                        if rawText.isEmpty {
                            Text("Paste text here")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: rawText) { _, newValue in
                        if newValue.count > 20_000 {
                            rawText = String(newValue.prefix(20_000))
                        }
                    }

                if rawText.count < 20 {
                    Text("Paste at least 20 characters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Button("Submit") {
                parse()
            }
            .disabled(!canSubmit)
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .tint(.black)
        }
        .navigationTitle("Update")
        .sheet(item: $parsedPlan) { plan in
            NavigationStack {
                PreviewView(plan: plan) { editedPlan in
                    handleSaveRequest(editedPlan)
                }
            }
        }
        .confirmationDialog("This overlaps existing workout days.", isPresented: $showOverlapDialog) {
            Button("Overwrite", role: .destructive) {
                if let pendingPlan {
                    save(pendingPlan, mode: .overwrite)
                }
            }
            Button("Merge") {
                if let pendingPlan {
                    save(pendingPlan, mode: .merge)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how GymJam should handle matching dates.")
        }
    }

    private func parse() {
        errorMessage = nil
        guard canSubmit else {
            errorMessage = "Add valid dates and workout text before submitting."
            return
        }
        let parser = WorkoutParser()
        parsedPlan = parser.parse(rawText: rawText, startDate: startDate, endDate: endDate)
    }

    private func handleSaveRequest(_ plan: ParsedPlan) {
        let planDates = Set(plan.days.map { Calendar.current.startOfDay(for: $0.date) })
        let overlaps = existingWODs.contains { planDates.contains(Calendar.current.startOfDay(for: $0.date)) }
        if overlaps {
            pendingPlan = plan
            showOverlapDialog = true
        } else {
            save(plan, mode: .merge)
        }
    }

    private func save(_ plan: ParsedPlan, mode: SaveMode) {
        let calendar = Calendar.current
        for day in plan.days {
            let date = calendar.startOfDay(for: day.date)
            let existing = existingWODs.first { calendar.isDate($0.date, inSameDayAs: date) }
            switch (mode, existing) {
            case (.overwrite, let wod?):
                wod.rawText = plan.sourceText
                wod.segments = day.segments
                wod.isCompleted = false
            case (.overwrite, nil), (.merge, nil):
                modelContext.insert(WOD(date: date, rawText: plan.sourceText, segments: day.segments))
            case (.merge, let wod?):
                wod.segments.append(contentsOf: day.segments)
                wod.rawText = [wod.rawText, plan.sourceText].joined(separator: "\n\n")
            }
        }
        try? modelContext.save()
        parsedPlan = nil
        pendingPlan = nil
        rawText = ""
        onSaved()
    }
}

private enum SaveMode {
    case overwrite
    case merge
}

struct PreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var plan: ParsedPlan
    let onSave: (ParsedPlan) -> Void

    init(plan: ParsedPlan, onSave: @escaping (ParsedPlan) -> Void) {
        _plan = State(initialValue: plan)
        self.onSave = onSave
    }

    var body: some View {
        List {
            ForEach($plan.days) { $day in
                Section(day.date.formatted(date: .abbreviated, time: .omitted)) {
                    ForEach($day.segments) { $segment in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(segmentTitle(segment))
                                .font(.headline)
                            ForEach($segment.exercises) { $exercise in
                                VStack(alignment: .leading, spacing: 6) {
                                    TextField("Exercise", text: $exercise.name)
                                    Text(exercise.detailText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ConfidenceBadge(score: exercise.parsedConfidence)
                                }
                            }
                            .onDelete { offsets in
                                segment.exercises.remove(atOffsets: offsets)
                            }
                            ForEach(segment.blocks) { block in
                                DisclosureGroup(block.type.title) {
                                    ForEach(block.movements) { movement in
                                        Text(movement.name)
                                    }
                                }
                            }
                        }
                    }

                    if !day.needsReview.isEmpty {
                        DisclosureGroup("Needs Review") {
                            ForEach(day.needsReview, id: \.self) { line in
                                Text(line)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Review your workout")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(plan)
                    dismiss()
                }
            }
        }
    }

    private func segmentTitle(_ segment: WorkoutSegment) -> String {
        if let prefix = segment.prefix {
            return "\(prefix): \(segment.name)"
        }
        return segment.name
    }
}

private struct ConfidenceBadge: View {
    let score: Double

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var label: String {
        if score >= 0.85 { return "High" }
        if score >= 0.6 { return "Medium" }
        return "Low"
    }

    private var color: Color {
        if score >= 0.85 { return .green }
        if score >= 0.6 { return .orange }
        return .red
    }
}
