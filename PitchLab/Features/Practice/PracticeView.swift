import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PracticeView: View {
    @StateObject private var store = ScoreStore()
    @StateObject private var model = PracticeViewModel()
    @State private var selectedID: UUID?
    @State private var showFiles = false
    @State private var photoItem: PhotosPickerItem?
    @State private var errorMessage: String?

    private var selectedScore: StoredScore? { store.items.first { $0.id == selectedID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let score = selectedScore {
                        practice(score)
                    } else {
                        library
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(selectedScore?.name ?? "练唱")
            .toolbar {
                if selectedScore != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("乐谱库", systemImage: "chevron.left") {
                            model.stop()
                            selectedID = nil
                        }
                    }
                }
            }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .xml, .image, .data]) { result in
                do {
                    let score = try store.importFile(at: result.get())
                    open(score)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else {
                            throw ScoreImportError.invalidImage
                        }
                        let score = try store.importImage(data)
                        open(score)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    photoItem = nil
                }
            }
            .alert("导入失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .onDisappear { model.stop() }
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("导入乐谱，开始练唱")
                    .font(.title2.bold())
                Text("支持 MusicXML、MXL、PDF 和乐谱照片。PDF 与照片可边看边唱；MusicXML 可逐音检查音准。")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button { showFiles = true } label: {
                    Label("从文件导入", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("从照片导入", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
            }
            if store.items.isEmpty {
                ContentUnavailableView("还没有乐谱", systemImage: "music.note.list", description: Text("先导入一份乐谱或照片"))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
            } else {
                Text("我的乐谱")
                    .font(.headline)
                ForEach(store.items) { score in
                    Button { open(score) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: icon(for: score.kind))
                                .font(.title3)
                                .frame(width: 38, height: 38)
                                .background(.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading) {
                                Text(score.name).font(.headline)
                                Text(score.kind == .musicXML ? "\(score.notes.count) 个可练习音符" : "看谱练唱")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("删除乐谱", role: .destructive) { store.remove(score) }
                    }
                }
            }
        }
    }

    private func practice(_ score: StoredScore) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            scorePreview(score)
            if let session = model.session {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("移调")
                            .font(.headline)
                        Spacer()
                        Button { model.transpose(by: -1) } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .disabled(session.transposition <= -12)
                        Text(session.transposition == 0 ? "原调" : String(format: "%+d 半音", session.transposition))
                            .font(.subheadline.monospacedDigit())
                            .frame(minWidth: 78)
                        Button { model.transpose(by: 1) } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(session.transposition >= 12)
                    }
                    .buttonStyle(.borderless)
                    Text("目标音 \(session.index + 1) / \(session.notes.count)")
                        .font(.headline)
                    Text("本轮已达标 \(session.passedCount) / \(session.notes.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text(model.targetName)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Spacer()
                        Label(session.currentPassed ? "已达标" : "待练习", systemImage: session.currentPassed ? "checkmark.circle.fill" : "circle.dotted")
                            .foregroundStyle(session.currentPassed ? .green : .secondary)
                    }
                    Text("当前声音：\(model.currentName)  ·  \(model.pitchHz.map { String(format: "%.1f Hz", $0) } ?? "—")")
                    Text("与目标相差：\(model.cents.map { String(format: "%+.0f 音分", $0) } ?? "—")")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("上一个", systemImage: "chevron.left") { model.previous() }
                            .disabled(session.index == 0)
                        Button("听目标音", systemImage: "play.fill") { model.playTarget() }
                        Button("下一个", systemImage: "chevron.right") { model.next() }
                            .disabled(session.index >= session.notes.count - 1)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
            } else {
                Text("边看谱边唱，下面会显示你的实时音高。PDF 和图片暂不自动识谱。")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("实时音高")
                        .font(.headline)
                    Spacer()
                    Text(model.currentName)
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.mint)
                }
                PitchCurve(readings: model.history)
                    .frame(height: 150)
            }
            .padding(20)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))

            if model.status == .denied {
                Text("麦克风权限已关闭，请在系统设置中开启。")
                    .foregroundStyle(.orange)
            } else if case .failed(let message) = model.status {
                Text("音频启动失败：\(message)")
                    .foregroundStyle(.red)
            }
            Button {
                model.status == .listening ? model.stop() : model.start()
            } label: {
                Label(model.status == .listening ? "停止练唱" : "开始练唱", systemImage: model.status == .listening ? "stop.fill" : "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
            .controlSize(.large)
            Text("MusicXML 只读取首个分部的单声部旋律；手动切换目标音。连续唱准约 0.3 秒即达标。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func scorePreview(_ score: StoredScore) -> some View {
        switch score.kind {
        case .pdf:
            PDFScoreView(url: store.url(for: score))
                .frame(height: 370)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        case .image:
            ZoomableScoreImage(url: store.url(for: score))
                .frame(height: 370)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        case .musicXML:
            VStack(alignment: .leading, spacing: 12) {
                Text("旋律音符")
                    .font(.headline)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(score.notes.enumerated()), id: \.offset) { entry in
                            Text(NoteMath.name(midi: entry.element + (model.session?.transposition ?? 0)))
                                .font(.subheadline.bold())
                                .padding(10)
                                .background(entry.offset == model.session?.index ? Color.mint.opacity(0.3) : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(alignment: .topTrailing) {
                                    if model.session?.passedIndices.contains(entry.offset) == true {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                            .offset(x: 5, y: -5)
                                    }
                                }
                        }
                    }
                }
            }
            .padding(20)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private func icon(for kind: ScoreKind) -> String {
        switch kind {
        case .musicXML: "music.note.list"
        case .pdf: "doc.richtext"
        case .image: "photo"
        }
    }

    private func open(_ score: StoredScore) {
        selectedID = score.id
        model.select(score)
    }
}

private struct ZoomableScoreImage: View {
    let url: URL
    @State private var scale = 1.0

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(MagnificationGesture().onChanged { scale = max(1, min(4, $0)) })
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
