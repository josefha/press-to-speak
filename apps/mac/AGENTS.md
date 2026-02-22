# AGENTS.md - PressToSpeak Project Context

This file is the primary handoff context for new agents working in this repository.

## Project Summary

PressToSpeak is a macOS menu bar app (Swift + SwiftUI, macOS 14+) with hold-to-talk transcription.

Primary flow:
1. User holds global hotkey.
2. App records microphone input.
3. On release, audio is transcribed (ElevenLabs or proxy endpoint).
4. Text is pasted into focused app.
5. If paste cannot be executed, text remains in clipboard as fallback.

## Current Product Decisions (Important)

1. Menu bar wording:
- Use `Open PressToSpeak` (not `Open App`).

2. Menu bar ordering:
- Keep `Open PressToSpeak` near bottom, directly above `Quit`.
- No separate `Open Settings…` item.

3. Menu bar utilities:
- Show `Copy Clipboard` button that copies latest transcription to clipboard.
- Do not show a long full transcription block in menu bar.

4. Dashboard layout:
- Quick actions near top.
- Latest transcription directly below quick actions.
- Previous transcriptions behind `View Previous` toggle.

5. Hotkey UX:
- Show current hotkey as text.
- `Update Hotkey` enters capture mode.
- Capture supports key combos (e.g. `Right Command + ,`) and modifier-only shortcuts.

## Key Technical Notes

### Hotkey model
- Hotkeys are stored as `KeyboardShortcut` in encoded `activationShortcut` string (SettingsStore).
- Legacy values still migrate from old `ActivationShortcut` values.
- Files:
  - `Sources/PressToSpeakCore/Models.swift`
  - `Sources/PressToSpeakInfra/SettingsStore.swift`
  - `Sources/PressToSpeakInfra/GlobalHotkeyMonitor.swift`
  - `Sources/PressToSpeakInfra/HotkeyCaptureService.swift`

### Paste fallback behavior
- `ClipboardPaster` should not hard-fail when synthetic paste is unavailable.
- If accessibility is unavailable or paste events cannot be created, leave transcription in clipboard.
- File:
  - `Sources/PressToSpeakInfra/ClipboardPaster.swift`

### Transcription providers
- Primary flow routes transcription through proxy API.
- `PressToSpeak Account` mode sends Supabase Bearer token.
- `Bring Your Own Keys` mode is temporarily disabled.
- Files:
  - `Sources/PressToSpeakInfra/ElevenLabsTranscriptionProvider.swift`
  - `Sources/PressToSpeakInfra/ProxyTranscriptionProvider.swift`
  - `Sources/PressToSpeakInfra/SupabaseAuthService.swift`
  - `Sources/PressToSpeakInfra/CredentialVault.swift`

### History
- Persisted transcription history in `UserDefaults` (`pressToSpeak.transcriptionHistory`).
- Latest item shown prominently; previous items copyable.
- Files:
  - `Sources/PressToSpeakInfra/TranscriptionHistoryStore.swift`
  - `Sources/PressToSpeakApp/AppViewModel.swift`
  - `Sources/PressToSpeakApp/Views/MainDashboardView.swift`

## Build / Run / Reinstall (No Xcode UI)

Monorepo root:

```bash
cd /Users/josef/Desktop/projects/private-projects/press-to-speak-mono/press-to-speak
```

App package root:

```bash
cd /Users/josef/Desktop/projects/private-projects/press-to-speak-mono/press-to-speak/apps/mac
```

1. Run from source:
```bash
make run
```

2. Build release binary:
```bash
make build
```

3. Package app bundle:
```bash
make package-app
```

4. Reinstall local app quickly (recommended test loop):
```bash
make install-local
```

5. Clean local install and local dist artifacts:
```bash
make clean-mac-local
```

6. Build production website distribution artifacts (recommended):
```bash
make production-export
```

7. Build website distribution artifacts from current packaged app:
```bash
make release-artifacts
```

8. Notarize release artifacts (after Developer ID signing):
```bash
NOTARY_PROFILE=\"press-to-speak-notary\" make notarized-release
```

App target:
- `/Applications/PressToSpeak.app`
- Website artifacts: `apps/mac/dist/release/*.dmg`, `apps/mac/dist/release/*.zip` (when run from monorepo root)

## Env Configuration

Project env files:
- `apps/mac/.env` (or `.env` when your shell cwd is `apps/mac`)
- `apps/mac/.env.production` for website release builds (`make production-export`)

Important keys:
- `TRANSCRIPTION_PROXY_URL`
- `TRANSCRIPTION_PROXY_API_KEY`
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `ELEVENLABS_MODEL_ID`
- `TRANSCRIPTION_REQUEST_TIMEOUT_SECONDS`

Supabase auth mode note:
- this product uses modern Supabase JWT verification via JWKS (asymmetric signing).
- do not set API `SUPABASE_JWT_SECRET` to `sb_secret_*`; leave it unset unless explicitly targeting legacy HS256 JWT setups.

Packaging behavior:
- packaging script uses `APP_ENV_FILE` (defaults to `.env`) and copies it into app bundle as `Contents/Resources/app.env`.
- `make production-export` is unsigned by default; pass `PRODUCTION_CODESIGN_IDENTITY="Developer ID Application: ..."` to sign production artifacts.
- SwiftPM resource bundles are copied into app bundle `Contents/Resources/`.
- App icon is generated as `Contents/Resources/AppIcon.icns` from `Sources/PressToSpeakApp/Resources/Branding/AppIcon.appiconset` (fallback `logo-dark.svg` / `logo-dark.png`).
- Release DMG is styled (fixed icon positions + drag-to-install background) via `scripts/build_release_artifacts.sh`, with default background `scripts/assets/dmg-background.svg`.
- `AppConfiguration` loads bundled env + process env for `.app` installs (working-directory `.env` is only loaded for non-bundled dev runs, or when `PRESS_TO_SPEAK_LOAD_WORKING_DIR_ENV=true` is set).

## Permission / TCC Notes

Critical:
- `Info.plist` must include `NSMicrophoneUsageDescription` or app will crash on mic access.
- Packaging script already injects this key.

Permission stability tips during iteration:
1. Keep bundle id constant: `com.opensource.presstospeak`.
2. Keep install path constant: `/Applications/PressToSpeak.app`.
3. Keep signing behavior consistent.

Codesign behavior:
- Package script skips ad-hoc signing by default.
- Optional explicit stable signing via:
```bash
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" make install-local
```

## Debugging / Logs

App log:
- `~/Library/Logs/PressToSpeak/app.log`

Tail logs:
```bash
tail -f /Users/josef/Library/Logs/PressToSpeak/app.log
```

System logs for process:
```bash
log stream --style compact --predicate 'process == "PressToSpeak"'
```

Crash reports:
- `~/Library/Logs/DiagnosticReports/`

## Agent Guardrails

When changing this project:
1. Preserve hold-to-talk behavior (press starts, release ends).
2. Keep clipboard fallback if paste is unavailable.
3. Preserve menu bar UX decisions listed above unless explicitly changed by user.
4. Validate with `swift build` before handing off.
5. Reinstall with `make install-local` after UI/behavior changes.
6. Update `README.md` and this file when workflows/assumptions change.
7. Treat this app as production software: prefer secure-by-default implementations and least-privilege design.
8. For auth/secrets/network boundaries, apply defense-in-depth and avoid exposing sensitive data in logs.
9. After large features, perform a self security review and fix high/medium risk issues before handoff.

## Fast Smoke Test Checklist

After reinstall:
1. Launch `/Applications/PressToSpeak.app`.
2. Open dashboard from menu bar.
3. Verify hotkey label and update flow (`Update Hotkey`).
4. Hold hotkey to transcribe in a text field.
5. Verify text pasted, or at minimum available in clipboard.
6. Verify `Copy Clipboard` menu action copies latest transcription.
