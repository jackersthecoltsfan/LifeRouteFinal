import SwiftUI

struct ContentView: View {
    var body: some View {
        LifeRouteWebView()
            .background(Color(uiColor: .systemBackground))
            .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    ContentView()
}
