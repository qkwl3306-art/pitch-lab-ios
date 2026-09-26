import SwiftUI
import UIKit

struct PitchView: View {
    @StateObject private var model = PitchViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform")
                            .font(.title2)
                            .foregroundStyle(.mint)
                        Text(model.noteName)
                            .font(.system(size: 84, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.6)
                        Text(model.pitchHz.map { String(format: "%.1f Hz", $0) } ?? "唱一个稳定的音")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("音准偏差")
                                .font(.headline)
                            Spacer()
                            Text(model.cents.map { String(format: "%+.0f 音分", $0) } ?? "—")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.mint)
                        }
                        GeometryReader { geometry in
                            ZStack {
                                Capsule().fill(.secondary.opacity(0.18)).frame(height: 10)
                                Capsule().fill(.mint).frame(width: 3, height: 28)
                                if let cents = model.cents {
                                    Circle()
                                        .fill(abs(cents) < 10 ? .mint : .orange)
                                        .frame(width: 22, height: 22)
                                        .offset(x: CGFloat(max(-50, min(50, cents))) / 50 * (geometry.size.width - 22) / 2)
                                }
                            }
                            .frame(height: geometry.size.height)
                        }
                        .frame(height: 30)
                        HStack {
                            Text("偏低")
                            Spacer()
                            Text("准确")
                            Spacer()
                            Text("偏高")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("最近 10 秒")
                            .font(.headline)
                        PitchCurve(readings: model.history)
                            .frame(height: 190)
                        Text("曲线中的空白表示没有检测到稳定音高")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))

                    statusContent
                    Button(action: toggleListening) {
                        Label(model.status == .listening ? "停止测量" : "开始测量", systemImage: model.status == .listening ? "stop.fill" : "mic.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                    .controlSize(.large)
                    Text("声音只在本机分析，不保存录音。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("测音高")
            .onDisappear { model.stop() }
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch model.status {
        case .denied:
            VStack(spacing: 8) {
                Text("麦克风权限已关闭")
                Button("打开系统设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        case .failed(let message):
            Text("音频启动失败：\(message)")
                .foregroundStyle(.red)
        case .interrupted:
            Text("音频被打断，正在恢复…")
                .foregroundStyle(.orange)
        case .requestingPermission:
            Text("正在请求麦克风权限…")
                .foregroundStyle(.secondary)
        case .idle, .listening:
            EmptyView()
        }
    }

    private func toggleListening() {
        if model.status == .listening { model.stop() } else { model.start() }
    }
}

private struct PitchCurve: View {
    let readings: [PitchReading]

    var body: some View {
        Canvas { context, size in
            let background = Path { path in
                for fraction in [0.25, 0.5, 0.75] {
                    let y = size.height * fraction
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            context.stroke(background, with: .color(.secondary.opacity(0.18)), lineWidth: 1)

            guard let first = readings.first, let last = readings.last else { return }
            let duration = max(10.0, last.time.timeIntervalSince(first.time))
            var line = Path()
            var previousHadPitch = false
            for reading in readings {
                guard let midi = reading.midi else {
                    previousHadPitch = false
                    continue
                }
                let x = size.width * last.time.timeIntervalSince(reading.time).magnitude / duration
                let point = CGPoint(
                    x: size.width - x,
                    y: size.height * (1 - max(40, min(88, midi)) / 88)
                )
                if previousHadPitch { line.addLine(to: point) } else { line.move(to: point) }
                previousHadPitch = true
            }
            context.stroke(line, with: .color(.mint), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .accessibilityLabel("最近十秒的音高曲线")
    }
}
