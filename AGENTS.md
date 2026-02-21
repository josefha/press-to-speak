# AGENTS.md - PressToSpeak Monorepo Context

This is a monorepo with two apps:

- `apps/mac`: PressToSpeak macOS menu bar app (Swift + SwiftUI).
- `apps/api`: TypeScript Express API layer.

## Primary Product Direction

1. Keep hold-to-talk UX in mac app.
2. Route production transcription traffic through your API for key safety and spend control.
3. Keep a thin, fast post-processing layer in API: OpenAI `gpt-5-mini` rewrite for cleanup/grammar, raw transcript fallback on rewrite timeout/error, snippet/keyword expansion as product logic.
4. Product mode defaults: default to `PressToSpeak Account` mode (Supabase-backed auth), and keep `Bring Your Own Keys` as an advanced option with stronger rate limits on open traffic.

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
7. Treat this product as production software: default to secure-by-default implementations and least-privilege decisions.
8. For auth, secrets, and API boundaries, prefer defense-in-depth (input validation, explicit allowlists, safe logging/redaction, fail-closed behavior).
9. After any large feature, run a self code review focused on security risks and apply fixes before handoff.
10. In handoff notes, include a short security review summary (findings, fixes, residual risks).
11. For Supabase schema changes, do not handwrite SQL migrations; generate migration files via Supabase CLI/MCP tooling and then review them.
