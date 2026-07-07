//
//  SegmentSectionView.swift
//  GymJam
//
//  Renders a segment header and its exercises in coach order.
//

import SwiftUI

struct SegmentSectionView: View {
    let segment: Segment

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            Text(segment.name)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)

            ForEach(segment.orderedExercises) { exercise in
                ExerciseCardView(exercise: exercise)
            }
        }
    }
}
