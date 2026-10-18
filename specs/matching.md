# Matching

Grigri works like Tinder or Happn, for climbing: swipe right for yes, left
for no (or tap ✓ and ✕). What people match on is a **plan**, not just a
person, and a plan can take a whole group.

## Profiles and plans are separate

- A **profile** ([Climber](../grigri_app/lib/model/climber.dart)) is about
  the person, created after their first [sign-in](sign-in.md): a
  **photo** (or their initials), name, age (optional:
  without it, cards show just the name), a bio, and:
  - **grades per discipline** (what they climb): sport, trad and gym on
    the route scale, bouldering on the boulder scale. Each scale is
    written in my **grade system**, like Celsius and Fahrenheit:
    **European** (French 4a–9a for routes, Fontainebleau 3–8B for
    boulders) or **American** (YDS 5.5–5.14d, the V scale VB–V13). The
    two write the same grades, index for index; switching changes how
    grades read everywhere in the app, never the grades themselves (the
    API stores them as `routes` / `boulders` indices); the choice is kept
    on the device, like the app's [language](i18n.md);
  - **gear** they own, for the group (rope, quickdraws, trad rack, belay
    device, crash pad, car) and their own (harness, helmet, climbing
    shoes), and up to 6 **photos of their gear**, edited from the Profile
    tab's Gear card and checked on each plan ([gear](gear.md)).

  - **where I climb**: my **location** and up to 5 other **areas** I'd
    climb near, each a place picked from the [sector index](sectors.md)
    (a crag, sector or gym, with its point). They're **private**: the
    server keeps them to about 1 km and only my own profile has them;
    everyone else's comes without (the app keeps mine when a refresh
    brings my profile back without them). They rank my
    [deck](#the-deck).

    The app **takes my location from the device instead of asking**, so
    it defaults to where I am: when my profile has no location (areas or
    not), it asks the phone or
    browser where it is once signed in (the system's location
    permission prompt the first time; coarse, through `geolocator`, at
    no running cost) and saves it as my location, rounded to 0.01°
    (about 1 km) and named after the closest place in the
    [sector index](sectors.md) ("Near Siurana, Spain"; "Where I am" with
    no place in the index). Discover asks me to set where I climb only
    when the device can't tell (no location service, permission refused,
    no fix within 15 s). A location I already have is never replaced.
    Android declares `ACCESS_COARSE_LOCATION`, iOS
    `NSLocationWhenInUseUsageDescription`, and the web app's
    `Permissions-Policy` allows `geolocation=(self)` ([deploy](deploy.md)).
    I can change my location from the **Profile** tab itself
    ([screens](screens.md)), saved at once, or in the profile editor
    with my areas.

  When is only the plan's: a profile has no availability or years
  climbing.
- A **plan** ([Plan](../grigri_app/lib/model/plan.dart)) is one outing:
  discipline, where (a sector, crag or gym: picked from the
  [sector index](sectors.md), with where it is and its point on the
  map, or typed in), its days (a first day, which may be left to be
  decided, and any more days after it, up to two weeks) and its time
  range (from and to, the same each day), the grades it's for, and
  notes. Joining closes when its first day starts; an undated plan stays
  open. It has
  no title: it's called by its place. Its members are its **group**,
  organizer first, and the group has **no size limit**: it's as big as
  the people who match.

## The deck

- **Discover**: plans to join. Upcoming plans that I'm
  not in and haven't swiped on, **ranked by how well they match my
  profile plus, weighing twice as much, how close they are** to the
  nearest of my location and areas ([the score](api.md#the-decks-ranking)):
  a plan in my grades nearby first; nearby plans before far ones, even
  ones a few grades off; ties soonest first, undated plans last. A plan typed in by hand (no
  point), or a deck without my location or areas, counts as about 70 km
  away. Each card shows **the plan first, highlighted** (the place, the
  date (the first day, "+N days" when there are more, or "Date to be
  decided") and the time range (none while undated) on lines of their own, the grades, a "Your
  grades" badge when they fit; the distance isn't shown, only used to
  rank), then the organizer with how many others are in the group
  ("Kit Marlow" and **+1**: tap it to show or hide the group's list,
  collapsed at first) and their profile (without the gear). The card
  is compact, to fit small phones: its text is 10% smaller than the
  rest of the app's (on top of the system's text size), and the plan's
  notes and the organizer's bio stop at three lines, with "…" when cut
  (the plan's screen and the profile sheet show them whole).
  - Right / ✓: I ask to join (a join request); a snackbar says "Asked to
    join. You'll get an alert when you're accepted." On a **demo** plan
    the group says yes at once (its made-up members can't answer): I
    join, and the match screen opens instead of the snackbar.
  - Left / ✕: I pass; the plan leaves my deck, until I tap ⟳ (refresh),
    which brings passed plans back (not ones I asked to join or cancelled).
  - Share (the small 36 dp button to the right of ✓; ✕ and ✓ stay
    centered): shares the top plan as
    text through the system's share sheet, "Climbing plan on Grigri:
    Bouldering at Block Hall, Sat 18 Oct · 19:00–22:00." and a link to
    the app at the API's origin (`/app/`; there are no links to one plan
    yet). On the web, the browser's share sheet, or an email draft where
    it has none. It doesn't swipe.

  Between plans, an approved [ad](ads.md#on-the-deck) now and then
  (one after every *n* plans swiped, as admins set it): right opens its
  link in the browser, left skips it.

  The server picks and orders the deck. A plan created, edited, joined,
  left or deleted is on (or off) everyone's next deck at once: the server
  keeps the upcoming plans in memory but checks the table's change log
  on every deck ([the deck's cache](backend.md#the-decks-cache)), and a
  plan leaves the deck once it starts. With nothing to show (GA starts
  empty), Discover says so and offers **New plan**.

Cards are dragged (they tilt, and stamp JOIN / PASS),
or thrown by the buttons. A drag past 28% of the width, or a quick flick,
counts.

## Join requests, in the group chat

Someone asking to join a plan shows up in its **group chat** as a card
("Asked to join" and when): their photo, name and age (tap for their
whole profile), their grade for the plan's discipline (marked when it
fits; nothing when they have none for it), and who in the group has said yes and who it's waiting for. Until
I've answered it has **Decline** and **Accept**; then it shows "You said
yes" and who it's still waiting for, **Joined**, **Declined** (when I said
no), or **Closed** (turned down by someone else). The
organizer and **every member** are notified ("<name> wants to join"), and
a newcomer is notified of the requests still open when they join. On a
guided plan only the guide is notified and has Decline and Accept; an
open plan has no requests (see [plan types](#plan-types-who-decides)). Chats
marks each chat with how many requests wait for my answer, and the Chats
tab's badge counts them all. The plan's screen lists them too, with
"Answer in the chat".

So the group doesn't miss them, the requests still waiting for **my**
answer are also **called out at the top of the chat**, under the pinned
plan: their avatar and name, how many have said yes, and ✕ / ✓ (the same
answer as the card's). Once I've answered, the request leaves the
callout; its card in the messages stays as the record.

## Plan types: who decides

Every plan has a **type**, picked in the plan editor under **Who can
join**, which says who lets newcomers in (the plan's **deciders**):

| Type | Who decides | Swiping right |
|---|---|---|
| **Shared** (the default; `private` in the API) | **every current member** | asks; the group answers |
| **Open** | nobody | **joins at once**: the match screen opens, as on a demo plan |
| **Guided** | **the organizer alone**, the guide | asks; only the guide answers |

- **Shared** (called **Private** until 2026-10-17; still `private` in the
  API and the data) is what every plan was before types, and a plan
  without a type (stored before them) is shared. The deck's card says
  **Shared** (with a group icon) at the top, beside the discipline; elsewhere
  it isn't marked.
- **Open**: there's no request to answer, no "asked to join" note and no
  notices to the group; the chat just says "<name> joined the plan 🎉".
  The deck's card says **Open: join at once** at the top, beside the
  discipline.
- **Guided**: the plan is a guide's outing, **expected to be paid**.
  Only [Premium](premium.md) climbers (and admins) make a plan guided:
  without Premium the editor's **Guided** is off, with "Guided plans are
  for Grigri Premium." under it, and the API refuses it (403); a plan
  that's guided already stays editable after Premium ends. It has a **price per climber** (an amount above 0, at most 10,000 with two
  decimals, in EUR, USD, GBP, CHF or BRL), shown as **Guided · €60** on
  the card and the plan, with "Paid to the guide, not through Grigri":
  Grigri takes no payment (Premium's Stripe isn't involved). Only the
  guide is notified of requests, sees them to answer (in the chat and the
  callout), can accept or decline, and is nudged; the other members see
  the requests with "The guide decides". If the guide leaves, the member
  picked to organize becomes the one who decides.
- **Changing the type** (the organizer, in the editor) takes effect at
  once: a plan made open lets in everyone waiting, and one made guided
  lets in whoever the guide has already accepted. Leaving the price out,
  or making the plan private or open, clears the price.

## The group decides

- A newcomer joins a plan when **every decider** has accepted them
  (every current member on a private plan, the guide on a guided one).
  **One decider's "no" turns them down.**
- When someone joins a private plan, the members who are still to decide
  on other open requests now include them: the group as it is then
  decides.
- Cancelling a plan I'm in (from Plans or the plan screen) is leaving it:
  it's out of my plans and chats at once, and the others keep it. When a
  member leaves, the requests stop waiting for them. The organizer leaving
  hands the plan to one of the remaining members **picked at random**, and
  the chat says so ("Ada left the plan; Ben organizes it now"); a member
  leaving just leaves ("Ada left the plan"). The last member leaving ends
  the plan, its requests and its chat. A plan I left never comes back to
  my deck.

## My request: pending, accepted or declined

Swiping right on a plan makes it **pending** ("Asked to join: pending…").
Plans lists it under **Asked to join**, tagged **Pending**, with who it's
still waiting for, and a **Nudge** button: it reminds the members who
haven't answered yet (a [notification](#notifications) each, asking them
to accept or decline) and confirms "Nudge sent to <names>". A request can
be nudged once every **12 hours**: until then the button reads **Nudged**
and is disabled (the server refuses an earlier one, and the app shows its
message). There's no Nudge on a declined request or once the plan has
started. When the whole group has said yes, it moves up to the
plans I'm in, tagged **Accepted**. When one member says no, it's tagged
**Declined** until I dismiss it (✕); it doesn't come back to my deck. Its
plan screen shows the same status.

## Matches

When someone joins a plan I'm in, or I join one, **"It's a match!"** opens
over the screen: the plan, highlighted, the group's avatars and names, and
**Open the group chat** or **Keep swiping**. That includes a group's yes
found by a [refresh](#refreshing) while I'm doing something else. A
group's no is a notification.

## Notifications

The **Notifications** tab, with a badge counting the unread ones, lists
newest first, with when it happened:

- **"<name> wants to join"** a plan I'm in (tap for its group chat, to
  answer);
- **"<name> is waiting for your answer"** ("To join <plan> · accept or
  decline in the group chat") when they nudged the members who haven't
  answered (tap for the chat); a later nudge replaces it, new and unread
  again;
- **"You're in: <plan>"** when a group accepted me (tap for the chat);
- **"Not this time: <plan>"** when one declined me (tap for the plan).

The [Grigri team chat](team-chat.md)'s news is a badge on Chats instead,
not a notification here.

Opening the tab marks them read; the ones that were new stay highlighted
("New") until I come back to it, and so do ones that arrive while it's
open.

## Group chat

Each plan has one chat for its whole group, with the plan pinned on top.
It notes who joined and who left, and holds the
[join requests](#join-requests-in-the-group-chat) for the group to
answer. Chats lists them, most recent first, under the
[Grigri team chat](team-chat.md), which is always on top.

A message is text, **one photo or one video**, or both. The attach button
offers only photos and videos: take a photo or record a video (where the
device has a camera; recordings stop at 30 s where the device lets the
app say), or choose one from the gallery. No other kind of file can be
sent: the app checks the picked bytes (JPEG, PNG or WebP; MP4 or MOV) and
the API only issues uploads of those types. Photos are downsized to
1600 px as they're picked; videos must be at most 50 MB ("Videos can be at
most 50 MB: send a shorter one"). Only the plan's members can upload to
its chat or read its messages; the media is kept 400 days
([backend](backend.md#chat-media)).

## Blocking someone

Anyone can block someone from their profile sheet, a card, a plan, an ad,
a join request card or a long press on their chat message, and unblock
them in Profile → Blocked people ([moderation.md](moderation.md#blocking-someone)).
Between two people with a block either way:

- no plan with one of them in its group is on the other's deck (nor
  their ads);
- neither can ask to join a plan the other is in (a neutral 409);
- blocking declines their open requests on plans I decide on (as my
  no);
- in plans we're both already in, nothing changes for the group; my app
  hides their messages and notifications about them from me;
- they aren't told.

Others can also report a profile, plan, message, photo or ad, which
admins answer within 24 hours ([moderation.md](moderation.md#reporting)).

## Data: the backend API

Everything comes from the database, through the backend's API
([api.md](api.md)); the app has no built-in data, and keeps nothing
between runs but my grade system and the app's [language](i18n.md)
(shared_preferences, display choices) and the bundled [sector index](sectors.md). [GrigriStore](../grigri_app/lib/data/grigri_store.dart) is
a cache over the API client ([api.dart](../grigri_app/lib/data/api.dart),
[http_api.dart](../grigri_app/lib/data/http_api.dart)): screens read it
and call its actions (like, pass, accept, reject, dismiss, create,
update, leave, send, save the profile, report, block and unblock
someone, and the admin's block, unblock and report answers), which call the API and update the cache with the answers. A
failed action shows the server's message at the bottom of the screen; a
401 tries fresh credentials once, then signs out; a 409 "no profile"
loads my profile again (`GET /api/me`, which makes a new one); a 403
"blocked" shows only the [blocked screen](admin.md#blocking).

- **Demo data**: every stage, production included, has the demo showcase
  (fictional climbers and their plans, [backend](backend.md#the-demo-showcase));
  RC and local also get made-up test data from the backend's seed (never
  in GA). All of it is marked **demo**: a demo plan (on the deck, its
  screen, the match screen) and a demo person's profile sheet begin with
  one discreet line, "Demo: made-up people and plans.", and a demo person's name
  has a **Demo** tag. A real plan's requests wait for its real members;
  a demo plan's group says yes at once.
- **Photos** are in the backend's photo store, never in the database or on
  the device: picked as before (my photo downsized to 640 px, gear photos
  to 1080 px, JPEG quality 75), uploaded when the profile is saved (`POST
  /api/photos` for a presigned upload, then the file), and saved in the
  profile as keys, shown from `<site>/photos/<key>`. A profile keeps up to
  6 gear photos.
- **Who answered**: the server matches as described above (unanimous yes,
  one no), and tells people by notifications.

## Refreshing

While the app is in the foreground, [live updates](live-updates.md) (a
hint over MQTT after each change that concerns me) refresh what changed,
and the app also polls, only what's on screen, as a safety net:

- after signing in: my profile, then my plans, my requests, the requests
  waiting for me, the deck, notifications (and, for admins, everyone);
- a tab, when I open it (Discover its deck, Chats every chat's latest
  messages and my [team chat](team-chat.md), and admins' team chats list,
  Admin its list of everyone, Profile my Premium and its prices), and
  every **15 seconds** my plans, requests to review and notifications,
  plus the open tab; every **2 minutes** instead while the live
  connection is up. While another screen covers the tabs (a chat, a
  plan, a dialog), the open tab's part waits; if it was due meanwhile, it
  runs once when that screen closes;
- on coming back to the foreground, the same at once; and my Premium
  the first time back after the app opened Stripe's Checkout or portal,
  or the App Store's subscriptions (afresh, [premium.md](premium.md)), or
  whenever the profile is on screen;
- an open **chat every 3 seconds** (a team chat too), asking only for messages after the
  last one it has; every **minute** instead while the live connection is
  up; at once on coming back to the foreground; and when something else
  (a hint, Chats) fetched it meanwhile, its count starts over;
- on a live update's hint, just what it names (a chat, requests,
  notifications, my plans), and after the live connection comes back from
  a drop in the foreground, my plans, requests, notifications and loaded
  chats;
- a plan's screen and chat load the plan (and its open requests) when
  they open.

When a refresh finds that a group accepted me (a new, unread "accepted"
notification), the match screen opens, once per notification; so does a
yes of mine that completes someone's request.
