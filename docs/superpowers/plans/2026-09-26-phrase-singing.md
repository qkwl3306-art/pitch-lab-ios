# 人声乐谱逐句练唱 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从 SVP/MIDI 人声旋律和单独歌词创建逐句练唱、错音重练与个人音域推荐。

**Architecture:** 将 SVP/MIDI 解析为统一的定时音符，再由分句器和歌词映射器生成练习数据。练习引擎只接受带时间的音高帧，独立于 UI；SwiftUI 负责导入、试听、倒数、显示结果与音域测试。持久化沿用 ScoreStore，保持旧清单可读。

**Tech Stack:** Swift 5, SwiftUI, AVFoundation, Foundation JSON, XCTest, XcodeGen, GitHub Actions macOS simulator.

## Global Constraints

- iOS 最低版本 17.0；未签名 IPA 由 GitHub Actions 生成，用户自行签名。
- SVP 与 MIDI 取人声旋律；LRC/TXT 为单独歌词；PDF/照片继续只看谱。
- 音准逐音容差 ±50 音分；推荐移调范围 -12 到 +12 半音。
- 音高分析仅在设备端，练习不保存原始录音。

---

### Task 1: 统一旋律模型与 SVP 解析

**Files:** Create `PitchLab/Score/VocalScore.swift`, `PitchLab/Score/SVPParser.swift`; Test `PitchLabTests/SVPParserTests.swift`.

**Interfaces:** `VocalNote(onset: Double, duration: Double, midi: Int, lyric: String?)`; `VocalScore(notes: [VocalNote], title: String)`; `SVPParser.parse(data: Data) throws -> VocalScore`.

- [ ] 从用户样例写 260 音符、音域和首尾时间测试，再写变速、无效文件测试。
- [ ] 运行 GitHub XCTest 确认新测试失败。
- [ ] 实现 SVP 时间映射、主轨与偏移解析；重跑测试通过。
- [ ] 提交。

### Task 2: MIDI 人声轨解析

**Files:** Create `PitchLab/Score/MIDIParser.swift`; Test `PitchLabTests/MIDIParserTests.swift`.

**Interfaces:** `MIDIParser.parse(data: Data) throws -> VocalScore`，多轨时优先 `Vocal`，再取第一条有效旋律轨。

- [ ] 用用户 MIDI 样例和构造变速、running status、损坏文件测试。
- [ ] 实现标准 MIDI 时间、note on/off 配对和轨道选择。
- [ ] GitHub XCTest 通过后提交。

### Task 3: 分句、歌词与存储

**Files:** Create `PitchLab/Score/PhraseBuilder.swift`, `PitchLab/Score/LyricsParser.swift`; modify `PitchLab/Score/ScoreStore.swift`, `PitchLab/Score/ScoreImportError.swift`; Tests `PitchLabTests/PhraseBuilderTests.swift`, `PitchLabTests/LyricsParserTests.swift`, `PitchLabTests/ScoreStoreTests.swift`.

**Interfaces:** `VocalPhrase(id: Int, noteRange: Range<Int>, text: String)`; `PhraseBuilder.make(score:)`; `LyricsParser.parseLRC/parseTXT`; `ScoreStore.importFile` accepts `.svp`, `.mid`, `.midi`, `.lrc`, `.txt` and persists optional vocal score/lyrics with backward compatible defaults.

- [ ] 写分句、歌词对应与旧清单解码测试。
- [ ] 实现导入和可修改的乐句边界/文字持久化。
- [ ] GitHub XCTest 通过后提交。

### Task 4: 逐句评分引擎与示范音

**Files:** Create `PitchLab/Features/Practice/PhraseScoring.swift`, `PitchLab/Features/Practice/PhrasePracticeViewModel.swift`; modify `PitchLab/Audio/TonePlayer.swift`; Tests `PitchLabTests/PhraseScoringTests.swift`.

**Interfaces:** 输入 `TimedPitchReading(time: Double, frequency: Double?)` 与目标乐句，输出逐音 `passed`, `cents`, `reason` 和整句通过状态；ViewModel 管理倒数、录音采样、重试、试听。

- [ ] 写准音、偏高、偏低、漏唱、换音边界、整句重试测试。
- [ ] 实现离线帧评分与实时状态机，试听按谱面时值播放。
- [ ] GitHub XCTest 通过后提交。

### Task 5: 音域测试与推荐调

**Files:** Create `PitchLab/Features/Practice/VocalRange.swift`, `PitchLab/Features/Practice/KeyRecommendation.swift`; Tests `PitchLabTests/KeyRecommendationTests.swift`.

**Interfaces:** `VocalRange(low: Int, high: Int)` 保存本地；`KeyRecommendation.recommend(notes: [Int], range: VocalRange) -> KeyAdvice`。

- [ ] 写覆盖率、边界、无完全覆盖、同分最小移调测试。
- [ ] 实现稳定音高采集、手动修正、推荐计算。
- [ ] GitHub XCTest 通过后提交。

### Task 6: SwiftUI 交互与交付

**Files:** Modify `PitchLab/Features/Practice/PracticeView.swift`, `PitchLabUITests/PitchLabUITests.swift`, `README.md`, `.github/workflows/ios.yml`.

- [ ] 加入 SVP/MIDI 与 LRC/TXT 导入、乐句列表、音高轨道、逐音反馈、音域测试和推荐调操作。
- [ ] 添加模拟器 UI 流程，验证导入样例、试听与重练按钮可用，上传截图。
- [ ] 检查旧乐谱导入及钢琴/听音测试无回归。
- [ ] GitHub CI 全部通过，下载新 IPA，核对 Info.plist 与哈希，合入 main 并交付。
