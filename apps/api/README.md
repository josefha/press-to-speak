# PressToSpeak API

TypeScript + Express API middle layer for transcription proxying and fast post-processing.

## Current Scope

- `POST /v1/voice-to-text` multipart endpoint
- ElevenLabs STT proxy (server-side API key)
- OpenAI rewrite pipeline (`gpt-5-mini`) for transcript restructuring
- Supabase JWT verification middleware (`off` / `optional` / `required` auth modes)
- optional BYOK headers for OpenAI + ElevenLabs (`x-openai-api-key`, `x-elevenlabs-api-key`)
- unauthenticated rate limiter for open traffic
- usage event capture hook (placeholder logger for now)

## Layering

- `src/external/**`: direct third-party adapters (OpenAI, ElevenLabs, future Supabase/Polar)
- `src/services/**`: business orchestration that composes external adapters
- `src/routes/**`: transport/http layer only

## Quick Start

From monorepo root:

```bash
cd apps/api
cp .env.example .env
npm install
npm run dev
```

Health check:

```bash
curl http://localhost:8787/healthz
```

Run integration tests:

```bash
npm test
```

## API

### `POST /v1/auth/signup`

Creates a Supabase account and returns normalized account/session fields.

Headers:

- `x-api-key` (required only when `PROXY_SHARED_API_KEY` is configured)

JSON body:

- `email` (required)
- `password` (required, min 8 chars)
- `profile_name` (optional)

Response fields:

- `account.user_id`
- `account.email`
- `account.profile_name`
- `account.tier` (`free` or `pro`)
- `session` (`null` if email confirmation is required)
- `requires_email_confirmation`

### `POST /v1/auth/login`

Signs in with Supabase email/password and returns account + session.

Headers:

- `x-api-key` (required only when `PROXY_SHARED_API_KEY` is configured)

JSON body:

- `email`
- `password`

### `POST /v1/auth/refresh`

Refreshes a Supabase session.

Headers:

- `x-api-key` (required only when `PROXY_SHARED_API_KEY` is configured)

JSON body:

- `refresh_token`

### `POST /v1/auth/logout`

Invalidates a Supabase session.

Headers:

- `x-api-key` (required only when `PROXY_SHARED_API_KEY` is configured)
- `Authorization: Bearer <access-token>` (or pass `access_token` in JSON body)

### `POST /v1/voice-to-text`

Content type: `multipart/form-data`

Required multipart fields:

- `file`: audio blob/file

Optional multipart fields (forwarded to ElevenLabs when provided):

- `model_id`
- `language_code`
- `temperature`
- `diarize`
- `tag_audio_events`
- `keyterms`

Headers:

- `x-request-id`
- `Authorization: Bearer <supabase-access-token>` (required if `USER_AUTH_MODE=required`, optional if `USER_AUTH_MODE=optional`)
- `x-api-key` (required only when `PROXY_SHARED_API_KEY` is configured)
- `x-openai-api-key` + `x-elevenlabs-api-key` (required together for BYOK requests)
- `x-user-id` (only used as unauthenticated fallback when `USER_AUTH_MODE` is `off` or `optional`)

Response shape:

- `transcript.raw_text`
- `transcript.clean_text`
- `provider.stt`
- `provider.rewrite`
- `timing`
- `warnings[]` (present if rewrite falls back to raw transcript)

Example:

```bash
curl -X POST http://localhost:8787/v1/voice-to-text \
  -H "x-user-id: local-dev-user" \
  -F "file=@/absolute/path/to/audio.wav" \
  -F "model_id=scribe_v1" \
  -F "diarize=false" \
  -F "tag_audio_events=false"
```

Example with Supabase JWT + shared proxy key:

```bash
curl -X POST http://localhost:8787/v1/voice-to-text \
  -H "Authorization: Bearer <SUPABASE_ACCESS_TOKEN>" \
  -H "x-api-key: <PROXY_SHARED_API_KEY>" \
  -F "file=@/absolute/path/to/audio.wav"
```

Example BYOK request without login (only if enabled by env):

```bash
curl -X POST http://localhost:8787/v1/voice-to-text \
  -H "x-openai-api-key: <OPENAI_KEY>" \
  -H "x-elevenlabs-api-key: <ELEVENLABS_KEY>" \
  -F "file=@/absolute/path/to/audio.wav"
```

## Authentication Modes

- `USER_AUTH_MODE=off`: no Supabase token verification. The API uses `x-user-id` when provided, otherwise `anonymous`.
- `USER_AUTH_MODE=optional`: verifies Supabase access tokens when present. Requests without tokens still run as unauthenticated.
- `USER_AUTH_MODE=required`: every request must include a valid Supabase access token in `Authorization: Bearer ...`.

`ALLOW_UNAUTHENTICATED_BYOK=true` creates an explicit unauthenticated path for requests carrying both BYOK provider keys. Default is `false` (secure-by-default).

Production recommendation: set `USER_AUTH_MODE=required`, set a strong `PROXY_SHARED_API_KEY`, and keep strict rate limits on unauthenticated traffic.

Supabase token verification sources:

- Symmetric JWT secret (`SUPABASE_JWT_SECRET`) if provided.
- Otherwise JWKS (`SUPABASE_JWKS_URL`, auto-derived from `SUPABASE_URL` by default).

Important: `SUPABASE_JWT_SECRET` is the legacy JWT signing secret, not Supabase API secret keys (`sb_secret_*`).
For modern asymmetric projects (for example ES256/RS256), leave `SUPABASE_JWT_SECRET` unset and use JWKS verification.

## Rate Limiting

- Unauthenticated requests are rate-limited with an in-memory fixed window (`UNAUTH_RATE_LIMIT_WINDOW_MS`, `UNAUTH_RATE_LIMIT_MAX_REQUESTS`).
- Auth routes are rate-limited with a separate in-memory fixed window (`AUTH_ROUTE_RATE_LIMIT_WINDOW_MS`, `AUTH_ROUTE_RATE_LIMIT_MAX_REQUESTS`).
- Response headers include `x-ratelimit-limit`, `x-ratelimit-remaining`, and `x-ratelimit-reset-ms`.
- For multi-instance production deployments, replace this with centralized rate limiting (Redis or gateway-level).

## Environment

See `.env.example`.

Required:

- `ELEVENLABS_API_KEY`
- `OPENAI_API_KEY`

Auth-related:

- `USER_AUTH_MODE` (`off`, `optional`, `required`)
- `ALLOW_UNAUTHENTICATED_BYOK` (`true`/`false`)
- `BYOK_HEADER_MAX_CHARS` (default `512`)
- `UNAUTH_RATE_LIMIT_WINDOW_MS` (default `60000`)
- `UNAUTH_RATE_LIMIT_MAX_REQUESTS` (default `20`)
- `SUPABASE_URL` (or explicit `SUPABASE_JWKS_URL`) when auth mode is `optional` or `required` and `SUPABASE_JWT_SECRET` is not set
- `SUPABASE_PUBLISHABLE_KEY` (required for `/v1/auth/*` route calls)
- `SUPABASE_JWT_AUDIENCE` (default `authenticated`)
- `SUPABASE_AUTH_TIMEOUT_MS` (default `5000`)
- `PROXY_SHARED_API_KEY` (optional shared ingress key)
- `AUTH_ROUTE_RATE_LIMIT_WINDOW_MS` (default `60000`)
- `AUTH_ROUTE_RATE_LIMIT_MAX_REQUESTS` (default `20`)

Logging controls:

- `LOG_PRETTY` (`true` by default in development): human-readable logs in terminal.
- `LOG_PIPELINE_TEXT` (`true` by default in development): logs raw transcript and cleaned transcript so you can compare LLM rewrite value.
- `LOG_PROVIDER_PAYLOADS` (`true` by default in development): logs ElevenLabs/OpenAI payload previews for inspection.
- `LOG_TEXT_MAX_CHARS` (default `1200`): max chars for transcript/payload previews before truncation.

## Deploy to Render (GitHub + Monorepo)

This repository includes a Render Blueprint at `render.yaml` configured for:

- monorepo root directory `apps/api`
- build command `npm ci && npm run build`
- start command `npm run start`
- health check `/healthz`

Steps:

1. Push this repo to GitHub.
2. In Render, click **New +** -> **Blueprint**.
3. Connect/select your GitHub repo and choose the branch you want to deploy.
4. Render reads `render.yaml` and creates `press-to-speak-api`.
5. Fill required secret env vars in Render:
   - `OPENAI_API_KEY`
   - `ELEVENLABS_API_KEY`
   - `PROXY_SHARED_API_KEY`
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
6. Deploy and verify `GET /healthz` returns 200.

Security defaults in Blueprint:

- `USER_AUTH_MODE=required`
- `ALLOW_UNAUTHENTICATED_BYOK=false`
- transcript/provider payload logging disabled (`LOG_PIPELINE_TEXT=false`, `LOG_PROVIDER_PAYLOADS=false`)
- no `SUPABASE_JWT_SECRET` configured (JWKS verification path)

## Architecture Docs

- `docs/architecture.md`
- `docs/llm-provider-decision.md`
- `docs/roadmap.md`
