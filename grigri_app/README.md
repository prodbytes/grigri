# grigri_app

The Grigri Flutter app (Android, iOS, web). For now a single static screen;
see [specs/](../specs/README.md) for what it does.

Build and run it through the repository's scripts, which pass the version
and settings (`GRIGRI_VERSION`, `GRIGRI_STAGE`):

```bash
devbox services up        # web, on http://localhost:2112/app/
devbox run android        # the Android phone attached by USB
make web|android|ios      # release builds (see the Makefile)
```

Checks: `flutter analyze` and `flutter test`.
