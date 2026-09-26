# Pitch Lab iOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS music tool with live pitch, piano, and ear quiz; produce an unsigned IPA through GitHub Actions.

**Architecture:** SwiftUI owns navigation and display. AVAudioEngine handles microphone and tone output. A pure NoteMath module converts frequencies and notes; a detector estimates fundamentals; view models isolate state. XcodeGen produces the Xcode project from a checked-in YAML specification.

**Tech Stack:** Swift 5.9+, SwiftUI, AVFoundation, Accelerate, XCTest, XcodeGen, GitHub Actions macOS runner.

## Global Constraints

- Minimum iOS 17.
- No network use at runtime, third-party app dependencies, or recorded audio storage.
- CI creates an unsigned IPA; user signs it before installation.
- Three tabs: pitch, piano, quiz.

---

### Task 1: Project and note math

**Files:** `project.yml`, `PitchLab/App/PitchLabApp.swift`, `PitchLab/Audio/NoteMath.swift`, `PitchLabTests/NoteMathTests.swift`.

**Interfaces:** `NoteMath.nearestMIDINote(frequency:) -> Int?`, `NoteMath.frequency(midi:) -> Double`, `NoteMath.cents(frequency:midi:) -> Double`, `NoteMath.name(midi:) -> String`.

- [ ] Write tests for A4=440, octave conversion, invalid frequencies and 50-cent offset.
- [ ] Implement NoteMath and app entry.
- [ ] Define XcodeGen app and unit-test targets, iOS 17, microphone usage text.
- [ ] Commit.

### Task 2: Pitch detection and microphone

**Files:** `PitchLab/Audio/PitchDetector.swift`, `PitchLab/Audio/MicrophonePitchService.swift`, `PitchLab/Features/Pitch/PitchViewModel.swift`, `PitchLabTests/PitchDetectorTests.swift`.

**Interfaces:** `PitchDetector.detect(samples:sampleRate:) -> Double?`; `MicrophonePitchService.start()`, `.stop()`, `.pitchHz`.

- [ ] Write generated sine and silence tests for detector.
- [ ] Implement autocorrelation with energy floor and confidence threshold.
- [ ] Capture microphone frames and publish throttled pitch updates on main actor.
- [ ] Convert results into note, cents and rolling history; handle permission and interruptions.
- [ ] Commit.

### Task 3: Tone player and piano

**Files:** `PitchLab/Audio/TonePlayer.swift`, `PitchLab/Features/Piano/PianoView.swift`.

**Interfaces:** `TonePlayer.noteOn(midi:)`, `.noteOff(midi:)`, `.stopAll()`.

- [ ] Implement sine-based polyphonic tone output with short attack and release.
- [ ] Build scrollable C3–B5 keyboard with touch down/up interaction.
- [ ] Verify source wiring and commit.

### Task 4: Quiz and app UI

**Files:** `PitchLab/Features/Quiz/QuizViewModel.swift`, `PitchLab/Features/Quiz/QuizView.swift`, `PitchLab/Features/Pitch/PitchView.swift`, `PitchLab/ContentView.swift`, `PitchLabTests/QuizViewModelTests.swift`.

**Interfaces:** Quiz model starts 10-note round, accepts pitch classes, reports score and per-question answers.

- [ ] Test question count, scoring and result transition.
- [ ] Implement quiz state and three-tab SwiftUI interface.
- [ ] Implement permission/error UI and pitch curve.
- [ ] Commit.

### Task 5: CI and delivery

**Files:** `.github/workflows/ios.yml`, `README.md`, `.gitignore`.

- [ ] Define macOS workflow that installs XcodeGen, generates project, runs iOS simulator tests, archives without signing and packages Payload/PitchLab.app as `.ipa`.
- [ ] Document build, signing responsibility and real-device checks.
- [ ] Push to GitHub and inspect workflow run, fix compile and test errors.
- [ ] Download or link successful unsigned IPA artifact.
