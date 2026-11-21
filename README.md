# Amethyst

Amethyst is a local-first Flutter desktop app for browsing and updating Markdown notes that represent games and anime. It is designed for Obsidian-compatible notes, but it does not require Obsidian to run.

## Privacy

The app never includes a vault path, a note export, or personal metadata in its tracked source. The first local setup stores the chosen root in the Git-ignored `config.json` file. Amethyst then loads that folder automatically and writes updates directly back to the selected notes.

## Note format

The app discovers Markdown files in directories whose names contain `game` or `anime` (case-insensitive). It reads frontmatter such as:

```yaml
---
title: Example series
status: "[[🟢 On]]"
progress: 3
episodes: 12
finished:
rating: 8
cover: https://example.com/cover.jpg
---
```

Use the folder button to select or change the parent directory containing your direct `Games` and `Animes` media-note folders. The selected path is saved locally in `config.json`, so it is loaded automatically on the next launch. Choose a card to edit its status and, for anime, progress. Selecting `Fin` also records today's date in `finished`.

## Local Qwen progress assistant

Open the sparkle button in the app bar to update anime progress from chat. Amethyst calls the Ollama API at `http://127.0.0.1:11434` and prefers the installed general-purpose `qwen3` model over a Coder model. Start Ollama first, then write a message such as `I watched episode 5 of Example Series.` The model extracts only the title and episode; Amethyst finds the local note and updates only its `progress` field. If multiple titles match, reply with the exact title, `first`, `second`, or `not season 2`; Amethyst retains the original episode number until the choice is resolved. Conversation text is selectable and copyable.

This feature is fully local: no OpenAI API, API key, account, or cloud note upload is used. The chosen model is saved as `ollamaModel` in Git-ignored `config.json`.

## Development

```bash
flutter pub get
flutter run -d macos
flutter analyze
flutter test
```

See [AGENTS.md](AGENTS.md) for contributor rules, `.agents/skills/` for Codex workflows, and `docs/` for maintained project context.
