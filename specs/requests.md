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
6. **Make the age optional in the profile; don't show it when it's left
   empty.** The profile editor's Age (optional) can be blank. A profile
   without an age shows just the name ("Name" instead of "Name, 30") on
   the decks, profile sheets and Profile.
7. **In the profile: a photo, a description, the climbs; no when or where
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
8. **No Requests tab: the tabs are Discover, Plans, Chats, Notifications
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
9. **A searchable database of climbing sectors, the cheapest way; then in
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
10. **When someone likes the plan but doesn't match yet, call it out at
    the top of the chat, so people know they need to approve or reject
    the new person.**
    - The [group chat](matching.md#join-requests-in-the-group-chat) pins
      a callout under the plan for each request still waiting for my
      answer: avatar, name, how many said yes, and ✕ / ✓ (the same accept
      and decline as the request's card). After I answer, it leaves the
      callout; the card in the messages stays as the record.
11. **Remove the static fake data; everything from the database; GA empty
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
