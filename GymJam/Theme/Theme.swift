//
//  Theme.swift
//  GymJam
//
//  Minimal design tokens. Uses system colors for automatic dark-mode and
//  high-contrast support. Intentionally sparse — the brief is "minimal".
//

import SwiftUI

enum Theme {
    // Spacing scale
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24

    // Corners
    static let cornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16

    // Colors
    static let accent = Color.accentColor
    static let cardBackground = Color(.secondarySystemBackground)
    static let screenBackground = Color(.systemBackground)
    static let expired = Color.red
    static let secondaryText = Color.secondary

    // Minimum tap target
    static let minTapTarget: CGFloat = 44
}

/// A reusable rounded card container.
struct Card<Content: View>: View {
    var isExpired: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .opacity(isExpired ? 0.7 : 1.0)
    }
}
