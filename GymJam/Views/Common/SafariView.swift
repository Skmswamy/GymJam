//
//  SafariView.swift
//  GymJam
//
//  In-app browser (SFSafariViewController) used for YouTube tutorial search,
//  so the user never leaves the app and workout position is preserved.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

enum YouTube {
    /// Builds a YouTube search URL for an exercise tutorial query.
    static func searchURL(for query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)")!
    }
}
