# Request log

Requests that shaped the specification, oldest first. Each entry summarizes
what was asked and what changed. See [README.md](README.md) for the current
spec.

## 2026-10-12

1. **Start the app's structure from prodbytes/presence: copy everything
   that isn't presence's own app, with a static screen with a label for
   the app, deployed to RC and GA.**
   - Structure, adapted from presence (and from TabScan, which was
     scaffolded from presence the same way): devbox (Flutter, Python, AWS
     CLI, make, curl), the dev container with its post-create script, the
     `Makefile` and `scripts/` (build, run on web and Android, logs,
     version, signed RC and GA release tags, deploy, private settings
     link, health monitor), `process-compose.yaml` (web app, index page,
     health check, on ports 2112 and 2113), the Release, Deploy and Deploy
     RC workflows, `grigri_infra/` (the S3 + CloudFront site with its
     security headers, and the GitHub OIDC deploy roles, scoped per
     stage), `grigri_index/`, the version files (0.1), the MIT license,
     CLAUDE.md and AGENTS.md, the barrel roll prompt, and this `specs/`
     folder. Left out, as presence's own: the auth, payments and health
     APIs, local AWS emulation (Floci) and local HTTPS, cloud sync and
     identity, the install script site, legal pages, and the Linux /
     Raspberry Pi builds.
   - The app ([grigri_app/](../grigri_app)): the
     [home screen](home-screen.md), a static screen with the name, a
     tagline and the version, on [Android, iOS and the web](platforms.md),
     with a widget test.
   - Deploys to https://grigri.nu01.com (GA) and
     https://rc.grigri.nu01.com (RC), in a new `grigri.nu01.com` Route 53
     zone delegated from `nu01.com` ([deploy](deploy.md)).

2. **Prepare the AWS account so grigri.nu01.com has its own hosted zone,
   with everything needed to deploy; and the Google sign-in keys.**
   - Done in the account (no code change): the public zone
     `grigri.nu01.com` (`Z087054988V7QH92N1FX`) and its NS delegation
     (TTL 3600) in `nu01.com`, as [deploy.md](deploy.md) describes; the
     repository variable `HOSTED_ZONE_ID`.
   - Pending an administrator: the `grigri-github-deploy` stack, the
     `AWS_DEPLOY_ROLE_ARN` / `AWS_DEPLOY_RC_ROLE_ARN` variables and the
     `GRIGRI_HEALTH_EMAILS` secret
     ([grigri_infra/README.md](../grigri_infra/README.md)). Google sign-in
     clients have no API, so they're made in the Google Cloud console; the
     app doesn't sign in yet.
3. **Add the local address so that local HTTPS works, like presence.**
   Floci runs as the local CloudFront ([grigri_floci/](../grigri_floci),
   `4-floci` in `devbox services up`), over HTTP on port 2114 and HTTPS on
   2543 at https://local.grigri.nu01.com:2543/app/, with an mkcert
   certificate made by `scripts/local-certs.sh`; devbox gains mkcert and
   OpenSSL, the dev container forwards the new ports and binds the dev
   servers on every interface, and the health monitor checks `🚚 cdn` and
   `🔒 https` ([development environment](dev-environment.md)).
   `local.grigri.nu01.com` needs A (127.0.0.1) and AAAA (::1) records in
   the `grigri.nu01.com` zone ([grigri_infra/README.md](../grigri_infra/README.md)).
4. **Serve the web app on port 7189.** The Flutter dev server's port
   (`FLUTTER_WEB_PORT`) defaults to 7189 instead of 2112, in
   `process-compose.yaml`, the run and health scripts, Floci's CloudFront
   origin, and the dev container's forwarded ports
   ([development environment](dev-environment.md)).
5. **Remove the static fake data; everything from a cheap database
   (DynamoDB); GA empty and real, fake data in RC and local; an admin can
   approve/reject any request.**
   - A backend, [grigri_api/](../grigri_api) ([backend](backend.md),
     [API](api.md)): one TypeScript Lambda (Node.js 22, arm64, 256 MB)
     with an internal router behind one HTTP API, whose JWT authorizer
     checks Google ID tokens (`GOOGLE_WEB_CLIENT_ID`) on every route but
     `GET /api/health`; one on-demand DynamoDB table (single-table design;
     point-in-time recovery and deletion protection in prod only);
     photos in a private bucket of the site stack, uploaded with presigned
     POSTs and served under `/photos/*`. The matchmaking rules (deck,
     unanimous yes, one no, leaving and organizer handover, notices, chat
     notes) moved from the app to pure, unit-tested modules, without the
     auto-answering made-up climbers. Admins (`GRIGRI_ADMIN_EMAILS`) see
     and accept or reject any open request. Plans follow the app's new
     shape (place, area, sector, start and end; no title or group size;
     grade scales `routes` and `boulders`).
   - Environments: production starts empty and is never seeded; the RC is
     seeded with made-up test data after each deploy, and the local stack
     on every start (`scripts/seed.sh`, idempotent, refuses prod).
   - Deploys ([deploy](deploy.md)): `scripts/deploy.sh` tests, builds and
     deploys the `<prefix>-api` stack before the site, whose CloudFront
     routes `/api/*` to it, and checks `/api/health`; the workflows set up
     Node.js and pass `GOOGLE_WEB_CLIENT_ID` and `GRIGRI_ADMIN_EMAILS`.
     The deploy roles gain the API's resources, scoped by name, with a
     permissions boundary on every role they create, and an artifact
     bucket per stage ([grigri_infra/README.md](../grigri_infra/README.md):
     redeploy `github-deploy.yaml`, set the new variable and secret). The
     web app's CSP allows photo uploads to the bucket and Google Identity
     Services.
   - Local ([development environment](dev-environment.md)): devbox gains
     Node.js 22; Floci deploys the same template (Lambda, HTTP API,
     DynamoDB, S3) and seeds it, routes `/api/*` and `/photos/*`, and runs
     in dev mode (`X-Grigri-Dev-User`) without a Google client; the health
     monitor checks `🔌 api`.
   - Cost ([backend](backend.md#cost)): nothing new costs anything while
     idle; DynamoDB on demand rather than Aurora Serverless v2 (about
     $43/month minimum) or RDS (hourly), an HTTP API ($1 per million)
     rather than a REST API ($3.50), one Lambda, S3 for photos.
6. **Theme in mountain colors (olive, light brown, sand, gray, other greens
   and a sky blue), harmonious, dark for now.** The app is dark only, with
   an explicit color scheme ([theme](theme.md)) instead of one derived from
   a seed color; every text color passes WCAG AA.
7. **A better icon instead of Flutter's default.** Mountain peaks with a
   snow cap and a moon, in a sand ring, on the theme's dark background,
   for Android (with an adaptive icon), iOS and the web (favicon, PWA
   icons, and the manifest's colors in the theme's instead of Flutter
   blue). How to regenerate the icons is in [platforms](platforms.md).
8. **Use this icon** (a grigri over mountains, shared as a
   PNG). It replaces the mountains-in-a-ring icon on every platform; its
   SVG sources are gone. The shared art is kept as the icon's source, and
   [scripts/make-icon.py](../scripts/make-icon.py) cleans its stray yellow
   pixels and makes the full and the adaptive-foreground PNGs
   ([platforms](platforms.md)).
9. **Make cost the most important perspective in design.** CLAUDE.md now
   says: serverless services with minimal cost; between services or
   libraries, the least costly one that meets the requirements; and say
   what a new cloud resource costs.
10. **On the Discover view, rank the suggestions by how much they match my
    profile and how close they are to me; let people set their location on
    their profile and add other locations of interest.** This entry is the
    backend's half; the app's is on the app's branch.
    - [API](api.md): a profile takes a `location` and up to 5 `areas`
      (named points), rounded to about 1 km and **private**: only my own
      profile carries them, never anyone else's `climbers`. Plans take
      their place's point (`lat`, `lon`), from the sector index.
    - The deck is ranked by [fit + nearness](api.md#the-decks-ranking):
      how well its grades suit mine (0–1) plus how close it is to my
      nearest location or area (0–1, e^(−km/50)), then soonest; it
      returns each plan's distance in km. The old "fits first" rule is
      gone.
    - The seed's plans carry their places' approximate points.
    - Cost: none; it's computed in the same request, over the same reads.
