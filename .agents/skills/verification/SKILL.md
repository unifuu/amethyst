---
name: verification
description: "Verify Amethyst changes before handoff. Use after code, dependency, test, or build configuration changes."
---

# Verification

Run the narrowest relevant checks first, then complete the standard Flutter checks for code or dependency changes:

```bash
flutter analyze
flutter test
```

- Report the commands run and their outcome.
- If a check cannot run because a required local tool is unavailable, report the exact blocker rather than claiming a successful build.
- Do not add a real notes folder or personal data as a test fixture.
