# API Roadmap (Docs to Scaffolding)

## Phase A: Repository scaffolding

- initialize Node + TypeScript + Express project
- add lint, test, and build scripts
- add env schema and runtime config loader
- split `external` adapters from `services` orchestration layer

## Phase B: Transcription proxy MVP

- `POST /v1/voice-to-text` multipart endpoint
- ElevenLabs adapter
- auth middleware baseline (shared proxy key + Supabase JWT verification modes)
- request logging and timing metrics

## Phase C: Rewrite MVP

- OpenAI `gpt-5-mini` rewrite integration
- timeout-bounded rewrite with raw transcript fallback
- response metadata for rewrite status/warnings

## Phase D: Users + Data + billing primitives

- Supabase integration for user + usage events (JWT verification implemented; DB persistence pending)
- BYOK open-route key overrides + unauthenticated rate limiting baseline
- quota checks
- billing event abstraction for future Polar integration

## Phase E: Snippets + richer transforms

- snippet mapping engine (DB-backed)
- user/team dictionary rules
- evaluate optional secondary rewrite providers
