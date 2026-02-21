# Cursor Context - PressToSpeak

## What this repo is

Menu bar dictation app for macOS (SwiftUI + SwiftPM). It records on hotkey hold, transcribes with ElevenLabs/proxy, then pastes text.

## Current UX contract

1. Menu bar action is named `Open PressToSpeak`.
2. `Open PressToSpeak` appears near bottom, above `Quit`.
3. Menu includes `Copy Clipboard` (copies latest transcription).
4. Dashboard has:
- quick actions first
- latest transcription directly under quick actions
- previous transcriptions hidden behind toggle
- hotkey shown as text + `Update Hotkey` flow

## Hotkey behavior

- Supports combo shortcuts (example: `⌘ + ,`).
- Supports modifier-only shortcuts.
- Update flow is capture-based (next key combo wins).

Primary files:
- `Sources/PressToSpeakCore/Models.swift`
- `Sources/PressToSpeakInfra/GlobalHotkeyMonitor.swift`
- `Sources/PressToSpeakInfra/HotkeyCaptureService.swift`
- `Sources/PressToSpeakApp/AppViewModel.swift`

## Must-not-break behavior

1. If paste cannot be executed, keep transcription in clipboard.
2. Maintain microphone privacy key in packaged `Info.plist`.
3. Keep run/reinstall workflow simple (`make install-local`).

## Useful commands

```bash
make run
make build
make package-app
make install-local
swift build
```

## Logs

```bash
tail -f ~/Library/Logs/PressToSpeak/app.log
log stream --style compact --predicate 'process == "PressToSpeak"'
```
