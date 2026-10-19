# Google Play

Shipping the Android app, **Grigri** (`com.nu01.grigri`), on Google
Play: what the repo does for it, and what the owner does by hand in Play
Console. It mirrors the [App Store](app-store.md): the same store copy,
privacy answers and rating.

## Done in the repo

- **Upload key**: an RSA 4096 key (alias `upload`, PKCS#12), made on
  2026-10-19, in the private `env.local/android/upload.jks` with its
  `key.properties` (store and key passwords; never committed), backed up
  in setec-astronomy's `grigri.nu01/env.local/android/`. Its SHA-1 is
  `20:E3:AD:E3:F8:00:B4:EB:04:C8:74:9C:98:7F:26:FF:5A:21:50:E5`. Losing
  it isn't fatal (Play App Signing keeps the real signing key; Play
  Console can reset an upload key), but keep it.
- **Release signing**: `grigri_app/android/app/build.gradle.kts` signs
  release builds with the upload key when `grigri_app/android/key.properties`
  (git-ignored; a link to `env.local/android/key.properties`) is there,
  and with the debug key otherwise, so `flutter run --release` and local
  APKs keep working.
- **`make aab`** (`scripts/make.sh aab`): the release bundle Play takes,
  `grigri_app/build/app/outputs/bundle/release/app-release.aab`, with the
  version and build settings the other targets use. It refuses to build
  without the upload key. Build it with production's settings
  (`GRIGRI_STAGE=prod` and the GA Google client IDs, as for the
  [App Store](app-store.md#build-and-upload)). The version code is the
  build number (Unix seconds): it only grows, and stays under Play's
  2,100,000,000 until 2036.

## In Play Console

The developer account is a **personal** one (nu01.com, identity verified
2026-10-16).

1. **Verify the contact phone number** (Home: "Finish setting up your
   developer account"). Until then no app can be created.
2. **Create the app**: name **Grigri: Join a climbing plan** or
   **Grigri Climbing** (as on the App Store), default language English
   (United States), app, free; accept the declarations.
3. **App signing**: Play App Signing (Google keeps the app signing key;
   uploads are signed with the upload key above).
4. **Google sign-in**: Play re-signs the app with its app signing key, so
   Google sign-in on installs from Play needs Android OAuth clients
   (Google Cloud project grigri-511416, package `com.nu01.grigri`) for
   the **app signing key's SHA-1** (Play Console → Test and release →
   App integrity) and the upload key's SHA-1. Without them, Google
   sign-in fails on Play installs (Sign in with Apple still works).
5. **Store listing**: the App Store's copy ([app-store.md](app-store.md#the-versions-page)):
   short description `Join a climbing plan` (80 characters at most), the
   full description, the 512 px icon, a 1024 × 500 feature graphic, and
   phone screenshots; category **Sports**; contact email
   julio@nu01.com; privacy policy https://grigri.nu01.com/privacy.html.
   "Plans, not partners" wording ([README](README.md)).
6. **App content**: privacy policy URL; ads: **yes** (climbers'
   [ads](ads.md) in the deck; no ad network); app access: sign-in required, with how to sign in
   (Google or Apple); content rating questionnaire as the App Store's age
   rating ([app-store.md](app-store.md#age-rating): user-generated
   content and chat with strangers); target audience 16 and over; **Data
   safety** matching the App Store's App Privacy answers and the privacy
   manifest: name, email, user ID, approximate location, photos and
   videos, messages, other user content, purchase history; all collected,
   none shared, encrypted in transit, deletable in the app (Me → Delete
   account); for app functionality only.
7. **Testing before production**: personal accounts created after
   November 2023 must run a **closed test with at least 12 testers for
   14 days** before applying for production access. Upload the bundle
   to a closed testing track, add the testers (an email list or a Google
   group), and apply for production from the Dashboard once it's done.
8. **Premium on Android** sells through Stripe in the browser
   ([premium](premium.md)). Play's payments policy wants digital goods
   bought in an app to go through Google Play Billing, as the App Store
   wanted its in-app purchase; review may refuse the Stripe buttons on
   Android. Google Play Billing isn't built.

## Cost

Google Play's developer registration ($25, once) is paid. No running
cost: nothing in AWS changes.
