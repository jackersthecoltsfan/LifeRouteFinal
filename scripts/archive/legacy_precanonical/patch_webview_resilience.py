from pathlib import Path

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()

marker = '''        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            webView?.window ?? UIWindow()
        }
'''

insert = '''        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Recover instead of leaving the native shell on a permanent black screen.
            // A terminated WebKit content process can happen after a runaway script,
            // memory pressure, or a transient WebKit failure.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                webView.reload()
            }
        }

        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            webView?.window ?? UIWindow()
        }
'''

if insert in text:
    print("WebView termination recovery already installed.")
elif marker not in text:
    raise SystemExit("Could not patch WebView resilience: marker not found")
else:
    path.write_text(text.replace(marker, insert, 1))
    print("Added WKWebView content-process recovery.")
