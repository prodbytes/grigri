# Sign-in

People sign in with **Google only**. The app sends the Google **ID token**
with every API call (`Authorization: Bearer <token>`), and the API checks
it: issuer `https://accounts.google.com`, audience the Google **web**
client ID, on every platform ([api.md](api.md)). The app never logs a
token.

## The flow

1. **Sign-in screen** ([sign_in_screen.dart](../grigri_app/lib/ui/sign_in_screen.dart)):
   the app's name and tagline, and the sign-in button. At start the app
   signs back in quietly when it can (google_sign_in's lightweight
   authentication).
2. `GET /api/me`: my profile, or none yet, and whether I'm an admin.
3. No profile yet: **Create your profile** (the profile editor) before
   the tabs; saving it (`PUT /api/me`) opens the tabs.
4. The tabs. **Sign out** is in the Profile tab's ⋯ menu (and in Create
   your profile's). Signing out, or a 401 the app can't recover from
   (on Android and iOS it first tries a fresh token quietly), goes back
   to the sign-in screen and forgets everything loaded.

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

- `GOOGLE_WEB_CLIENT_ID`: the web client ID. CI takes it from the
  repository variable of the same name (Deploy, Deploy RC and Release).
- `GOOGLE_IOS_CLIENT_ID`: iOS only. `scripts/dart-defines.sh` also writes
  it, and its reversed form `com.googleusercontent.apps.<id>`, to the
  git-ignored `grigri_app/ios/Flutter/Private.xcconfig` as
  `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_IOS_URL_SCHEME`, which `Info.plist`
  uses; no ID is committed. CI's Release takes it from the repository
  variable of the same name.
- `GRIGRI_API_URL`: the API's site. Optional: the web app calls its own
  origin (`/api`, `/photos`, served by the same CloudFront distribution);
  Android and iOS default to the stage's site: https://grigri.nu01.com for
  `GRIGRI_STAGE=prod`, https://rc.grigri.nu01.com otherwise. Release
  builds a GA tag's apps with `GRIGRI_STAGE=prod`, the rest with `rc`.

On a build without `GOOGLE_WEB_CLIENT_ID`, the sign-in screen says
sign-in isn't set up.

## Local dev sign-in

A **local** build (`GRIGRI_STAGE` empty or `local`) **without**
`GOOGLE_WEB_CLIENT_ID`, whose API isn't one of the deployed sites, shows
**Dev sign-in** instead: an email, sent as `X-Grigri-Dev-User: <email>`
instead of a token, for the local API's dev mode. RC and production
builds can't show it (they have a stage), and the deployed APIs refuse
dev mode anyway.

## Admins

The API says who's an admin (`"admin": true` from `GET /api/me`: a
verified email in the stage's admin list). Admins get the **Admin** tab
([screens](screens.md)): every open join request, anyone's, to **Approve**
(`POST /api/admin/requests/{planId}/{climberId}/accept`: they join now,
as if every member had said yes, when there's a spot) or **Reject**
(`…/reject`: they're told the group declined), each after a confirmation.
