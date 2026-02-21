# PressToSpeak Monorepo

This repository now contains:

- `apps/mac`: the existing PressToSpeak macOS menu bar app (Swift/SwiftUI).
- `apps/api`: TypeScript Express API middle layer (scaffolded).

## Why This Layout

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
