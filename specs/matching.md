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
  - **gear** they can bring: rope, quickdraws, trad rack, crash pad, car,
    and up to 6 **photos of their gear**.

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
  map, or typed in), the day and
  its time range (from and to), the grades it's for, and notes. It has
  no title: it's called by its place. Its members are its **group**,
  organizer first, and the group has **no size limit**: it's as big as
  the people who match.

## The deck

- **Discover**: plans to join. Upcoming plans that I'm
  not in and haven't swiped on, **ranked by how well they match my
  profile plus how close they are** to the nearest of my location and
  areas ([the score](api.md#the-decks-ranking)): a plan in my grades
  nearby first; one in my grades far away still before one next door
  that I don't climb; ties soonest first. A plan typed in by hand (no
  point), or a deck without my location or areas, counts as about 70 km
  away. Each card shows **the plan first, highlighted** (the place, the
  date and the time range on lines of their own, the grades, a "Your
  grades" badge when they fit; the distance isn't shown, only used to
  rank), then the organizer with how many others are in the group
  ("Kit Marlow" and **+1**: tap it to show or hide the group's list,
  collapsed at first) and their profile (without the gear). The card
  is compact, to fit small phones.
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

  The server picks and orders the deck. With nothing to show (GA starts
  empty), Discover says so and offers **New plan**.

Cards are dragged (they tilt, and stamp JOIN / PASS),
or thrown by the buttons. A drag past 28% of the width, or a quick flick,
counts.

## Join requests, in the group chat

Someone asking to join a plan shows up in its **group chat** as a card
("Asked to join" and when): their photo, name and age (tap for their
whole profile), their grade for the plan's discipline (marked when it
fits), and who in the group has said yes and who it's waiting for. Until
I've answered it has **Decline** and **Accept**; then it shows "You said
yes" and who it's still waiting for, **Joined**, **Declined** (when I said
no), or **Closed** (turned down by someone else, or by an admin). The
organizer and **every member** are notified ("<name> wants to join"), and
a newcomer is notified of the requests still open when they join. Chats
marks each chat with how many requests wait for my answer, and the Chats
tab's badge counts them all. The plan's screen lists them too, with
"Answer in the chat".

So the group doesn't miss them, the requests still waiting for **my**
answer are also **called out at the top of the chat**, under the pinned
plan: their avatar and name, how many have said yes, and ✕ / ✓ (the same
answer as the card's). Once I've answered, the request leaves the
callout; its card in the messages stays as the record.

## The group decides

- A newcomer joins a plan when **every current member** has accepted
  them. **One "no" turns them down.**
- When someone joins, the members who are still to decide on other open
  requests now include them: the group as it is then decides.
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

Opening the tab marks them read; the ones that were new stay highlighted
("New") until I come back to it, and so do ones that arrive while it's
open.

## Group chat

Each plan has one chat for its whole group, with the plan pinned on top.
It notes who joined and who left, and holds the
[join requests](#join-requests-in-the-group-chat) for the group to
answer. Chats lists them, most recent first.

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

## Data: the backend API

Everything comes from the database, through the backend's API
([api.md](api.md)); the app has no built-in data, and keeps nothing
between runs but my grade system and the app's [language](i18n.md)
(shared_preferences, display choices) and the bundled [sector index](sectors.md). [GrigriStore](../grigri_app/lib/data/grigri_store.dart) is
a cache over the API client ([api.dart](../grigri_app/lib/data/api.dart),
[http_api.dart](../grigri_app/lib/data/http_api.dart)): screens read it
and call its actions (like, pass, accept, reject, dismiss, create,
update, leave, send, save the profile, and the admin's approve and
reject), which call the API and update the cache with the answers. A
failed action shows the server's message at the bottom of the screen; a
401 tries fresh credentials once, then signs out; a 409 "no profile"
loads my profile again (`GET /api/me`, which makes a new one).

- **Demo data**: every stage, production included, has the demo showcase
  (fictional climbers and their plans, [backend](backend.md#the-demo-showcase));
  RC and local also get made-up test data from the backend's seed (never
  in GA). All of it is marked **demo**: a demo plan (on the deck, its
  screen, the match screen) and a demo person's profile sheet begin with
  one discreet line, "Demo: automatically generated, not real people or
  plans. It's here to show how Grigri works.", and a demo person's name
  has a **Demo** tag. A real plan's requests wait for its real members
  (or an [admin](sign-in.md#admins)); a demo plan's group says yes at once.
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
  waiting for me, the deck, notifications (and, for admins, every open
  request);
- a tab, when I open it (Discover its deck, Chats every chat's latest
  messages, Admin its requests), and every **15 seconds** my plans,
  requests to review and notifications, plus the open tab; every
  **2 minutes** instead while the live connection is up;
- an open **chat every 3 seconds**, asking only for messages after the
  last one it has; every **minute** instead while the live connection is
  up;
- on a live update's hint, just what it names (a chat, requests,
  notifications, my plans), and after the live connection comes back from
  a drop, my plans, requests, notifications and loaded chats;
- a plan's screen and chat load the plan (and its open requests) when
  they open.

When a refresh finds that a group accepted me (a new, unread "accepted"
notification), the match screen opens, once per notification; so does a
yes of mine that completes someone's request.
