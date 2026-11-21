---
name: obsidian-media-notes
description: "Safely read and update Amethyst Markdown media notes. Use for note discovery, frontmatter parsing, or status and progress writes."
---

# Obsidian Media Notes

Treat the user's local Markdown files as the source of truth. Read [docs/note-schema.md](../../../docs/note-schema.md) before changing note behavior.

- Scan only direct child media collections below a folder selected at runtime; never add a real folder path, note export, or personal note content to this repository.
- Preserve note bodies and frontmatter fields that are unrelated to the requested update. A progress update may synchronize only numbered tasks within the `## Episodes` section.
- Support the documented scalar and wiki-link field forms. Normalize only for display; write the expected source format back to the note.
- Add focused tests for parser or writer changes, including preservation of unrelated fields.
