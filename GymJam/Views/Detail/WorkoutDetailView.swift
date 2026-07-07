//
//  WorkoutDetailView.swift
//  GymJam
//
//  Screen 2 — every exercise for the selected day, in coach order (never sorted).
//  Rest days show a recovery card. Shared by Home (interactive) and History
//  (read-only) — behaviour is identical because Detail has no mutations.
//

import SwiftUI

struct WorkoutDetailView: View {
    let day: WorkoutDay
    var isReadOnly: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingXL) {
                if day.isRestDay {
                    restCard
                } else {
                    ForEach(day.orderedSegments) { segment in
                        SegmentSectionView(segment: segment)
                    }
                }
            }
            .padding(Theme.spacingL)
        }
        .background(Theme.screenBackground)
        .navigationTitle(day.dayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(day.dayName).font(.headline)
                    Text(day.date.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            AnalyticsService.shared.track(.workoutOpened, ["day": day.dayName])
        }
    }

    private var restCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.spacingS) {
                Label("Rest Day", systemImage: "moon.zzz.fill")
                    .font(.title3.weight(.semibold))
                Text("Enjoy your recovery.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
