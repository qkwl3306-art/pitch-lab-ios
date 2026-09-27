# Singing Audio and Responsiveness Design

## Goal

Make phrase practice feel like singing with the melody, replace the piercing demonstration tone, and keep the controls responsive while pitch is being analyzed.

## Observed behavior

- The current demonstration plays each note as a looped pure sine wave.
- Starting practice enables microphone capture and a countdown, but it does not play the imported phrase.
- Every detected pitch is published to the SwiftUI model and appended to the chart readings, invalidating the practice view repeatedly.
- Demonstration currently starts and stops audio nodes for each note.

## Design

1. Render each phrase to one short, soft piano-like mono audio buffer. Use a gentle attack/release envelope and a low harmonic mix so the sound is less piercing than the current pure sine wave. Raise the playback gain substantially above the current 0.22 player level. Keep the note sequence faithful to imported onset, duration, and selected transposition.
2. Use that renderer for both “听示范” and the accompaniment during practice. After microphone startup and the existing three-second countdown, start the phrase buffer and capture at the same time. Use the normal play-and-record session mode for phrase practice so measurement mode does not suppress playback level. Prefer system echo-canceled input on supported iOS 18.2+ speaker routes so the accompaniment is less likely to contaminate pitch analysis. Stop/cancel must stop both capture and playback.
3. Keep the pitch samples needed for scoring separate from display updates. Throttle published pitch/chart changes to a small fixed rate (target 5 updates per second), and keep only the current phrase’s display points. Scoring continues to receive the unthrottled valid samples for the entire phrase.
4. Add unit tests for phrase audio rendering (timing, transposition, finite bounded samples) and for UI update throttling. Preserve existing phrase scoring thresholds and countdown behavior.

## Boundaries

- The accompaniment is synthesized from the imported SVP/MIDI note track; it is not an original recording or backing track.
- No song library, microphone-based note extraction changes, scoring-rule changes, or new user-facing sound settings are included.
- The same softer, louder sound applies to phrase demonstration and phrase accompaniment. Piano-key and ear-training sounds are outside this change.

## Acceptance criteria

- Tapping “听示范” plays the complete current phrase with a softer piano-like timbre, honoring note timing and transposition.
- Starting practice counts down, then plays the phrase accompaniment while microphone capture and scoring continue.
- Phrase demonstration and accompaniment use a stronger playback gain than the current 0.22 level without clipping the rendered samples.
- On supported iOS 18.2+ routes, phrase capture requests echo-canceled input; unsupported routes keep the normal pitch-capture path.
- Stop, finish, phrase change, and cancellation stop phrase playback and microphone capture.
- The pitch view updates at no more than about 5 Hz, while the scorer still receives raw capture samples.
- New unit tests and the existing simulator unit/UI test suite pass in GitHub Actions. Real-device latency and sound quality still require checking on the user’s iPhone.
