# grigri_app

The Grigri Flutter app (Android, iOS, web): matchmaking on climbing plans.
See [specs/](../specs/README.md) for what it does.

| Path | Holds |
|---|---|
| `lib/model/` | Profiles (`Climber`), plans, join requests, messages, and the climbing vocabulary (disciplines, grade scales, when) |
| `lib/data/` | The backend API client (`api.dart`, `http_api.dart`), Google sign-in (`auth.dart`), and `GrigriStore`, the screens' cache over the API |
| `lib/ui/` | The screens: sign-in, the swipe deck, match, plans, chat, profile, admin |
| `lib/config.dart` | The API's site and the Google client IDs, from `--dart-define` |
| `lib/theme.dart` | The dark mountain theme |

Build and run it through the repository's scripts, which pass the version
and settings (`GRIGRI_VERSION`, `GRIGRI_STAGE`, `GRIGRI_API_URL`,
`GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`; see
[specs/sign-in.md](../specs/sign-in.md)):

```bash
devbox services up        # web, on http://localhost:2112/app/
devbox run android        # the Android phone attached by USB
make web|android|ios      # release builds (see the Makefile)
```

Checks: `flutter analyze` and `flutter test`.
