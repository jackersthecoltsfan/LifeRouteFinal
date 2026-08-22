import SwiftUI
import WebKit
import UIKit

struct LifeRouteWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "lifeRoute")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false

        if let url = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "Web"
        ) {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.loadHTMLString("""
            <html><body style="background:#08111f;color:white;font-family:-apple-system;padding:32px">
            <h2>LifeRoute couldn't load its interface.</h2>
            </body></html>
            """, baseURL: nil)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "lifeRoute" else { return }
            // Native bridge for future Calendar / Routes / notification actions.
            print("LifeRoute bridge message:", message.body)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if url.isFileURL || url.scheme == "about" {
                decisionHandler(.allow)
                return
            }

            if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            guard let viewController = webView.window?.rootViewController else {
                completionHandler()
                return
            }

            let alert = UIAlertController(title: "LifeRoute", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            viewController.present(alert, animated: true)
        }
    }
}
