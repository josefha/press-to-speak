# AGENTS.md - PressToSpeak Monorepo Context

This is a monorepo with two apps:

- `apps/mac`: PressToSpeak macOS menu bar app (Swift + SwiftUI).
- `apps/api`: TypeScript Express API layer.

## Primary Product Direction

1. Keep hold-to-talk UX in mac app.
2. Route production transcription traffic through your API for key safety and spend control.
3. Keep a thin, fast post-processing layer in API:
- OpenAI `gpt-5-mini` rewrite for cleanup/grammar
- raw transcript fallback on rewrite timeout/error
- snippet/keyword expansion as product logic

## Monorepo Commands

From repo root:

```bash
make mac-run              # run from SwiftPM (no install)
make mac-build-binary     # build .build/release/PressToSpeakApp
make mac-build-app        # package apps/mac/dist/PressToSpeak.app
make mac-install-app      # install /Applications/PressToSpeak.app
make mac-open-app         # open /Applications/PressToSpeak.app
make mac-install-and-open # install, then open
make api-dev
make api-build
```

Legacy aliases still work: `make run`, `make build`, `make package-app`, `make install-local`.

## Where to Change What

- mac app behavior/UI: `apps/mac/Sources/**`
- mac packaging/build scripts: `apps/mac/scripts/**`
- API service code: `apps/api/src/**`
- API system design: `apps/api/docs/**`

## Guardrails

1. Preserve hold-to-talk behavior (press starts recording, release stops).
2. Preserve clipboard fallback if synthetic paste is unavailable.
3. Preserve menu bar wording/order decisions unless explicitly changed by the user.
4. Validate mac app with `swift build` in `apps/mac` before handoff.
5. Reinstall app with `make install-local` after UI/behavior changes.
6. Keep README + AGENTS docs synchronized when workflows change.
