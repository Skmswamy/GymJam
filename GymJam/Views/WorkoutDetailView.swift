import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var wod: WOD
    @State private var selectedExercise: Exercise?
    @State private var editingExercise: Exercise?

    var body: some View {
        List {
            ForEach(wod.segments) { segment in
                Section(segmentTitle(segment)) {
                    if segment.exercises.isEmpty && segment.blocks.isEmpty {
                        Text("Rest")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(segment.exercises) { exercise in
                        ExerciseRow(exercise: exercise, action: {
                            selectedExercise = exercise
                        }, editAction: {
                            editingExercise = exercise
                        })
                    }

                    ForEach(segment.blocks) { block in
                        DisclosureGroup("\(block.type.title) \(block.totalDurationMin.map { "\($0) min" } ?? "")") {
                            ForEach(block.movements) { movement in
                                ExerciseRow(exercise: movement, action: {
                                    selectedExercise = movement
                                }, editAction: {
                                    editingExercise = movement
                                })
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(wod.date.formatted(date: .numeric, time: .omitted))
        .sheet(item: $selectedExercise) { exercise in
            YouTubeSearchView(exerciseName: exercise.name)
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseEditView(exercise: exercise) { edited in
                updateExercise(edited)
            }
        }
    }

    private func segmentTitle(_ segment: WorkoutSegment) -> String {
        if let prefix = segment.prefix {
            return "\(prefix): \(segment.name)"
        }
        return segment.name
    }

    private func updateExercise(_ edited: Exercise) {
        var segments = wod.segments
        for segmentIndex in segments.indices {
            if let exerciseIndex = segments[segmentIndex].exercises.firstIndex(where: { $0.id == edited.id }) {
                segments[segmentIndex].exercises[exerciseIndex] = edited
                wod.segments = segments
                try? modelContext.save()
                return
            }
            for blockIndex in segments[segmentIndex].blocks.indices {
                if let movementIndex = segments[segmentIndex].blocks[blockIndex].movements.firstIndex(where: { $0.id == edited.id }) {
                    segments[segmentIndex].blocks[blockIndex].movements[movementIndex] = edited
                    wod.segments = segments
                    try? modelContext.save()
                    return
                }
            }
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise
    let action: () -> Void
    let editAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if exercise.supersetId != nil {
                        Text("SUPERSET")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    Text(exercise.name)
                        .font(.body.weight(.semibold))
                }
                Text(exercise.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let notes = exercise.notes, !notes.isEmpty {
                    Text("Notes: \(notes)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: editAction) {
                Image(systemName: "pencil")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(exercise.name)")

            Button(action: action) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.red)
                        .frame(width: 44, height: 32)
                    Image(systemName: "play.fill")
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search YouTube for \(exercise.name)")
        }
        .contentShape(Rectangle())
    }
}

private struct ExerciseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exercise: Exercise
    let onSave: (Exercise) -> Void

    init(exercise: Exercise, onSave: @escaping (Exercise) -> Void) {
        _exercise = State(initialValue: exercise)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $exercise.name)
                TextField("Reps", text: Binding(
                    get: { exercise.reps ?? "" },
                    set: { exercise.reps = $0.isEmpty ? nil : $0 }
                ))
                Toggle("Each side", isOn: $exercise.eachSide)
                TextField("Notes", text: Binding(
                    get: { exercise.notes ?? "" },
                    set: { exercise.notes = $0.isEmpty ? nil : $0 }
                ))
            }
            .navigationTitle("Edit Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(exercise)
                        dismiss()
                    }
                }
            }
        }
    }
}
