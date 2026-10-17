# Ads

[Premium](premium.md) climbers advertise on Grigri: their ads show on
everyone's **Discover** deck, between plans, once an admin approves them.
That's all Premium is for.

## An ad

A **link** (an absolute `https://` or `http://` web address with a host,
no credentials, at most 500 characters) and what's shown for it: **text**
(at most 200 characters, over the media) and a **photo or video** (a
JPEG, PNG or WebP photo up to 2 MB, or an MP4 or MOV video up to 50 MB,
as in chats), or text alone. It needs text or media. It can be limited
to **regions** (see [Regions](#regions)); without any, it shows
everywhere.

It's `pending` when added, then `approved` or `rejected` by an admin
(who can change their mind either way). A climber keeps at most 20 ads.

## The Ads tab

A tab of its own in the bottom bar, **Ads** ("Anuncios", "Anzeigen",
"Pubs", "Anúncios", "Anuncis"), shown while I'm Premium, after
Alerts and before Admin and Me. It lists my ads, newest first: a thumbnail, the text (or the
link's site), the site, where it shows ("Shows in Siurana, España" or
"Shows everywhere"), and its status ("Waiting for review",
"Approved: showing", "Rejected"), with **Delete** (after a confirmation;
the ad and its media are deleted for good). Empty: "No ads yet" and what
an ad does.

**New ad** opens the editor: the text over the ad, the link (checked as
the API does: "Enter a web address, starting with https://"), **Add a
photo or video** (the chat's picker: camera or gallery), **Where it
shows** (its regions, as chips with ✕, and **Add a region**; none:
"Everywhere") and a **preview** of its card as the deck shows it. **Send for review** uploads the media
(`POST /api/ads/media`, a presigned upload under `photos/ads/<my id>/`,
pending until the ad is saved), saves the ad (`POST /api/ads`), and says
"Sent: an admin will review it."

If my Premium ends, the tab goes away; my ads stay (they show again once
I renew) and stop showing on the deck at once.

## Regions

An advertiser picks where an ad shows: a whole country (Spain), a region
(Catalonia) or a town (Siurana), up to 10. **Add a region** opens a
search ("Country, region or town"): it searches when I press search
(never as I type), lists what it finds with each place's full name, to
tell two Siuranas apart, and credits "© OpenStreetMap contributors".
Picking one adds it.

The search is OpenStreetMap's Nominatim, through the API
(`GET /api/places`, Premium only): free, with no key; the API identifies
itself as Grigri, as Nominatim's terms ask, and climbers' addresses
never reach it. A place found is a short name ("Siurana, España"; a
country by its name alone), in the app's language where it can be, and
its bounding box.

An ad keeps each region's name and box (names go through the
[filter](moderation.md#the-filter), as its text does). The deck widens each box on
every side by **50 km, or a tenth of its size when that's more**, so it
reaches a bit further, to be sure: Siurana's reaches Cornudella, Reus and
Tarragona (not Barcelona, about 100 km away), and Spain's reaches just
over its borders (Perpignan, not Paris). Boxes across the antimeridian
work too.

## On the deck

`GET /api/discover` also answers `"ads": [Ad]` and `"adEvery": n`: the
approved ads whose owner is Premium (or the showcase's made-up advertiser,
see [Sample ads](#sample-ads)) and not blocked, never my own, never one
I skipped, only ones that [reach](#regions) my profile's location or one
of my areas (an ad without regions reaches everyone; with regions, it
never reaches someone who set neither), the most recently approved first (20 at most), and how often
to show one. The app puts an ad after about every *n* plans **swiped**:
each gap is *n* give or take 30% (rounded down; at least 1), drawn at
random as the deck needs it and kept until that ad is swiped, so the
deck doesn't reshuffle. With the default of 10, an ad comes after 7 to 13
plans. It counts the plans I've swiped since the last ad, so the next ad
comes up as I go (it isn't pushed further down each time). An ad I
opened doesn't come back until ⟳; with no plans left, no ads either.

An ad's card fills with its photo (a video shows a play button and loads
only when played, in the chat's video viewer), with its text over a dark
fade, the link's site, "Ad by <name>", and an **Ad** tag. Dragging it
stamps **OPEN** and **SKIP**:

- right / ✓ ("Open the ad's link"): opens the link in the browser
  (`url_launcher`, outside the app);
- left / ✕ ("Skip the ad"): skips it **for good**: it never shows to me
  again, on any device, even after ⟳ (`POST /api/ads/{id}/skip`, kept
  as `CLIMBER#<me>` / `ADSKIP#<ad id>`; if saving fails it still stays
  off this deck until I sign out);
- share: the ad's text and link.

## Admin → Ads

The [Admin](admin.md) tab has a sub-navigation: **Users** and **Ads**.
Ads shows:

- **On Discover**: how often the deck shows an ad, **No ads** or "An ad
  after every *n* plans" (1, 2, 3, 4, 5, 7, 10, 15, 20, 30 or 50; 10 by
  default), saved at once (`PUT /api/admin/ads/settings`); the deck
  varies each gap a little around it;
- **Waiting for review** / **Approved: showing** / **Rejected**: the ads
  in that status, newest first, each with who placed it (tap for their
  profile), its full link, where it shows, its card's preview, and **Approve** /
  **Reject**.

## API

| Route | Does |
|---|---|
| `GET /api/ads` | → `{"ads": [Ad], "premium": bool}`: mine, newest first |
| `POST /api/ads/media` | body `{"contentType"}` → `{"key", "url", "fields", "maxBytes"}` (Premium only, 403 otherwise) |
| `POST /api/ads` | body `{"text", "link", "media"?: {"key"}, "regions"?: [Region]}` → `{"ad"}`, pending (Premium only; 400 for a bad link, text over 200, no content, media not uploaded, or bad regions: over 10, a name missing or over 120 characters, or a box out of range or with its south north of its north; 409 past 20 ads) |
| `GET /api/places?q=&lang=` | Premium only: places named like `q` (2–100 characters), named in `lang` where they can be → `{"places": [Region + "label"]}` (8 at most; `label` is the full name); 503 when the search doesn't answer |
| `DELETE /api/ads/{id}` | its owner or an admin: deletes it and its media → `{}` |
| `POST /api/ads/{id}/skip` | I skipped it on the deck: never on my deck again (one write, no read; 400 for a bad id) → `{}` |
| `GET /api/admin/ads?status=pending\|approved\|rejected` | admins: → `{"ads", "climbers", "every"}` |
| `POST /api/admin/ads/{id}/approve`, `…/reject` | admins: → `{"ad"}` |
| `PUT /api/admin/ads/settings` | admins: body `{"every": 0–50}` → `{"every"}` (0: no ads) |

`Ad` = `{"id", "ownerId", "text", "link", "media"?: {"kind": "image"|"video", "key"}, "regions"?: [Region], "status", "createdAt", "reviewedAt"?}`;
`Region` = `{"name", "south", "west", "north", "east"}` (degrees; `west` > `east` across the antimeridian).

## Sample ads

Every stage, production included, has sample ads from a made-up
advertiser account, **Climbing Siurana** (`seed-climbing-siurana`, a demo
profile), written with the [demo showcase](backend.md#the-demo-showcase)
([seed/ads.ts](../grigri_api/seed/ads.ts)): four approved ads for the climbing school at
https://www.climbingsiurana.com/en/, each linking to its page there:

- a guided climbing day in Siurana (from 65€), shown around Siurana;
- "From the gym to the rock", a five-day course (from 450€), around
  Siurana;
- a sport climbing camp in Margalef, with coaching (from 490€), around
  Margalef;
- the via ferrata at La Morera de Montsant (from 45€), around La Morera.

Their regions are OpenStreetMap's boxes for those villages, so they show
to climbers in the Priorat and the Costa Daurada.

Their photos are the school's own: the showcase downloads each from the
school's site and puts it in the photos bucket at
`photos/ads/seed-climbing-siurana/<name>.<ext>`, never tagged pending,
once: an ad already saved with its photo isn't copied again. If a photo
can't be copied, that ad is saved with its text alone, and the copy is
tried again the next time the showcase is written. Rewriting a sample ad
keeps its status (an admin can reject one, and it stays rejected) and
its dates, so it never moves ahead of real advertisers' ads. A demo
owner advertises without Premium; real climbers still need it.

## Data

In the app's table: an ad is `AD#<id>` / `AD`, indexed by status (gsi1,
`ADS#<status>`) and by owner (gsi2, `ADSBY#<ownerId>`), both sorted by
when it was added; the setting is `META#ADS` / `META` (`every`); an ad I
skipped is `CLIMBER#<me>` / `ADSKIP#<ad id>`, deleted with my account. Media is
in the photos bucket under `photos/ads/`, served at `/photos/ads/…`, and
expires a day after upload unless an ad uses it.

## Reports

Anyone can report an ad on the deck (its ⋮), or block its owner; admins
can remove a reported ad from Admin → Reports
([moderation.md](moderation.md)). Ads' text goes through the
[filter](moderation.md#the-filter). Ads of people with a block between
us don't show on my deck.

## Cost

The place search is free (Nominatim) and costs a Lambda call per search,
only when an advertiser presses search. Regions are a few numbers in the
ad's item; checking them is arithmetic on ads the deck already reads.

Nothing while idle. Each deck adds three reads (the setting, one query of
the approved ads, one query of the ads I skipped) plus a batch read of
their owners' subscriptions and profiles: about $0.0000006 per deck. A
skip is one write ($0.000000625). The skips sit in DynamoDB rather than
on the device so they hold on every device I use; they cost a few bytes
each. The sample ads' four photos (about 1 MB) sit in each stage's
photos bucket: a fraction of a cent a month. Ad photos and videos cost what chat
media does (S3 storage and uploads); videos load only when someone plays
them, so the deck's ads cost no CloudFront transfer beyond their photos.
