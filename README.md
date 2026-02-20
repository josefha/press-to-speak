# PressToSpeak (macOS Menu Bar App)

Swift/SwiftUI macOS menu bar app for hold-to-talk voice transcription with ElevenLabs.

## Current Status

This repository now includes the MVP end-to-end flow:

- global hold-to-talk hotkey (configurable in Settings)
- AVFoundation microphone recording
- ElevenLabs `v1/speech-to-text` transcription
- optional proxy API mode
- automatic paste into active app with clipboard restore
- menu bar settings and non-Xcode build/package scripts

## Requirements

- macOS 14+
- Xcode Command Line Tools (Xcode UI is not required)

Install Command Line Tools:

```bash
xcode-select --install
```

Verify Swift is available:

```bash
swift --version
```

## Setup

```bash
cp .env.example .env
```

Edit `.env` and set at least:

- `ELEVENLABS_API_KEY`

Optional:

- `ELEVENLABS_MODEL_ID` (`scribe_v1` or `scribe_v2`)
- `TRANSCRIPTION_REQUEST_TIMEOUT_SECONDS`
- `TRANSCRIPTION_PROXY_URL` + `TRANSCRIPTION_PROXY_API_KEY` (for proxy mode)

## Proxy API Contract (MVP)

When `API Mode` is set to `Use Proxy API`, the app sends a `multipart/form-data` request to `TRANSCRIPTION_PROXY_URL` with:

- `file` (recorded audio file)
- `model_id`
- `system_prompt`
- `user_context`
- `locale` (optional)
- repeated `vocabulary_hints` fields

Expected response JSON should include one of these string keys:

- `text`
- `transcript`
- `result`
- `output`
- `content`

## Run (No Xcode)

```bash
make run
```

This launches the menu bar app directly from SwiftPM.

Usage:

1. Open menu bar icon and grant Accessibility permission.
2. Pick your activation shortcut in Settings.
3. Hold shortcut to record, release to transcribe and paste.

Note: ElevenLabs STT does not currently accept a free-form system prompt field. In direct ElevenLabs mode, `Locale` and `Vocabulary Hints` are applied. `Default System Prompt` and `User Context` are sent in proxy mode and are kept in the architecture for future local/post-processing support.

## Build Release Binary

```bash
make build
```

Output binary:

- `.build/release/PressToSpeakApp`

## Package `.app` Bundle (No Xcode)

```bash
make package-app
```

Output app bundle:

- `dist/PressToSpeak.app`

## Install Locally

```bash
make install-local
```

App install target:

- `/Applications/PressToSpeak.app`

## Permissions

The app requires:

- Microphone access (recording)
- Accessibility access (global hotkey + paste simulation)

## Project Structure

- `Sources/PressToSpeakApp`: SwiftUI menu bar shell + app state.
- `Sources/PressToSpeakCore`: Domain protocols/models/orchestration.
- `Sources/PressToSpeakInfra`: Environment loading, settings persistence, provider/paster implementations.
- `scripts/package_app.sh`: `.app` bundle packaging script.
- `docs/architecture.md`: MVP architecture and epics.
