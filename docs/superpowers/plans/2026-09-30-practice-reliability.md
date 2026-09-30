# Practice reliability repair plan

Goal: Fix the six review findings approved by the user on 2026-09-30.

Architecture: Keep self-paced scoring independent of audio capture. Bind retry actions to the displayed score, phrase, transposition and mode. Retain capture across repeated attempts and throttle display publication independently of scoring.

Tech stack: SwiftUI, Combine, AVFoundation, XCTest, GitHub macOS CI.

- [x] Reproduce retry stalls, stale phrase state and incorrect skipped-note feedback with failing tests.
- [x] Repair retry traversal in SelfPacedPracticeSession; test several remaining unresolved notes.
- [x] Inject capture and clock into PhrasePracticeViewModel for deterministic tests; preserve active microphone across restart and mode changes.
- [x] Initialize historical retry using current context and previous feedback; clear presentation on stop.
- [x] Record per-note pitch evidence and label unknown skipped notes as pending retry.
- [x] Replace fixed-duration rounded trace with a rolling eight-second fractional-pitch trace and current target guide.
- [x] Wire mode changes, historical retry and complete-phrase restart in VocalPracticeView.
- [x] Run regression suite and simulator UI tests in GitHub CI; inspect build results and download verified unsigned IPA.

Verification: Base repairs passed 90 unit tests, 5 simulator UI tests and the unsigned device build in run 36723429254. The follow-up test for skipping all unresolved retry notes failed as expected in run 36723750488; the final build must pass this regression before delivery.

