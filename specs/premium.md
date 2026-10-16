# Premium

**Status: planned, not built.** Nothing in the app, the API or the
infrastructure implements it yet; this file records the decisions made
so far.

## Price

| Plan | Price |
|---|---|
| Monthly | **$20** a month |
| Yearly | **$200** a year (two months free against monthly) |

## What it's for

Premium is **for advertisement only**: it changes what is advertised,
not what Grigri can do. Climbing, matching, chats and every feature stay
the same for everyone, premium or not.

Still to decide before building it (asked 2026-10-16, left for later):

- what "advertisement" means here: showing the Premium offer without
  selling it yet, premium users' plans promoted on others' decks, or
  premium removing ads that free users see;
- how it's paid (App Store and Google Play in-app subscriptions, and
  the web), and what each store's cut leaves;
- the prices in other currencies.

## Cost

Nothing yet. When it's built, payments should cost per transaction only
(store or processor fees), with no monthly minimum, in line with
[Backend's cost rules](backend.md#cost).
