# Amethyst contributor guide

- Keep all source code, documentation, UI text, and commit messages in English.
- Amethyst is local-first. Never add a real vault path, user name, note content, or generated personal data to the repository.
- Keep desktop support for macOS, Windows, and Linux. Do not add cloud sync without explicit approval.
- Treat Markdown note files as the source of truth. Preserve unknown frontmatter and body text when updating a field.

## Repository skills

- Use `$obsidian-media-notes` for changes to note discovery, frontmatter parsing, or writing note fields.
- Use `$flutter-desktop` for Flutter UI, state, platform integration, or package changes.
- Use `$verification` when code, dependencies, or build behavior changes before handing work off.
- Use `$local-ai-progress` for local Ollama/Qwen chat parsing or chat-driven progress updates.
- Read `docs/note-schema.md` for the supported note format and `docs/architecture.md` for component boundaries when relevant.
