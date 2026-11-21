---
name: local-ai-progress
description: "Build or modify Amethyst's local Ollama/Qwen progress assistant. Use for chat parsing, model selection, title matching, or AI-driven progress updates."
---

# Local AI Progress

- Keep all inference on the local Ollama endpoint. Do not add cloud AI APIs, API keys, analytics, or note uploads.
- Use the model only to extract a title and episode number. Amethyst must resolve the local note and perform the field update itself.
- Update only the `progress` field for chat-driven actions. The operation must remain idempotent for the same episode number.
- If zero or multiple note titles match, explain the ambiguity and do not write a note.
- Preserve the pending candidate list and episode number while resolving a follow-up choice such as `first`, `second`, or `not season 2`.
- Prefer an exact normalized title or an unambiguous title mention in a follow-up reply before asking the user to clarify again.
- Test parsing and note matching changes without using personal notes as fixtures.
