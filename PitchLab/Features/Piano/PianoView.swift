import SwiftUI

struct PianoView: View {
    @State private var player = TonePlayer()

    private let whiteNotes = (48...83).filter { ![1, 3, 6, 8, 10].contains($0 % 12) }
    private let blackNotes = (48...83).filter { [1, 3, 6, 8, 10].contains($0 % 12) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("触摸琴键，听见标准音")
                        .font(.title2.bold())
                    Text("C3 到 B5 · 可同时弹奏多个音")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Button("低音区") { withAnimation { proxy.scrollTo(48, anchor: .leading) } }
                            Button("中音区") { withAnimation { proxy.scrollTo(60, anchor: .leading) } }
                            Button("高音区") { withAnimation { proxy.scrollTo(72, anchor: .leading) } }
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                        ScrollView(.horizontal) {
                            ZStack(alignment: .topLeading) {
                                HStack(spacing: 1) {
                                    ForEach(whiteNotes, id: \.self) { note in
                                        PianoKey(note: note, isBlack: false, player: player)
                                            .frame(width: 48, height: 230)
                                            .id(note)
                                    }
                                }
                                ForEach(blackNotes, id: \.self) { note in
                                    let previousWhites = whiteNotes.filter { $0 < note }.count
                                    PianoKey(note: note, isBlack: true, player: player)
                                        .frame(width: 30, height: 140)
                                        .offset(x: CGFloat(previousWhites) * 49 - 15)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .scrollIndicators(.hidden)
                    }
                }

                Label("可左右滑动，或使用音区按钮", systemImage: "hand.draw")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.top, 32)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("钢琴")
            .onDisappear { player.stopAll() }
        }
    }
}

private struct PianoKey: View {
    let note: Int
    let isBlack: Bool
    let player: TonePlayer
    @State private var pressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isBlack ? (pressed ? Color.gray : Color.black) : (pressed ? Color.mint.opacity(0.55) : Color.white))
            .overlay(alignment: .bottom) {
                Text(NoteMath.name(midi: note))
                    .font(.caption2.bold())
                    .foregroundStyle(isBlack ? .white : .black)
                    .padding(.bottom, 12)
            }
            .shadow(color: .black.opacity(0.17), radius: 3, y: 3)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            pressed = true
                            player.noteOn(midi: note)
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                        player.noteOff(midi: note)
                    }
            )
            .accessibilityLabel("\(NoteMath.name(midi: note)) 琴键")
    }
}
