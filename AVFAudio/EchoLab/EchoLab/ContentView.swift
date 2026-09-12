import SwiftUI

struct ContentView: View {
    @StateObject private var engine = AudioEngineManager()

    var body: some View {
        TabView {
            RecorderView()
                .tabItem { Label("Record", systemImage: "mic.circle") }
            EffectsRackView()
                .tabItem { Label("Effects", systemImage: "slider.horizontal.3") }
        }
        .environmentObject(engine)
    }
}

#Preview {
    ContentView()
}
