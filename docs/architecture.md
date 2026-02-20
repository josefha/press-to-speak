# MVP Architecture

## Goal

Hold a configurable key to record speech, release to transcribe via ElevenLabs, and paste text into the active app.

## Layers

1. `PressToSpeakApp` (UI + lifecycle)
- Menu bar shell
- Status and settings UI
- Invokes transcription pipeline

2. `PressToSpeakCore` (domain contracts)
- `AudioRecorder`
- `TranscriptionProvider`
- `TextPaster`
- `TranscriptionOrchestrator`

3. `PressToSpeakInfra` (concrete integrations)
- `.env` loader
- app settings persistence
- ElevenLabs provider adapter
- clipboard paste adapter
- (future) global hotkey + AVAudio recorder

## Data Flow

1. User holds configured hotkey.
2. Recorder starts.
3. User releases hotkey.
4. Recorder stops and yields audio file URL.
5. Prompt builder merges:
- default system prompt
- user context
- custom vocabulary
6. Provider sends request to ElevenLabs or proxy API.
7. Result text is returned.
8. Text is pasted into focused field and clipboard is restored.

## Epics

1. Repository + Build Foundations (done)
2. Menu Bar UX + Settings (done for MVP)
3. Global Hold-to-Talk (done for MVP)
4. Audio Capture (done for MVP)
5. ElevenLabs API Integration (done for MVP)
6. Prompt and Vocabulary Controls (basic MVP done)
7. Safe Paste + Permissions UX (basic MVP done)
8. Packaging, codesign, and release docs (in progress)

## Future Extensions

- Local transcription provider behind `TranscriptionProvider` protocol.
- User-defined spoken shortcuts (phrase expansion).
