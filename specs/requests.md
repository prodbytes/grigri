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
2. **Add the local address so that local HTTPS works, like presence.**
   Floci runs as the local CloudFront ([grigri_floci/](../grigri_floci),
   `4-floci` in `devbox services up`), over HTTP on port 2114 and HTTPS on
   2543 at https://local.grigri.nu01.com:2543/app/, with an mkcert
   certificate made by `scripts/local-certs.sh`; devbox gains mkcert and
   OpenSSL, the dev container forwards the new ports and binds the dev
   servers on every interface, and the health monitor checks `🚚 cdn` and
   `🔒 https` ([development environment](dev-environment.md)).
   `local.grigri.nu01.com` needs A (127.0.0.1) and AAAA (::1) records in
   the `grigri.nu01.com` zone ([grigri_infra/README.md](../grigri_infra/README.md)).
3. **Serve the web app on port 7189.** The Flutter dev server's port
   (`FLUTTER_WEB_PORT`) defaults to 7189 instead of 2112, in
   `process-compose.yaml`, the run and health scripts, Floci's CloudFront
   origin, and the dev container's forwarded ports
   ([development environment](dev-environment.md)).
4. **Remove the static fake data; everything from a cheap database
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
5. **Make sign-in last as long as possible: the API's own sessions (365
   days without use, sliding); clean up photos never saved to a
   profile.** (Asked as "make sign out longer, max time": Google ID tokens
   last an hour and can't be refreshed quietly on the web, so people were
   signed out hourly.)
   - Sessions ([API](api.md#sessions), [backend](backend.md)):
     `POST /api/session` trades a Google ID token, now verified by the
     function (jose, Google's keys cached; issuer, audience, expiry), for
     an opaque session token stored only as its SHA-256 hash. Every other
     route but `GET /api/health` takes it as a bearer token (401
     `signed out` otherwise). It slides (at most one write per session per
     day) and expires after 365 days without use (DynamoDB TTL, checked by
     the function too); no absolute limit. `DELETE /api/session` signs
     out, `DELETE /api/sessions` everywhere (a new keys-only index, gsi3,
     by subject). Admin is decided per request from the session's
     verified email and the current list. The HTTP API's JWT authorizer
     is gone. Dev mode (local only) keeps `X-Grigri-Dev-User` and also
     takes `{"devUser"}` at `POST /api/session`.
   - Photos: presigned uploads are tagged `grigri-pending=true`, a
     lifecycle rule on the photos bucket expires pending photos after a
     day, and saving a profile clears the tag of its new photos (400 if
     one isn't uploaded) and deletes the ones it drops. The function may
     now tag, untag and delete under `photos/` (still no reads); the
     permissions boundary allows the same, and the deploy roles may turn
     on TTL. Administrators redeploy `github-deploy.yaml` before the next
     API deploy.
   - Cost ([backend](backend.md#cost)): one DynamoDB read per request
     (about $0.06 per million), a write per active session per day, and
     one S3 request per new photo saved; nothing while idle.
   - Local ([Floci](../grigri_floci/README.md)): the same; Floci ignores
     the upload's tag field and skips the template's TTL setting (the
     ready hook turns TTL on itself).
