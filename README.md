# PressToSpeak Monorepo

This repository now contains:

- `apps/mac`: the existing PressToSpeak macOS menu bar app (Swift/SwiftUI).
- `apps/api`: docs-only architecture for the upcoming production API middle layer.

## Why This Layout

You want production control over:

- ElevenLabs API key safety
- user-level usage metering and spend limits
- post-transcription cleanup and formatting logic
- future snippet expansion and product-specific business rules

So the mac app remains focused on UX, while the API layer owns policy, metering, and transformation.

## Current Status

- `apps/mac` is fully runnable today.
- `apps/api` currently contains architecture docs only (no runtime scaffolding yet).

## Common Commands (from repo root)

```bash
make run
make build
make package-app
make install-local
```

These commands forward to `apps/mac`.

## Monorepo Structure

```text
apps/
  mac/    # Swift macOS app (existing implementation)
  api/    # TypeScript Express API (planned, docs-only for now)
```

## API Architecture Docs

- Overview: `apps/api/README.md`
- Detailed plan: `apps/api/docs/architecture.md`
- LLM provider decision: `apps/api/docs/llm-provider-decision.md`
- Implementation roadmap: `apps/api/docs/roadmap.md`

## Next Step

When you are ready, we can scaffold `apps/api` as a TypeScript Express service with:

- auth + per-user usage accounting hooks (Supabase)
- transcription proxy endpoint to ElevenLabs
- deterministic cleanup pipeline
- optional fast LLM rewrite pass
