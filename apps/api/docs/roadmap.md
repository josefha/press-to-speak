# API Roadmap (Docs to Scaffolding)

## Phase A: Repository scaffolding

- initialize Node + TypeScript + Express project
- add lint, test, and build scripts
- add env schema and runtime config loader

## Phase B: Transcription proxy MVP

- `POST /v1/voice-to-text` multipart endpoint
- ElevenLabs adapter
- auth middleware placeholder
- request logging and timing metrics

## Phase C: Post-processing MVP

- deterministic filler removal
- punctuation/grammar normalization rules
- snippet mapping engine (in-memory, then DB-backed)

## Phase D: Users + Data + billing primitives

- Supabase integration for user + usage events
- quota checks
- billing event abstraction for future Polar integration

## Phase E: Optional LLM polish

- provider abstraction (`rewriteProvider` interface)
- timeout-bounded rewrite pass
- A/B latency and quality evaluation
