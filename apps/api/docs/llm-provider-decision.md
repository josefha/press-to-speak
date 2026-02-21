# LLM Provider Decision (Text Post-Processing)

Date: 2026-02-21

## Decision

Primary provider/model for rewrite-polish:

- OpenAI `gpt-5-mini`

Fallback tiers:

- OpenAI `gpt-5-nano` for strict low-latency/cost mode

## Why This Fits Your Use Case

Your rewrite task is short-text, well-defined, and latency-sensitive:

- remove fillers
- normalize punctuation
- polish grammar
- apply product-specific formatting constraints

`gpt-5-mini` is a strong default for this profile because it is explicitly positioned for well-defined tasks with cost/latency efficiency.

## Runtime Policy

1. Call LLM on final transcript segments.
2. Keep prompt constrained to cleanup/restructure only.
3. Use strict timeout budget (example 500ms).
4. If timeout/failure, return raw transcript output and continue.
5. Keep response parsing constrained and validated before returning to clients.

## Suggested Rewrite Contract

Input:

- `raw_text`
- `locale`
- `style_profile`
- `snippet_rules`
- `custom_dictionary`

Output (strict JSON):

- `clean_text`
- `confidence` (optional)

## Acceptance Benchmarks Before Production

- p95 rewrite latency <= 700ms
- timeout/error fallback rate < 1%
- measurable grammar/readability lift vs deterministic-only path
- no regression in user-perceived responsiveness (raw transcript still immediate)
