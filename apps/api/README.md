# PressToSpeak API (Planned)

This folder is intentionally docs-only for now.

Target stack:

- TypeScript
- Express
- Supabase (user mapping + usage tracking)
- Polar.sh (future billing)

Primary role:

- Thin, fast API middle layer between clients and ElevenLabs STT.
- Enforce auth, quotas, spend controls, and request policy.
- Post-process transcript text (rules first, optional LLM polish second).

See `docs/architecture.md` for the system design.
See `docs/llm-provider-decision.md` for the initial rewrite-model recommendation.
