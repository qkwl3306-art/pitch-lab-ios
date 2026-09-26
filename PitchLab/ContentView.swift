import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PitchView()
                .tabItem { Label("测音高", systemImage: "waveform") }
            PianoView()
                .tabItem { Label("钢琴", systemImage: "pianokeys") }
            QuizView()
                .tabItem { Label("听音测试", systemImage: "ear.badge.waveform") }
        }
        .tint(.mint)
    }
}
