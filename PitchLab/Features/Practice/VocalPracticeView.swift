import Combine
import SwiftUI
import UniformTypeIdentifiers

private struct SavedPhraseProgress: Codable {
    var shift: Int
    var attempts: [Int: Int]
    var passed: Set<Int>
    var lastFeedback: [Int: PhraseFeedback]
}

struct VocalPracticeView: View {
    @ObservedObject var store: ScoreStore
    let score: StoredScore
    @StateObject private var model = PhrasePracticeViewModel()
    @State private var selectedPhrase = 0
    @State private var shift = 0
    @State private var showLyricsFile = false
    @State private var showPaste = false
    @State private var showPhraseText = false
    @State private var phraseText = ""
    @State private var pastedLyrics = ""
    @State private var showRange = false
    @State private var rangeLow = UserDefaults.standard.integer(forKey: "vocal-range-low")
    @State private var rangeHigh = UserDefaults.standard.integer(forKey: "vocal-range-high")
    @State private var attempts: [Int: Int] = [:]
    @State private var passed: Set<Int> = []
    @State private var lastFeedback: [Int: PhraseFeedback] = [:]
    @State private var errorMessage: String?

    private var current: StoredScore { store.items.first { $0.id == score.id } ?? score }
    private var melody: VocalScore? { current.vocalScore }
    private var phrases: [VocalPhrase] { current.phrases }
    private var phrase: VocalPhrase? { phrases.indices.contains(selectedPhrase) ? phrases[selectedPhrase] : nil }
    private var range: VocalRange? {
        rangeLow > 0 && rangeHigh >= rangeLow ? VocalRange(low: rangeLow, high: rangeHigh) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("人声旋律 · \(melody?.notes.count ?? 0) 个音符 · \(phrases.count) 句")
                .font(.headline)
            if let melody, let phrase {
                phraseControls(melody: melody, phrase: phrase)
                PitchLane(score: melody, phrase: phrase, shift: shift, readings: model.readings,
                          feedback: model.feedback ?? lastFeedback[selectedPhrase])
                    .frame(height: 170)
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                practiceControls(melody: melody, phrase: phrase)
                if let feedback = model.feedback ?? lastFeedback[selectedPhrase] { results(feedback) }
            } else {
                ContentUnavailableView("没有可练习的旋律", systemImage: "music.note")
            }
            lyricControls
            rangeControls
        }
        .fileImporter(isPresented: $showLyricsFile, allowedContentTypes: [.plainText, .data]) { result in
            do { try store.importLyrics(at: result.get(), for: current) }
            catch { errorMessage = error.localizedDescription }
        }
        .sheet(isPresented: $showPaste) {
            NavigationStack {
                VStack(alignment: .leading) {
                    Text("每行一句歌词，依次对应自动分出的句子。")
                        .foregroundStyle(.secondary)
                    TextEditor(text: $pastedLyrics)
                        .border(.secondary.opacity(0.3))
                }
                .padding()
                .navigationTitle("粘贴歌词")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { showPaste = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            do {
                                let lines = try LyricsParser.parseTXT(data: Data(pastedLyrics.utf8))
                                try store.setLyrics(lines, for: current)
                                showPaste = false
                            } catch { errorMessage = error.localizedDescription }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showRange) {
            VocalRangeCaptureView { captured in
                rangeLow = captured.low
                rangeHigh = captured.high
                UserDefaults.standard.set(captured.low, forKey: "vocal-range-low")
                UserDefaults.standard.set(captured.high, forKey: "vocal-range-high")
            }
        }
        .sheet(isPresented: $showPhraseText) {
            NavigationStack {
                TextEditor(text: $phraseText)
                    .padding()
                    .navigationTitle("编辑本句歌词")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { showPhraseText = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                guard phrases.indices.contains(selectedPhrase) else { return }
                                var changed = phrases
                                changed[selectedPhrase].text = phraseText.trimmingCharacters(in: .whitespacesAndNewlines)
                                do { try store.updatePhrases(changed, for: current); showPhraseText = false }
                                catch { errorMessage = error.localizedDescription }
                            }
                        }
                    }
            }
        }
        .alert("操作失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: { Text(errorMessage ?? "未知错误") }
        .onChange(of: model.feedback) { _, feedback in
            guard let feedback else { return }
            attempts[selectedPhrase, default: 0] += 1
            lastFeedback[selectedPhrase] = feedback
            if feedback.passed { passed.insert(selectedPhrase) }
            saveProgress()
        }
        .onAppear { loadProgress() }
        .onDisappear { model.stop() }
    }

    private var lyricControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("歌词").font(.headline)
            Text("导入 LRC／TXT，或按每行一句粘贴。LRC 时间会匹配最近的句子。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("导入歌词", systemImage: "doc.text") { showLyricsFile = true }
                Button("粘贴歌词", systemImage: "doc.on.clipboard") { showPaste = true }
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var rangeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("适合我的调").font(.headline)
                Spacer()
                Button(range == nil ? "测量音域" : "重测音域") { showRange = true }
            }
            if let range {
                Text("舒适音域 \(NoteMath.name(midi: range.low))～\(NoteMath.name(midi: range.high))")
                    .font(.subheadline)
                if let melody {
                    recommendation(melody: melody, range: range)
                }
            } else {
                Text("先唱出舒适的最低音和最高音，便可推荐整首歌的调。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            transposeControls
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func recommendation(melody: VocalScore, range: VocalRange) -> some View {
        let advice = KeyRecommendation.recommend(notes: melody.notes.map(\.midi), range: range)
        let keyName = advice.semitones == 0 ? "原调" : String(format: "%+d 半音", advice.semitones)
        let lowName = advice.lowestNote.map(NoteMath.name(midi:)) ?? "—"
        let highName = advice.highestNote.map(NoteMath.name(midi:)) ?? "—"
        return VStack(alignment: .leading, spacing: 5) {
            Text("建议 \(keyName) · 覆盖 \(advice.coveredNoteCount)/\(advice.totalNoteCount) 个音")
            Text("原调覆盖 \(advice.originalCoveredNoteCount)/\(advice.totalNoteCount) · 建议调 \(lowName)～\(highName)")
                .font(.caption).foregroundStyle(.secondary)
            if advice.outOfRangeNoteCount > 0 {
                Text("仍有 \(advice.outOfRangeNoteCount) 个音超出舒适音域")
                    .font(.caption).foregroundStyle(.orange)
            }
            Button("应用建议调") { changeShift(to: advice.semitones) }
                .buttonStyle(.bordered)
        }
    }

    private var transposeControls: some View {
        HStack {
            Text("整首移调").font(.subheadline)
            Spacer()
            Button { changeShift(to: shift - 1) } label: { Image(systemName: "minus.circle.fill") }
                .disabled(shift <= -12)
            Text(shift == 0 ? "原调" : String(format: "%+d", shift))
                .frame(minWidth: 48).monospacedDigit()
            Button { changeShift(to: shift + 1) } label: { Image(systemName: "plus.circle.fill") }
                .disabled(shift >= 12)
        }
        .buttonStyle(.borderless)
    }

    private func phraseControls(melody: VocalScore, phrase: VocalPhrase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("第 \(selectedPhrase + 1) / \(phrases.count) 句")
                .font(.headline)
            Text(phrase.text).font(.title3.bold())
            Button("编辑本句歌词") { phraseText = phrase.text; showPhraseText = true }
                .font(.caption)
            Text("\(phrase.noteRange.count) 个音 · 已练 \(attempts[selectedPhrase, default: 0]) 次 · \(passed.contains(selectedPhrase) ? "已达标" : "待达标")")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(phrase.noteRange, id: \.self) { index in
                        Text(NoteMath.name(midi: melody.notes[index].midi + shift))
                            .font(.caption.monospacedDigit())
                            .padding(6)
                            .background(.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(phrases.indices, id: \.self) { index in
                        Button("\(index + 1)\(passed.contains(index) ? " ✓" : "")") {
                            model.stop()
                            selectedPhrase = index
                        }
                        .buttonStyle(.bordered)
                        .tint(index == selectedPhrase ? .mint : .gray)
                    }
                }
            }
            HStack {
                Button("上句") { model.stop(); selectedPhrase -= 1 }.disabled(selectedPhrase == 0)
                Button("下句") { model.stop(); selectedPhrase += 1 }.disabled(selectedPhrase >= phrases.count - 1)
            }
            .buttonStyle(.bordered)
            if selectedPhrase < phrases.count - 1 {
                HStack {
                    Text("调整本句结尾")
                    Button("少一个音") { moveBoundary(by: -1, melody: melody) }
                    Button("多一个音") { moveBoundary(by: 1, melody: melody) }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func practiceControls(melody: VocalScore, phrase: VocalPhrase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("当前音高：\(model.currentName)")
                Spacer()
                switch model.phase {
                case .idle: Text("准备练习")
                case .countdown(let count): Text("倒数 \(count)")
                case .recording: Text("跟唱中")
                case .finished: Text("本轮结束")
                }
            }
            .font(.subheadline)
            HStack {
                Button("听示范", systemImage: "play.fill") {
                    model.preview(score: melody, phrase: phrase, transposition: shift)
                }
                Button(attempts[selectedPhrase, default: 0] > 0 ? "重练本句" : "开始跟唱", systemImage: "mic.fill") {
                    model.begin(score: melody, phrase: phrase, transposition: shift)
                }
                .buttonStyle(.borderedProminent)
                Button("停止") { model.stop() }
            }
            .buttonStyle(.bordered)
            if model.microphoneStatus == .denied {
                Text("请到系统设置中开启麦克风权限。")
                    .foregroundStyle(.orange)
            } else if case .failed(let message) = model.microphoneStatus {
                Text("麦克风启动失败：\(message)").foregroundStyle(.red)
            }
            Text("听示范后，倒数三秒开始跟唱。每个音按时间检查；全部达标才通过本句。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func results(_ feedback: PhraseFeedback) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(feedback.passed ? "本句通过，可以练下一句" : "标出的音再练一次")
                .font(.headline)
                .foregroundStyle(feedback.passed ? .green : .orange)
            ForEach(feedback.notes, id: \.noteIndex) { note in
                HStack {
                    Text("第 \(note.noteIndex - (phrase?.noteRange.lowerBound ?? 0) + 1) 音 · \(NoteMath.name(midi: note.targetMIDI))")
                    Spacer()
                    Text(statusText(note.status))
                    if let cents = note.cents { Text(String(format: "%+.0f 音分", cents)) }
                }
                .font(.subheadline)
                .foregroundStyle(note.status == .passed ? .green : .primary)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func statusText(_ status: NoteFeedbackStatus) -> String {
        switch status {
        case .passed: "唱准"
        case .high: "偏高"
        case .low: "偏低"
        case .missed: "漏唱"
        }
    }

    private func changeShift(to value: Int) {
        guard (-12...12).contains(value), shift != value else { return }
        model.stop()
        shift = value
        attempts = [:]
        passed = []
        lastFeedback = [:]
        saveProgress()
    }

    private func moveBoundary(by delta: Int, melody: VocalScore) {
        guard let changed = PhraseBuilder.moveBoundary(after: selectedPhrase, by: delta, in: phrases, score: melody) else { return }
        do {
            model.stop()
            try store.updatePhrases(changed, for: current)
            attempts = [:]
            passed = []
            lastFeedback = [:]
            saveProgress()
        } catch { errorMessage = error.localizedDescription }
    }

    private var progressKey: String { "phrase-progress-\(score.id.uuidString)" }

    private func saveProgress() {
        let progress = SavedPhraseProgress(shift: shift, attempts: attempts, passed: passed,
                                           lastFeedback: lastFeedback)
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    private func loadProgress() {
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let saved = try? JSONDecoder().decode(SavedPhraseProgress.self, from: data) else { return }
        attempts = saved.attempts
        passed = saved.passed
        lastFeedback = saved.lastFeedback
        shift = saved.shift
    }
}

private struct PitchLane: View {
    let score: VocalScore
    let phrase: VocalPhrase
    let shift: Int
    let readings: [TimedPitchReading]
    let feedback: PhraseFeedback?

    var body: some View {
        Canvas { context, size in
            let notes = phrase.noteRange.compactMap { score.notes.indices.contains($0) ? score.notes[$0] : nil }
            guard let minimum = notes.map(\.midi).min(), let maximum = notes.map(\.midi).max() else { return }
            let low = Double(minimum + shift - 2)
            let span = Double(maximum - minimum + 4)
            let timeSpan = max(0.1, phrase.end - phrase.start)
            func x(_ time: Double) -> CGFloat { CGFloat((time - phrase.start) / timeSpan) * size.width }
            func y(_ midi: Double) -> CGFloat { size.height * (1 - CGFloat((midi - low) / span)) }
            for midi in (minimum + shift - 2)...(maximum + shift + 2) {
                let row = y(Double(midi))
                var line = Path()
                line.move(to: CGPoint(x: 0, y: row))
                line.addLine(to: CGPoint(x: size.width, y: row))
                context.stroke(line, with: .color(.gray.opacity(0.2)), lineWidth: 1)
            }
            for (offset, note) in notes.enumerated() {
                let status = feedback?.notes.first { $0.noteIndex == phrase.noteRange.lowerBound + offset }?.status
                let color: Color = status == .passed ? .green : status == nil ? .mint : .orange
                let rect = CGRect(x: x(note.onset), y: y(Double(note.midi + shift)) - 5,
                                  width: max(3, x(note.onset + note.duration) - x(note.onset)), height: 10)
                context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(color))
            }
            var sung = Path()
            var drawing = false
            for sample in readings {
                guard let hz = sample.frequency, let midi = NoteMath.nearestMIDINote(frequency: hz) else {
                    drawing = false
                    continue
                }
                let point = CGPoint(x: x(sample.time), y: y(Double(midi)))
                if drawing { sung.addLine(to: point) } else { sung.move(to: point) }
                drawing = true
            }
            context.stroke(sung, with: .color(.orange), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .accessibilityLabel("旋律与跟唱音高曲线")
    }
}

@MainActor
private final class RangeCaptureModel: ObservableObject {
    @Published private(set) var status: MicrophonePitchService.Status = .idle
    @Published private(set) var current: Int?
    @Published private(set) var samples: [Double] = []
    private let microphone = MicrophonePitchService()
    private var subscriptions = Set<AnyCancellable>()

    init() {
        microphone.$status.sink { [weak self] in self?.status = $0 }.store(in: &subscriptions)
        microphone.$pitchHz.sink { [weak self] frequency in
            guard let self else { return }
            self.current = frequency.flatMap(NoteMath.nearestMIDINote(frequency:))
            if let frequency { self.samples.append(frequency) }
        }.store(in: &subscriptions)
    }
    func start() { samples = []; microphone.start() }
    func capture() -> Int? {
        let result = VocalRangeSampling.stableMIDI(frequencies: samples)
        microphone.stop()
        return result
    }
    func stop() { microphone.stop() }
}

private struct VocalRangeCaptureView: View {
    let onSave: (VocalRange) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = RangeCaptureModel()
    @State private var low: Int?
    @State private var high: Int?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("先用舒服的声音唱最低音，持续约两秒后点“记录最低音”；再唱舒服的最高音。不要勉强压低或拉高。")
                Text("当前：\(model.current.map(NoteMath.name(midi:)) ?? "—")")
                    .font(.title.bold())
                HStack {
                    Button("开始测量") { model.start() }
                    Button(low == nil ? "记录最低音" : "记录最高音") {
                        if let note = model.capture() {
                            if low == nil { low = note } else { high = note }
                        } else { error = "声音不够稳定，请持续唱同一个音后再记录。" }
                    }
                }
                .buttonStyle(.bordered)
                Text("最低：\(low.map(NoteMath.name(midi:)) ?? "—") · 最高：\(high.map(NoteMath.name(midi:)) ?? "—")")
                if let low, let high {
                    Text("可手动微调测量结果")
                    Stepper("最低 \(NoteMath.name(midi: low))", value: Binding(get: { low }, set: { self.low = $0 }), in: 24...96)
                    Stepper("最高 \(NoteMath.name(midi: high))", value: Binding(get: { high }, set: { self.high = $0 }), in: 24...96)
                    Button("保存舒适音域") {
                        guard low <= high else { error = "最低音需要低于最高音"; return }
                        onSave(VocalRange(low: low, high: high))
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                if model.status == .denied { Text("请到系统设置中开启麦克风权限。") }
                if let error { Text(error).foregroundStyle(.red) }
                Spacer()
            }
            .padding()
            .navigationTitle("测量舒适音域")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
            .onDisappear { model.stop() }
        }
    }
}
