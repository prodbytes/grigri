# Premium

**Status: partly built.** Who is premium is decided (an rbacr role) and
the first premium feature, the [route finder](route-finder.md), is built.
Paying for it isn't: premium is granted by hand for now.

## Who is premium

Whoever holds the `premium` role of rbacr's `grigri` system (granted in
rbacr, like `admin`), and every admin (and rbacr root). The API asks
rbacr with the roles lookup it already makes for `GET /api/me` (kept 60 s
per function instance), so a grant shows within a minute.
`GET /api/me` says `"premium": true|false`; premium routes answer 403
`premium only` to everyone else.

## Premium features

- The [route finder](route-finder.md): routes on the rock through the
  camera, and recording and learning them.

## Price

| Plan | Price |
|---|---|
| Monthly | **$20** a month |
| Yearly | **$200** a year (two months free against monthly) |

## What it's for

Premium was first meant to be for advertisement only (2026-10-16); the
route finder, asked for as premium only, is its first feature of its
own. Climbing, matching, chats and every other feature stay the same for
everyone.

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
