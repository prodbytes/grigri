# Ads

[Premium](premium.md) climbers advertise on Grigri: their ads show on
everyone's **Discover** deck, between plans, once an admin approves them.
That's all Premium is for.

## An ad

A **link** (an absolute `https://` or `http://` web address with a host,
no credentials, at most 500 characters) and what's shown for it: **text**
(at most 200 characters, over the media) and a **photo or video** (a
JPEG, PNG or WebP photo up to 2 MB, or an MP4 or MOV video up to 50 MB,
as in chats), or text alone. It needs text or media.

It's `pending` when added, then `approved` or `rejected` by an admin
(who can change their mind either way). A climber keeps at most 20 ads.

## The Ads tab

A tab of its own in the bottom bar, **Ads** ("Anuncios", "Anzeigen",
"Pubs", "Anúncios", "Anuncis"), shown while I'm Premium, between Me and
Admin. It lists my ads, newest first: a thumbnail, the text (or the
link's site), the site, and its status ("Waiting for review",
"Approved: showing", "Rejected"), with **Delete** (after a confirmation;
the ad and its media are deleted for good). Empty: "No ads yet" and what
an ad does.

**New ad** opens the editor: the text over the ad, the link (checked as
the API does: "Enter a web address, starting with https://"), **Add a
photo or video** (the chat's picker: camera or gallery) and a **preview**
of its card as the deck shows it. **Send for review** uploads the media
(`POST /api/ads/media`, a presigned upload under `photos/ads/<my id>/`,
pending until the ad is saved), saves the ad (`POST /api/ads`), and says
"Sent: an admin will review it."

If my Premium ends, the tab goes away; my ads stay (they show again once
I renew) and stop showing on the deck at once.

## On the deck

`GET /api/discover` also answers `"ads": [Ad]` and `"adEvery": n`: the
approved ads whose owner is Premium and not blocked, never my own, the
most recently approved first (20 at most), and how often to show one.
The app puts an ad after every *n* plans **swiped**: it counts the plans
I've swiped since the last ad, so the next ad comes up as I go (it isn't
pushed further down each time). Ads I swiped this session don't come
back until ⟳; with no plans left, no ads either.

An ad's card fills with its photo (a video shows a play button and loads
only when played, in the chat's video viewer), with its text over a dark
fade, the link's site, "Ad by <name>", and an **Ad** tag. Dragging it
stamps **OPEN** and **SKIP**:

- right / ✓ ("Open the ad's link"): opens the link in the browser
  (`url_launcher`, outside the app);
- left / ✕ ("Skip the ad"): skips it;
- share: the ad's text and link.

## Admin → Ads

The [Admin](admin.md) tab has a sub-navigation: **Users** and **Ads**.
Ads shows:

- **On Discover**: how often the deck shows an ad, **No ads** or "An ad
  after every *n* plans" (1, 2, 3, 4, 5, 7, 10, 15, 20, 30 or 50; 5 by
  default), saved at once (`PUT /api/admin/ads/settings`);
- **Waiting for review** / **Approved: showing** / **Rejected**: the ads
  in that status, newest first, each with who placed it (tap for their
  profile), its full link, its card's preview, and **Approve** /
  **Reject**.

## API

| Route | Does |
|---|---|
| `GET /api/ads` | → `{"ads": [Ad], "premium": bool}`: mine, newest first |
| `POST /api/ads/media` | body `{"contentType"}` → `{"key", "url", "fields", "maxBytes"}` (Premium only, 403 otherwise) |
| `POST /api/ads` | body `{"text", "link", "media"?: {"key"}}` → `{"ad"}`, pending (Premium only; 400 for a bad link, text over 200, no content, or media not uploaded; 409 past 20 ads) |
| `DELETE /api/ads/{id}` | its owner or an admin: deletes it and its media → `{}` |
| `GET /api/admin/ads?status=pending\|approved\|rejected` | admins: → `{"ads", "climbers", "every"}` |
| `POST /api/admin/ads/{id}/approve`, `…/reject` | admins: → `{"ad"}` |
| `PUT /api/admin/ads/settings` | admins: body `{"every": 0–50}` → `{"every"}` (0: no ads) |

`Ad` = `{"id", "ownerId", "text", "link", "media"?: {"kind": "image"|"video", "key"}, "status", "createdAt", "reviewedAt"?}`.

## Data

In the app's table: an ad is `AD#<id>` / `AD`, indexed by status (gsi1,
`ADS#<status>`) and by owner (gsi2, `ADSBY#<ownerId>`), both sorted by
when it was added; the setting is `META#ADS` / `META` (`every`). Media is
in the photos bucket under `photos/ads/`, served at `/photos/ads/…`, and
expires a day after upload unless an ad uses it.

## Reports

Anyone can report an ad on the deck (its ⋮), or block its owner; admins
can remove a reported ad from Admin → Reports
([moderation.md](moderation.md)). Ads' text goes through the
[filter](moderation.md#the-filter). Ads of people with a block between
us don't show on my deck.

## Cost

Nothing while idle. Each deck adds two reads (the setting, one query of
the approved ads) plus a batch read of their owners' subscriptions and
profiles: about $0.0000005 per deck. Ad photos and videos cost what chat
media does (S3 storage and uploads); videos load only when someone plays
them, so the deck's ads cost no CloudFront transfer beyond their photos.
