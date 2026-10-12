# Development environment

- **Toolchain**: [devbox.json](../devbox.json), locked in `devbox.lock`:
  Flutter, Python (the index server, the deploy script), the AWS CLI, GNU
  make and curl. `devbox shell` enters it.
- **Dev container** ([.devcontainer/](../.devcontainer)): Ubuntu 24.04 with
  Devbox 0.18.1 (the release binary, SHA-256 checked) and Nix 2.35.0
  (single-user, installer hash-checked); `post-create.sh` fetches the
  locked Nix store paths from `cache.nixos.org`, then runs
  `devbox install`, handing Codespaces' `GITHUB_TOKEN` to Nix against
  GitHub API rate limits. Docker-in-Docker, the Dart, Flutter, Python,
  Docker and YAML extensions, and ports 2112 and 2113 forwarded.
  Codespaces ask for 4 CPUs and 8 GB.
- **Services** (`devbox services up`, [process-compose.yaml](../process-compose.yaml)):
  - `2-flutter-web`: the app on http://localhost:2112/app/ (the `/app/`
    base href production uses), on Flutter's `web-server` device, through
    `scripts/flutter-web.sh` (also `devbox run web`). Ready when `/app/`
    answers. Stopping it also stops whatever listens on the port.
  - `5-index`: [grigri_index/site](../grigri_index) on
    http://localhost:2113/.
  - `0-health-check`: once both are ready, it prints the local URLs once
    (🧗 the app, 🏠 the index), then every 15 s (`HEALTH_CHECK_INTERVAL`)
    one line for the whole check: the time, then each dependency as its
    icon, a short label and ✅ or ❌, e.g.
    `2026-10-12 18:02:10  🏠 index ✅  🧗 web ✅`.
  - The ports (2112, 2113) differ from presence's and TabScan's, so the
    projects can run side by side. Servers bind to 127.0.0.1;
    `GRIGRI_BIND_HOST=0.0.0.0` serves other devices (a phone's browser).
- **Android** (USB, debugging on; `ANDROID_SERIAL` picks one of several):
  `devbox run android` runs a debug build attached
  (`scripts/flutter-android.sh`); `devbox run android-release` installs a
  release build over the app (keeping its data), starts it and checks it
  runs (`scripts/android-install.sh`); `devbox run android-log` streams the
  app's log lines and the system's related errors
  (`scripts/android-log.sh`, `--clear`, `--all`).
- **Any device**: `bash scripts/flutter-run.sh -d <device>`.
- **Settings**: `.env` (git-ignored; see [.env.example](../.env.example)),
  linked from the private `prodbytes/setec-astronomy` repo
  (`grigri.nu01/`) by `scripts/link-private.sh`. Only names listed in
  `scripts/dart-defines.sh` reach the app (now `GRIGRI_STAGE`); the
  version is passed as `GRIGRI_VERSION`.
- **Checks**: `flutter analyze` and `flutter test` in `grigri_app/`; the
  Release workflow runs both on pull requests that touch the app or the
  build.
