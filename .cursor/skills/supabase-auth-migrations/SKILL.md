# Supabase Auth + Generated Migrations

Use this skill when working on PressToSpeak auth, Supabase integration, and schema changes.

## Scope

- mac app supports two modes:
1. `PressToSpeak Account` (default): Supabase sign-up/sign-in, Bearer token to API.
2. `Bring Your Own Keys` (advanced): user-supplied OpenAI + ElevenLabs keys, unauthenticated path only if API env explicitly allows it.
- API verifies Supabase access tokens in `USER_AUTH_MODE=optional|required`.
- API can allow open BYOK traffic only with explicit opt-in (`ALLOW_UNAUTHENTICATED_BYOK=true`) and rate limiting.

## Secure Defaults

- Keep `USER_AUTH_MODE=required` in production.
- Keep `ALLOW_UNAUTHENTICATED_BYOK=false` in production unless intentionally opening a free tier.
- Use `PROXY_SHARED_API_KEY` between mac app and API.
- Use `SUPABASE_PUBLISHABLE_KEY` in client apps.
- Never expose Supabase secret/service-role keys in the mac app.
- Keep request log redaction for `Authorization`, `x-api-key`, `x-openai-api-key`, `x-elevenlabs-api-key`.

## Migration Policy (Generated, Not LLM-Written)

Do not handwrite migration SQL in this repo.

Required flow:
1. Apply intended schema/policy changes to a dev database (via Supabase MCP SQL tools or Supabase Studio).
2. Generate migration SQL from the actual diff:
```bash
supabase db diff -f <migration_name>
```
3. Review generated SQL (RLS, grants, policies, destructive operations).
4. Validate replay from scratch:
```bash
supabase db reset
```
5. Commit only generated migration files under `supabase/migrations/`.

Allowed exception: create an empty migration file only when absolutely necessary for manual hotfixes, and mark it as manual in PR notes.

## Cursor MCP Checklist

- Use a non-production environment for iterative SQL changes.
- After MCP-applied changes, always run `supabase db diff -f ...` locally so migration files are tool-generated.
- Before merge, confirm no migration SQL was authored by LLM/copied manually.

## Self-Review Checklist (Security)

- Auth bypass checks: required paths reject missing/invalid tokens.
- BYOK checks: both provider headers required together.
- Token lifecycle: refresh and expiration handling in client.
- Rate limit behavior for unauthenticated traffic.
- Secret handling: no keys/tokens in logs or persisted plaintext files.
