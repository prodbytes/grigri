# Premium

A subscription that lets a climber **advertise on Grigri** (their
[ads](ads.md)), use the **[route finder](route-finder.md)** (routes on
the rock through the camera) and make **[guided plans](matching.md#plan-types-who-decides)**
(a guide's paid outing). Everything else stays the same for
everyone, Premium or not: climbing, matching, chats, every other
feature. Admins get both without subscribing.

## Two ways to pay

| Platform | Sold by | Bought in | Managed in |
|---|---|---|---|
| Android, the web | **Stripe** | Stripe Checkout, in the browser | Stripe's billing portal |
| iOS | **The App Store** (in-app purchase, auto-renewable subscriptions) | StoreKit's purchase sheet, in the app | the App Store's subscriptions (Settings → Apple ID → Subscriptions) |

Apple's App Store guideline 3.1.1 requires digital subscriptions bought
in an iOS app to go through Apple's in-app purchase, so the iOS app
never shows Stripe: no Checkout link, no mention, no "I've paid" button.
Either way the subscription is the same Premium: one billing item per
climber in Grigri, rbacr's `premium` role (below), the same features. A
climber subscribed on one platform is Premium on all of them.

## Price

| Plan | Stripe (Android, web) | App Store (iOS) |
|---|---|---|
| Monthly | **$20** a month | **$19.99** a month |
| Yearly | **$200** a year (two months free against monthly) | **$199.99** a year |

Stripe's prices are in US dollars only, for now; they live in one place,
`PREMIUM_PRICES` in [premium.ts](../grigri_api/src/premium.ts), and the
Android and web app shows what `GET /api/premium` says. The App Store's
are set in App Store Connect (Apple's price points mostly end in .99;
$19.99 and $199.99 are the nearest to $20 and $200), and Apple converts
them for every other storefront; the iOS app shows the App Store's own
localized prices, from StoreKit.

What Grigri keeps: Stripe takes 2.9% + $0.30 per charge plus 0.7%
(Billing), about $0.88 of a $20 month and $6.50 of a $200 year. **Apple
takes 15%** under its App Store Small Business Program (under $1 million
a year in proceeds; enroll in App Store Connect), **30% otherwise** (15%
anyway on a subscriber's renewals after their first paid year): about
$3.00 of a $19.99 month and $30.00 of a $199.99 year at 15%. Apple is the
merchant of record: it charges the buyer's sales tax and VAT itself.

## Paying on Android and the web: Stripe

Payments are **Stripe's**: Stripe Checkout takes the payment and Stripe's
billing portal handles cancelling, cards and invoices, both on Stripe's
own pages in the browser. No card ever reaches Grigri. The API talks to
Stripe's REST API directly ([stripe.ts](../grigri_api/src/stripe.ts), no
SDK).

1. **Profile → Grigri Premium** shows the pitch and the two prices
   ("$20 a month", "$200 a year"). Tapping one asks
   `POST /api/premium/checkout {"plan"}` for a Checkout page (a
   subscription at the plan's price, with my climber id in the
   subscription's metadata) and opens it in the browser.
2. Stripe sends me back to `<site>/app/premium.html` (a static page:
   "switch back to the Grigri app"). On a phone I switch back myself.
3. Stripe tells the API through its **webhook**,
   `POST /api/stripe/webhook`: the API checks the event's signature
   (the endpoint's signing secret, 5 minutes' tolerance), then reads the
   subscription the event is about back from Stripe and saves that copy,
   so it's always Stripe's latest whatever order events arrive in. An
   older subscription's late event never overwrites a newer paid one.
   Subscriptions without Grigri's metadata (other products on the
   account) are ignored.
4. The app reads Premium again when it comes back to the foreground, when
   the Profile tab opens, and on **I've paid: check again**.

Subscribed, the card says "Premium: renews on <date>" (or "ends on <date>"
once cancelled) and offers **Manage subscription**: Stripe's billing
portal (`POST /api/premium/portal`), to cancel or change the card.

Without Stripe's keys on a stage, Premium can't be bought through Stripe:
the Android and web card says "Premium isn't available yet." and the
Stripe routes answer 503.

**Deleting my account** ([sign-in.md](sign-in.md#deleting-my-account))
cancels the subscription **at once** (Stripe's `DELETE
/v1/subscriptions/{id}`: no more charges, no refund of the period
already paid) and revokes the role, before anything else is deleted;
Stripe's later events about it are ignored, so nothing of the deleted
account is saved again. An **App Store** subscription can't be cancelled
by Grigri: the confirmation says to cancel it in iOS Settings, and the
deletion unties it from the account (`APPLE#<originalTransactionId>`
goes), so a new account can restore it; its later notifications find no
account and are ignored.

## Paying on iOS: the App Store

Two **auto-renewable subscriptions** in one subscription group, "Grigri
Premium": `com.nu01.grigri.premium.monthly` and
`com.nu01.grigri.premium.yearly` (bundle id `com.nu01.grigri`). The app
uses Flutter's [in_app_purchase](https://pub.dev/packages/in_app_purchase)
plugin (StoreKit 2), behind a small interface
([app_store.dart](../grigri_app/lib/data/app_store.dart)) so the widget
tests use a fake store.

1. **Profile → Grigri Premium** asks StoreKit for the two products and
   shows their **localized prices** ("$19.99 a month", "$199.99 a year").
   Next to the buttons are the subscription's terms Apple requires: that
   it's an auto-renewing subscription, each plan's price and period,
   charged to the Apple ID, renewing unless cancelled at least 24 hours
   before the period ends, managed and cancelled in the App Store account
   settings; and links to the **Privacy policy**
   (`https://grigri.nu01.com/privacy.html`) and the **Terms of use
   (EULA)**, Apple's standard one
   (`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`).
   **Restore purchases** is always there. If StoreKit can't load the
   products (no App Store, products not approved yet), the card says "The
   App Store can't be reached right now." with **Try again** and
   **Restore purchases**, and no buy buttons.
2. Tapping a price buys it through StoreKit's sheet, with the
   **appAccountToken** set to my account's: a UUID the API derives from
   my climber id (SHA-256, as a version 8 UUID) and gives in
   `GET /api/premium` as `appleAccountToken`. Every transaction of the
   subscription carries it, so the API knows whose it is.
3. The app sends the **signed transaction** (StoreKit 2's
   `jwsRepresentation`, which the plugin gives as
   `verificationData.serverVerificationData`) to
   `POST /api/premium/apple`, and only once the API has it **finishes**
   the transaction. A transaction the API can never take (another
   account's, not Grigri's) is finished too, with the API's message; one
   that failed on the way (offline, a server error) is left unfinished,
   and StoreKit hands it over again at the next launch. Renewals StoreKit
   reports while the app runs go the same way.
4. **Restore purchases** asks StoreKit for my current subscriptions and
   sends them the same way (say on a new phone); "No App Store
   subscription to restore." when none makes me Premium.
5. The App Store tells the API through **App Store Server Notifications
   V2**, `POST /api/apple/notifications`: renewals, lapses, refunds,
   cancellations.

Subscribed, the card says "Premium: renews on <date>" (or "ends on
<date>" once auto-renewal is off) and **Manage subscription** opens
`https://apps.apple.com/account/subscriptions` (on any platform, for a
subscription bought in the App Store). A subscription bought through
Stripe shows on iOS without a manage link (it's managed on Android or the
web).

### Verifying Apple's signatures

Both the app's transactions and the notifications are JWS signed by
Apple; the API verifies them **offline**, the way Apple's
app-store-server-library does, with `node:crypto` only (no App Store
Server API call, no key, no new dependency;
[app-store.ts](../grigri_api/src/app-store.ts)):

- the header's `alg` is `ES256` (nothing else: no `none`, no HMAC), it
  has no `crit`, and its `x5c` holds exactly three certificates;
- the intermediate is issued and signed by **Apple Root CA - G3**, the
  only trusted root, embedded in
  [apple-root.ts](../grigri_api/src/apple-root.ts) (public, from
  `https://www.apple.com/certificateauthority/AppleRootCA-G3.cer`; a test
  checks its SHA-256 fingerprint), whatever `x5c[2]` says; the
  intermediate is a CA; the leaf is issued and signed by the intermediate;
- the leaf carries Apple's OID `1.2.840.113635.100.6.11.1` and the
  intermediate `1.2.840.113635.100.6.2.1`;
- all three certificates were valid when Apple signed it (the payload's
  `signedDate`);
- the signature verifies with the leaf's P-256 key.

Then the transaction must be Grigri's: `bundleId` `com.nu01.grigri`, one
of the two product ids, an auto-renewable subscription, `environment`
`Production` or `Sandbox`. **Sandbox is accepted** (App Review and
TestFlight buy in the sandbox, against the production API) and recorded
on the subscription; sandbox subscriptions renew every few minutes and
stop after a few renewals.

### Whose a subscription is

- `POST /api/premium/apple` takes a transaction only with **my**
  appAccountToken (409 otherwise: bought from another Grigri account, or
  without one).
- The first time Grigri sees a subscription (its
  `originalTransactionId`, the same across renewals and resubscribes) it
  **ties it to that climber**, once (`APPLE#<originalTransactionId>`,
  a conditional write). Another account sending it later gets 409, even
  with its own token (the same Apple ID buying again from a second Grigri
  account): one subscription, one account.
- A notification about a subscription Grigri doesn't know yet is
  acknowledged and left (the app sends the transaction itself); one whose
  token isn't its owner's is ignored.

### Keeping it in step

The saved copy is `source: "apple"`, the subscription id is the
`originalTransactionId`, no Stripe customer, and its status in Stripe's
words, so `premiumOf`, `isPaid` and rbacr's grants work unchanged:

| Apple says | Saved as |
|---|---|
| a transaction not yet expired (status 1) | `active` until `expiresDate` |
| billing retry (3) or billing grace period (4) | `past_due`, until the grace period's end if any |
| expired (2), `EXPIRED`, `GRACE_PERIOD_EXPIRED` | `expired` |
| refunded or revoked (5, a `revocationDate`), `REFUND`, `REVOKE` | `canceled` |

`autoRenewStatus` 0 in the renewal info (`DID_CHANGE_RENEWAL_STATUS`)
marks it ending at `expiresDate`. Notifications handled: `SUBSCRIBED`,
`DID_RENEW`, `DID_CHANGE_RENEWAL_STATUS`, `DID_FAIL_TO_RENEW`, `EXPIRED`,
`GRACE_PERIOD_EXPIRED`, `REFUND`, `REVOKE` (others carrying a transaction,
like `DID_CHANGE_RENEWAL_PREF`, update it from the signed data the same
way; `TEST` and other apps' are acknowledged and ignored).

Out of order and twice: each saved copy keeps when Apple signed it
(`appleSignedAt`: the notification's `signedDate`, or the transaction's
for the app's); an older one never overwrites it, and the same one again
changes nothing. As with Stripe, another subscription's lapse never
overwrites a paid one. A failure to update rbacr answers 500, so Apple
sends the notification again (it retries for a few days).

## Who is Premium

Whoever holds the `premium` role of rbacr's `grigri` system
(`premium-rc` on the RC, which asks production's rbacr too, so its
test-mode payments never make anyone Premium on production). Like every
role, it's [rbacr's](roles.md); Grigri keeps only the billing.

- **Paying grants it**: the Stripe webhook, or the App Store's
  transaction or notification, after saving the latest copy of the
  subscription, grants the role to the subscriber's verified email (Stripe:
  from checkout, in the subscription's metadata, also prefilled in
  Checkout; the App Store: the buyer's session, or the one Grigri keeps)
  until the paid period's end plus two days' grace, while it's paid
  (`active`, `trialing` or `past_due`). Each renewal moves the end; a
  cancelled subscription keeps it to the end of the period paid for; once
  it's over (or ended at once, a refund), the role is revoked. If rbacr
  fails, the webhook or notification answers 500, and Stripe or Apple
  sends it again.
- **Admins** hold it too: rbacr's `admin` implies `premium` and
  `premium-rc`. Roots hold every role. A root can also grant `premium`
  in rbacr by hand (a comp); a later payment by the same email replaces
  that grant's end with the paid period's.
- **Checks**: the API asks rbacr for the caller's roles (kept a minute
  per function instance; `GET /api/premium` asks afresh, so **I've paid:
  check again** sees a payment at once, and so does the iOS app after
  `POST /api/premium/apple`). Ad owners in the deck are checked by their
  kept emails. Making a plan guided (`POST /api/plans`, or a `PUT` that
  changes its type to guided) checks the caller the same way: 403 "guided
  plans are for Premium climbers" without it. A plan that's guided
  already stays editable once Premium ends. Checkout needs a verified email (Google's always is).

## Data

In rbacr, the role (above). In Grigri, one billing item per climber,
`CLIMBER#<id>` / `PREMIUM`: who sells it (`source`, absent for Stripe's
from before), Stripe's customer and subscription ids or the App Store's
original transaction id, its status, plan, period end, whether it's
cancelled, the subscriber's email, when it was read, and for the App
Store its environment and when Apple signed it. One climber has one at a
time: the newest paid one wins. And for the App Store, who each
subscription belongs to: `APPLE#<originalTransactionId>` / `APPLE`
(`climberId`). `GET /api/me` and `GET /api/premium` answer
`"premium": {"active", "plan"?, "until"?, "ending"?, "source"?}`:
`active` is the role; `plan`, `until`, `ending` and `source` (`stripe` or
`apple`) come from a paid subscription (none for admins, or a comp).

## Keys and setup

### Stripe

- `GRIGRI_STRIPE_SECRET_KEY` (a secret key, `sk_live_…`/`sk_test_…`, or a
  restricted one, `rk_…`, with write access to Checkout Sessions,
  Customer portal and Subscriptions, to cancel one when an account is
  deleted) and
  `GRIGRI_STRIPE_WEBHOOK_SECRET` (`whsec_…`): repository secrets for
  production (live mode), `GRIGRI_STRIPE_SECRET_KEY_RC` and
  `GRIGRI_STRIPE_WEBHOOK_SECRET_RC` for the RC (test mode); `.env` for
  local (test mode). [deploy.sh](../scripts/deploy.sh) passes them to the
  API stack (`StripeSecretKey`, `StripeWebhookSecret`, no-echo) with
  `SiteUrl`, the stage's site. Without both: no Premium through Stripe (a
  warning).
- In Stripe, per mode: a **webhook endpoint** at
  `https://<site>/api/stripe/webhook` for `checkout.session.completed`,
  `customer.subscription.created`, `customer.subscription.updated`,
  `customer.subscription.deleted`, `invoice.paid` and
  `invoice.payment_failed`; and the **customer portal** turned on
  (Settings → Billing → Customer portal), allowing cancellation.
- Locally, Stripe can't reach Floci: `stripe listen --forward-to
  https://local.grigri.nu01.com:2543/api/stripe/webhook` forwards test
  events (its `whsec_…` goes in `.env`).

### The App Store

No keys or secrets: the API trusts Apple's root certificate, in the code.
What the owner sets up in **App Store Connect** (all done on 2026-10-17
except the review screenshots and the localizations other than English;
see [app-store](app-store.md)):

1. **Agreements, Tax, and Banking**: accept the **Paid Applications**
   agreement and fill in the bank account and tax forms (nothing can be
   sold before). Optionally enroll in the **App Store Small Business
   Program** (15% instead of 30%).
2. **The app → Monetization → Subscriptions**: a subscription group
   **Grigri Premium**, with two auto-renewable subscriptions:
   `com.nu01.grigri.premium.monthly` (1 month, $19.99) and
   `com.nu01.grigri.premium.yearly` (1 year, $199.99), each with its
   availability (all storefronts) and Apple's converted prices.
3. For the group and each subscription, **localizations** (display name
   and description) in English, Spanish, German, French, Portuguese and
   Catalan, as the app speaks: e.g. "Grigri Premium (monthly)": "Advertise
   on Grigri and find routes on the rock with the camera."
4. For each subscription, a **review screenshot** of the paywall (the
   Profile tab's Grigri Premium card on an iPhone) and review notes; the
   first subscriptions are submitted for review **with an app version**.
5. **App Information → App Store Server Notifications**: Version 2, the
   **Production Server URL**
   `https://grigri.nu01.com/api/apple/notifications` and the **Sandbox
   Server URL** the same (App Review and TestFlight buy in the sandbox
   against production). To test the RC's renewals, point the sandbox URL
   at `https://rc.grigri.nu01.com/api/apple/notifications` for a while.
   Each stage acknowledges and ignores subscriptions it doesn't know. The
   "Request a Test Notification" button sends a `TEST`, which the API
   acknowledges.
6. **Users and Access → Sandbox → Test Accounts**: sandbox Apple IDs, to
   buy without paying on a device (Settings → App Store → Sandbox
   Account), or in Xcode with a StoreKit configuration file.
7. The App ID `com.nu01.grigri` has In-App Purchase enabled (it is by
   default; no entitlement needed).

The privacy policy page (`https://grigri.nu01.com/privacy.html`) must
exist; the store listing links it too.

## Cost

Nothing while idle: no monthly fee, no new AWS resource (the same Lambda,
the same table). Per payment, Stripe's or Apple's share (see Price): the
App Store's is the dearest way to sell, but it is the only one Apple
allows in the iOS app. On AWS, a webhook, a notification, a transaction
or a checkout is one Lambda call and a read and a write or two (an App
Store subscription adds one small item, written once): well under a cent
a month at any likely volume. The App Store's signatures are verified in
the function, offline (a millisecond of CPU), so no App Store Server API
call, no key to keep, and nothing to pay for verification. Stripe is the
cheapest option that meets the rest: Paddle and Lemon Squeezy (merchants
of record) take 5% + $0.50; the App Store and Google Play take 15–30%
(Google Play's billing rule for Android is to revisit before publishing
there).
