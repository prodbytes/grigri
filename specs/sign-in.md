# Sign-in

People sign in with **Google** or **Sign in with Apple**, on every
platform (Android, iOS and the web) and every stage (local, RC, GA).
Apple's is required on iOS (App Store guideline 4.8: an app that signs in with Google
must also offer an option that asks only for name and email, lets people
hide their email, and doesn't track them for ads; Apple's does). Then
they stay signed in with the API's own **session**: the ID token is used
once, to start it.

- After signing in (Google's button on the web, the app's on Android and
  iOS; Apple's sheet on iOS, Apple's page in a popup on the web or a
  Custom Tab on Android), the app calls `POST /api/session` with
  `{"idToken"}` (Google) or `{"appleIdToken", "nonce", "authorizationCode",
  "name"}` (Apple). The API checks the token ([below](#token-checks);
  [api.md](api.md#sessions)) and answers a session token.
- The app keeps the session token on the device and sends
  `Authorization: Bearer <session token>` on every API call. It doesn't
  ask Google or Apple again until the API says 401 or the person signs
  out.
- A session lasts **until sign-out, or 365 days without use**. It slides:
  each day it's used pushes the 365 days forward; there's no absolute
  limit.
- The same session token opens the app's [live updates](live-updates.md)
  connection, checked by the MQTT broker's authorizer, which refuses an
  ended session and drops a connection within the hour of its sign-out.
- The app never logs a token; its [log](logging.md) scrubs emails, ID
  tokens (any JWT, Apple's too) and bearer tokens from every line, and
  the request bodies that carry them (and Apple's authorization code)
  are never logged. The only URL that carries one is the live updates'
  WebSocket URL (browsers can't set headers on a WebSocket), to AWS IoT
  Core over TLS; it's never logged or shown, and API calls never put a
  token in a URL.
- A Google account and an Apple ID are **different accounts**, even with
  the same email: each has its own subject (`https://accounts.google.com#<sub>`
  or `apple#<sub>`) and profile. There's no linking.

## Where the session is kept

Behind a small interface (`SessionStorage`,
[session_storage.dart](../grigri_app/lib/data/session_storage.dart);
tests use an in-memory one):

| | Android | iOS | Web |
|---|---|---|---|
| Storage | flutter_secure_storage: encrypted with a Keystore key | flutter_secure_storage: the Keychain, readable after first unlock, this device only (never synced or restored elsewhere) | the site's local storage (shared_preferences) |

On the web, any script running on the page could read local storage, so
an XSS bug could steal a session (until it's signed out everywhere, or
unused for a year). The site's strict CSP (scripts only from the site, Flutter's
CanvasKit, Google Identity Services and Apple's sign-in JS) is what guards it.

## The flow

1. **Start**: with a kept session the app goes straight to step 2, with
   no Google or Apple round-trip. Without one, the **sign-in screen**
   ([sign_in_screen.dart](../grigri_app/lib/ui/sign_in_screen.dart)):
   the [landing page](landing.md)'s look on every platform. A GriGri
   Pics photo edge to edge (the first photo in the catalog, credited
   under it), the logo, the headline **Join a climbing plan.**, the
   tagline and the sign-in buttons (Google's first, then Sign in with
   Apple), with a demo plan card
   that swipes right on a loop, bringing in the landing page's three
   made-up plans in turn, each at another crag (still, on the first,
   when the device asks for less motion). Below: how it works, what's free, and a last call, **Join free
   with Google**, which signs in (on the web it scrolls back up to
   Google's button, the only one that can). The photos come from GriGri
   Pics' catalog, `<site>/pics/catalog.json`, a static file read without
   a token. When it can't be read, the screen shows no photos and works
   the same. (Without a kept
   session, the app also tries google_sign_in's lightweight
   authentication at start, and starts a session if Google answers.)
2. `GET /api/me`: my profile, and whether I'm an admin. The first time,
   the API creates the profile from my account: its name (as the session
   kept it: Google's `name` claim, or the name Apple gave the app), the
   rest empty. Without a name (Apple gives it only at the first sign-in
   to the app, and the person may leave it out), the profile starts as
   "Climber", which they change with **Edit profile**. No step to fill it
   in: signing in is enough.
3. The tabs. I fill in the rest (photo, age, about, grades, gear, where I
   climb) when I like, with **Edit profile** on the Profile tab.

## The sign-in screen

- **Sign in with Google**: the app's button on Android and iOS (a filled
  button), Google's own on the web.
- **Sign in with Apple**, on every platform, below Google's and as
  prominent: as wide, 50 tall, with rounded ends, in Apple's white style
  (the Apple logo and Apple's wording in black on white, the app's own
  button, not sign_in_with_apple's `SignInWithAppleButton`, whose text
  is 43% of its height and broke onto two lines). The label is 16 px,
  on one line, shrunk to fit a narrow screen, in the app's language ("Sign in with Apple",
  "Iniciar sesión con Apple", "Mit Apple anmelden", "Se connecter avec
  Apple", "Iniciar sessão com a Apple", "Inicia la sessió amb Apple").
- Both are disabled while a sign-in is under way.
- Cancelling Apple's sheet (or closing its popup or Custom Tab) is quiet: no error. A failure says "Couldn't
  sign in with Apple. Try again." (Google's: "Couldn't sign in with
  Google. Try again."); the API refusing the token: "Couldn't sign in.
  Try again."

## Deleting my account

App Store guideline 5.1.1(v): an app that makes accounts lets people
delete them from inside it.

- **Delete account**, at the end of the Profile tab (in clay, the
  theme's warning color), opens a confirmation that says what goes: my
  profile and photos, my messages and photos in group chats, my join
  requests and ads; I leave all my plans (someone else takes over the
  ones I organize; one with only me ends); Premium paid by card is
  cancelled at once, with no refund of the time left; a subscription
  bought through Apple must be cancelled in the iPhone's Settings; I'm
  signed out on every device. **Delete for good** works only once
  "I understand this can't be undone" is ticked; **Cancel** keeps the
  account.
- Confirmed, the app calls `DELETE /api/me` with `{"confirm": true}`.
  Done, the API has ended every session of mine, so the app forgets
  its own and goes back to the sign-in screen. If it fails, the app says
  "Couldn't delete your account. Try again." and stays signed in; trying
  again finishes the job.
- Only ever my own account: the route takes no id, the account is the
  session's. It's a session route, so a [blocked](admin.md#blocking)
  climber can delete theirs too (rbacr's block stays on their email).

What the API does, in this order. Every step can run again, so a retry
after a failure picks up where it stopped; the account's link to its
climber and its sessions go last, so a retry still gets in.

1. **Premium**: a [Stripe](premium.md) subscription that isn't cancelled
   yet is cancelled **at once** (no more charges, no refund of the period
   paid; Stripe keeps its invoices, as tax records require), and rbacr's
   `premium` role is revoked. If Stripe or rbacr fails, nothing is
   deleted. Stripe's later events about that subscription are ignored.
   Grigri can't cancel a subscription bought through Apple: the
   confirmation says to cancel it in Settings, and the subscription is
   untied from the account (Stripe isn't asked), so a new account can
   restore it.
2. **The sign-in provider's grants**, before any data is deleted: Sign
   in with Apple's tokens are revoked at Apple, which Apple requires on
   deletion (`revokeAppleTokens`, [below](#apple-token-revocation); it never
   throws, so a failure at Apple is logged and the deletion goes on).
   Then the API's `onDeleteAccount` hook (`Deps.onDeleteAccount` in
   [api.ts](../grigri_api/src/api.ts)) runs with `{subject, climberId,
   email}`, for any other provider; it must be idempotent, and throwing
   stops the deletion, to be retried. Google needs nothing: its ID token
   is used once, at sign-in.
3. **What I wrote and added, removed** (the privacy-friendly choice, not
   "Deleted climber" placeholders): in every plan I'm in, left or asked
   to join, my messages (and their photos and videos in S3), the request
   notes of my join requests, and the photos I added to its Your Pics.
   The others get live-update hints. Notes the chat wrote earlier
   ("… created the plan", "… joined") keep the name they were written
   with.
4. **Out of every plan**, through the usual [leave](matching.md) rules:
   an organizer's plan is handed to a member picked at random, a plan
   with only me ends (with its requests and chat), open requests stop
   waiting for my yes; the chat's note says "A climber left the plan",
   never my name; the others get live-update hints.
5. **My join requests withdrawn**, whatever became of them (the plan's
   version moves on, so an answer racing it reloads without it).
6. **My ads**, with their photos or videos.
7. **My blocks, both ways** ([moderation](moderation.md)): whom I blocked
   and who blocked me, so nobody's Blocked people keeps me; and I'm no
   longer a known admin.
8. **My profile and gear photos** in S3, then **every item keyed to me**
   (`CLIMBER#<id>`: the profile, memberships, passes, notices, the kept
   email, the Premium copy, and anything added there later), then the
   sign-in subject's link to my climber (`SUB#<subject>`), then **every
   session** (signed out on every device: an old token gets 401).

Not deleted: walls and routes I added to the [route finder](route-finder.md)
(the shared map of the rock, without personal data; they lose their
attribution); notices other people got about me (they point to a profile
that's gone); [match scores](match-scores.md) (they expire a day after
their plan starts, and the next run skips me); uploads never saved
(expired within a day by the bucket's rule). Signing in again with the
same Google account starts a new, empty profile.

Cost: no new resource. A deletion is a few dozen DynamoDB reads and
writes, S3 deletes (free) and one or two Stripe calls (free): well under
a cent.

## Per platform

| | Android | iOS | Web |
|---|---|---|---|
| Google | the app's **Sign in with Google** | the app's **Sign in with Google** | Google's own button (rendered by google_sign_in_web) |
| Apple | **Sign in with Apple**: Apple's page in a Chrome Custom Tab, for the Services ID; Apple posts its answer to the site's `/api/apple/callback`, which sends it back to the app | **Sign in with Apple** (Apple's sheet: Face ID, the Apple ID's name and email, or a relay email), for the bundle ID | **Sign in with Apple**: Apple's page in a popup (Apple's JS), for the Services ID; it answers the page with `postMessage` |

The same Apple ID is the same account on all three: Apple gives one
`sub` per developer team, whichever client (the bundle ID or the
Services ID, grouped under the primary App ID) signed it in.

### Google

[google_sign_in](https://pub.dev/packages/google_sign_in) 7:

| | Android | iOS | Web |
|---|---|---|---|
| Client IDs | the web client ID as the server client ID; Google matches the app by its Android OAuth client (`com.nu01.grigri` and the signing key's SHA-1) | `GOOGLE_IOS_CLIENT_ID` as the client ID, the web client ID as the server client ID | the web client ID |
| Also needs | nothing in the app | `GIDClientID` and the reversed client ID as a URL scheme (`CFBundleURLTypes`) in `Info.plist`, from build settings | the site's CSP allows Google Identity Services (`accounts.google.com/gsi/`) |

The settings are public identifiers, never secrets, compiled in with
`--dart-define` (allowed by `scripts/dart-defines.sh`, from the environment
or `.env`; see [.env.example](../.env.example)):

- `GOOGLE_WEB_CLIENT_ID`: the web client ID. Each stage has its own
  client, whose JavaScript origin is its site: CI takes production's from
  the repository variable `GOOGLE_WEB_CLIENT_ID` (Deploy, and Release for
  GA tags) and the RC's from `GOOGLE_WEB_CLIENT_ID_RC` (Deploy RC, and
  Release for the other tags).
- `GOOGLE_WEB_CLIENT_ID_LOCAL`: the local site's web client
  (`devbox services up`), whose JavaScript origin is
  `https://local.grigri.nu01.com:2543`: Google matches the port too, so
  the origin without it isn't enough. `scripts/flutter-web.sh` builds the
  local web app with it, and the local API checks it (process-compose's
  Floci); without it both use `GOOGLE_WEB_CLIENT_ID`. Device builds still
  use `GOOGLE_WEB_CLIENT_ID`, as they talk to a deployed stage.
- `GOOGLE_IOS_CLIENT_ID`: iOS only. `scripts/dart-defines.sh` also writes
  it, and its reversed form `com.googleusercontent.apps.<id>`, to the
  git-ignored `grigri_app/ios/Flutter/Private.xcconfig` as
  `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_IOS_URL_SCHEME`, which `Info.plist`
  uses; no ID is committed. CI's Release takes it from the repository
  variable `GOOGLE_IOS_CLIENT_ID` for GA tags, `GOOGLE_IOS_CLIENT_ID_RC`
  for the rest.
- `GRIGRI_API_URL`: the API's site. Optional: the web app calls its own
  origin (`/api`, `/photos`, served by the same CloudFront distribution);
  Android and iOS default to the stage's site: https://grigri.nu01.com for
  `GRIGRI_STAGE=prod`, https://rc.grigri.nu01.com otherwise. Release
  builds a GA tag's apps with `GRIGRI_STAGE=prod`, the rest with `rc`.

On a build without `GOOGLE_WEB_CLIENT_ID` the Google button is still
there (the plain one, also on the web), and tapping it fails with the
sign-in error. The local API's dev mode (`devUser`, the
`X-Grigri-Dev-User` header: see [API](api.md)) is for scripts and
`curl`, not the app.

### Apple

[sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple) 8
([apple_sign_in.dart](../grigri_app/lib/data/apple_sign_in.dart)):

- The app asks for the **email** and **full name** scopes. Apple shows
  its own sheet, where the person may edit the name and choose **Hide My
  Email** (a `@privaterelay.appleid.com` address). Apple gives the name
  (and the email) to the app **only the first time** an Apple ID signs in
  to it; the token never has the name.
- Each sign-in makes a fresh random **nonce** (32 characters); Apple gets
  its SHA-256 (hex) and signs it into the identity token; the app sends
  the raw nonce with the token, and the API checks it, so a token can't
  be replayed from another sign-in.
- The app sends `appleIdToken`, `nonce`, the `authorizationCode` (for
  [revocation](#apple-token-revocation)) and the `name` (given and family
  name, when Apple gave them) to `POST /api/session`.
- **iOS**: Apple's own sheet, for the bundle ID. The capability: [Runner.entitlements](../grigri_app/ios/Runner/Runner.entitlements)
  has `com.apple.developer.applesignin` = `[Default]`, set as
  `CODE_SIGN_ENTITLEMENTS` for the Runner target in every configuration.
  The bundle ID `com.nu01.grigri` is the client.
- **The web and Android**: Apple's web flow, for the **Services ID**
  `com.nu01.grigri.signin` (`APPLE_SERVICE_ID`, compiled in with that
  default, the same on every stage; a public identifier), returning to
  the **return URL** `<site>/api/apple/callback` (`AppConfig.appleRedirectUri`:
  the page's origin on the web, the stage's site on Android). The nonce
  works the same way: Apple puts the SHA-256 the app gives it in the
  token.
  - **Web**: `index.html` loads Apple's JS
    (`appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js`),
    and the tap opens Apple's page in a popup, with nothing awaited
    before (so browsers don't block it). Apple's page answers the app's
    page with `postMessage`; the return URL must still be one of the
    Services ID's, on the page's origin. Closing the popup
    (`popup_closed_by_user`) or cancelling (`user_cancelled_authorize`)
    is a quiet cancel. The site's CSP allows Apple's JS
    (`script-src https://appleid.cdn-apple.com/appleauth/static/jsapi/`);
    the popup is a window, not a frame, so nothing else.
  - **Android**: sign_in_with_apple opens Apple's page in a Chrome
    Custom Tab (`response_mode=form_post`). Apple posts the answer
    (`code`, `id_token`, `state`, `user` the first time, or `error`) to
    the return URL; the API answers **307** to
    `intent://callback?<those fields only>#Intent;package=com.nu01.grigri;scheme=signinwithapple;end`,
    which opens sign_in_with_apple's `SignInWithAppleCallback` activity
    (declared in `AndroidManifest.xml`, scheme `signinwithapple`, path
    `callback`). The package is fixed (`com.nu01.grigri` on every stage:
    the app has no flavors), never taken from the request, so no other app
    gets the answer. The route is public, never logs the body (it carries
    the identity token), and takes only a form (`application/x-www-form-urlencoded`,
    up to 64 KB; anything else is 415).

## Token checks

In the API, before any session is made (`POST /api/session`, the only
route that takes an ID token):

| | Google ([google.ts](../grigri_api/src/google.ts)) | Apple ([apple.ts](../grigri_api/src/apple.ts)) |
|---|---|---|
| Signature | RS256, Google's keys (`https://www.googleapis.com/oauth2/v3/certs`) | RS256, Apple's keys (`https://appleid.apple.com/auth/keys`) |
| Issuer | `https://accounts.google.com` or `accounts.google.com` | `https://appleid.apple.com` |
| Audience | the web client ID, or one of the stage's iOS client IDs | the app's bundle ID (`AppleBundleId`, default `com.nu01.grigri`) or the Services ID (`AppleServiceId`, default `com.nu01.grigri.signin`) |
| Also | `sub`, `exp`, `iat`; expiry (30 s leeway) | `sub`, `exp`, `iat`, `nonce`; expiry (30 s leeway); `nonce` = SHA-256 (hex) of the nonce the app sent (16 to 128 URL-safe characters, required) |
| Subject | `https://accounts.google.com#<sub>` | `apple#<sub>` |
| Email | kept on the session only when `email_verified` | the same (Apple's are verified; maybe a relay address) |
| Name | the token's `name` claim | the `name` the app sends (whitespace collapsed, at most 60 characters), for the new profile only |

Both key sets are fetched once per warm Lambda and cached by
[jose](https://github.com/panva/jose) (already the API's one dependency
for tokens; an unknown key ID refetches, rate-limited). Only RS256 is
taken (never `none` or HMAC); a token over 4 KB isn't parsed. A refused
token is 401 `invalid Google ID token` or `invalid Apple ID token`; an
Apple token without a well-formed nonce is 400.

## Apple token revocation

Apple requires an app that offers Sign in with Apple to **revoke the
person's Apple tokens when they delete their account**. The pieces, in
[apple.ts](../grigri_api/src/apple.ts) (`AppleTokens`):

- **At sign-in**, with a Sign in with Apple key configured, the API
  trades the authorization code for a **refresh token** at
  `https://appleid.apple.com/auth/token` (`grant_type=authorization_code`,
  `client_id` the client the identity token was issued to (its `aud`:
  the bundle ID on iOS, the Services ID on the web and Android; a code
  for any other client isn't exchanged), `client_secret` a JWT: ES256,
  signed with the key, header `kid` the key ID, `iss` the team ID, `sub`
  that client ID, `aud` `https://appleid.apple.com`, valid 5 minutes, made per call).
  It keeps the refresh token only if the ID token in Apple's answer is
  for the same `sub` as the identity token just checked (so nobody can
  attach someone else's code to their account), on the item
  `SUB#apple#<sub>` / `APPLE` (`refreshToken`, `clientId`, `updatedAt`; DynamoDB
  encrypts it at rest; never returned or logged). Each sign-in replaces
  it. It's best effort: Apple refusing or not answering (3 s timeout)
  logs a warning (status and Apple's error code only) and the sign-in
  goes on.
- **At account deletion**: `Api.revokeAppleTokens(climberId)` (in
  [api.ts](../grigri_api/src/api.ts), calling
  `AppleTokens.revoke(climberId)`) reads the profile's subject; for an
  Apple account with a kept token it posts the token to
  `https://appleid.apple.com/auth/revoke`
  (`token_type_hint=refresh_token`, as the token's own `clientId`, the
  bundle ID for tokens kept before it was recorded), then deletes
  the kept token whatever Apple said. It never throws; it answers
  `'revoked'`, `'none'` (not an Apple account, or no token kept),
  `'skipped'` (no key configured: a warning) or `'failed'` (logged).
  Account deletion (`DELETE /api/me`) calls it in its step 2, before
  any data goes (it reads the profile's `subject`), and deletes the
  `SUB#<subject>` items (`SUB` and `APPLE`) with the sign-in link.
- **Without the key** (any of `AppleTeamId`, `AppleKeyId`,
  `ApplePrivateKey` empty, or a key that isn't a PKCS#8 .p8): Sign in with
  Apple still works; no code is exchanged and nothing is revoked, with a
  warning in the log (once per warm Lambda at sign-in, and at each
  revocation).

## Configuration the owner does

1. **Apple Developer portal**, Certificates, Identifiers & Profiles →
   Identifiers → `com.nu01.grigri`: enable **Sign in with Apple** (as a
   primary App ID). Xcode's automatic signing usually does this itself
   once the entitlement is in the project; a manual provisioning profile
   must be regenerated after it.
2. **Identifiers** → **+** → **Services IDs**: identifier
   **`com.nu01.grigri.signin`**, description "Grigri". Enable **Sign in
   with Apple** → **Configure**: primary App ID `com.nu01.grigri`;
   **Domains and Subdomains** `grigri.nu01.com`, `rc.grigri.nu01.com`,
   `local.grigri.nu01.com`; **Return URLs**
   `https://grigri.nu01.com/api/apple/callback`,
   `https://rc.grigri.nu01.com/api/apple/callback` and
   `https://local.grigri.nu01.com:2543/api/apple/callback` (the local
   site's port, as Google needs it too). Without the Services ID, Apple's
   page on the web and Android says `invalid_client`; iOS doesn't need it.
3. For revocation, **Keys** → **+**: a key with **Sign in with Apple**
   enabled, configured for the primary App ID `com.nu01.grigri`. Download
   the `.p8` (once only) and note its **Key ID** and the **Team ID**.
4. Give them to the deploy ([deploy.md](deploy.md)): repository
   variables `GRIGRI_APPLE_TEAM_ID` and `GRIGRI_APPLE_KEY_ID`, and the
   repository **secret** `GRIGRI_APPLE_PRIVATE_KEY` (the `.p8` file's
   text; `scripts/deploy.sh` strips its BEGIN/END lines and line breaks).
   For a deploy by hand, the same names in `.env` (the key's base64 body
   on one line). One key serves both stages and both clients (the
   bundle ID and the Services ID). The key is a secret: never commit it.
5. App Store Connect: nothing more (the App Privacy answers stay "name
   and email, linked to the person, not for tracking").

The API's `AppleBundleId` and `AppleServiceId` (template parameters,
`APPLE_BUNDLE_ID` and `APPLE_SERVICE_ID` in the function; the local API
uses the same defaults) default to `com.nu01.grigri` and
`com.nu01.grigri.signin`; change them only if those identifiers change
(the app's `APPLE_SERVICE_ID` with the latter).

**Cost**: none. The checks and token calls run in the same Lambda
invocation as the sign-in (a few hundred milliseconds more on an Apple
sign-in with the key configured); Apple's endpoints are free; the
refresh token is one small item per Apple account. The web and Android
flow adds one request to the existing API per Android sign-in (the
return URL's 307), no new resource. Sign in with Apple needs the Apple
Developer Program the App Store needs anyway.

## Signing out

- **Sign out**, in the Profile tab's ⋯ menu, after a confirmation: `DELETE /api/session` (best effort:
  signed out on the device even when the API can't be told), the kept
  token is forgotten, and the app signs out of Google (Apple has no
  sign-out: the next Sign in with Apple shows Apple's sheet again).
- **Sign out everywhere**, in the Profile tab's ⋯ menu, after a
  confirmation: `DELETE /api/sessions` ends all my sessions, on every
  phone and browser, then this device signs out as above. If the API
  can't be told, the app stays signed in and says so.
- **A 401** from any call (`{"error": "signed out"}`: the session ended,
  was signed out everywhere, or went a year unused): the token is
  forgotten, the app signs out of Google, says "Signed out: please sign
  in again." and goes back to the sign-in screen.

Signing out forgets everything loaded.

## Admins

The API says who's an admin (`"admin": true` from `GET /api/me`: a
verified email holding rbacr's `grigri` `admin` role, [roles](roles.md)).
Admins get the **Admin** tab ([admin.md](admin.md)): everyone, to block or
unblock. An Apple account is an admin the same way, by its verified
email (a relay address holds no role unless one is granted to it).

## Blocked

A climber an admin blocked gets 403 `blocked` from the API: the app shows
only "Your account is blocked", with **Sign out** and **Try again**
([admin.md](admin.md#blocking)).
