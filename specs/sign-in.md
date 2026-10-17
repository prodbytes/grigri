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
   confirmation says to cancel it in Settings.
2. **The sign-in provider's grants**: the API's `onDeleteAccount` hook
   (`Deps.onDeleteAccount` in [api.ts](../grigri_api/src/api.ts)) runs
   with `{subject, climberId, email}` before any data is deleted. It's
   where Sign in with Apple revokes Apple's tokens, which Apple requires
   on deletion (the subject's issuer, `https://appleid.apple.com`, says
   it's an Apple account). It must be idempotent; throwing stops the
   deletion, to be retried. Google needs nothing: its ID token is used
   once, at sign-in.
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
7. **My profile and gear photos** in S3, then **every item keyed to me**
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
verified email holding rbacr's `grigri` `admin` role, [roles](roles.md)).
Admins get the **Admin** tab ([admin.md](admin.md)): everyone, to block or
unblock.

## Blocked

A climber an admin blocked gets 403 `blocked` from the API: the app shows
only "Your account is blocked", with **Sign out** and **Try again**
([admin.md](admin.md#blocking)).
