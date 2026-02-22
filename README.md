# PressToSpeak Monorepo

[presstospeak.com](https://www.presstospeak.com/) is an open-source voice-to-text app for macOS.
Press a shortcut, speak naturally, and let AI turn rough speech into clean, polished text that can be pasted into any app.

Keyboard -> 50 words per minutes
PressToSpeak -> 200 words per minutes

## How to use PressToSpeak Now

1. Download the macOS app from [presstospeak.com/](https://www.presstospeak.com/).
2. Open the app and create an account (or log in) with your PressToSpeak.com account.
3. Start dictating with the default PressToSpeak account mode.

Bring Your Own Keys (BYOK) is temporarily disabled while account mode is stabilized.

If you want to build and run everything yourself, developer instructions are below.

## What Is In This Repository

This monorepo contains:

- `apps/mac`: the existing PressToSpeak macOS menu bar app (Swift/SwiftUI).
- `apps/api`: TypeScript Express API middle layer (scaffolded).

## Product Concept

PressToSpeak focuses on a hold-to-talk workflow:

1. Hold your shortcut to record.
2. Release to transcribe.
3. Paste the result into the active app.

The API layer adds account auth, usage control, and post-processing so the mac app can stay fast and UX-focused.

## Why This Monorepo Layout

You want production control over:

- ElevenLabs API key safety
- user-level usage metering and spend limits
- post-transcription cleanup and formatting logic
- future snippet expansion and product-specific business rules

So the mac app remains focused on UX, while the API layer owns policy, metering, and transformation.

## Current Status

- `apps/mac` is fully runnable today.
- `apps/api` now has a working scaffold and `POST /v1/voice-to-text`.

## Common Commands (from repo root)

```bash
make mac-run              # run from SwiftPM (no install)
make mac-build-binary     # build .build/release/PressToSpeakApp
make mac-build-app        # package apps/mac/dist/PressToSpeak.app
make mac-production-export # build website artifacts with apps/mac/.env.production
make mac-install-app      # install /Applications/PressToSpeak.app
make mac-open-app         # open /Applications/PressToSpeak.app
make mac-install-and-open # install, then open
```

Legacy aliases still work: `make run`, `make build`, `make package-app`, `make install-local`.

API commands:

```bash
make api-install
make api-dev
make api-typecheck
make api-build
```

## Monorepo Structure

```text
apps/
  mac/    # Swift macOS app
  api/    # TypeScript Express API middle layer
```

## API Architecture Docs

- Overview: `apps/api/README.md`
- Detailed plan: `apps/api/docs/architecture.md`
- LLM provider decision: `apps/api/docs/llm-provider-decision.md`
- Implementation roadmap: `apps/api/docs/roadmap.md`
- Render monorepo deploy blueprint: `render.yaml`

## License

This repository is licensed under the MIT License. See `LICENSE`.
