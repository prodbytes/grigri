# Moderation

What keeps Grigri's people-made content in check, as Apple's App Store
guideline 1.2 (user-generated content) asks: a **filter** on what people
post, a way to **report** anything objectionable and admins who answer
reports **within 24 hours**, and a way for anyone to **block** someone.
Grigri's contact address is published on its support pages.

Content people make: profiles (name, photo, bio, gear photos), plans
(place typed by hand, notes), group chats (text, photos, videos), plan
photos (Your Pics) and Premium climbers' [ads](ads.md).

## The filter

The API refuses text with a slur or an explicit sexual term, with a 400
whose message starts `objectionable:` and names the field ("objectionable:
bio has words Grigri doesn't allow; please keep it friendly"). The app
shows its own words for it, in the user's language: "Please keep it
friendly: that has words Grigri doesn't allow."

- **What it checks**: the profile's name and bio (`PUT /api/me`), a plan's
  notes and, when typed by hand (no `sectorId`), its place and area
  (`POST`/`PUT /api/plans`), chat messages' text (the
  [Grigri team chat](team-chat.md)'s too, both ways), and ads' text.
- **How**: a small word list in
  [filter.ts](../grigri_api/src/domain/filter.ts), a few words each in
  English, Spanish, German, French, Portuguese and Catalan. It matches
  **whole words** ("class" and "Scunthorpe" pass), ignoring case and
  accents ("MARICÓN"), with letters repeated ("fuuuck"), a plural "s",
  common leetspeak ("$lut", "n1gger"; read both with and without it, so
  "Schlampe!" is still caught), and letters spaced or dotted out
  ("f u c k", "p.u.t.a").
- **Keeping the list**: words go in plain, lowercase and without accents.
  Words innocent in another of the six languages stay out (Catalan
  "negre" is "black", Portuguese "pede" is "asks", Catalan "polla" a
  young hen, French "retard" a delay, Spanish "Kike" a name, and English
  "bite", "chink" and "spic" are everyday words), and so does mild
  swearing. Tests check that every listed word is caught and that
  ordinary climbing talk in each language passes.
- **Photos and videos aren't machine-filtered**: reports and admins'
  removal cover them. If that's ever not enough, the cheapest option
  would be Amazon Rekognition's `DetectModerationLabels` on new uploads
  only (about $0.001 per image, nothing while idle, called from the API
  when a photo is kept); videos would cost far more per minute, so they'd
  stay on reports. Not built.

## Reporting

Any signed-in climber can **Report** a profile, a plan, a chat message,
a plan photo or an ad, from:

- the ⋮ on a **profile sheet** (Report and Block),
- the ⋮ on the **plan screen** (on others' plans; the Discover card has
  none: tapping its organizer opens their profile sheet, with Report and
  Block),
- the ⋮ on an **ad** on the deck,
- the ⋮ on a **join request card** in a chat (their profile),
- a **long press on a chat message** (someone else's): Report or Block.

Nothing of my own has the menu (the API refuses reporting my own, 400).
Reporting asks why: **Spam**, **Harassment**, **Inappropriate content**,
**Fake profile** or **Other**, and "Anything else we should know?"
(optional, up to 500 characters); **Send report** thanks me: "Thanks,
we'll review it within 24 hours."

- `POST /api/reports` `{kind: "profile"|"plan"|"message"|"pic"|"ad",
  targetId, planId? (a message's or photo's), reason:
  "spam"|"harassment"|"inappropriate"|"fake"|"other", text?}` → `{}`.
  I must be able to see it: a chat message or plan photo only as a
  member of its plan (403), and it must exist (404). The chat's own notes
  can't be reported (400).
- The report keeps a **copy of the content** (a profile's name, bio and
  photos; a plan's place and notes; a message's text and attachment; a
  photo; an ad's text, link and media), so the admin sees what was
  reported even if it changes, and **whose** it is (the profile's
  climber, the organizer, the author, who added the photo, the ad's
  owner).
- Reporting the same thing again replaces my report (its id comes from
  me and the content), so nobody floods the list.
- The reported person is never told, and nobody but admins sees who
  reported what.

## Answering reports (admins)

**Admin → Reports** ([admin.md](admin.md)), next to Users and Ads, lists
the open reports, oldest first: what kind and why, when, whose it is
(avatar and name; tap for their profile), "Reported by <name>", the
reporter's words, and the content as it was (its text, link and photos;
a video as an icon). Each has:

- **Dismiss**: nothing wrong; it closes.
- **Remove content**: a chat message is deleted with its photo or video
  (and the plan photo it made); a plan photo is deleted (a chat photo
  from the chat too); an ad is deleted with its media; a plan's notes are
  cleared; a profile's bio, photo and gear photos are cleared (the name
  stays: the filter checks names). The files go from the photos bucket.
- **Block climber**: after the same confirmation as Admin → Users, the
  person whose content it is is blocked app-wide (rbacr's `blocked`
  role, [admin.md](admin.md#blocking)).

`GET /api/admin/reports` → `{reports: [Report], climbers}`;
`POST /api/admin/reports/{id}/dismiss` | `/remove` | `/block` →
`{report}` (admins only, 403 for anyone else; 404 for no such report;
409 when it was already handled). A handled report leaves the list; it's
kept a year (TTL), with who handled it and when.

**Timely response**: when a report arrives, every admin gets one
notification, **"New reports to review"** ("Admin → Reports · answer
within 24 hours"; tap it for Admin → Reports), and a live-update `notice`
hint, so an admin with the app open sees it at once. Each new report
replaces it, unread again, so a burst of reports is one notification.
Grigri knows who to tell because an admin's app loading (`GET /api/me`)
adds them to a small list (one item); before telling anyone it asks
rbacr whether they're still an admin, and forgets those who aren't. No
email or push service: in-app notices cost nothing new.

## Blocking someone

Anyone can **Block** someone, from the ⋮ on their profile sheet, a
Discover card (its organizer), the plan screen (its organizer), an ad
(its owner) or a join request card, or a long press on their chat
message. "Block <name>?" says what it does, and a snackbar confirms it.
This is my own block, not an admin's (which shuts someone out of Grigri,
[admin.md](admin.md#blocking)). **Profile → Blocked people** lists whom
I blocked, each with **Unblock**.

What a block between us does (either of us blocked the other), exactly:

- **The deck**: no plan with them in its group (organizer or member)
  is on my deck, and no plan with me in it is on theirs. Their ads leave
  my deck, and mine theirs.
- **Asking to join**: neither of us can ask to join a plan the other is
  in: 409 "you can't ask to join this plan", which doesn't say why.
- **Their requests**: when I block them, their open requests on plans I
  decide on (I'm a member of a private plan, or the guide of a guided
  one) are declined, as my "no" (they get the usual "Not this time").
  Requests on plans where I don't decide wait as before.
- **Plans we're both already in** stay as they are (the group decides
  who's in; either of us can leave). On my side only, the app hides
  their chat messages and notifications about them (requests, nudges);
  they still see mine, so they can't tell.
- **They aren't told**, and nothing the API returns says who blocked
  them.
- **Unblocking** undoes all of it from then on; declined requests stay
  declined.

`GET /api/blocks` → `{blocked: [climberId], climbers}` (only whom I
blocked); `POST /api/blocks/{id}` → `{blocked: true}` (400 for myself,
404 for no such climber); `DELETE /api/blocks/{id}` → `{blocked:
false}`.

## Data and cost

All in the table already there ([backend.md](backend.md)); **no new
resources**:

- A report is one item, `REPORT#<id>` / `REPORT`, in the open-reports
  index partition (`gsi1`, `REPORTS#open`) while open; once handled it
  leaves the index and expires a year later (TTL deletes are free). A
  report costs a write, a read or two to copy the content, and a notice
  write per admin.
- A block is two items written together: `CLIMBER#<me>` /
  `BLOCK#<them>` and its mirror `CLIMBER#<them>` / `BLOCKEDBY#<me>`. Both
  begin with `BLOCK`, so **one query of my own partition** gives every
  block either way: the deck and asking to join add that one query (half
  a read unit when there are none), never a scan.
- The admins' list is one item, `META#ADMINS` (a string set).
- Hiding blocked people's messages happens in the app, so chat polling
  costs nothing more.
- The filter runs in the function, in microseconds: no moderation service
  to pay.
