# PressToSpeak API Architecture (v0 Plan)

## Goals

1. Keep transcription UX fast.
2. Protect provider keys and control spend.
3. Support product-specific post-processing (cleanup, snippets, formatting).
4. Stay provider-flexible for rewrite/polish logic.

## High-Level Flow

1. macOS app records audio locally.
2. app sends audio + metadata to PressToSpeak API (not directly to ElevenLabs).
3. API authenticates user and checks quota/policy.
4. API forwards to ElevenLabs STT.
5. API returns raw transcript immediately when available.
6. API runs post-processing pipeline:
   - deterministic cleanup rules (fast)
   - snippet expansion / dictionary replacements
   - optional short LLM polish pass
7. API streams/publishes polished result update.

## Why Keep This In Your API Layer

ElevenLabs STT is strong at recognition (timestamps, diarization, punctuation, event tagging, keyterms), but your product needs additional transforms:

- filler removal (`hmm`, `uh`, etc.)
- punctuation normalization for final user output
- grammar/style polish
- product-specific keyword-to-snippet expansion
- user/team dictionary logic

Those are business behaviors and should remain under your control.

## Latency Strategy

Fast path:

- return raw transcript as soon as STT completes.
- deterministic rules execute in-process (<10-30ms typical for short utterances).

Optional polish path:

- invoke a small/fast rewrite model only for final transcript.
- use strict timeout budget (for example 300-700ms).
- if timeout/failure: return deterministic result; do not block UX.

UI behavior:

- render raw transcript first.
- replace with polished transcript asynchronously when ready.

## Suggested Service Components

1. `gateway` (Express route handlers)
- auth
- request validation
- rate limiting
- usage metering hooks

2. `stt-service`
- ElevenLabs client adapter
- request shaping
- retries/backoff for transient errors

3. `postprocess-service`
- deterministic cleanup rules
- punctuation and casing normalizer
- snippet expansion (global + user dictionary)
- optional LLM rewrite adapter

4. `usage-service`
- capture per-user duration/characters/request counts
- emit billing events for later Polar integration

5. `audit/logging`
- request IDs
- latency metrics per stage
- provider error observability

## Data Model (Initial)

Core entities (planned):

- `users` (linked from auth provider)
- `usage_events` (user_id, request_id, seconds_audio, chars_out, provider_cost_estimate)
- `plans` (limits/policy)
- `snippet_rules` (scope: global/user/team, trigger, expansion, enabled)
- `cleanup_rules` (rule_id, scope, pattern/action)

Supabase can own auth + relational tables initially.

## API Endpoints (Proposed)

1. `POST /v1/transcriptions`
- multipart audio upload
- returns raw transcript + request id + timing

2. `GET /v1/transcriptions/:id`
- returns latest state (`raw`, `processed`, `final`)

3. `POST /v1/snippets`
- create snippet mappings

4. `GET /v1/snippets`
- list snippet mappings for user/team

5. `POST /v1/usage/heartbeat` (optional)
- client telemetry for UX correlation only

## Post-Processing Pipeline Design

Order matters for quality + speed:

1. normalize whitespace and punctuation tokens
2. remove filler tokens from allowlist with boundary-aware matching
3. apply dictionary replacements/snippets (deterministic)
4. grammar/style polish (optional LLM)
5. final formatting policy (sentence case, trailing punctuation rules)

All deterministic steps should be idempotent and unit-tested.

## LLM Provider Strategy for Fast Short-Text Polish

Recommendation: keep a provider abstraction and start with one fast mini model, then benchmark a backup.

Initial recommendation is documented in `llm-provider-decision.md`.

Selection criteria:

- low first-token latency
- strong instruction-following for constrained rewrite tasks
- deterministic behavior at low temperature
- competitive token pricing for short text

Guardrails:

- hard max input length
- strict timeout
- JSON schema output or constrained format
- fallback to deterministic output on timeout/error

## Security and Spend Controls

1. Do not expose ElevenLabs key to clients.
2. Require authenticated requests (JWT/session).
3. Enforce per-user quotas/rate limits.
4. Attach request IDs and cost estimates to usage events.
5. Add circuit breakers if provider error rate spikes.

## Rollout Plan

Phase 1:

- API proxy to ElevenLabs
- usage metering + per-user limits
- deterministic cleanup only

Phase 2:

- snippet dictionary endpoints
- async polished transcript update

Phase 3:

- optional LLM polish with benchmarked provider
- billing pipeline to Polar.sh

## Non-Goals (for first implementation)

- multi-provider STT routing
- complex workflow orchestration
- full multi-tenant admin UI
