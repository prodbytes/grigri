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
10. **Begin the app: matchmaking like Tinder or Happn, for sports.** Swipe
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
11. **Someone joins a plan only when every member accepts them; meanwhile
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
12. **Make the age optional in the profile; don't show it when it's left
    empty.** The profile editor's Age (optional) can be blank. A profile
    without an age shows just the name ("Name" instead of "Name, 30") on
    the decks, profile sheets and Profile.
13. **In the profile: a photo, a description, the climbs; no when or where
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
14. **No Requests tab: the tabs are Discover, Plans, Chats, Notifications
    and Profile. Accepting or declining a join request happens inside the
    group chat; when someone asks to join, notify the organizer and
    everyone already in.**
    - The Requests tab and its people deck are gone. Each request is a
      card in the plan's group chat, with Accept / Decline and who has said
      yes ([matching](matching.md#join-requests-in-the-group-chat)); one
      decline still turns them down. Chats shows "N to answer", and its tab
      badge counts them.
    - Notifications is a tab (the bell on each tab's bar is gone). It adds
      "<name> wants to join" for every member of the plan, which opens the
      chat. A newcomer also hears of the requests still open.
    - The plan screen no longer has ✓ / ✕; it points to the chat.
    - Fixed: long chat notes overflowed their label instead of wrapping.
15. **A searchable database of climbing sectors, the cheapest way; then in
    the new plan screen: no title; where is one search field; when is the
    date and a time range (from, to) instead of a start and a length; a
    European / American grade system switch above the grades, like Celsius
    and Fahrenheit; no group size (the group is whoever matches); notes;
    publish.**
    - [Sectors](sectors.md): a static index searched on the device (no
      server), built from OpenStreetMap by `tool/build_sectors.dart`.
      OpenBeta was set aside: it barely covers Europe. The bundled index is
      a placeholder until the build runs.
    - [Plans](matching.md#profiles-and-plans-are-separate) lose their title
      (they're called by their place), length and group size, and gain an
      end time and the sector's id; plans saved before are read with their
      length as the time range. Discover no longer skips full plans: none
      are.
    - The grade system is my setting, everywhere: grades on cards, chats,
      profiles and the editors read in it. The scales are now routes and
      boulders, each written both ways.
    - The [plan editor](screens.md) is as asked; the profile editor gains
      the same grade switch.
16. **When someone likes the plan but doesn't match yet, call it out at
    the top of the chat, so people know they need to approve or reject
    the new person.**
    - The [group chat](matching.md#join-requests-in-the-group-chat) pins
      a callout under the plan for each request still waiting for my
      answer: avatar, name, how many said yes, and ✕ / ✓ (the same accept
      and decline as the request's card). After I answer, it leaves the
      callout; the card in the messages stays as the record.
17. **Add the rbacr integration; at the end of the profile view, show the
    user's roles.**
    - New feature: [Roles](roles.md). The app depends on rbacr's Dart
      client (pinned to a commit) and asks rbacr's `/api/me`; the
      [Profile](screens.md) tab ends with a Roles card: my roles in the
      `grigri` system and my global ones, the email rbacr knows me by,
      or why there are none (not signed in, none yet, rbacr unreachable,
      with Retry).
    - Grigri has no sign-in yet, so only development builds ask rbacr,
      with the local dev server's token; `scripts/dart-defines.sh` passes
      `RBACR_URL`, and `RBACR_TOKEN` only to the dev run scripts, for a
      localhost rbacr outside a deploy.
    - [Development environment](dev-environment.md): `devbox services up`
      runs rbacr's dev server (`1-rbacr`, port 2115, CORS for the web
      app), the health line gains 🔑 rbacr, debug Android builds allow
      plain http and `devbox run android` sets up `adb reverse` for it;
      `.env.example` lists `RBACR_URL` and `RBACR_TOKEN`.
18. **Remove the static fake data; everything from the database; GA empty
    and real, fake data in RC and local; an admin can approve/reject any
    request; Google sign-in.**
    - The app's data all comes from the backend API ([api.md](api.md)):
      the store is a cache over an API client, with loading states and the
      server's errors at the bottom of the screen. Gone: the demo data
      (`seed.dart`), the made-up climbers' answering policies and their
      timer, the on-device state (shared_preferences now keeps only the
      grade system, a display preference), and Profile's "Reset the demo
      data". GA starts empty; RC and local get made-up
      data from the backend's seed ([matching](matching.md#data-the-backend-api)).
    - [Refreshing](matching.md#refreshing) polls only what's on screen,
      while the app is in the foreground: tabs on opening and every 15 s,
      an open chat every 3 s with `after=`. A group's yes found by a
      refresh opens the match screen.
    - Photos are uploaded to the backend's photo store (presigned POSTs)
      and kept in profiles as keys, shown from `<site>/photos/<key>`.
    - [Sign-in](sign-in.md) with Google only (google_sign_in 7: Google's
      button on the web, the web client ID as server client ID on Android
      and iOS), **Create your profile** after the first sign-in, Sign out
      in Profile's ⋯; a local-only dev sign-in without a client ID. New
      public build settings `GRIGRI_API_URL`, `GOOGLE_WEB_CLIENT_ID` and
      `GOOGLE_IOS_CLIENT_ID` (allowed in `scripts/dart-defines.sh`, empty in
      `.env.example`, repository variables in CI); iOS's client ID and URL
      scheme reach `Info.plist` through the git-ignored `Private.xcconfig`;
      Release builds a GA tag's apps for production, the rest for RC. The
      site's CSP allows Google Identity Services.
    - Admins get an **Admin** tab to approve or reject any open request
      ([screens](screens.md)).
    - Merged with the sector search, time-range plans without title or
      group size, the grade systems and the chat's join callout: plans
      travel to the API in that shape (no spots, nothing is ever full),
      and the callout's ✕ / ✓ call the API like the request cards.
    - Every tab has an [empty state](screens.md) with what to do next.
19. **Merge it all to main; publish a new rbacr image.**
    - The open stack merged into `main`: the scaffold, local HTTPS with
      the backend API, the mountain theme and icons, cost first, and
      matchmaking (the app on the API, with sign-in and the roles card).
      Merged together: the deploy workflows pass `GOOGLE_WEB_CLIENT_ID`
      (to the app and the API) and `GRIGRI_ADMIN_EMAILS`; the CSP keeps
      sign-in, the API and photo uploads; `devbox services up` runs Floci,
      the API and the local rbacr side by side (web on 7189), and rbacr's
      CORS allows the web app directly and through Floci's HTTPS
      ([development environment](dev-environment.md)).
    - `prodbytes/rbacr-local` republished (amd64 and arm64,
      `0.1.202610121814` and `latest`) from rbacr's main, so the local
      rbacr answers the web app's CORS preflights.
    - Also merged: the API's long sessions and pending-photo cleanup
      (#21, from `local-https`) with the app's side (#19) and Discover's
      ranking by match and distance (#20).
20. **Make sign-in last as long as possible: the API's own sessions (365
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
    - The app (on the web people were signed out after about an hour, when
      the Google ID token it sent on every call expired): after Google
      sign-in it calls `POST /api/session` once with the ID token and
      sends the API's session token as the bearer on every call; Google
      isn't asked again until a 401 or a sign-out. A kept session starts
      the app signed in, straight to `GET /api/me`. Sessions last until
      sign-out or 365 days without use ([sign-in](sign-in.md)).
    - The token is kept in secure storage on Android and iOS
      (flutter_secure_storage: Keystore, Keychain this-device-only) and in
      local storage on the web (guarded by the site's CSP).
    - A 401 forgets the token and goes back to the sign-in screen; the
      quiet Google refresh on 401 is gone. Sign out calls
      `DELETE /api/session`; Profile's ⋯ adds **Sign out everywhere**
      (`DELETE /api/sessions`, after a confirmation;
      [screens](screens.md)).
    - The local dev sign-in starts a session with `{"devUser"}` too,
      instead of sending `X-Grigri-Dev-User` on every call.
21. **On the Discover view, rank the suggestions by how much they match my
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
22. **On the Discover view, rank the suggestions by how much they match my
    profile and how close they are to me; let people set their location on
    their profile and add other locations of interest.** The app's half;
    the backend's is entry 21.
    - [Matching](matching.md): a profile has a private **location** and up
      to 5 **areas**, picked from the sector index; the deck is ranked by
      grade fit plus nearness to the nearest of them (the server's score),
      replacing "fits first, then soonest"; cards say how far each plan
      is. The app keeps my location and areas when a refresh brings my
      profile back without them.
    - [Screens](screens.md): the profile editor's "Where you climb"
      section and a full-screen location picker; Discover's distance
      line and, without a location, a hint with **Set**; saving the
      profile refreshes the deck.
    - [Sectors](sectors.md): index rows carry each place's point (`out
      center` from OpenStreetMap; the placeholder gets approximate
      points); a plan keeps its sector's point. The index is cached once
      loaded, not as a pending load.
23. **Make sure the app is internationalized (English, Spanish, German,
    French, Portuguese, Catalan); keep the translation bundles up to date;
    let the user pick in the profile.**
    - New feature: [Languages](i18n.md). Flutter's gen-l10n with ARB
      bundles in `grigri_app/lib/l10n/` (`app_en.arb` the described
      template, and es, de, fr, pt, ca); every text the app writes
      itself moved into them, with ICU plurals, placeholders and a
      `select` for disciplines; discipline, gear and grade-system names
      and dates follow the language; the failures the app describes itself
      (timeouts, unreachable server, photo uploads, signed out, sign-in,
      signing out everywhere) too, as do the Where-you-climb section, the
      location picker, the Discover hint and plan distances. Server data
      and messages stay as written.
    - A **Language** picker (System default, or each language named in
      itself) in the [profile editor](screens.md) and on the Profile tab,
      applied at once and kept on the device next to the grade system;
      by default the device's language, English when the app doesn't
      speak it. The web page's `<html lang>` follows it.
    - `test/l10n_test.dart` fails when a bundle misses or adds keys, or
      its placeholders differ from English; widget tests cover the device
      language, the English fallback, switching to Spanish and back, and
      the pick kept on the device.
24. **Check the running health checks; add them if not yet done.** The
    health checks' half of entry 25.
    - [Deploy](deploy.md): each stage's site stack also has a Route 53
      health check of `/api/health` (it must say `"ok":true`), with its
      own alarm (`<stack>-api-health`) on the same topic, so the API is
      watched like the web app.
25. **Check the data works as expected: GA with no data, RC with made-up
    data; push the tags, check the workflows and the health checks.**
    The deploy configuration's half; the health checks' is entry 24.
    - [Sign-in](sign-in.md), [deploy](deploy.md): each stage has its own
      Google web client (its JavaScript origin is its own site), so the
      RC's sign-in works on https://rc.grigri.nu01.com: Deploy RC and the
      Release of non-GA tags use the repository variables
      `GOOGLE_WEB_CLIENT_ID_RC` and `GOOGLE_IOS_CLIENT_ID_RC`; Deploy and
      GA releases keep `GOOGLE_WEB_CLIENT_ID` and `GOOGLE_IOS_CLIENT_ID`.
26. **The web favicon.** The site root's redirect page
    (`grigri_index/site/index.html`) had no favicon, so `/` showed the
    browser's default until it reached `/app/`.
    - [Platforms](platforms.md): the root page now links
      `grigri_index/site/favicon.png`, a copy of the app's favicon (the
      grigri icon); regenerating the icon includes copying it there. The
      root's CSP already allows images from the site.
27. **Health alarms to julio+health@nu01.com; let rbacr handle roles.**
    - [Roles](roles.md), [API](api.md): who is an admin is rbacr's
      answer (`POST /api/check`, system `grigri`, role `admin`; roots
      too), asked with an rbacr root's API token, kept 60 s, failing
      closed. The `GRIGRI_ADMIN_EMAILS` list (secret, template parameter
      `AdminEmails`, `.env`) is gone.
    - [Deploy](deploy.md), [backend](backend.md): deploys take the
      optional secret `GRIGRI_RBACR_TOKEN` (template parameter
      `RbacrToken`); without it they warn and nobody is an admin. Locally
      the API asks the local rbacr with `.env`'s `RBACR_TOKEN`.
    - The repository secret `GRIGRI_HEALTH_EMAILS` is set (not in the
      repository).
28. **(Follow-up to 25: the first deploys failed.)** The deploy roles
    couldn't tag the HTTP API's stage (`apigateway:TagResource`), so both
    stages' first API create rolled back.
    - [Deploy](deploy.md): the roles may `apigateway:TagResource` and
      `UntagResource` on HTTP APIs; `scripts/deploy.sh` deletes a stack
      left in `ROLLBACK_COMPLETE` (a failed first create, holding nothing)
      before deploying it again.
29. **Live updates: push over MQTT (AWS IoT Core) instead of polling.**
    - New feature, [Live updates](live-updates.md): after each change the
      API publishes a tiny hint (`{"kind", "planId"}`, never data) to each
      affected climber's topic, `grigri/<stage>/climbers/<id>/hint`
      (members for messages, requests, joins, leaves and plan edits; the
      requester for a no; the newcomer for a match; never the one who
      acted), best effort and never failing a request. The app keeps one
      MQTT-over-WebSocket connection in the foreground (mqtt_client,
      pinned), connects with its session token, refetches just what a
      hint names through the API, and reconnects with backoff (1 s up to a
      minute, jittered).
    - An IoT Core custom authorizer (`<prefix>-api-realtime`, unsigned)
      and its function (`<prefix>-api-realtime-auth`) look the session up
      as the API does and allow only connecting as `<climberId>-…` and
      subscribing to and receiving that climber's own topics; they fail
      closed, re-check every hour and disconnect within a day.
    - [API](api.md): `GET /api/realtime` says where to connect; the hint
      table. [Matching](matching.md#refreshing): polling stays as a
      safety net, slowed while connected (2 minutes; an open chat every
      minute) and back to 15 s / 3 s when the connection drops.
      [Sign-in](sign-in.md): the session token also opens the live
      connection (the only URL that carries it).
    - Infra ([backend](backend.md), [deploy](deploy.md)): the API role
      may publish only to `topic/grigri/<stage>/climbers/*`; the
      permissions boundary and the deploy policy cover exactly that, the
      `<prefix>-*` IoT authorizers and `iot:DescribeEndpoint`
      (**redeploy `grigri_infra/github-deploy.yaml` once**);
      `scripts/deploy.sh` looks up the IoT Data-ATS endpoint and passes
      it to the API (for `GET /api/realtime`) and the site (CSP
      `connect-src wss://<endpoint>`).
    - Cost ([backend](backend.md#live-updates-cost)): IoT Core
      connectivity ($0.08 per million connection-minutes) and messages
      ($1 per million; about $2 per million hints), an authorizer call
      per connect and per open hour; about half a cent per thousand
      person-hours online, versus $2–4 for the polling it replaces;
      cheaper than API Gateway WebSockets (3× the connection-minutes plus
      a connection table) and no second platform (Cloudflare Durable
      Objects). $0 idle.
    - [Local](dev-environment.md#live-updates): Floci's own MQTT broker
      over WSS on the HTTPS port; Floci has no custom authorizers and its
      HTTP Publish doesn't reach subscribers, so locally the broker is
      open (like dev mode) and the function publishes over MQTT. The
      health check gains `📡 mqtt`.
30. **Create the profile from the Google account at sign-in, then let it
    be edited: no "Create your profile" screen; just signing in should
    be fine.**
    - [API](api.md), [backend](backend.md): `POST /api/session` keeps the
      Google ID token's `name` claim on the session (dev mode: the
      email's part before the @). The first `GET /api/me` creates the
      profile with that name (`Climber` without one) and the rest empty,
      so it never answers `"climber": null`. No new resource: one more
      attribute on the session item and one write per new account, both
      within what DynamoDB on demand already bills (fractions of a cent).
    - [Sign-in](sign-in.md), [screens](screens.md), [matching](matching.md),
      [i18n](i18n.md): the app goes from sign-in straight to the tabs; the
      "Create your profile" step, its welcome line, **Start climbing** and
      its strings are gone. **Edit profile** on the Profile tab fills in
      the rest. A 409 "no profile" now loads the profile again.

## 2026-10-13

31. **(Follow-up to 25: make sign-in work on the iPhone.)** The deployed
    sites didn't exist yet: the site stack refused the API's host name.
    - [Deploy](deploy.md): the API stack's `ApiDomain` output is
      `<id>.execute-api.<region>.amazonaws.com` (it lacked the region),
      the `/api/*` origin the site stack takes as `ApiDomainName`.
32. **Google sign-in on the iPhone opens Google's popup but never enters
    the app.** The API took only tokens issued to the web client, but on
    iOS Google issues the ID token to the app's iOS client, so every
    iPhone sign-in got a 401.
    - [API](api.md), [sign-in](sign-in.md), [backend](backend.md):
      `POST /api/session` also takes tokens issued to the stage's iOS
      clients (template parameter `GoogleIosClientIds`, from the
      repository variables in Deploy and Deploy RC; `scripts/deploy.sh`'s
      optional `GOOGLE_IOS_CLIENT_IDS`), never without a web client.
33. **Make sure logging is available both on the web and the phone, so we
    can fix things; don't show the logs to the user, they're just for
    developers.**
    - [Logging](logging.md) (new): the app's log (`lib/log.dart`) prints
      each line to the platform's log (browser console, device log) and,
      on Android and iOS, appends it to `grigri.log` in the app's storage
      (rotated past 512 KB). Startup, every sign-in step and failure,
      failed API calls, MQTT connection failures and uncaught errors are
      logged, scrubbed of emails and tokens. No screen or button shows
      them.
    - [Development environment](dev-environment.md): `devbox run ios-log`
      (`scripts/ios-log.sh`) copies the log file off the iPhone over USB
      (`--follow`, `--previous`), like `android-log`.
34. **Brazilian Portuguese would be better (than European).** `app_pt.arb`
    is rewritten in Brazilian Portuguese (você; Salvar, Sair, celular,
    Buscar; esportiva, academia, costuras, móveis, pico), and the picker
    calls it "Português (Brasil)" ([i18n](i18n.md)).
35. **Remove the app's dev sign-in (local API); always show Google.**
    - [Sign-in](sign-in.md): the sign-in screen only ever shows **Sign in
      with Google**. The email "Dev sign-in" of local builds without a
      client ID is gone, and so is the "sign-in isn't set up" message: a
      build without `GOOGLE_WEB_CLIENT_ID` shows the button, and signing
      in fails with the sign-in error. The app no longer sends `devUser`.
      The local API's dev mode stays, for scripts and `curl`.
    - [Dev environment](dev-environment.md), `.env.example`: a local
      build needs `GOOGLE_WEB_CLIENT_ID` to sign in.
36. **Take the user's location from the phone or web instead of asking,
    and ask only if it isn't found. Reduce the nav bar's font size, it's
    breaking; use a shorter word than "Notifications", and short words
    on every nav bar item.**
    - [Matching](matching.md), [screens](screens.md): with no location or
      areas on my profile, the app takes my location from the device
      (`geolocator`: GPS or network on phones, the browser's geolocation
      on the web; free) and saves it, named after the nearest place in
      the sector index; the Discover hint asks only when the device
      can't tell. The location picker has **Use my current location**.
      Android asks for coarse location, iOS has a location usage string.
    - [Deploy](deploy.md): the web app's `Permissions-Policy` allows
      `geolocation=(self)` (it denied location); no new resources, no
      added cost.
    - [Screens](screens.md): the nav bar's labels are 11 pt (were 12) and
      short words in every language: Find, Plans, Chats, Alerts, Me,
      Admin in English; a widget test checks they each fit on one line
      on a 360 dp phone.
37. **On Find, make the card a little smaller to fit smaller phones; show
    how many people are with the organizer ("Maria +3"), keeping the list
    of the others collapsed until tapped; remove the distance line; put
    the date and the time on separate lines; after asking to join, don't
    say the organizer will decide, just that you'll get an alert when
    accepted.**
    - [Matching](matching.md), [screens](screens.md): the deck's card is
      compact (less padding, a smaller title, a 20 px avatar; 56 dp swipe
      buttons, tighter margins); the plan shows the date and the time
      range on separate lines (everywhere it's highlighted) and no
      distance (the server's distance still ranks the deck); the
      organizer has **+N**, which shows or hides the rest of the group.
      The snackbar says "Asked to join. You'll get an alert when you're
      accepted."
    - [Languages](i18n.md): the distance and "will decide" strings are
      gone; new: the snackbar and the +N button's tooltips (Show the
      group, Hide the group), in every language.
38. **Make the shade of green of the primary color a little darker.**
    - [Theme](theme.md): olive, the primary, is `#8F9B5D` (was
      `#A3B06A`), about 12% darker; dark text on it (`night`) keeps a
      contrast of about 5.9:1.
39. **Roles aren't shown on the profile page: verify the rbacr integration
    and show the roles on the profile; I must be an admin.**
    - Found: deployed and phone builds had no way to ask rbacr (the app
      only asked with the local dev token, so the card always said "Not
      signed in"), and the repository secret `GRIGRI_RBACR_TOKEN` isn't
      set, so the deployed API can't ask rbacr and nobody is an admin.
    - [Roles](roles.md), [API](api.md): `GET /api/me` returns `roles`, my
      Grigri and global roles, which the API asks rbacr for
      (`POST /api/roles`) with the root token it already uses for admins;
      `null` when rbacr can't say. The app's Roles card shows them, with
      Retry. The app no longer has an rbacr client: the `rbacr` package,
      `lib/data/roles.dart`, the `RBACR_URL`/`RBACR_TOKEN` dart-defines,
      the local rbacr's CORS and the Android `adb reverse` are gone
      ([dev environment](dev-environment.md)). No new resource: one more
      rbacr call per profile load, cached for a minute.
    - Still needed: an rbacr API token owned by a root, as the repository
      secret `GRIGRI_RBACR_TOKEN`, then a deploy.
