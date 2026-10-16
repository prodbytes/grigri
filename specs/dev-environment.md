# Development environment

- **Toolchain**: [devbox.json](../devbox.json), locked in `devbox.lock`:
  Flutter, Node.js 22 (the API, [grigri_api/](../grigri_api)), Python (the
  index server, the deploy script), the AWS CLI, GNU make, curl, and
  mkcert and OpenSSL (the local HTTPS certificate). `devbox shell` enters it.
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
  - `1-rbacr`: rbacr's dev server (the `prodbytes/rbacr-local` image, in
    Docker, as the `grigri-rbacr` container with the `grigri-rbacr-data`
    volume) on http://localhost:2115, which the local API asks for admins
    and [roles](roles.md) (the app never calls it). It takes
    `RBACR_TOKEN` from `.env` as its root token (owner
    `dev@rbacr.local`), or generates one and logs it. Ready when
    `/health` answers; nothing waits for it, so the app runs without it
    (its roles then fail, with Retry, and nobody is an admin).
  - `5-index`: [grigri_index/site](../grigri_index) on
    http://localhost:2113/.
  - `6-pics`: [scripts/pics-local.sh](../scripts/pics-local.sh) loads
    [GriGri Pics](pics.md) into Floci's `grigri-local-pics` bucket with
    `grigri_api/pics/load.mjs` whenever it has no catalog (Floci keeps
    nothing between starts), checking every 30 s; photos are downloaded
    once, then cached in `grigri_api/pics/.cache`.
  - `4-floci`: [Floci](https://floci.io/) as the local CloudFront and the
    local AWS ([grigri_floci/](../grigri_floci), Docker, bound to
    127.0.0.1): `/app*` to the web app, `/api/*` to the local API,
    `/photos/*` to the local photos bucket, `/pics/*` to the local GriGri
    Pics bucket, everything else to the index,
    as in production. Before it starts, `scripts/build-api.sh` builds the
    API when its sources changed; its ready hook deploys the API's
    template into Floci (Lambda, HTTP API, DynamoDB, S3, and the live
    updates' authorizer function) and loads the made-up test data. Floci's
    MQTT broker is the local IoT Core for [live updates](#live-updates). Without `GOOGLE_WEB_CLIENT_ID` in `.env` the API
    runs in dev mode: callers name themselves with
    `X-Grigri-Dev-User: <email>`, or get a session from `POST /api/session`
    with `{"devUser": "<email>"}`. Admins are whoever the local rbacr says
    holds `grigri`'s `admin` role, asked with `RBACR_TOKEN` from `.env`
    through `host.docker.internal` ([backend.md](backend.md)).
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
    (🧗 the app, 🏠 the index, 🔒 HTTPS, 🔌 the API, 📡 MQTT), then every 15 s
    (`HEALTH_CHECK_INTERVAL`) one line for the whole check: the time, then
    each dependency as its icon, a short label and ✅ or ❌, e.g.
    `2026-10-12 18:27:56  🏠 index ✅  🧗 web ✅  🚚 cdn ✅  🔒 https ✅  🔌 api ✅  📡 mqtt ✅  🔑 rbacr ✅`.
    `🚚 cdn` asks Floci with the alias as `Host`; `🔒 https` validates the
    certificate against mkcert's CA and pins the name to 127.0.0.1, so
    neither needs DNS or `mkcert -install`; `🔌 api` asks
    `/api/health` through the CDN and expects the `local` stage; `📡 mqtt`
    asks for a WebSocket upgrade (subprotocol `mqtt`) at
    `wss://local.grigri.nu01.com:2543/mqtt` and expects 101; `🔑 rbacr`
    asks the local rbacr's `/health`.
  - The ports (7189, 2113, 2114, 2115, 2543) differ from presence's and TabScan's, so the
    projects can run side by side. Servers bind to 127.0.0.1;
    `GRIGRI_BIND_HOST=0.0.0.0` serves other devices (a phone's browser).
- **Live updates** ([live-updates.md](live-updates.md)) run locally on
  Floci's built-in MQTT broker, which serves MQTT over WebSocket at
  `/mqtt` on Floci's ports (`FLOCI_SERVICES_IOT_MQTT_AUTO_START` starts
  it with Floci): `GET /api/realtime` answers
  `wss://local.grigri.nu01.com:2543/mqtt` (the HTTPS port and mkcert
  certificate the site uses) with no authorizer. Floci (the pinned
  nightly) emulates IoT Core only in part, so two things differ from AWS:
  - **No custom authorizer**: this Floci has no `CreateAuthorizer` (a
    newer nightly checks one at connect, but still doesn't enforce
    Subscribe or Receive policies), so the template creates the
    `AWS::IoT::Authorizer` only outside `local`, and the local broker
    lets anyone connect and subscribe to anything, like dev mode trusts
    a header. The authorizer's function is still deployed locally
    (`grigri-local-api-realtime-auth`), so it can be invoked directly
    with an IoT-style event against the real local table; its policies
    are covered by the API's tests.
  - **Publishing over MQTT**: Floci's HTTP `iot-data` Publish returns 200
    but doesn't reach MQTT subscribers, so the local function (it sees
    `AWS_ENDPOINT_URL`) publishes with a minimal MQTT 3.1.1 client over
    WebSocket to `ws://<Floci>/mqtt` (Node's built-in WebSocket, no
    library) instead of `iot-data:Publish`.

  Why not something else: a separate broker container (Mosquitto or EMQX
  with an HTTP auth hook calling the authorizer) would enforce topic
  scoping locally, but adds a service, an image and an auth bridge to
  keep in step, for a check the tests already make; polling only would
  leave the live path untested until RC. Floci's broker costs nothing
  more and exercises the same app code, URL shape, hints and API path.
- **Android** (USB, debugging on; `ANDROID_SERIAL` picks one of several):
  `devbox run android` runs a debug build attached
  (`scripts/flutter-android.sh`); `devbox run android-release` installs a
  release build over the app (keeping its data), starts it and checks it
  runs (`scripts/android-install.sh`); `devbox run android-log` streams the
  app's log lines and the system's related errors
  (`scripts/android-log.sh`, `--clear`, `--all`).
- **iPhone**: `devbox run ios-log` shows the app's log file from the
  iPhone attached by USB (`scripts/ios-log.sh`, `--follow`, `--previous`;
  [logging](logging.md)).
- **Any device**: `bash scripts/flutter-run.sh -d <device>`.
- **Settings**: `.env` (git-ignored; see [.env.example](../.env.example)),
  linked from the private `prodbytes/setec-astronomy` repo
  (`grigri.nu01/`) by `scripts/link-private.sh`. Only names listed in
  `scripts/dart-defines.sh` reach the app (`GRIGRI_STAGE`,
  `GRIGRI_API_URL`, `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`: see
  [sign-in](sign-in.md); no rbacr token: roles come from the API);
  the version is passed as `GRIGRI_VERSION`. The app always signs in
  with Google, so a local build needs `GOOGLE_WEB_CLIENT_ID` to sign in.
- **Checks**: `flutter analyze` and `flutter test` in `grigri_app/`; the
  Release workflow runs both on pull requests that touch the app or the
  build. The API: `npm run check` in `grigri_api/` (type check, tests,
  build); the deploys run it too.
- **Test data**: `STAGE=local bash scripts/seed.sh` re-seeds the local
  stack (Floci seeds it on every start).
