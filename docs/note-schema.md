# Note schema

Amethyst reads Obsidian-compatible Markdown files with YAML-style frontmatter. It only considers files inside direct child folders of the user-selected root whose names contain `game` or `anime` (case-insensitive). This prevents templates and other unrelated vault notes from appearing in the library.

## Supported fields

| Field | Purpose | Example |
| --- | --- | --- |
| `title` | Display name | `title: Example title` |
| `status` | Media state, optionally as a wiki link | `status: "[[🟢 On]]"` |
| `progress` | Current anime episode | `progress: 3` |
| `episodes` | Total anime episodes | `episodes: 12` |
| `finished` | Completion date | `finished: 2026-11-21` |
| `rating` | Personal rating | `rating: 8` |
| `cover` | Remote cover image URL | `cover: https://example.com/cover.jpg` |

## Write guarantees

When Amethyst changes a status or progress field, it preserves unrelated frontmatter and Markdown body content. A progress update additionally synchronizes numbered Obsidian tasks inside the `## Episodes` section: episodes at or below progress are checked, while later episodes are unchecked. Other sections are not changed. The app stores completion dates as ISO-8601 calendar dates (`YYYY-MM-DD`).
