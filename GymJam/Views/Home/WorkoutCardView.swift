//
//  WorkoutCardView.swift
//  GymJam
//
//  A single workout-day card for Home. Shows date, day name, segment names,
//  exercise count, and a separate "Complete Workout" CTA. Past dates render red
//  with reduced opacity (PRD "Expired Workout Styling").
//

import SwiftUI

struct WorkoutCardView: View {
    let day: WorkoutDay
    var onComplete: () -> Void

    private var isPast: Bool {
        Calendar.current.startOfDay(for: day.date) < Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        Card(isExpired: isPast) {
            VStack(alignment: .leading, spacing: Theme.spacingM) {
                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text(day.dayName)
                        .font(.title3.weight(.semibold))
                    Text(day.date.formatted(.dateTime.month(.wide).day()))
                        .font(.subheadline)
                        .foregroundStyle(isPast ? Theme.expired : Theme.secondaryText)
                }

                if day.isRestDay {
                    Label("Rest Day", systemImage: "moon.zzz.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    if !day.segmentNames.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.spacingXS) {
                            Text("Segments")
                                .font(.caption.smallCaps())
                                .foregroundStyle(.secondary)
                            Text(day.segmentNames.joined(separator: " · "))
                                .font(.subheadline)
                        }
                    }
                    Text("\(day.totalExercises) Exercise\(day.totalExercises == 1 ? "" : "s")")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Divider()

                Button(action: onComplete) {
                    Text("Complete Workout")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.dayName), \(day.date.formatted(.dateTime.month().day())), \(day.isRestDay ? "rest day" : "\(day.totalExercises) exercises")")
    }
}
