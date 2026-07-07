//
//  ExerciseCardView.swift
//  GymJam
//
//  A single exercise card. Only fields with values are shown (progressive
//  disclosure, PRD §9). "Watch Tutorial" opens an in-app YouTube search.
//

import SwiftUI

struct ExerciseCardView: View {
    let exercise: Exercise
    @State private var tutorialURL: URL?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                Text(exercise.name)
                    .font(.headline)

                let metrics = metricRows
                if !metrics.isEmpty {
                    HStack(spacing: Theme.spacingXL) {
                        ForEach(metrics, id: \.label) { metric in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.label)
                                    .font(.caption.smallCaps())
                                    .foregroundStyle(.secondary)
                                Text(metric.value)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }

                if let notes = exercise.coachNotes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("Notes")
                            .font(.caption.smallCaps())
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.subheadline)
                    }
                }

                Button {
                    tutorialURL = YouTube.searchURL(for: exercise.tutorialQuery)
                    AnalyticsService.shared.track(.tutorialOpened, ["exercise": exercise.name])
                } label: {
                    Label("Watch Tutorial", systemImage: "play.rectangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: Theme.minTapTarget)
                }
                .buttonStyle(.borderless)
                .tint(Theme.accent)
            }
        }
        .sheet(item: $tutorialURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
    }

    private struct Metric { let label: String; let value: String }

    private var metricRows: [Metric] {
        var rows: [Metric] = []
        if let v = exercise.sets, !v.isEmpty { rows.append(.init(label: "Sets", value: v)) }
        if let v = exercise.reps, !v.isEmpty { rows.append(.init(label: "Reps", value: v)) }
        if let v = exercise.rounds, !v.isEmpty { rows.append(.init(label: "Rounds", value: v)) }
        if let v = exercise.duration, !v.isEmpty { rows.append(.init(label: "Duration", value: v)) }
        return rows
    }
}

// Allow URL to drive `.sheet(item:)`.
extension URL: Identifiable {
    public var id: String { absoluteString }
}
