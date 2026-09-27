# Continuous Self-Paced Singing Practice Design

## Goal

Make score practice follow the learner's pace instead of requiring a new three-second countdown and a fixed-timing attempt for every phrase. Keep the microphone running through a practice attempt, let the learner repeat a difficult note, tolerate short pauses, and offer both note-by-note and whole-phrase practice.

## Current behavior and problem

Phrase practice starts a three-second countdown, plays the whole synthesized phrase, and stops capture after the score's fixed duration. Scoring compares microphone readings against score note time windows. A tempo difference or a short pitch-detection gap can therefore make a sung note appear missed. Repeating the phrase requires starting another attempt.

## Design

### Shared session behavior

- Replace the attempt button label with “准备好了”. Starting a practice mode requests microphone access and begins continuous capture immediately; do not show the three-second countdown.
- Keep capture active while the learner repeats notes and advances through the selected phrase. Stop capture only when the learner stops, leaves the screen, or completes/exits the exercise.
- Retain score import, phrase selection, transposition, vocal-range advice, and manual “听示范”. Do not automatically play fixed-tempo accompaniment during self-paced practice.
- A short silence of up to two seconds does not fail or advance a note. The active target remains visible. Silence alone never produces “漏唱”.
- Keep the current ±50-cent accuracy threshold. A note passes only after a short stable run of valid pitch readings within tolerance, avoiding progress on a single noisy frame. Show current target, detected pitch/deviation, and note status as they update.
- A note that the learner explicitly skips remains incomplete. At exercise completion, notes not sung accurately or explicitly skipped are reported as needing practice rather than silently passed.

### Practice modes

1. **逐音练习** — Show one target note at a time. The learner can repeat it for as long as needed. Once it is accurate, they tap “下一个音”; tapping next while it is inaccurate marks it for later review. The microphone stays active across all notes.
2. **递进练句** — Start with the first note. After a stage is accurate, expand the target segment by one note. Each new stage is sung again from the phrase beginning, so the learner builds a longer accurate sequence until reaching the whole phrase. Short pauses do not reset the stage.
3. **整句跟唱** — Follow the score from its first note to its last note. Advance automatically after a target has stable in-tune readings; when the learner is off pitch, keep the current target active so they can correct it. The learner may manually skip a target. A short pause keeps the current target rather than advancing based on elapsed time.

### Feedback and recovery

- Keep per-note results visible while practicing and summarize notes that need another try when the learner finishes the phrase.
- Let the learner retry the current note or restart the phrase without reopening the microphone or waiting through another countdown.
- Preserve the existing saved per-phrase practice history and passing status behavior where compatible with the new modes.
- If microphone permission is denied or capture fails, show the existing actionable microphone error state and do not start the exercise.

## Boundaries

- This change concerns self-paced phrase practice using the imported SVP/MIDI pitch sequence; it does not extract notes from audio or add automatic lyric transcription.
- It does not change score import formats, transposition limits, key recommendation, demo timbre, or the ±50-cent threshold.
- The synthesized demo remains available on demand, but self-paced modes do not start fixed-tempo accompaniment automatically.

## Acceptance criteria

- Tapping “准备好了” starts microphone capture without a three-second countdown.
- The microphone remains active while notes are repeated and while the learner advances through a phrase.
- In note-by-note mode, each target remains available until the learner advances; an inaccurate note can be repeated without restarting the phrase.
- In progressive mode, each successful stage adds one note and the expanded segment is sung again from the phrase beginning.
- In whole-phrase mode, stable accurate pitch advances the target; inaccurate pitch retains it for correction.
- One- to two-second silences do not mark a note missed, reset practice progress, or advance the target.
- Explicit skips are visible as incomplete, and phrase completion reports unresolved notes.
- Live pitch display remains responsive without dropping microphone samples needed to judge stability.
- Unit tests cover stable pitch confirmation, inaccurate retries, pause tolerance, manual advance/skip, progressive stage growth, and automatic whole-phrase progression. The existing simulator UI/unit suite and unsigned IPA workflow pass in GitHub Actions.

## Design self-review

- The three requested interaction styles are distinct and have explicit advancement rules.
- Pause behavior is consistent: silence never advances or fails a target; only accurate pitch or an explicit user action changes progression.
- Existing scoring threshold, imported target source, and unrelated features remain in scope boundaries.
- No placeholders remain. Platform-specific microphone failures retain existing error handling.
