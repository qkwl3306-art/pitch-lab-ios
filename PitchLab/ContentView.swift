import SwiftUI

struct ContentView: View {
    @StateObject private var access = PracticeAccessStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            PracticeGate { PitchView() }
                .tabItem { Label("测音高", systemImage: "waveform") }
            PracticeGate { PianoView() }
                .tabItem { Label("钢琴", systemImage: "pianokeys") }
            PracticeGate { QuizView() }
                .tabItem { Label("听音测试", systemImage: "ear.badge.waveform") }
            PracticeView()
                .tabItem { Label("练唱", systemImage: "music.note.list") }
            SupportSettingsView()
                .tabItem { Label("support.tab", systemImage: "gearshape") }
        }
        .tint(.mint)
        .environmentObject(access)
        .task { await access.run() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { access.updateAccess() }
        }
    }
}
