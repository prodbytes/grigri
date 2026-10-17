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
  ([release](release.md#versioning)) fit: the version `0.1.202610171230`
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

The four the guidelines asked for are merged: **Sign in with Apple**
(4.8), **account deletion** in Me → Delete account (5.1.1(v)),
**report, block and filter** (1.2), and **Apple in-app purchase for
Premium** (3.1.1).

## In App Store Connect

Set up on 2026-10-17. The GA build **0.1.202610171131** (build
`1792236692`) is uploaded, processed and picked on the version's page;
its icon replaced App Store Connect's grid placeholder (the icon comes
from the build's `AppIcon`, the 1024 px `ios-marketing` one included;
there's no separate icon upload). Both subscriptions have their review
screenshot. What's left is the owner's: **Add for Review** on the
version's page and on each subscription (the first subscriptions go to
review with the app version), then **Submit for Review**.

### Apple accounts and signing

1. The paid **Apple Developer Program** ($99 a year; a free Personal
   Team can't distribute), team `LMX88986F3`. It's the only running cost
   here, and there's no cheaper way onto the App Store.
2. An **Apple Distribution** certificate: Xcode's automatic signing makes
   it on the first archive (Xcode → Settings → Accounts → the team →
   Manage Certificates otherwise). `IOS_DEVELOPMENT_TEAM` in `.env` is the
   paid team's ID ([platforms](platforms.md)).
3. The App ID **com.nu01.grigri** (Certificates, Identifiers & Profiles,
   "XC com nu01 grigri") has **Sign in with Apple** (primary App ID) and
   In-App Purchase. Adding a capability invalidates the provisioning
   profiles; automatic signing makes new ones.
4. The app record: **Grigri Climbing** (Apple ID `6823947725`; the name
   "Grigri" is taken on the App Store), primary language **English
   (U.S.)**, bundle ID **com.nu01.grigri**, SKU **grigri-ios**, full
   access. The home screen still says **Grigri** (the bundle's display
   name); only the store listing's name differs.
5. **Business**: the Free and Paid Apps agreements, the bank account and
   the tax forms are active, so Premium can be sold.

### App information

- **Subtitle**: `Join a climbing plan`.
- **Category**: **Sports** (primary), **Social Networking** (secondary).
  Climbing comes first; Sports keeps it away from dating apps.
- **Content rights**: contains third-party content, with the rights to
  it (the crag photos, credited; what climbers post).
- **Privacy policy URL**: https://grigri.nu01.com/privacy.html
- **Support URL**: https://grigri.nu01.com/support.html
- **Marketing URL** (optional): https://grigri.nu01.com/
- **Copyright**: 2026, the owner's name.
- **Price**: Free, available in all 175 countries or regions.
- **Subscriptions**: the group **Grigri Premium** with
  `com.nu01.grigri.premium.monthly` (1 month, $19.99) and
  `com.nu01.grigri.premium.yearly` (1 year upfront, $199.99; not
  Apple's "monthly with a 12-month commitment"), in all countries at
  Apple's converted prices, with English display names ("Grigri Premium
  (monthly)" / "(yearly)": "Advertise and find routes with the camera.")
  and review notes ([premium](premium.md)). They go to review with the
  first app version. Their review screenshot is the iOS Premium card
  (both App Store prices, the renewal terms, the policy and EULA links,
  Restore purchases), rendered offscreen with the app's fake App Store,
  since the sandbox doesn't sell products before their metadata is
  complete.
- **App Store Server Notifications**: the production and sandbox URLs
  are both `https://grigri.nu01.com/api/apple/notifications`.

### App Privacy questionnaire

Published. **Yes, we collect data**, and for each type below: **linked to
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

- Social media (plans spread to many people through the deck),
  advertising: **Yes**. Social media off for under-13s: **No** (that
  needs Apple's Declared Age Range API, which Grigri doesn't call).

Apple's answers-based rating is **13+**; it's **overridden to 16+**
(17+ on iOS before 26), to match the policy's "not for under-16s" and
the profile's age rule (16–99). Don't lower it by answering "No" to
chat.

### The version's page

Version **0.1.202610171131** (it must match the uploaded build's
version; change both together). The English copy is entered, as below,
with the support and marketing URLs and the copyright "2026 Julio
Machado Faerman". Keep to the "plans, not partners" wording
([README](README.md)):

- **Name**: Grigri Climbing
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
- **Screenshots**: App Store Connect now requires the **6.3-inch
  iPhone** set ("iPhone with Dynamic Island, medium display": **1206 ×
  2622** portrait, or 1179 × 2556) and scales it to the other iPhones;
  the 6.9-inch set (1320 × 2868) is optional. Five are up: Find (the
  deck, a demo plan with a credited crag photo), a group chat, a chat
  with join requests to answer, Plans, and the plan editor. They're the
  web app on the local stack, signed in as the made-up seed climber Sam
  Okoro, taken with Playwright at a 402 × 874 viewport and 3× scale.
  Use the demo showcase or made-up people only; no real climbers' names
  or faces.
- **What's New**: for later versions.

### Review notes and demo account

Entered on the version's page. Reviewers must be able to sign in and
see real plans:

- **Sign-in**: **Sign-in required** is off: reviewers sign in with
  Apple, so there's no demo account. If Apple asks for one, make a
  Google account for review only, sign in with it once on production,
  turn off its two-step verification, and give its email and password
  there.
- **What they'll see**: production's **demo showcase** (made-up
  climbers' plans around the world, [matching](matching.md)), so the
  deck isn't empty.
- **Notes**: how to sign in (Apple or Google, no demo account), the
  Find deck and its demo plans, swiping right and open plans, Report
  and Block (acted on within 24 hours), Me → Delete account, Premium by
  in-app purchase (Me → Grigri Premium), and the location rounded to
  about 1 km.
- **Contact**: Julio Machado Faerman, the owner's phone and
  julio@nu01.com.

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
