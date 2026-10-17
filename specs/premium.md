# Premium

A subscription that lets a climber **advertise on Grigri** (their
[ads](ads.md)) and use the **[route finder](route-finder.md)** (routes on
the rock through the camera). Everything else stays the same for
everyone, Premium or not: climbing, matching, chats, every other
feature. Admins get both without subscribing.

## Price

| Plan | Price |
|---|---|
| Monthly | **$20** a month |
| Yearly | **$200** a year (two months free against monthly) |

In US dollars only, for now. The prices live in one place,
`PREMIUM_PRICES` in [premium.ts](../grigri_api/src/premium.ts); the app
shows what `GET /api/premium` says.

## Paying: Stripe

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

**Deleting my account** ([sign-in.md](sign-in.md#deleting-my-account))
cancels the subscription **at once** (Stripe's `DELETE
/v1/subscriptions/{id}`: no more charges, no refund of the period
already paid) and revokes the role, before anything else is deleted;
Stripe's later events about it are ignored, so nothing of the deleted
account is saved again.

**Who is Premium**: whoever holds the `premium` role of rbacr's `grigri`
system (`premium-rc` on the RC, which asks production's rbacr too, so
its test-mode payments never make anyone Premium on production). Like
every role, it's [rbacr's](roles.md); Grigri keeps only the billing.

- **Paying grants it**: the webhook, after saving Stripe's latest copy
  of the subscription, grants the role to the subscriber's verified
  email (from checkout, in the subscription's metadata, also prefilled
  in Checkout) until the paid period's end plus two days' grace, while
  Stripe says `active`, `trialing` or `past_due` (a failed renewal
  Stripe is still retrying). Each renewal moves the end; a cancelled
  subscription keeps it to the end of the period paid for; once it's
  over (or ended at once), the role is revoked. If rbacr fails, the
  webhook answers 500, and Stripe sends the event again.
- **Admins** hold it too: rbacr's `admin` implies `premium` and
  `premium-rc`. Roots hold every role. A root can also grant `premium`
  in rbacr by hand (a comp); a later payment by the same email replaces
  that grant's end with the paid period's.
- **Checks**: the API asks rbacr for the caller's roles (kept a minute
  per function instance; `GET /api/premium` asks afresh, so **I've paid:
  check again** sees a payment at once). Ad owners in the deck are
  checked by their kept emails. Checkout needs a verified email (Google's
  always is).

Without Stripe's keys on a stage, Premium can't be bought: the card says
"Premium isn't available yet." and the routes answer 503.

**Apple's rules**: App Store builds may have to sell this through Apple's
in-app purchase instead of a link to Stripe; the phone builds installed
from Xcode don't go through review. To revisit before publishing on the
App Store (Google Play has a similar rule).

## Data

In rbacr, the role (above). In Grigri, one billing item per climber,
`CLIMBER#<id>` / `PREMIUM`: Stripe's customer and subscription ids, its
status, plan, period end, whether it's cancelled, the subscriber's email,
and when it was read. `GET /api/me` and `GET /api/premium` answer
`"premium": {"active", "plan"?, "until"?, "ending"?}`: `active` is the
role; `plan`, `until` and `ending` come from a paid subscription (none
for admins, or a comp).

## Keys and setup

- `GRIGRI_STRIPE_SECRET_KEY` (a secret key, `sk_live_…`/`sk_test_…`, or a
  restricted one, `rk_…`, with write access to Checkout Sessions,
  Customer portal and Subscriptions, to cancel one when an account is
  deleted) and
  `GRIGRI_STRIPE_WEBHOOK_SECRET` (`whsec_…`): repository secrets for
  production (live mode), `GRIGRI_STRIPE_SECRET_KEY_RC` and
  `GRIGRI_STRIPE_WEBHOOK_SECRET_RC` for the RC (test mode); `.env` for
  local (test mode). [deploy.sh](../scripts/deploy.sh) passes them to the
  API stack (`StripeSecretKey`, `StripeWebhookSecret`, no-echo) with
  `SiteUrl`, the stage's site. Without both: no Premium (a warning).
- In Stripe, per mode: a **webhook endpoint** at
  `https://<site>/api/stripe/webhook` for `checkout.session.completed`,
  `customer.subscription.created`, `customer.subscription.updated`,
  `customer.subscription.deleted`, `invoice.paid` and
  `invoice.payment_failed`; and the **customer portal** turned on
  (Settings → Billing → Customer portal), allowing cancellation.
- Locally, Stripe can't reach Floci: `stripe listen --forward-to
  https://local.grigri.nu01.com:2543/api/stripe/webhook` forwards test
  events (its `whsec_…` goes in `.env`).

## Cost

Nothing while idle: no monthly fee, no new AWS resource. Per payment,
Stripe's fees: 2.9% + $0.30 per card charge, plus Stripe Billing's 0.7%
of subscription volume (pay as you go): about $0.88 of a $20 month, $6.50
of a $200 year. On AWS, a webhook or a checkout is one Lambda call and a
read and a write or two: well under a cent a month at any likely volume.
Stripe is the cheapest option that meets it: Paddle and Lemon Squeezy
(merchants of record) take 5% + $0.50; the App Store and Google Play
take 15–30%.
