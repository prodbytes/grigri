# grigri_app

The Grigri Flutter app (Android, iOS, web): matchmaking on climbing plans.
See [specs/](../specs/README.md) for what it does.

| Path | Holds |
|---|---|
| `lib/model/` | Profiles (`Climber`), plans, join requests, messages, and the climbing vocabulary (disciplines, grade scales, when) |
| `lib/data/` | `GrigriStore`, the matching rules and state; the demo data; on-device storage |
| `lib/ui/` | The screens: the swipe decks, match, plans, chat, profile |
| `lib/theme.dart` | The dark mountain theme |

Build and run it through the repository's scripts, which pass the version
and settings (`GRIGRI_VERSION`, `GRIGRI_STAGE`):

```bash
devbox services up        # web, on http://localhost:2112/app/
devbox run android        # the Android phone attached by USB
make web|android|ios      # release builds (see the Makefile)
```

Checks: `flutter analyze` and `flutter test`.
