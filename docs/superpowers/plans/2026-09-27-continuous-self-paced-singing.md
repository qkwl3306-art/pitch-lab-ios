# Continuous Self-Paced Singing Practice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fixed-tempo phrase attempts with continuous microphone practice that supports note-by-note repetition, progressive phrase building, and self-paced whole-phrase singing.

**Architecture:** Add a pure, testable practice state machine for the three modes and stable-pitch confirmation. Keep microphone capture active in the view model, feed every detected pitch to the state machine, and publish only the state needed by the UI. Update the phrase screen to select a mode, display and scroll to the active score note, and offer retry, advance, skip, restart, and stop actions.

**Tech Stack:** Swift 5, SwiftUI, AVFoundation, Combine, XCTest, GitHub Actions on macOS 15.

## Global Constraints

- Keep iOS deployment target 17.0.
- Replace the attempt button label with “准备好了”. Starting a practice mode requests microphone access and begins continuous capture immediately; do not show the three-second countdown.
- A short silence of up to two seconds does not fail or advance a note. The active target remains visible. Silence alone never produces “漏唱”.
- Keep the current ±50-cent accuracy threshold.
- After showing a completion summary, keep the microphone session available for immediate retries. Stop capture when the learner taps stop/done or leaves the screen.
- Do not automatically play fixed-tempo accompaniment during self-paced practice. Retain manual “听示范”.
- Keep all detected samples needed for stable-pitch confirmation; throttle only UI presentation.
- Run simulator tests and unsigned IPA packaging through the existing GitHub Actions workflow.

---

### Task 1: Add self-paced practice state and stable pitch matcher

**Files:**
- Create: `PitchLab/Features/Practice/SelfPacedPracticeSession.swift`
- Test: `PitchLabTests/SelfPacedPracticeSessionTests.swift`
- Modify: `project.yml` only if the new source/test files are not included by the existing directory source globs.

**Interfaces:**
- `enum SelfPacedPracticeMode: String, CaseIterable` with `.noteByNote`, `.progressive`, and `.wholePhrase`.
- `struct SelfPacedPracticeSession` initialized with `noteRange: Range<Int>` and `mode: SelfPacedPracticeMode`.
- Expose `currentNoteIndex: Int?`, `progressiveEndIndex: Int?`, `passedNoteIndices: Set<Int>`, `skippedNoteIndices: Set<Int>`, and `isComplete: Bool`.
- `mutating func observe(frequency: Double?, targetMIDI: Int, at time: TimeInterval) -> SelfPacedPitchUpdate` computes cents and confirms stable pitch only after at least 0.25 seconds of consecutive in-tune readings within ±50 cents. Nil/out-of-range readings reset only the stability window; they do not fail or advance the target.
- `mutating func advance()`, `skipCurrent()`, `retryCurrent()`, and `restart()` implement explicit controls. In note-by-note mode, `advance()` advances a passed note or records an inaccurate current note as unresolved before moving forward.
- `SelfPacedPitchUpdate` returns current cents, whether the target just passed, and whether the exercise stage/phrase completed.

- [ ] **Step 1: Add failing state tests** for mode initialization, bad-pitch retry, in-tune stable confirmation, nil/short-pause tolerance, manual advancement and skip, progressive prefix growth, whole-phrase auto-advance, consecutive repeated notes requiring a new pitch attack or manual advance, and final completion retaining the session for retry.
- [ ] **Step 2: Run the new tests in macOS CI** and confirm the missing state type causes the focused test build to fail. Do not attempt to run Xcode on Windows.
- [ ] **Step 3: Implement the smallest pure state machine** with one authoritative current index. In progressive mode, set the initial end index to the first note; after the full prefix is accurately sung, increment the end index and reset the current index to the phrase start. In whole-phrase mode, auto-advance only after stable confirmation. In note-by-note mode, mark accurate notes passed but wait for `advance()`.
- [ ] **Step 4: Implement explicit skip and retry semantics.** Skipping records the current note index as unresolved and advances; note-by-note advance uses the same rule if the note is still inaccurate. Retry clears that note's unresolved state and resets its stable-pitch window. Restart returns to the first note and clears attempt-local results.
- [ ] **Step 5: Run the focused state tests** and verify short nil-pitch gaps do not mark misses, stable readings do, and accurate/skip sets remain disjoint.
- [ ] **Step 6: Commit** as `feat: model self-paced singing progress`.

### Task 2: Integrate continuous capture and live feedback in the view model

**Files:**
- Modify: `PitchLab/Features/Practice/PhrasePracticeViewModel.swift`
- Test: `PitchLabTests/SelfPacedPracticeSessionTests.swift`
- Reuse: `PitchLab/Audio/MicrophonePitchService.swift`

**Interfaces:**
- Add published `mode`, `targetNoteIndex`, `targetCents`, `passedNoteIndices`, `skippedNoteIndices`, and `sessionSummary` to `PhrasePracticeViewModel`.
- Replace `.countdown(Int)` attempt lifecycle with `.idle`, `.listening`, and `.complete`; keep microphone error state from `MicrophonePitchService`.
- `begin(score:phrase:transposition:mode:)` initializes the state machine and starts `microphone.start(mode: .default)` immediately.
- `advance()`, `skipCurrent()`, `retryCurrent()`, and `restart()` forward explicit learner actions into the session state.

- [ ] **Step 1: Remove the three-second countdown and fixed-duration auto-finish task.** Start capture immediately after the learner chooses a mode and taps “准备好了”.
- [ ] **Step 2: Feed every incoming microphone pitch to the state machine** with the selected score note's MIDI plus transposition. A transition to an identical consecutive MIDI target must re-arm after an observed pitch break so one sustained sound cannot pass two notes; the manual advance control remains available for legato repeated notes. Continue updating detected pitch/deviation at the existing display-limited cadence and preserve pitch history for the graph.
- [ ] **Step 3: Keep microphone capture active after phrase completion** while the summary is visible; stop only on stop/done, explicit new phrase/mode setup, or view disappearance. Restart/retry must not insert a countdown.
- [ ] **Step 4: Keep manual preview separate.** Preview may stop an active practice session before playing; starting a practice mode must never auto-play a fixed-tempo sequence.
- [ ] **Step 5: Run state, pitch display limiter, phrase scoring, and microphone capture tests.**
- [ ] **Step 6: Commit** as `feat: keep singing practice continuously listening`.

### Task 3: Add mode controls and self-paced score presentation

**Files:**
- Modify: `PitchLab/Features/Practice/VocalPracticeView.swift`
- Create if needed: `PitchLab/Features/Practice/SelfPacedPracticeControls.swift`
- Test: `PitchLabUITests/PitchLabUITests.swift`

**Interfaces:**
- Provide a three-choice mode control bound to `SelfPacedPracticeMode`.
- In idle state, show “准备好了”; while listening show target note, detected note/cents, live status, and mode-specific actions; in complete state show unresolved notes plus immediate retry/restart controls.
- The score-note strip uses `ScrollViewReader` and scrolls the active note into view when `targetNoteIndex` changes.
- In note-by-note mode expose repeat/retry, “下一个音”, and explicit skip. In progressive mode show current prefix length and completion before adding the next note. In whole-phrase mode show auto-follow plus manual skip.

- [ ] **Step 1: Add UI tests** that import a fixture score and verify all three mode choices, immediate listening without countdown, note-by-note controls, progressive stage indicator, and whole-phrase live target.
- [ ] **Step 2: Run UI tests in macOS CI** and confirm the new controls are absent before implementation.
- [ ] **Step 3: Replace old “开始跟唱／重练本句” countdown controls** with the mode selector and “准备好了” action.
- [ ] **Step 4: Add target-note scrolling and pitch feedback** without rebuilding the complete screen for every audio frame; use the existing pitch display limiter for high-frequency visual data.
- [ ] **Step 5: Add complete/retry/stop controls** and show unresolved notes distinctly from passed notes. Preserve phrase selection, transposition, lyric editing, demo button, and stored per-phrase history.
- [ ] **Step 6: Run UI tests and review simulator screenshots** for an iPhone-size layout, mode switching, and target-note visibility.
- [ ] **Step 7: Commit** as `feat: add self-paced singing practice modes`.

### Task 4: Full verification and unsigned IPA delivery

**Files:**
- Modify: `docs/superpowers/plans/2026-09-27-continuous-self-paced-singing.md` to mark completed steps and record CI evidence.

- [ ] **Step 1: Run `git diff --check`** and inspect the final diff for accidental scoring-threshold or unrelated audio changes.
- [ ] **Step 2: Push the implementation to `main`** to trigger `.github/workflows/ios.yml`.
- [ ] **Step 3: Verify GitHub Actions** passes simulator unit/UI tests, device build, plist/document checks, and unsigned IPA packaging.
- [ ] **Step 4: Download the IPA artifact**, calculate its SHA-256, and verify it contains `Payload/PitchLab.app`.
- [ ] **Step 5: Report the workflow URL, test results, IPA path and checksum.** State that real-device self-paced pitch progression still needs the user's vocal/environment check.
- [ ] **Step 6: Commit** the plan's completed status and verification reference.

## Self-review

- Every design feature maps to a task: shared continuous session (Task 2), three learning modes and pause/retry/skip behavior (Tasks 1–3), live note scrolling/feedback (Task 3), microphone errors and retained session summary (Task 2), and CI/IPA delivery (Task 4).
- Tests exercise the pure progression rules and UI entry points. State-machine tests should verify stability and pauses without requiring hardware audio.
- The spec's existing ±50-cent threshold is unchanged; stable confirmation is a duration requirement, not a looser scoring threshold.
- No new dependency or unsupported deployment target is introduced.
