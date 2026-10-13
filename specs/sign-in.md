# Sign-in

People sign in with **Google only**, then stay signed in with the API's
own **session**: the Google ID token is used once, to start it.

- After Google sign-in (Google's button on the web, the app's on Android
  and iOS), the app calls `POST /api/session` with `{"idToken"}`. The API
  checks the token (issuer `https://accounts.google.com`; audience the
  Google **web** client ID, or on iOS the app's **iOS** client ID: Google
  issues an iPhone's token to the iOS client even with the web client as
  its server client; [api.md](api.md)) and answers a session token.
- The app keeps the session token on the device and sends
  `Authorization: Bearer <session token>` on every API call. It doesn't
  ask Google again until the API says 401 or the person signs out.
- A session lasts **until sign-out, or 365 days without use**. It slides:
  each day it's used pushes the 365 days forward; there's no absolute
  limit.
- The same session token opens the app's [live updates](live-updates.md)
  connection, checked by the MQTT broker's authorizer, which refuses an
  ended session and drops a connection within the hour of its sign-out.
- The app never logs a token; its [log](logging.md) scrubs emails, ID
  tokens and bearer tokens from every line. The only URL that carries one is the live
  updates' WebSocket URL (browsers can't set headers on a WebSocket), to
  AWS IoT Core over TLS; it's never logged or shown, and API calls never
  put a token in a URL.

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
CanvasKit and Google Identity Services) is what guards it.

## The flow

1. **Start**: with a kept session the app goes straight to step 2, with
   no Google round-trip. Without one, the **sign-in screen**
   ([sign_in_screen.dart](../grigri_app/lib/ui/sign_in_screen.dart)):
   the app's name and tagline, and the sign-in button. (Without a kept
   session, the app also tries google_sign_in's lightweight
   authentication at start, and starts a session if Google answers.)
2. `GET /api/me`: my profile, and whether I'm an admin. The first time,
   the API creates the profile from my Google account: its name (as the
   session kept it from the ID token), the rest empty. No step to fill it
   in: signing in is enough.
3. The tabs. I fill in the rest (photo, age, about, grades, gear, where I
   climb) when I like, with **Edit profile** on the Profile tab.

## Signing out

- **Sign out**, in the Profile tab's ⋯ menu, after a confirmation: `DELETE /api/session` (best effort:
  signed out on the device even when the API can't be told), the kept
  token is forgotten, and the app signs out of Google.
- **Sign out everywhere**, in the Profile tab's ⋯ menu, after a
  confirmation: `DELETE /api/sessions` ends all my sessions, on every
  phone and browser, then this device signs out as above. If the API
  can't be told, the app stays signed in and says so.
- **A 401** from any call (`{"error": "signed out"}`: the session ended,
  was signed out everywhere, or went a year unused): the token is
  forgotten, the app signs out of Google, says "Signed out: please sign
  in again." and goes back to the sign-in screen.

Signing out forgets everything loaded.

## Per platform

[google_sign_in](https://pub.dev/packages/google_sign_in) 7:

| | Android | iOS | Web |
|---|---|---|---|
| Button | the app's **Sign in with Google** | the app's **Sign in with Google** | Google's own (rendered by google_sign_in_web) |
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

Every build, local ones too, shows only **Sign in with Google**; the app
has no other way in. On a build without `GOOGLE_WEB_CLIENT_ID` the
button is still there (the plain one, also on the web), and tapping it
fails with the sign-in error. The local API's dev mode (`devUser`, the
`X-Grigri-Dev-User` header: see [API](api.md)) is for scripts and
`curl`, not the app.

## Admins

The API says who's an admin (`"admin": true` from `GET /api/me`: a
verified email in the stage's admin list). Admins get the **Admin** tab
([screens](screens.md)): every open join request, anyone's, to **Approve**
(`POST /api/admin/requests/{planId}/{climberId}/accept`: they join now,
as if every member had said yes) or **Reject**
(`…/reject`: they're told the group declined), each after a confirmation.
