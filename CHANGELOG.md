# Changelog

## Unreleased: V1.1

- Whisper small and compressed large-v3-turbo with fully local tokenizers.
- Automatic or explicit transcription language, including English and Korean.
- Validated, copied local WhisperKit model imports with persistence.
- Existing Bark models and local-only inference retained.
- Local testing only; do not treat this branch as a published release.

## 0.1.0-preview.1

Initial source-only preview from DOO MADE.

- English on-device dictation with Bark 3.0, Plus and Pro.
- Explicit verified model download/repair and selected-model restoration.
- Microphone readiness, per-app input selection and five-second signal test.
- Configurable tap/hold dictation and paste-last recovery shortcuts.
- Local word/phrase dictionary with edit, remove and undo.
- Guarded clipboard delivery, cancellation, interruption handling and five-minute limit.
- Notch/floating feedback and Settings reopening for the menu-bar app.

Build from source. No notarized binary, hosted CI, or broad device compatibility
claim is included. See docs/TESTING.md and docs/LICENSING.md.
