# Score Import and Singing Practice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import PDF, photos, MusicXML and MXL; show scores and let users practice pitch with per-note results for MusicXML.

**Architecture:** A store copies selected files into app Documents. A parser extracts first-part melody from MusicXML; ZIPFoundation reads compressed MXL. Practice state reuses microphone pitch and tone playback services. PDFKit and SwiftUI render visual scores.

**Tech Stack:** SwiftUI, PDFKit, PhotosUI, Foundation XMLParser, ZIPFoundation, XCTest.

## Global Constraints

- Minimum iOS 17.
- No file or microphone data leaves the device.
- PDF/photo is visual practice only; MusicXML/MXL uses manual target-note stepping.
- ±30 cents marks a stable target note accurate.

---

### Task 1: Score parsing

**Files:** `PitchLab/Score/MusicXMLParser.swift`, `PitchLab/Score/MXLLoader.swift`, `PitchLabTests/MusicXMLParserTests.swift`, `project.yml`.

**Interfaces:** `MusicXMLParser.parse(data:) throws -> [Int]`; `MXLLoader.load(url:) throws -> Data`.

- [ ] Add tests for notes, sharps, flats, rests, chords, first part and malformed XML; run CI to see missing parser failure.
- [ ] Implement XMLParser delegate and restricted MXL archive lookup using ZIPFoundation.
- [ ] Run CI and fix parser/test failures.
- [ ] Commit.

### Task 2: Store and visual score display

**Files:** `PitchLab/Score/ScoreStore.swift`, `PitchLab/Features/Practice/PracticeView.swift`, `PitchLab/Features/Practice/PDFScoreView.swift`, `PitchLab/ContentView.swift`.

**Interfaces:** Store imports a URL or image data, lists items by id/name/type, removes item by id; practice view selects a saved score.

- [ ] Implement Files importer for XML/MXL/PDF and Photos Picker for images.
- [ ] Copy imported content to Documents, reject unsupported or damaged files, and render PDF/image/MusicXML notes.
- [ ] Add fourth tab and commit.

### Task 3: Practice audio and scoring

**Files:** `PitchLab/Features/Practice/PracticeViewModel.swift`, `PitchLabTests/PracticeScoringTests.swift`, `README.md`.

**Interfaces:** `PracticeScoring.isAccurate(frequency:targetMIDI:) -> Bool`; model starts/stops microphone, changes target, plays reference note and tracks result.

- [ ] Add tests for ±30 cents, silence and target change, and observe expected failure in CI.
- [ ] Implement scoring, integrate existing pitch service and tone player, show curve/readout.
- [ ] Run CI test, device build, and unsigned IPA packaging; document limitations.
- [ ] Commit and push.

### Task 4: Transposition

**Files:** `PitchLab/Features/Practice/PracticeSession.swift`, `PitchLab/Features/Practice/PracticeViewModel.swift`, `PitchLab/Features/Practice/PracticeView.swift`, `PitchLabTests/PracticeScoringTests.swift`.

**Interfaces:** `PracticeSession.setTransposition(_:)` accepts −12...+12; `currentMIDI` and reference playback use transposed pitch.

- [ ] Add tests for two-semitone lowering, ±12 bounds and score reset after a key change; run CI to see failure.
- [ ] Implement transposed targets and a semitone stepper in the practice view.
- [ ] Run CI tests and unsigned IPA packaging; commit and push.
