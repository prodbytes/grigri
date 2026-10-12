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
3. **Theme in mountain colors (olive, light brown, sand, gray, other greens
   and a sky blue), harmonious, dark for now.** The app is dark only, with
   an explicit color scheme ([theme](theme.md)) instead of one derived from
   a seed color; every text color passes WCAG AA.
4. **A better icon instead of Flutter's default.** Mountain peaks with a
   snow cap and a moon, in a sand ring, on the theme's dark background,
   for Android (with an adaptive icon), iOS and the web (favicon, PWA
   icons, and the manifest's colors in the theme's instead of Flutter
   blue). The SVG sources and how to regenerate the icons are in
   [platforms](platforms.md).
