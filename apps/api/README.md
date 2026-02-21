# PressToSpeak API

TypeScript + Express API middle layer for transcription proxying and fast post-processing.

## Current Scope

- `POST /v1/voice-to-text` multipart endpoint
- ElevenLabs STT proxy (server-side API key)
- OpenAI rewrite pipeline (`gpt-5-mini`) for transcript restructuring
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

## API

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

Optional headers:

- `x-request-id`
- `x-user-id` (for usage metering hook)

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

## Environment

See `.env.example`.

Required:

- `ELEVENLABS_API_KEY`
- `OPENAI_API_KEY`

## Architecture Docs

- `docs/architecture.md`
- `docs/llm-provider-decision.md`
- `docs/roadmap.md`
