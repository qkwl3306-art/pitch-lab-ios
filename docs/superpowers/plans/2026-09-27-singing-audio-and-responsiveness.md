# Singing Audio and Responsiveness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make phrase demonstration audible and gentle, play the imported melody during singing practice, and keep the pitch screen responsive.

**Architecture:** A pure PCM renderer creates one enveloped phrase buffer from onset/duration/MIDI events. `TonePlayer` schedules that buffer for demonstration or simultaneous play-and-record. `PhrasePracticeViewModel` stores all scoring readings privately and publishes a rate-limited, bounded display stream.

**Tech Stack:** Swift 5, SwiftUI, AVFoundation, Combine, XCTest, GitHub Actions on macOS.

## Global Constraints

- Keep iOS deployment target 17.0.
- Preserve existing pitch-scoring thresholds and the three-second countdown.
- Synthesize accompaniment only from imported score notes; do not download or claim to provide original recordings.
- Keep full-rate microphone samples for scoring and limit only UI updates.
- Verify simulator tests and unsigned device IPA through the existing GitHub Actions workflow.

---

### Task 1: Phrase PCM renderer

**Files:**
- Create: `PitchLab/Audio/ToneSequenceRenderer.swift`
- Test: `PitchLabTests/ToneSequenceRendererTests.swift`

**Interfaces:**
- Produces `ToneSequenceEvent(midi: Int, onset: Double, duration: Double)` and `ToneSequenceRenderer.render(events:sampleRate:) -> [Float]`.
- Uses event onset relative to phrase start. Output ends with a 120 ms release tail.

- [ ] **Step 1: Write tests first** for silence before a delayed first note, nonzero audible samples during notes, a release tail, and finite samples bounded to `[-1, 1]`.
- [ ] **Step 2: Run the test on macOS CI and confirm it fails because the renderer is absent.** Windows has no Swift/Xcode runtime, so use a temporary test-only commit only if a red run is needed; do not leave the test-only commit on main.
- [ ] **Step 3: Implement a 44.1 kHz renderer** with a 10 ms attack, 120 ms release, fundamental plus quiet second and third harmonics, and a peak-safe per-phrase gain. Derive every sample from event MIDI, onset, and duration.
- [ ] **Step 4: Run the focused renderer tests and confirm they pass.**

### Task 2: Shared demonstration and sing-along accompaniment

**Files:**
- Modify: `PitchLab/Audio/TonePlayer.swift`
- Modify: `PitchLab/Audio/MicrophonePitchService.swift`
- Modify: `PitchLab/Features/Practice/PhrasePracticeViewModel.swift`
- Test: `PitchLabTests/ToneSequenceRendererTests.swift`

**Interfaces:**
- `TonePlayer.playPhrase(_ samples: [Float], duringCapture: Bool)` schedules one pre-rendered phrase buffer.
- `MicrophonePitchService.start(mode: AVAudioSession.Mode? = nil)` keeps existing callers in measurement mode and permits phrase practice to request `.default`.

- [ ] **Step 1: Extend the renderer tests** to verify a transposed event changes pitch while keeping its onset and duration.
- [ ] **Step 2: Implement one sequence player node** in `TonePlayer`; use `.playback/.default` for demonstration and preserve `.playAndRecord/.default` during practice. Set sequence gain to 0.62 (from 0.22 on the old note player). Stop and detach the sequence node on cancellation or completion.
- [ ] **Step 3: Set microphone capture mode per start request** and request echo-canceled input on iOS 18+ only when the active built-in speaker/microphone route reports support; ignore optional echo-cancellation errors so recording still starts.
- [ ] **Step 4: Change preview to schedule the phrase once** instead of creating and detaching an audio node for every note.
- [ ] **Step 5: Before microphone startup, build phrase events from the selected score range, apply `shift`, and render them off the main actor. After the existing countdown, set the scoring time origin and start the phrase player while recording.** Stop playback in `stop()` and `finish()`.
- [ ] **Step 6: Run all existing phrase scoring, microphone, renderer, and UI tests.**

### Task 3: Rate-limit display updates without losing scoring samples

**Files:**
- Create: `PitchLab/Features/Practice/PitchDisplayLimiter.swift`
- Modify: `PitchLab/Features/Practice/PhrasePracticeViewModel.swift`
- Test: `PitchLabTests/PitchDisplayLimiterTests.swift`

**Interfaces:**
- `PitchDisplayLimiter.shouldPublish(at:) -> Bool` permits an immediate first value and then at most one display update per 0.2 seconds.
- Private raw readings feed `PhraseScoring`; published readings retain only the current phrase and no more than 256 display points.

- [ ] **Step 1: Write tests first** for the first update, rejection inside 0.2 seconds, acceptance at the interval, and recovery after a longer gap.
- [ ] **Step 2: Run the focused limiter tests and confirm they fail because the limiter is absent.**
- [ ] **Step 3: Implement the limiter** and apply it only to published `currentHz`/chart readings; append every incoming capture sample to a non-published scoring array.
- [ ] **Step 4: Update `finish()`** to score from raw samples, and reset both arrays at the start of each attempt.
- [ ] **Step 5: Run limiter and phrase scoring tests.**

### Task 4: Integration verification

**Files:**
- Modify: `docs/superpowers/plans/2026-09-27-singing-audio-and-responsiveness.md`

- [ ] **Step 1: Run `git diff --check`.**
- [ ] **Step 2: Push the implementation and wait for GitHub Actions** to complete simulator build, unit/UI tests, device build, Info.plist checks, and unsigned IPA packaging.
- [ ] **Step 3: Review the run summary for all test counts and artifact SHA-256.**
- [ ] **Step 4: Deliver the IPA and state that speaker bleed, actual loudness, and responsiveness still need an iPhone check.**

## Self-review

- Renderer, accompaniment, playback gain/session mode, sample throttling, raw scoring, and CI acceptance all have explicit tasks.
- All new symbols and file paths are defined in the task interfaces.
- No placeholders or scoring-rule changes remain in the plan.
