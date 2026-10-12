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
     home screen, a static screen with the name, a
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
     clients have no API, so they're made in the Google Cloud console
     (project `grigri-511416`); the app doesn't sign in yet.
   - Google clients so far: GA Android (`com.nu01.grigri`), its ID in
     `.env` as `GOOGLE_ANDROID_CLIENT_ID_GA` (named in `.env.example`).
     Still to make: web (both sites' origins and `localhost:2112`), iOS,
     and RC Android if the RC gets its own package.
3. **Theme in mountain colors (olive, light brown, sand, gray, other greens
   and a sky blue), harmonious, dark for now.** The app is dark only, with
   an explicit color scheme ([theme](theme.md)) instead of one derived from
   a seed color; every text color passes WCAG AA.
4. **Begin the app: matchmaking like Tinder or Happn, for sports.** Swipe
   left / right or the buttons; profiles with climbing details (grades,
   when, where); plans separate from profiles and highlighted on the match
   screen; mutual yes makes a match and opens a chat; several people can
   match the same plan, which becomes a group; a newcomer joins only when
   every current member accepts.
   - [Matching](matching.md): the Discover deck of plans (best fits first)
     and the Requests deck of people; unanimous acceptance, one "no" is
     enough; matches; one group chat per plan.
   - [Screens](screens.md): Discover, Requests, Plans, Chats and Profile;
     the plan and profile editors; the match screen. The static home
     screen is gone.
   - No backend yet: the rules run on the device, the state is saved
     with shared_preferences, and demo data with made-up climbers (who
     answer by fixed policies) starts it.
5. **Someone joins a plan only when every member accepts them; meanwhile
   the plan shows as pending in their list, then as accepted. Notify people
   when they're accepted or rejected. Let people reject, too: one
   rejection is a rejection.**
   - The unanimous yes and the single "no" were already the rule
     ([matching](matching.md#the-group-decides)). New: the made-up
     climbers answer 10 seconds after a request (instantly in tests), so
     it shows as pending first.
   - Plans lists my plans as **Organizing** or **Accepted**, and the ones I
     asked to join as **Pending** (and who it's waiting for) or
     **Declined** (dismissable) ([screens](screens.md)).
   - [Notifications](matching.md#notifications): a bell on every tab, with
     a badge for unread ones, opens "You're in" and "Not this time"
     notifications. A yes that arrives later also opens "It's a match!",
     and a no shows a note at the bottom.
   - Besides swiping left in Requests, the plan screen has ✓ and ✕ for
     each person asking to join.
6. **In the profile: a photo, a description, the climbs; no when or where
   (that's for plans), and nothing under the picture (no home area or years
   climbing); the gear, with photos of it.**
   - [Profiles](matching.md#profiles-and-plans-are-separate) gain a photo
     (shown wherever their avatar is, initials otherwise) and up to 6 gear
     photos, and lose availability, places, home area and years climbing;
     profiles saved before are read without them.
   - Discover ranks by grades alone, then the soonest, and its only badge
     is "Your grades". The demo deck now opens on Tuesday's bouldering.
   - The [profile editor](screens.md) takes or picks the photos
     (image_picker, downsized as picked, kept on the device); iOS gains the
     camera and photo library usage strings ([platforms](platforms.md)).
