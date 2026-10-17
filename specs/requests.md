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
40. **In the Find view, add a smaller share button beside the accept and
    reject ones.**
    - [Matching](matching.md), [screens](screens.md): a 44 dp share button
      between ✕ and ✓ (both 56 dp) shares the top plan's discipline,
      place, date and time with a link to the app, through `share_plus`
      (the system's share sheet; on the web the browser's, or an email
      draft). Strings in every language. No cloud change, no cost.
41. **Let events and profiles be marked as "demo"; on those, add a
    disclaimer that this isn't real data, just a demonstration to help you
    see how the system works.**
    - [API](api.md), [backend](backend.md#the-seed): Climber and Plan
      have an optional `demo: true`, stored on the item and returned
      (others' profiles too); only the seed sets it, on all its profiles
      and plans (RC and local; GA is never seeded). The API's input
      ignores it, so nobody marks their own data.
    - [Matching](matching.md): the app shows a disclaimer at the top of a
      demo plan (deck card, plan screen, match screen) and of a demo
      person's profile sheet, and a **Demo** tag after their name; in
      every language. No new resource or cost.
42. **When a demo plan is found and accepted (swiped right), match
    automatically.**
    - [API](api.md), [matching](matching.md): `POST /api/plans/{id}/join`
      on a demo plan saves the request and then accepts it on the group's
      behalf, as an admin's yes does: I join, get the accepted notice,
      and the chat gets the joined note. The app refreshes its
      notifications right after, so the match screen opens (no "you'll
      get an alert" snackbar). Real plans are unchanged.
43. **On Find, make the share button a bit smaller and put it to the right
    of the accept and reject buttons.**
    - [Screens](screens.md), [matching](matching.md): the share button is
      36 dp (was 44) and sits to the right of ✓; a spacer as wide on the
      left keeps ✕ and ✓ centered. A widget test checks both.
44. **On Find, the refresh button reloads the plans, the ones I already
    passed on too: I may have changed my mind.**
    - [API](api.md): `DELETE /api/passes` forgets my passes, except on
      plans I asked to join. [Matching](matching.md),
      [screens](screens.md): Discover's ⟳ calls it, then reloads the deck.
      No new resource; one query and a batch delete per refresh.
45. **In the plans view, let a user cancel a plan. If a user cancels a
    plan, remove it from the view and from the chats, but keep it open for
    the others: they may keep the plan, and automatically select a random
    new person as the organizer.**
    - [Screens](screens.md): each plan I'm in on Plans has a ⋮ menu with
      **Cancel the plan**; the plan screen's button is now always **Cancel
      the plan**. Both use one confirmation (**Keep it** / **Cancel it**)
      that says whether the plan ends (I'm alone) or the others keep it
      and, if I organize it, who organizes now is picked at random. The
      old leave strings went; new ones in every language.
    - [Matching](matching.md), [API](api.md): cancelling is the existing
      `POST /api/plans/{id}/leave`. The organizer leaving now hands the
      plan to a random remaining member (was: the next one), and the chat
      note says who organizes now. The plan leaves my Plans and Chats at
      once and stays out of my deck. No new resource or cost.
    - Refresh on Find never brings back a plan I cancelled: leaving marks
      its pass `left`, which `DELETE /api/passes` keeps; and the new
      organizer comes first in `memberIds`, as the model requires.
46. **Show clearly but discreetly when data is fake (automatically
    generated); generate a few profiles, preferably famous late climbers,
    owning a few plans, so users can see how the app works while there
    are few events.** Decided with the user: fictional names that nod to
    the legends (nobody real is portrayed), and on GA too.
    - [Backend](backend.md#the-demo-showcase): the demo showcase, six
      fictional climbers each organizing a plan at a well-known crag, on
      every stage including production, marked demo; the API re-dates it
      before a deck when it's over 12 hours old (no new resource; under a
      cent a month). RC and local keep their test seed too.
    - [Matching](matching.md): the demo notice is one discreet italic line,
      "Demo: automatically generated, not real people or plans. It's here
      to show how Grigri works.", in every language.
    - [API](api.md), [deploy](deploy.md), [README](README.md): GA no
      longer "starts empty".
47. **Add a nudge button to send a notification to all members of the plan
    to either accept or reject the given membership.**
    - [API](api.md): `POST /api/plans/{id}/nudge`, for the requester of an
      open request: a new Notice kind `nudge` ("they're still waiting for
      your answer", `climberId` the requester) for each member who hasn't
      said yes, and a `notice` [hint](live-updates.md) to them. At most
      once every 12 hours per request: the request keeps `nudgedAt`
      (written with a conditional update, so racing nudges can't both
      pass) and an earlier nudge gets **429**. 404 without a request; 409
      when declined, already in, or the plan has started. A new nudge
      replaces the last one's notice (stable id
      `<planId>/nudge/<climberId>`), unread again.
    - [Matching](matching.md), [screens](screens.md): Plans' pending
      requests have **Nudge** (then **Nudged**, disabled, for 12 hours;
      none on a declined request or a started plan) and a snackbar "Nudge
      sent to <names>"; members see "<name> is waiting for your answer" in
      Notifications, counted in the badge, opening the group chat. Older
      apps skip the unknown notice kind. Strings in every language.
    - Cost: no new resource. A nudge is one plan-and-requests read, one
      conditional write, one notice write and one IoT hint per waiting
      member (fractions of a cent per thousand), and the 12-hour limit
      caps it at two per request per day.
48. **In the chat, make sure that users can add images and put those on
    S3, videos as well, but not other files.**
    - [Matching](matching.md#group-chat), [screens](screens.md): a chat
      message can carry one photo or one video, with or without text.
      The composer's attach button offers only photos and videos (take
      or choose a photo, record or choose a video); the picked one shows
      above the box with its size, then "Uploading…" with a progress bar.
      Photos show inline (tap for full screen), videos as a poster that
      plays full screen with `video_player`. Other files are refused in
      the app (by their bytes) and by the API (by content type). Strings
      in every language; iOS asks for the microphone too, for recorded
      videos ([platforms](platforms.md)).
    - [API](api.md): `POST /api/plans/{id}/media` (members only) issues a
      presigned POST for `image/jpeg|png|webp` (≤ 2 MB) or
      `video/mp4|quicktime` (≤ 50 MB), key `chat/<planId>/<random>.<ext>`,
      tagged pending. `POST /api/plans/{id}/messages` takes
      `{"text"?, "attachment"?}`; the attachment must be this plan's and
      uploaded, and loses its pending tag. Messages return
      `attachment: {key, kind}`. Presigned POSTs now last 15 minutes.
    - [Backend](backend.md#chat-media): same photos bucket (under
      `photos/chat/`), same CloudFront `/photos/*` behavior, served
      public-by-unguessable-key like profile photos. One new lifecycle
      rule (also in Floci) expires chat media 400 days after upload.
      Cost: storage at $0.023/GB-month (about $0.80/month at steady state
      for 100 plans a month with a video each, $8 for 1,000), transfer
      within CloudFront's free 1 TB; nothing while idle.

## 2026-10-14

49. **Tag every AWS resource with the cost-allocation tags `project` and
    `tenancy`, so Cost Explorer can split the bill by product and stage.**
    - [Deploy](deploy.md): `scripts/deploy.sh` deploys both stacks with
      the stack tags `project=grigri` and `tenancy=GA` (`RC` for
      `STAGE=rc`). The administrator deploys `grigri-github-deploy` with
      `tenancy=shared` and tags the `grigri.nu01.com` zone the same way
      ([grigri_infra/README.md](../grigri_infra/README.md)).
    - The deploy roles may add `project` and `tenancy` to their stage's
      distribution and certificate (tagged changes there were scoped to
      requests carrying `grigri:stage`). No new resource or cost.
50. **Replace the site's Route 53 health checks with the central
    nu01-monitor, to cut their cost.** Route 53 health checks bill per
    check, more for HTTPS and string matching; one shared monitor for all
    nu01 projects (the `nu01-monitor` stack, nu01 repo) checks every 5
    minutes instead.
    - [Deploy](deploy.md): `grigri_infra/site.yaml` drops both health
      checks (`/app/version.json`, `/api/health`), their alarms, the SNS
      health topic and its email subscriptions, the
      `HealthNotificationEmails` parameter and the health outputs (and the
      `AWS::LanguageExtensions` transform, used only for the subscriptions);
      the next deploy of each stage deletes them. The endpoints stay.
    - `scripts/deploy.sh`, the Deploy and Deploy RC workflows and
      `.env.example` no longer take `GRIGRI_HEALTH_EMAILS`; the repository
      secret is unused and can be deleted.
    - The deploy roles keep their health check, alarm and topic
      permissions until the next GA and RC deploys have deleted them.
51. **The cost-tagged site deploy failed on CloudFront Functions.**
    - The RC site deploy rolled back: the deploy role may not
      `cloudfront:TagResource` the stage's CloudFront Functions
      (`<prefix>-web-app-index`, ...), which do take tags, so the new
      `project`/`tenancy` stack tags couldn't reach them.
    - The `CloudFrontFunctions` statement in `grigri_infra/github-deploy.yaml`
      also allows `cloudfront:TagResource`/`UntagResource` on the stage's
      own functions (`function/<prefix>-*`).

## 2026-10-16

52. **Score how likely a climber and a plan end in a match, with aityx
    (System One), and show it to admins; score every profile against
    every plan into a table, previewed on the Admin tab.**
    - [Match scores](match-scores.md) (new): the decision model
      (`grigri_api/src/match/model.json`), the facts the API sends, the
      score, level and reason it answers.
    - [API](api.md): `GET /api/discover` carries `scores` for admins
      (the best 30 plans, live); new `GET /api/admin/scores`.
    - A separate scoring function (`<stack>-scorer`) and table
      (`<stack>-scores`), run by hand with `scripts/score-matches.sh`;
      profiles join a new gsi1 `CLIMBERS` partition when saved, and
      `scripts/index-climbers.sh` adds the older ones once per stage.
    - [Screens](screens.md): the Discover card shows an admin the score
      and its reason; the Admin tab opens with the latest run's best
      scores.
    - [Deploy](deploy.md): the `GRIGRI_AITYX_API_KEY` secret (optional;
      no key, no scores) and the `GRIGRI_AITYX_URL` variable.
    - [docs/match-scores.md](../docs/match-scores.md) (new, and the new
      docs/ folder): how it works, with references to the key code.
    - Cost: about $0.00007 of aityx credits per score; nothing while
      idle ([backend](backend.md#cost)).

53. **Plenty of demo plans in Siurana and Margalef; a shorter demo
    disclaimer.**
    - [Backend](backend.md#the-demo-showcase): the showcase grows to
      eleven climbers and twenty plans, seven in Siurana (El Pati, L'Olla,
      Can Piqué, La Siuranella, El Mirador, Grau dels Masets, Ca la
      Isabel) and seven in Margalef (sport sectors and boulders), one to
      seven days ahead. A `SHOWCASE_VERSION` on the showcase's marker
      makes every stage rewrite it on the first deck after a deploy.
    - [Matching](matching.md#data-the-backend-api): the demo line reads
      "Demo: made-up people and plans." (in every language).
54. **Make the distance from me to a plan a strong weight in scoring.**
    - [API](api.md#the-decks-ranking): the deck ranks by fit + 2 ×
      nearness (`NEAR_WEIGHT` in `rules.ts`), so nearby plans come before
      far ones even a few grades off; a plan next door I don't climb now
      comes before one in my grades 50 km away.
    - [Match scores](match-scores.md#the-model): model v2,
      match_likelihood = grade_fit × (0.2 + 0.8 × nearness) × group_odds
      × timing (was 0.5 + 0.5 ×). No cost change.
55. **Let me set my location on the profile screen, defaulting to where
    I am.**
    - [Screens](screens.md): the Profile tab has a **Where you climb**
      card: my location (a spinner while it's being detected), tap to
      pick a place or my current location, saved at once.
    - [Matching](matching.md#profiles-and-plans-are-separate): the app
      takes my location from the device whenever my profile has none,
      even when I have areas (before, areas alone stopped it).
56. **Our own version of theCrag's API, photo lookup only: photos in S3,
    with their metadata queried in S3 as cheaply as possible, in a bucket
    apart from user data, seeded with the crags around Siurana and
    Margalef (ideally 5 photos each), shown on the plan; members upload
    and delete plan photos, and chat photos join them. Two sets, apart:
    "Your Pics" and "GriGri Pics".**
    - [Plan photos](pics.md) (new): Your Pics (members' uploads and chat
      photos; delete by whoever added it, the organizer or an admin) and
      GriGri Pics (Grigri's own photos, credited, looked up by the plan's
      sector, point, place and area).
    - GriGri Pics in a new bucket in the site stack
      (`<site stack>-pics-<account>`), served at `/pics/*`; each photo's
      metadata is an S3 annotation, and a catalog made from them is what
      the API reads (once per warm function). S3 Select, asked for first,
      is closed to new accounts (`MethodNotAllowed` here); annotations
      can be queried only through annotation tables and Athena (up to an
      hour behind, seconds per query, billed per query), so the catalog
      is the cheap lookup.
    - The data ([grigri_api/pics/crags.json](../grigri_api/pics/crags.json)):
      10 freely licensed Wikimedia Commons photos, 5 of Siurana and 5 of
      Margalef as areas; no photo could be tied reliably to a single
      OpenStreetMap crag, so the 11 Margalef crags have none yet. Loaded
      by `grigri_api/pics/load.mjs` on every deploy and, locally, by the
      new `6-pics` process.
    - [API](api.md): `GET /api/plans/{id}/pics`, `POST
      /api/plans/{id}/pics/upload`, `POST /api/plans/{id}/pics`, `DELETE
      /api/plans/{id}/pics/{picId}`, `GET /api/pics`; a photo sent in the
      chat joins the plan's pics; a `pics` hint.
    - Plan photos live in the photos bucket under `photos/plans/`, with a
      400-day lifecycle rule like chat media's; the function's role (and
      the stages' permissions boundary) may read GriGri Pics' catalog.
    - [Screens](screens.md): the plan screen's Your Pics and GriGri Pics.
    - Cost: ~$0.0002/month of storage for GriGri Pics, a GET per cold
      start; Your Pics cost as chat photos do ([pics.md](pics.md#cost)).
57. **A little smaller text on Discover; plan notes and bios cut to
    about three lines, with "…".**
    - [Matching](matching.md#the-deck): the swipe card's text is 10%
      smaller than the app's (on top of the system's text size); the
      plan's notes and the organizer's bio stop at three lines, ending in
      "…" when cut. The plan screen and the profile sheet show them whole.
58. **Remove every feature from the Admin tab and start it over: for
    now, just a list of people with the option to block or unblock.**
    - [Admin](admin.md) (new): the tab lists everyone by name
      (`GET /api/admin/climbers`), with **Block** (after a confirmation)
      and **Unblock** (`POST /api/admin/climbers/{id}/block`,
      `…/unblock`); never on my own row (the API refuses it too). A
      blocked climber gets 403 `blocked` from every route but signing
      out, sees only "Your account is blocked" in the app (Sign out, Try
      again), and their plans leave everyone's Discover. A profile save
      can't clear a block.
    - Removed: the Admin tab's match scores preview
      (`GET /api/admin/scores`, and the API's read access to the scores
      table) and its open join requests to approve or reject
      (`GET /api/admin/requests`, `POST /api/admin/requests/…/accept`,
      `…/reject`), with their texts in every language. Admins' deck
      scores and the scoring run stay ([match scores](match-scores.md)).
    - [API](api.md), [Screens](screens.md), [Sign-in](sign-in.md),
      [Backend](backend.md), [Matching](matching.md),
      [Live updates](live-updates.md), [Roles](roles.md) and
      [docs/match-scores.md](../docs/match-scores.md) revised to match.
    - Cost: nothing new to run; the list is one index query, a block one
      write.
59. **The nav icons were missing labels.** With the Admin tab (six
    tabs), the bar showed only the selected tab's label.
    - [Screens](screens.md): every tab always shows its label; the short
      11 pt labels fit six tabs on a 360 dp phone.

60. **Premium users pay $20 a month or $200 a year; premium is for
    advertisement only.** Spec only for now, nothing built.
    - [Premium](premium.md) (new): the prices, that premium changes only
      advertisement (every feature stays for everyone), and the open
      questions: what advertisement covers, how it's paid, other
      currencies.

61. **No GriGri Pics with watermarks or people's names.**
    - Two Margalef photos are out of
      [crags.json](../grigri_api/pics/crags.json): one with a watermark
      whose caption named the climber, and one whose file is titled with
      a first name. Margalef keeps 3; Commons has no other free photo of
      its cliffs without a name or a watermark, so none replace them.
    - [Plan photos](pics.md): the rule, and 8 photos (5 Siurana, 3
      Margalef). The next deploy's loader deletes the two from the
      bucket and the catalog.
62. **Make the home screen look nicer, after popular apps' home screens
    (Strava, Tinder), using the pictures.**
    - [Screens](screens.md): the Discover card is a dating-app-style
      card: the crag's photo edge to edge (or a backdrop in the
      discipline's colors), the plan over it in white on a dark fade
      (the place large and bold, area, date and time, grades, Your
      grades, the photo's credit), and below, always in view, the
      organizer with the group's avatars and +N; notes and profile on
      scrolling. Still no distance, date and time apart, notes cut to
      three lines (request 37). The ✕ and ✓ buttons are raised, ✓
      bigger.
    - [API](api.md), [Pics](pics.md#on-the-deck): `GET /api/discover`
      gives each plan's cover, its best GriGri Pics photo with credit.
    - Cost: none new; the covers come from the catalog the function
      already keeps, and the photos are served by the site's CloudFront.
63. **Just like presence and tabscan, make sure our APIs can be used only
    by our client.**
    - Presence's mechanism, since tabscan's APIs have none: the
      [origin check](origin-check.md) (new). The site's CloudFront sends
      the API a secret header (`x-grigri-origin-verify`), and the API
      function refuses a request without it (403 `use the site`), so the
      API answers only through `https://grigri.nu01.com/api/...` (or the
      RC site), never at its `execute-api` host. No client holds the
      secret, and the app is unchanged.
    - [Deploy](deploy.md): the secret is `GRIGRI_ORIGIN_SECRET` or derived
      per stage from `GRIGRI_RBACR_TOKEN` (no new CI secret). The API
      demands it only once the site already sends it (two deploys to turn
      it on), and the smoke test checks that a direct call gets 403.
      Local is unchanged (no secret).
    - [API](api.md): the 403 and where it comes from.
    - Limits, as in presence: a script calling through the site with a
      session token from a real Google sign-in looks like the app. Only
      attestation (Play Integrity, App Attest) could tell them apart, and
      that isn't done.
    - Cost: none.
64. **GriGri Pics by crag, not by whole region.**
    - [crags.json](../grigri_api/pics/crags.json) now lists every named
      OpenStreetMap crag and climbing sector (`sport=climbing` too, not
      only `climbing=crag`) around Siurana and Margalef: 45, with
      Racó de la Finestra.
    - Photos were searched per crag (by name, by Commons' geosearch
      around each crag, and on Flickr through Openverse) and placed on a
      crag only when they reliably show it: Racó de la Finestra has its
      own. The rest stay with their area, now 12 for Siurana and 6 for
      Margalef (6 new from Flickr, CC BY and CC BY-SA). 19 photos in all,
      every one without a watermark or a person's name; one more Margalef
      photo is out (its description named a climber).
    - [Plan photos](pics.md): how photos are placed, and the counts.

65. **Let people subscribe to Premium in their profile, with real
    payments.** (First half of the request for ads; the ads come in the
    next entry.)
    - [Premium](premium.md) rewritten as built: Stripe Checkout from the
      profile's **Grigri Premium** card, the billing portal to manage it,
      Stripe's webhook (signed) keeping each subscription in step; active
      while paid (or retrying) to the period's end plus two days.
    - [API](api.md): `GET /api/premium`, `POST /api/premium/checkout`,
      `POST /api/premium/portal`, `POST /api/stripe/webhook`; `GET
      /api/me` carries `premium`.
    - [Deploy](deploy.md): Stripe's keys as secrets (live for GA, test
      for RC), `StripeSecretKey`, `StripeWebhookSecret` and `SiteUrl` on
      the API stack. The web app gets `premium.html`, where Stripe sends
      people back. The app opens links with `url_launcher`.
    - Cost: no new AWS resource and nothing idle; Stripe's 2.9% + $0.30
      plus 0.7% per payment ([backend](backend.md#cost)).

66. **Ads: Premium users submit ads in a new Ads tab; admins approve or
    reject them in an Admin sub-nav and set their rate; ads show like
    plans, with an image or video, text over it, and a link that opens in
    the browser when accepted.**
    - [Ads](ads.md) (new): the ad (link, text, photo or video), the Ads
      tab and its editor with a preview, the deck (one ad after every *n*
      plans swiped; ✓ opens the link with `url_launcher`, ✕ skips),
      Admin → Ads, the routes, data and cost.
    - [Admin](admin.md): a sub-navigation, **Users** and **Ads**.
    - [Screens](screens.md), [Matching](matching.md), [API](api.md),
      [Premium](premium.md), [Backend](backend.md#cost) revised to match;
      the bar has up to seven tabs.
    - Cost: nothing idle; a couple of reads per deck.

67. **A premium-only camera view: the routes on the rock drawn bolt by
    bolt, labeled with their grade, so climbers see which route is
    which; climbers record and annotate new routes, and the app learns
    them.**
    - [Route finder](route-finder.md) (new): walls (reference photos and
      the routes drawn on the first), recognized on the phone by matching
      the camera's frames to the views (FAST corners, upright BRIEF,
      RANSAC homography, in plain Dart, in a background isolate); the
      routes drawn over the rock with their grade and name; recording a
      route bolt by bolt on a photo (new rock becomes a wall); learning a
      wall from each confirmed view (12 at most). The web finds routes on
      a photo.
    - [Premium](premium.md): the route finder is Premium's first feature
      besides ads (an active subscription, or an admin; checked by the
      API on every `/api/walls` route).
    - [API](api.md): `/api/walls` (lookup, photo upload, create, routes,
      views), premium only; walls in the table's gsi1 `WALLS` partition,
      views in the photos bucket under `photos/walls/`.
    - [Screens](screens.md): **Routes on the rock** on the plan screen.
    - The site's `Permissions-Policy` allows the camera to the app
      (`camera=(self)`); the iOS camera prompt mentions routes.
    - Cost: nothing per frame (on the phone); ~$0.0001 a wall a month
      ([backend](backend.md#cost)).
68. **Let all roles be stored and managed in rbacr; sync when paid; add
    to rbacr's APIs as needed.**
    - [Roles](roles.md): every role is rbacr's: `admin`, `premium`
      (granted by the Stripe webhook until the paid period's end plus
      grace, revoked when it ends; admins hold it through rbacr's
      implication) and `blocked` (the Admin tab's Block/Unblock); the RC
      has its own `premium-rc` and `blocked-rc` (it shares production's
      rbacr). Premium no longer comes from Grigri's subscription copy,
      which stays for billing only; the profile's `blocked` flag is gone.
    - `scripts/rbacr-setup.sh` (new) sets up the `grigri` system's roles
      and implications, idempotently, on every deploy and locally
      (`7-rbacr-setup`).
    - The API keeps each climber's verified email privately
      (`CLIMBER#<id>` / `EMAIL`), to ask rbacr about people other than
      the caller; checkout sends the email to Stripe with the
      subscription.
    - rbacr: no API change was needed (grants with an end, revokes,
      implications and the grants listing were there). The TypeScript
      client library (`rbacr-lib`) isn't written yet; Grigri's API keeps
      its own small client (`grigri_api/src/rbacr.ts`), now with grants.
    - Nobody was Premium, blocked or advertising on either stage, so
      nothing moved.
69. **Barrel roll: commit what was pending.**
    - `.env.example` documents the Google Cloud project's OAuth clients
      and `GOOGLE_ANDROID_CLIENT_ID_GA` (reference only: Android matches
      the client by package name and signing SHA-1).
    - The iOS Swift Package Manager pins Xcode wrote
      (`Package.resolved`, both workspaces) are committed, so builds
      resolve the same package versions.
70. **Do it all: write rbacr's TypeScript client library and use it.**
    - rbacr: `rbacr-lib` specified (its README) and built: a
      dependency-free client for `/api` (checks and role lists kept
      briefly, fail-closed helpers, and for roots grants with a validity,
      revokes, the grants listing and a role's holders), with unit and
      end-to-end tests, CI, and releases as GitHub release tarballs
      (0.1.0; 0.1.1 also takes plain http for `*.localhost` and
      `host.docker.internal`, which the local API in Docker uses).
    - [Roles](roles.md): Grigri's API calls rbacr through rbacr-lib
      (`grigri_api/src/rbacr.ts` wraps it); rbacr not knowing the
      `grigri` system is no longer kept as "no" for a minute.
71. **When creating a plan, let users search a crag by name, sorted by
    distance first.**
    - [Sectors](sectors.md): the search takes where I am (my location,
      else my first area) and sorts matches nearest first, places
      without a point last; with nothing typed it offers the nearest.
    - [Screens](screens.md): the plan editor's **Where** shows each
      suggestion's distance ("· 0.7 km").
72. **People match with a plan, not a partner: the title is "Find a
    climbing plan", and partners, when worth saying, are always plural;
    note it in CLAUDE.md and memory.**
    - The sign-in tagline, in all six languages: "Find a climbing plan:
      make one, or swipe right on one, and climb together." The web
      app's description (page, manifest, pubspec): "Grigri: find a
      climbing plan".
    - The match model's reasons no longer call a climber "a partner".
    - The rule: CLAUDE.md ("Wording: plans, not partners") and the
      product section of [README.md](README.md).

## 2026-10-17

72. **Let plans have multiple days: besides the start date, expected to
    be filled but not required, let the user add more dates, as wanted.**
    - [Matching](matching.md), [API](api.md#json-shapes): a plan's start
      and end are now optional (an **undated** plan, "Date to be
      decided": it can always be joined, ranks after dated plans and
      shows no hours), and a plan takes `moreDays`, up to 13 more days
      after the first (two weeks in all), each its own start–end. The
      API validates them like the first day; an edit that leaves days
      out clears them. Undated plans sort after every date in the
      by-start index (`~` for the date), so the deck still reads one
      index.
    - [Screens](screens.md): the editor's start date
      (still the next Saturday for a new plan) has ✕ to leave it open,
      **Add a day** adds more days as removable chips, and the hours
      apply to every day. Cards and lists show "Sat 17 Oct +2 days";
      the plan's screen lists every day.
    - [Match scores](match-scores.md): an undated plan counts as 30 days
      away, and its scores expire a month after the run.
    - The demo showcase's Frankenjura plan is now two days (showcase
      version 3), so the feature shows on every stage.
    - Cost: none added; the extra days are a few bytes on the plan's
      item.

73. **Make the index page like popular apps (Tinder, Airbnb, Strava): a
    nice page that gets people to sign in, clear that the app is free,
    with photos of crags near the visitor when their location is
    available.**
    - [Landing page](landing.md), new: `/` is no longer only a redirect.
      It has a full-photo hero with a swiping demo card, "100% free" and
      Sign in with Google, a row of GriGri Pics photo cards sorted nearest
      first (the location is used in the browser only), how it works, and
      what's free. It's in the app's six languages. Signed-in climbers and
      links with a query string still go straight to `/app/`.
    - [Plan photos](pics.md): CloudFront may read `pics/catalog.json` too,
      which the page reads. The loader now gives it a cache time of one
      hour instead of `no-cache`.
    - [Deploy](deploy.md): the index CSP allows the page's own script,
      style and fetches (`'self'`, no inline code), and allows location for
      the page itself. The smoke test checks for the landing page.
74. **Add plan types: "open", which anyone can join; "guided", which is
    expected to be paid; and "private", the default, like now, where a
    newcomer must be accepted.**
    - [Matching](matching.md): new section, plan types. Each type has
      its deciders: every member (private), nobody (open: a swipe right
      joins at once) or the organizer alone (guided). A guided plan has a
      price per climber (EUR, USD, GBP, CHF or BRL), paid to the guide,
      not through Grigri. Changing a plan's type lets in whoever now has
      enough yeses.
    - [API](api.md): `type` and `price` on Plan; join, accept, reject,
      requests to review and nudges follow the deciders; plans without a
      type are private.
    - [Screens](screens.md): **Who can join** in the plan editor (with
      the price for guided plans); the deck's card and the plan show
      "Open: join at once" or "Guided · €60"; only deciders get Accept
      and Decline (other members of a guided plan see "The guide
      decides").
    - [Backend](backend.md): the seed's Montserrat plan is guided and
      the after-work gym plan is open.

75. **Still seeing the old login page locally, though it was replaced by
    a more modern one: rebuild, restart, and make sure the new page is on
    every platform, the web included.**
    - [Sign-in](sign-in.md): the app's sign-in screen (at `/app/`, and on
      Android and iOS, where the landing page never showed) now has the
      landing page's look: a GriGri Pics photo edge to edge, "100% free",
      **Find a climbing plan.**, Google's sign-in, the swiping demo card,
      how it works, what's free and a last call, in the six languages.
      The app reads GriGri Pics' catalog (`/pics/catalog.json`, no
      token) for the photos.
    - [Landing page](landing.md): the headline and the last call follow
      "Find a climbing plan" (they said "partner"), in every language, as
      do the page's title and description.
    - Cost: none added. The catalog and photos are files CloudFront
      already serves from its cache.

76. **The swiping animation shows a single plan (Margalef): add two
    more, at other crags.**
    - [Landing page](landing.md) and [sign-in](sign-in.md): the demo card
      cycles through three made-up plans (different days, styles and
      climbers), each at a different crag from GriGri Pics' catalog, in
      the six languages. On the landing page the next plan comes in
      while the card is off screen, at the end of each animation loop.

77. **Verify the app is ready for the Apple App Store, and help ship it.**
    - [App Store](app-store.md), new: the submission's spec and
      checklist: what the repo does, what other pull requests are adding
      (Sign in with Apple, account deletion, report and block, Apple
      in-app purchase for Premium), and what the owner does by hand (the
      paid membership, the distribution certificate, the App Store
      Connect record, App Privacy and age rating answers, category, URLs,
      screenshots, draft store copy, review notes and a demo account,
      building and uploading, TestFlight first).
    - [Platforms](platforms.md): iOS is iPhone only
      (`TARGETED_DEVICE_FAMILY = 1`, no iPad orientations),
      `ITSAppUsesNonExemptEncryption` is false, and the app bundles a
      privacy manifest (`PrivacyInfo.xcprivacy`: no tracking; name,
      email, user ID, coarse location, photos and videos, messages,
      other user content and purchases, all linked, for app
      functionality; `UserDefaults` with reason CA92.1).
    - [Landing page](landing.md): new `/privacy.html` and
      `/support.html` (English, dated 2026-10-17, in the page's look),
      linked from the footer in all six languages.
    - [Screens](screens.md): **Privacy policy** and **Support** at the
      end of Profile open those pages in the browser.
    - [Release builds](release.md): `make ipa` builds the signed archive
      for App Store Connect. Apple allows a version and a build number of
      up to three integers in 18 characters (TN2420); Grigri's
      (`0.1.YYYYMMDDHHMM`, 16, and Unix seconds, 10) fit, so iOS keeps
      the same version, and iOS builds now refuse one that doesn't.
    - Cost: none in AWS (two small static pages in the site bucket,
      served from CloudFront's cache). The App Store itself needs the
      Apple Developer Program, $99 a year.

78. **Delete my account from inside the app (App Store guideline
    5.1.1(v)).**
    - [Sign-in](sign-in.md#deleting-my-account), new section: **Delete
      account** at the end of the Profile tab, with a confirmation that
      says what's deleted and a box to tick; then `DELETE /api/me`
      `{"confirm": true}`, and the app is signed out and back on the
      sign-in screen. The API cancels a Stripe subscription at once (no
      refund of the period paid) and revokes rbacr's Premium role, runs
      the `onDeleteAccount` hook (for Sign in with Apple's token
      revocation), removes my messages, their media, my request notes
      and my Your Pics photos, leaves every plan through the leave rules
      (handed over, or ended; the note says "A climber left the plan"),
      withdraws my requests, and deletes my ads, photos, every item keyed
      to me, the sign-in link and every session. Each step can run
      again, so a retry finishes the job.
    - [API](api.md): the route; Stripe's events about a deleted
      account's subscription are ignored.
    - [Screens](screens.md), [Premium](premium.md), [Admin](admin.md),
      [Backend](backend.md), [Plan photos](pics.md): the button, the
      immediate cancellation (a restricted Stripe key now needs write
      access to Subscriptions), blocked climbers may delete their
      account, and photos go with it.
    - Cost: no new resource; a deletion is a few dozen DynamoDB reads
      and writes, free S3 deletes and one or two free Stripe calls.

79. **Google sign-in on the local site failed with "Error 400:
    origin_mismatch" (origin `https://local.grigri.nu01.com:2543`): fix
    the authentication for Google and Apple.**
    - [Sign-in](sign-in.md), [dev environment](dev-environment.md): the
      local site was built with the RC's web client, whose only origin is
      the RC site. The local web app and the local API now use the local
      web client, `GOOGLE_WEB_CLIENT_ID_LOCAL` in `.env` (else
      `GOOGLE_WEB_CLIENT_ID`), whose JavaScript origins in Google Cloud
      now include `https://local.grigri.nu01.com:2543` (with its port:
      Google matches it).
    - Cost: none. OAuth clients are free.


80. **In the nav bar, Me should always be the last tab, on the right; for
    admins after Ads and Admin.**
    - [Screens](screens.md), [ads](ads.md#the-ads-tab): the bottom bar is
      now Discover, Plans, Chats, Alerts, then Ads (Premium) and Admin
      (admins), and Me always last.
    - Cost: none.

81. **Remove the "You don't climb this discipline" pill.**
    - [Match scores](match-scores.md#on-an-admins-deck): an admin's deck
      card no longer shows the reason pill when the reason is that I
      don't climb the plan's discipline; other reasons still show.
    - Cost: none.

82. **In the profile view, let the discipline selection be a separate item
    from the grading system; show examples on the grading system.**
    - [Screens](screens.md): the profile editor has a **Grade system**
      section of its own (heading and hint in all six languages) before
      **What you climb**, which now holds only the disciplines and their
      grade ranges. Each option of the switch shows the same route and
      boulder grade written its way: 🧗 6a 🪨 7A (European), 🧗 5.10b 🪨 V6
      (American). The plan editor's switch is unchanged.
    - Cost: none.
