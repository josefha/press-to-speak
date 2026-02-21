# PressToSpeak (macOS Menu Bar App)

Swift/SwiftUI macOS menu bar app for hold-to-talk voice transcription via the PressToSpeak API.

## Current Status

This repository now includes the MVP end-to-end flow:

- global hold-to-talk hotkey (configurable in Settings)
- AVFoundation microphone recording
- default `PressToSpeak Account` mode with Supabase sign-up/sign-in
- advanced `Bring Your Own Keys` mode (OpenAI + ElevenLabs keys stored in Keychain)
- proxy API mode for all transcription traffic
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

- `TRANSCRIPTION_PROXY_URL`

Optional:

- `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` (preferred for PressToSpeak Account mode; `SUPABASE_ANON_KEY` is still supported)
- `TRANSCRIPTION_PROXY_API_KEY`
- `ELEVENLABS_MODEL_ID` (`scribe_v1` or `scribe_v2`)
- `TRANSCRIPTION_REQUEST_TIMEOUT_SECONDS`

## Proxy API Contract (MVP)

The app sends a `multipart/form-data` request to `TRANSCRIPTION_PROXY_URL` (for example `http://127.0.0.1:8787/v1/voice-to-text`) with:

- `file` (recorded audio file)
- `model_id`
- `system_prompt`
- `user_context`
- `locale` (optional)
- repeated `vocabulary_hints` fields

Headers by mode:

`PressToSpeak Account` mode:
- `Authorization: Bearer <supabase-access-token>`
- optional `x-api-key: <TRANSCRIPTION_PROXY_API_KEY>`

`Bring Your Own Keys` mode:
- `x-openai-api-key: <OPENAI_API_KEY>`
- `x-elevenlabs-api-key: <ELEVENLABS_API_KEY>`
- optional `x-api-key: <TRANSCRIPTION_PROXY_API_KEY>`

Preferred response JSON shape:

- `transcript.clean_text` (or fallback to `transcript.raw_text`)

Backward-compatible fallback keys still supported:

- `text`
- `transcript`
- `result`
- `output`
- `content`

## Run (No Xcode)

From monorepo root:

```bash
make run
```

Or from this directory (`apps/mac`):

```bash
make run
```

This launches the menu bar app directly from SwiftPM.

Usage:

1. Open menu bar icon and grant Accessibility permission.
2. Click `Open PressToSpeak` to open the dashboard window.
3. Pick your activation shortcut at the top.
4. Hold shortcut to record, release to transcribe and paste.
5. Use `Latest transcription`, `View Previous`, and copy buttons to reuse earlier text.

`Default System Prompt`, `User Context`, `Locale`, and `Vocabulary Hints` are sent to the API for provider orchestration and cleanup.

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

When run from monorepo root with `make package-app`, output is at:

- `apps/mac/dist/PressToSpeak.app`

## Website Distribution (Outside App Store)

Yes, you can distribute this app from your website without the Mac App Store.

### Do you need an Apple Developer license?

- For the best user experience (`double-click install` with minimal warnings): **Yes**, you need a paid Apple Developer Program account to use:
1. Developer ID Application signing
2. Apple notarization

- Without paid Apple Developer signing/notarization: you can still distribute, but users may see stronger Gatekeeper warnings and need manual override steps.

### Build downloadable artifacts (`.zip` + `.dmg`)

```bash
make release-artifacts
```

Outputs:
- `dist/release/PressToSpeak-<version>-macOS.zip`
- `dist/release/PressToSpeak-<version>-macOS.dmg`

### Recommended production release flow (signed + notarized)

1. Use a Developer ID identity:
```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make release-artifacts
```

2. Notarize and staple:
```bash
NOTARY_PROFILE="press-to-speak-notary" make notarized-release
```

3. Upload the notarized `.dmg` (and optional `.zip`) from `dist/release/` to your website download button.

### Notary profile setup (one-time)

Store notary credentials in keychain:

```bash
xcrun notarytool store-credentials "press-to-speak-notary" \
  --apple-id "<apple-id-email>" \
  --team-id "<TEAMID>" \
  --password "<app-specific-password>"
```

## Install Locally

```bash
make install-local
```

App install target:

- `/Applications/PressToSpeak.app`

### Permission Persistence During Testing

macOS privacy permissions (Microphone/Accessibility) are tied to app identity. To reduce repeated permission prompts:

1. Keep the same bundle id (`com.opensource.presstospeak`).
2. Keep installing to the same path (`/Applications/PressToSpeak.app`).
3. Avoid changing signing identity between builds.

By default this project now skips ad-hoc signing in packaging to improve local testing stability.
If you want explicit signing, use a stable identity every time:

```bash
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" make install-local
```

Current Makefile default:

```bash
CODESIGN_IDENTITY="Apple Development: Your Name Josef Karakoca"
```

If that identity is not present in Keychain, packaging will skip codesign and continue.

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
