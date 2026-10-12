# Development environment

- **Toolchain**: [devbox.json](../devbox.json), locked in `devbox.lock`:
  Flutter, Python (the index server, the deploy script), the AWS CLI, GNU
  make, curl, and mkcert and OpenSSL (the local HTTPS certificate). `devbox shell` enters it.
- **Dev container** ([.devcontainer/](../.devcontainer)): Ubuntu 24.04 with
  Devbox 0.18.1 (the release binary, SHA-256 checked) and Nix 2.35.0
  (single-user, installer hash-checked); `post-create.sh` fetches the
  locked Nix store paths from `cache.nixos.org`, then runs
  `devbox install`, handing Codespaces' `GITHUB_TOKEN` to Nix against
  GitHub API rate limits. Docker-in-Docker (for Floci), the Dart,
  Flutter, Python, Docker and YAML extensions, ports 7189, 2113, 2114 and
  2543 forwarded, and `GRIGRI_BIND_HOST=0.0.0.0` so Floci can reach the
  dev servers.
  Codespaces ask for 4 CPUs and 8 GB.
- **Services** (`devbox services up`, [process-compose.yaml](../process-compose.yaml)):
  - `2-flutter-web`: the app on http://localhost:7189/app/ (the `/app/`
    base href production uses), on Flutter's `web-server` device, through
    `scripts/flutter-web.sh` (also `devbox run web`). Ready when `/app/`
    answers. Stopping it also stops whatever listens on the port.
  - `5-index`: [grigri_index/site](../grigri_index) on
    http://localhost:2113/.
  - `4-floci`: [Floci](https://floci.io/) as the local CloudFront
    ([grigri_floci/](../grigri_floci), Docker, bound to 127.0.0.1): `/app*`
    to the web app, everything else to the index, as in production.
    HTTP on http://grigri.localhost:2114/app/ (`FLOCI_PORT`), HTTPS on
    **https://local.grigri.nu01.com:2543/app/** (`FLOCI_HTTPS_PORT`) and
    https://grigri.localhost:2543/app/. Hot reload works through it.
    `scripts/local-certs.sh` first writes the mkcert certificate (for
    `local.grigri.nu01.com`, `grigri.localhost`, `*.grigri.localhost`,
    `localhost`, `127.0.0.1`, `::1`) to the git-ignored
    `grigri_floci/certs/`, only when it's missing, expires within 30 days,
    misses a name or wasn't signed by this machine's CA. Browsers trust it
    after a one-time `devbox run mkcert -install`.
    `local.grigri.nu01.com` is a public name for 127.0.0.1 and ::1 (Route
    53), so it works as an OAuth origin.
  - `0-health-check`: once all are ready, it prints the local URLs once
    (🧗 the app, 🏠 the index, 🔒 HTTPS), then every 15 s
    (`HEALTH_CHECK_INTERVAL`) one line for the whole check: the time, then
    each dependency as its icon, a short label and ✅ or ❌, e.g.
    `2026-10-12 18:27:56  🏠 index ✅  🧗 web ✅  🚚 cdn ✅  🔒 https ✅`.
    `🚚 cdn` asks Floci with the alias as `Host`; `🔒 https` validates the
    certificate against mkcert's CA and pins the name to 127.0.0.1, so
    neither needs DNS or `mkcert -install`.
  - The ports (7189, 2113, 2114, 2543) differ from presence's and TabScan's, so the
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
