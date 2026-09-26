import SwiftUI

struct QuizView: View {
    @StateObject private var model = QuizViewModel()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if model.session.isFinished {
                        results
                    } else {
                        quiz
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("听音测试")
            .onAppear { if !model.session.isFinished { model.playCurrent() } }
            .onDisappear { model.stop() }
        }
    }

    private var quiz: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Text("第 \(model.session.answers.count + 1) / \(model.session.notes.count) 题")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Image(systemName: "music.note")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(.indigo)
                    .frame(height: 90)
                Text("你听到了哪个音？")
                    .font(.title2.bold())
                Button {
                    model.playCurrent()
                } label: {
                    Label("再听一次", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<12, id: \.self) { pitchClass in
                    Button(NoteMath.pitchClasses[pitchClass]) {
                        model.answer(pitchClass)
                    }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Text("请不要借助钢琴或参考音。成绩仅反映本轮辨音表现。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var results: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.indigo)
                Text("本轮完成")
                    .font(.title.bold())
                Text("\(model.session.score) / \(model.session.notes.count)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                Text("正确率 \(model.session.score * 100 / max(model.session.notes.count, 1))%")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))

            VStack(spacing: 0) {
                ForEach(Array(model.session.notes.enumerated()), id: \.offset) { entry in
                    let index = entry.offset
                    let note = entry.element
                    HStack {
                        Text("第 \(index + 1) 题")
                        Spacer()
                        Text("你选 \(NoteMath.pitchClasses[model.session.answers[index]])")
                        Text("答案 \(NoteMath.name(midi: note))")
                            .fontWeight(.semibold)
                            .foregroundStyle(note % 12 == model.session.answers[index] ? .green : .orange)
                    }
                    .padding(.vertical, 10)
                    if index < model.session.notes.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))

            Button("再测一轮") { model.restart() }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.large)
        }
    }
}
