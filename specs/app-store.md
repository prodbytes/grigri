# App Store

Shipping the iOS app, **Grigri** (`com.nu01.grigri`), on Apple's App
Store: what the repo already does for it, what other changes are still
on their way, and what the owner does by hand in Apple's portals.
TestFlight comes first, then review for the App Store.

## Done in the repo

- **iPhone only**: `TARGETED_DEVICE_FAMILY = 1` for the project and the
  Runner target in every configuration, and no
  `UISupportedInterfaceOrientations~ipad` in `Info.plist`. iPads run it as
  an iPhone app. Supporting the iPad would need iPad screenshots and an
  iPad review pass, for few climbers.
- **Export compliance**: `ITSAppUsesNonExemptEncryption` is `false` in
  `Info.plist`, so App Store Connect doesn't ask for each build. The app
  uses only HTTPS/TLS (the API, photos, live updates over WSS) and the
  operating system's own crypto (the Keychain, through
  `flutter_secure_storage`); `grigri_app/lib` has no crypto of its own.
- **Privacy manifest**:
  [grigri_app/ios/Runner/PrivacyInfo.xcprivacy](../grigri_app/ios/Runner/PrivacyInfo.xcprivacy),
  bundled with the Runner target (it's in the project's Resources build
  phase). No tracking and no tracking domains. Collected data, all
  **linked** to the user, **not used for tracking**, for **App
  Functionality** only:

  | Data type | What in Grigri |
  |---|---|
  | Name | the account's name, the profile's name |
  | Email Address | the account's email (roles and billing; never shown) |
  | User ID | the climber id, the Google or Apple account id |
  | Coarse Location | where I climb, rounded to about 1 km ([matching](matching.md)) |
  | Photos or Videos | profile and gear photos, chat photos and videos, plan photos, ads' media, route finder walls |
  | Emails or Text Messages | group chat messages |
  | Other User Content | bio, age, grades, gear, plans, join requests, ads' text |
  | Purchase History | Premium's subscription (Stripe; Apple in-app purchase once added) |

  Required-reason APIs the app's own code uses: `UserDefaults` (through
  `shared_preferences`: the language, the grade system), reason
  **CA92.1** (the app's own data). Plugins ship their own manifests
  (`path_provider_foundation`, `shared_preferences_foundation`, and the
  rest).
- **Privacy policy and support pages** on the site root, in the
  landing page's look ([landing](landing.md)):
  https://grigri.nu01.com/privacy.html and
  https://grigri.nu01.com/support.html (English; dated 2026-10-17;
  contact julio@nu01.com). The landing page's footer links both, in the
  page's six languages. The policy must stay true: change it with any
  change to what Grigri collects, keeps or shares.
- **In the app**: **Privacy policy** and **Support** at the end of the
  Profile (Me) tab open those pages on the stage's site in the browser
  ([screens](screens.md)).
- **Version strings**: Apple's
  [CFBundleShortVersionString](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring)
  must be three period-separated integers, and
  [CFBundleVersion](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion)
  one to three; neither page gives a size limit for an integer. Apple's
  [TN2420](https://developer.apple.com/library/archive/technotes/tn2420/_index.html)
  adds that each may be **at most 18 characters**. Grigri's
  ([release](release.md#versioning)) fit: the version `0.2.202610171230`
  is 16 characters, the build number (Unix seconds, ten digits) 10, and
  both only grow (a version must be higher than the last one, a build
  number higher than the last one of its version). So iOS builds keep the
  same version as the others. `scripts/make.sh` refuses an iOS build
  whose version or build number breaks either rule (for example X.Y grown
  to `100.1`). If App Store Connect ever refused the 12-digit Z, set
  `VERSION_Z` to something smaller that still grows.
- **`make ipa`**: a signed release `.ipa` for App Store Connect
  (`flutter build ipa --release`, with the version, build number and
  build settings `make ios` uses), in `grigri_app/build/ios/ipa/`.

## In progress, in their own pull requests

- **Sign in with Apple** (guideline 4.8: an app that offers Google
  sign-in must offer it too).
- **Account deletion** in the app, **Me → Delete account** (guideline
  5.1.1(v)). Until then, by email, as the policy says.
- **Report, block and filter** for people and content (guideline 1.2,
  user-generated content): report a person, plan or message; block a
  person; act on reports within 24 hours (the support page promises it).
- **Apple in-app purchase for Premium** (guideline 3.1.1: Premium is
  sold in the app, so it can't send iPhone users to Stripe).

Submit for review only once these four are merged.

## By hand, by the owner

### Apple accounts and signing

1. Join the paid **Apple Developer Program** ($99 a year; a free
   Personal Team can't distribute). It's the only running cost here, and
   there's no cheaper way onto the App Store.
2. An **Apple Distribution** certificate: Xcode's automatic signing makes
   it on the first archive (Xcode → Settings → Accounts → the team →
   Manage Certificates otherwise). `IOS_DEVELOPMENT_TEAM` in `.env` is the
   paid team's ID ([platforms](platforms.md)).
3. In **App Store Connect → Apps → +**: a new iOS app, name **Grigri**,
   primary language **English (U.S.)**, bundle ID **com.nu01.grigri**
   (register it under Certificates, Identifiers & Profiles first, with
   the Sign in with Apple capability once that's in), SKU
   **grigri-ios**, full access.

### App information

- **Category**: **Sports** (primary), **Social Networking** (secondary).
  Climbing comes first; Sports keeps it away from dating apps.
- **Privacy policy URL**: https://grigri.nu01.com/privacy.html
- **Support URL**: https://grigri.nu01.com/support.html
- **Marketing URL** (optional): https://grigri.nu01.com/
- **Copyright**: 2026, the owner's name.
- **Price**: Free. **In-app purchases**: Premium monthly and yearly, once
  Apple's in-app purchase is in.

### App Privacy questionnaire

Answer **Yes, we collect data**, and for each type below: **linked to
the user**, **not used for tracking**, purpose **App Functionality**
only. It must match the privacy manifest above.

- Contact Info: **Name**, **Email Address**.
- Location: **Coarse Location**.
- User Content: **Photos or Videos**, **Emails or Text Messages**,
  **Other User Content**.
- Identifiers: **User ID**.
- Purchases: **Purchase History**.

Everything else: not collected (no device ID, no usage data, no
diagnostics, no crash data sent anywhere, no health, financial,
contacts, browsing or search history; the precise location never leaves
the phone). Tracking: **No**.

### Age rating

The questionnaire's answers:

- Violence, sexual content, profanity, drugs, gambling, horror, medical:
  **None**.
- **User-generated content**: **Yes** (profiles, plans, chats, photos,
  ads).
- **Messaging and chat**: **Yes**, with people the user may not know.
- Unrestricted web access: **No** (links open in the browser, outside
  the app).
- Contests, in-app controls: **No**.

With unmoderated chat between strangers and meetings in person, expect
**16+** in Apple's current scale (older questionnaires gave **17+**);
it also fits the policy's "not for under-16s" and the profile's age
rule (16–99). Apple works the rating out from the answers; don't pick a
lower one by answering "No" to chat.

### The version's page

Draft copy (English); keep to the "plans, not partners" wording
([README](README.md)):

- **Name**: Grigri
- **Subtitle** (30 characters): `Join a climbing plan`
- **Promotional text** (170): `Make a plan for the crag or the gym, or
  swipe right on someone else's. Each match opens the group's chat.
  Free for every climber.`
- **Description**:

  > Grigri finds you a climbing plan.
  >
  > Make a plan, where, when and which grades, or swipe through the
  > plans near you and swipe right on the one you like. Every match
  > opens the plan's group chat: sort out the rope, the ride and the
  > coffee.
  >
  > • Private plans: the group lets newcomers in one at a time, when
  > everyone says yes.
  > • Open plans: anyone can join at once.
  > • Guided plans: a guide decides who joins and sets a price.
  > • Profiles with your grades (French or YDS, Font or V) and the gear
  > you can bring.
  > • Group chats with photos and videos.
  > • Photos of the crags, credited to their authors.
  > • Where you climb stays private and is kept to about 1 km.
  >
  > Free for every climber: plans, swiping, matches and chats cost
  > nothing. Premium is optional, for advertising on Grigri and for the
  > route finder.
  >
  > In English, Spanish, German, French, Portuguese and Catalan.

- **Keywords** (100 characters, commas, no spaces):
  `climbing,bouldering,crag,belay,partners,sport climbing,trad,gym,outdoor,rope`
- **Screenshots**: the **6.9-inch iPhone** set is required, **1320 ×
  2868** portrait (an iPhone 16 Pro Max or 17 Pro Max simulator); 3 to
  10 of them: Find (the deck, a plan with a crag photo), the plan's
  group chat, Plans, the profile, the plan editor. Use the demo showcase
  or made-up people only; no real climbers' names or faces.
- **What's New**: for later versions.

### Review notes and demo account

Reviewers must be able to sign in and see real plans:

- **Sign-in**: Sign in with Apple, once it's in, needs no demo account.
  Until then (and as a fallback), make a Google account for review only
  (e.g. a new Gmail address), sign in with it once on production, and
  give its email and password in **App Review Information → Sign-in
  required**. Turn off its two-step verification, or Google's challenge
  stops the reviewer.
- **What they'll see**: production's **demo showcase** (made-up
  climbers' plans around the world, [matching](matching.md)), so the
  deck isn't empty.
- **Notes** to paste:

  > Grigri matches climbers with climbing plans. Swipe right on a plan
  > in Find to ask to join; the group answers in its chat. Open plans
  > let you in at once: swipe right on one to see the group chat right
  > away. To report a person or content, open their profile or the
  > message and tap Report; Block hides them. Account deletion is in
  > Me → Delete account. Premium (advertising and the route finder) is
  > an auto-renewing subscription bought with in-app purchase. Location
  > is used only to show nearby plans first, rounded to about 1 km.

- **Contact**: the owner's name, phone and julio@nu01.com.

### Build and upload

1. On a Mac with Xcode, in the repo: the **GA** build settings
   (`GRIGRI_STAGE=prod` and the GA Google client IDs, from
   `env.local/google/ga`, in the environment or `.env`; the app's API is
   then https://grigri.nu01.com) and the paid team in
   `IOS_DEVELOPMENT_TEAM`.
2. `make ipa` (`scripts/make.sh ipa`), with a Flutter 3.47 checkout on
   the `PATH` rather than devbox's: devbox's Flutter comes from the Nix
   store, read-only, and Xcode can't re-sign the `Flutter.framework` it
   copies ("Permission denied"; seen 2026-10-17). It writes
   `Private.xcconfig` ([platforms](platforms.md)), checks the version
   strings, and runs `flutter build ipa --release`. The archive lands in
   `grigri_app/build/ios/archive/Runner.xcarchive`, the `.ipa` in
   `grigri_app/build/ios/ipa/`. Build from the GA tag's commit
   ([release](release.md)), so the version matches it: `VERSION_Z` and
   `BUILD_NUMBER` from the tag.
3. Upload, either:
   - **Xcode → Window → Organizer**: open the archive, **Distribute App
     → App Store Connect → Upload**; or
   - **Transporter** (Mac App Store): drag the `.ipa` in, **Deliver**; or
   - `xcrun altool --upload-app -f grigri_app/build/ios/ipa/*.ipa -t ios
     --apiKey <key id> --apiIssuer <issuer id>`, with an App Store Connect
     API key (Users and Access → Integrations; the `.p8` file in
     `~/.appstoreconnect/private_keys/`, never in the repo).
4. **TestFlight** first: the build appears after processing (minutes to
   an hour). Test it on the owner's iPhone (internal testing needs no
   review), then add external testers if wanted (a short beta review).
5. **Submit for review**: pick the build on the version's page, answer
   the export compliance question (already answered by `Info.plist`),
   and submit. Release manually or automatically once approved.

## Cost

Apple Developer Program: **$99 a year**, the only way to publish on the
App Store. Nothing in AWS changes: the two pages are a few KB more in
the site bucket, served from CloudFront's cache within its free tier.
