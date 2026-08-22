import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.07, blue: 0.12)
                .ignoresSafeArea()

            LifeRouteWebView()
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

#Preview {
    ContentView()
}
