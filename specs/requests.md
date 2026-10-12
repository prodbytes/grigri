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
