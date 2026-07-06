import SwiftUI
import WebKit

struct YouTubeSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let exerciseName: String
    @State private var webView = WKWebView()
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var searchURL: URL {
        let truncated = String(exerciseName.prefix(100))
        let encoded = "\(truncated) tutorial".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? truncated
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)")!
    }

    var body: some View {
        NavigationStack {
            ZStack {
                YouTubeWebView(url: searchURL, webView: webView, isLoading: $isLoading, errorMessage: $errorMessage)

                if isLoading {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            self.errorMessage = nil
                            webView.load(URLRequest(url: searchURL))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.black)
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        openInYouTube()
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .accessibilityLabel("Open in YouTube app")
                }
            }
        }
        .onDisappear {
            webView.navigationDelegate = nil
            webView.stopLoading()
        }
    }

    private func openInYouTube() {
        let query = exerciseName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? exerciseName
        if let appURL = URL(string: "youtube://www.youtube.com/results?search_query=\(query)+tutorial"),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            UIApplication.shared.open(searchURL)
        }
    }
}

struct YouTubeWebView: UIViewRepresentable {
    let url: URL
    let webView: WKWebView
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, errorMessage: $errorMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = webView.configuration
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .default()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var errorMessage: String?
        private let allowedHosts = ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "google.com", "accounts.google.com", "googleusercontent.com", "ytimg.com", "i.ytimg.com"]

        init(isLoading: Binding<Bool>, errorMessage: Binding<String?>) {
            _isLoading = isLoading
            _errorMessage = errorMessage
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            errorMessage = "Couldn't load YouTube. Try again."
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            errorMessage = "No internet or YouTube could not load. Try again."
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let host = navigationAction.request.url?.host?.lowercased() else {
                decisionHandler(.allow)
                return
            }
            let allowed = allowedHosts.contains(host) || allowedHosts.contains { host.hasSuffix(".\($0)") }
            decisionHandler(allowed ? .allow : .cancel)
        }
    }
}
