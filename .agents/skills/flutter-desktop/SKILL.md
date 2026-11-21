---
name: flutter-desktop
description: "Build or modify Amethyst's Flutter desktop experience. Use for UI, state management, desktop platform integration, or package changes."
---

# Flutter Desktop

Read [docs/architecture.md](../../../docs/architecture.md) before changing component boundaries or persistence behavior.

- Keep macOS, Windows, and Linux as supported targets unless the request explicitly changes that scope.
- Keep the experience local-first. Do not add analytics, cloud sync, network APIs, or account requirements without explicit approval.
- Prefer small, testable Dart components when a change adds substantial behavior.
- Use accessible Material controls and keep UI text in English.
