# Architecture

Amethyst is a local-first Flutter desktop application. The current implementation is intentionally small and uses these boundaries:

- `LibraryPage` owns configuration loading, folder selection, search, media-type filtering, and the note collection displayed in the UI.
- `AppConfig` reads and writes the local `config.json` file, which stores the selected notes-root path and is ignored by Git.
- `NoteRepository` discovers Markdown files, reads frontmatter, applies field-level writes, and synchronizes numbered checkboxes in an `## Episodes` section after a progress update.
- `MediaNote` is the in-memory representation used by UI components.
- `NoteCard` renders a media note; `EditNoteDialog` collects status and anime progress updates.
- `LocalProgressChatPage` sends chat text to the local Ollama service, preserves pending ambiguity choices, renders selectable conversation text, and writes only the matching note's `progress` field.

The selected notes directory is local-only configuration. `config.json` is Git-ignored and may contain a private local path; it must never be committed. The repository must not contain exported note data or any personally identifying vault details.

The local AI assistant calls `http://127.0.0.1:11434` only. It has no cloud fallback and no API key. The optional `ollamaModel` value in `config.json` selects a locally installed Qwen model.
