# Sign-in

People sign in with **Google** (every platform) or, on iOS, **Sign in
with Apple** (App Store guideline 4.8: an app that signs in with Google
must also offer an option that asks only for name and email, lets people
hide their email, and doesn't track them for ads; Apple's does). Then
they stay signed in with the API's own **session**: the ID token is used
once, to start it.

- After signing in (Google's button on the web, the app's on Android and
  iOS; Apple's sheet on iOS), the app calls `POST /api/session` with
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
CanvasKit and Google Identity Services) is what guards it.

## The flow

1. **Start**: with a kept session the app goes straight to step 2, with
   no Google or Apple round-trip. Without one, the **sign-in screen**
   ([sign_in_screen.dart](../grigri_app/lib/ui/sign_in_screen.dart)):
   the app's name and tagline, and the sign-in buttons. (Without a kept
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
- **Sign in with Apple**, on iOS only, above Google's and as prominent:
  the same width and height (52), the same rounded ends, in Apple's own
  style ([sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple)'s
  `SignInWithAppleButton`: the Apple logo and Apple's wording, white on
  the dark theme), its text in the app's language ("Sign in with Apple",
  "Iniciar sesión con Apple", "Mit Apple anmelden", "Se connecter avec
  Apple", "Iniciar sessão com a Apple", "Inicia la sessió amb Apple").
- Both are disabled while a sign-in is under way.
- Cancelling Apple's sheet is quiet: no error. A failure says "Couldn't
  sign in with Apple. Try again." (Google's: "Couldn't sign in with
  Google. Try again."); the API refusing the token: "Couldn't sign in.
  Try again."

## Per platform

| | Android | iOS | Web |
|---|---|---|---|
| Google | the app's **Sign in with Google** | the app's **Sign in with Google** | Google's own button (rendered by google_sign_in_web) |
| Apple | not offered | **Sign in with Apple** (Apple's sheet: Face ID, the Apple ID's name and email, or a relay email) | not offered |

Sign in with Apple is offered on iOS only: Apple's guideline concerns the
App Store app, and Android or the web would need a Services ID, a return
URL and Apple's JavaScript, for no requirement.

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
- The capability: [Runner.entitlements](../grigri_app/ios/Runner/Runner.entitlements)
  has `com.apple.developer.applesignin` = `[Default]`, set as
  `CODE_SIGN_ENTITLEMENTS` for the Runner target in every configuration.
  No setting is compiled in: the bundle ID `com.nu01.grigri` is the
  client.

## Token checks

In the API, before any session is made (`POST /api/session`, the only
route that takes an ID token):

| | Google ([google.ts](../grigri_api/src/google.ts)) | Apple ([apple.ts](../grigri_api/src/apple.ts)) |
|---|---|---|
| Signature | RS256, Google's keys (`https://www.googleapis.com/oauth2/v3/certs`) | RS256, Apple's keys (`https://appleid.apple.com/auth/keys`) |
| Issuer | `https://accounts.google.com` or `accounts.google.com` | `https://appleid.apple.com` |
| Audience | the web client ID, or one of the stage's iOS client IDs | the app's bundle ID (`AppleBundleId`, default `com.nu01.grigri`) |
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
  `client_id` the bundle ID, `client_secret` a JWT: ES256, signed with
  the key, header `kid` the key ID, `iss` the team ID, `sub` the bundle
  ID, `aud` `https://appleid.apple.com`, valid 5 minutes, made per call).
  It keeps the refresh token only if the ID token in Apple's answer is
  for the same `sub` as the identity token just checked (so nobody can
  attach someone else's code to their account), on the item
  `SUB#apple#<sub>` / `APPLE` (`refreshToken`, `updatedAt`; DynamoDB
  encrypts it at rest; never returned or logged). Each sign-in replaces
  it. It's best effort: Apple refusing or not answering (3 s timeout)
  logs a warning (status and Apple's error code only) and the sign-in
  goes on.
- **At account deletion**: `Api.revokeAppleTokens(climberId)` (in
  [api.ts](../grigri_api/src/api.ts), calling
  `AppleTokens.revoke(climberId)`) reads the profile's subject; for an
  Apple account with a kept token it posts the token to
  `https://appleid.apple.com/auth/revoke`
  (`token_type_hint=refresh_token`, the same client secret), then deletes
  the kept token whatever Apple said. It never throws; it answers
  `'revoked'`, `'none'` (not an Apple account, or no token kept),
  `'skipped'` (no key configured: a warning) or `'failed'` (logged).
  **Account deletion (`DELETE /api/me`) must call it before it deletes
  the profile** (it reads the profile's `subject`), and delete the
  `SUB#<subject>` items (`SUB` and `APPLE`) with the rest.
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
2. For revocation, **Keys** → **+**: a key with **Sign in with Apple**
   enabled, configured for the primary App ID `com.nu01.grigri`. Download
   the `.p8` (once only) and note its **Key ID** and the **Team ID**.
3. Give them to the deploy ([deploy.md](deploy.md)): repository
   variables `GRIGRI_APPLE_TEAM_ID` and `GRIGRI_APPLE_KEY_ID`, and the
   repository **secret** `GRIGRI_APPLE_PRIVATE_KEY` (the `.p8` file's
   text; `scripts/deploy.sh` strips its BEGIN/END lines and line breaks).
   For a deploy by hand, the same names in `.env` (the key's base64 body
   on one line). One key serves both stages (the same bundle ID). The
   key is a secret: never commit it.
4. App Store Connect: nothing more (the App Privacy answers stay "name
   and email, linked to the person, not for tracking").

The API's `AppleBundleId` (template parameter, `APPLE_BUNDLE_ID` in the
function) defaults to `com.nu01.grigri`; change it only if the bundle ID
changes.

**Cost**: none. The checks and token calls run in the same Lambda
invocation as the sign-in (a few hundred milliseconds more on an Apple
sign-in with the key configured); Apple's endpoints are free; the
refresh token is one small item per Apple account. Sign in with Apple
needs the Apple Developer Program the App Store needs anyway.

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
