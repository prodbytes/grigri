# Matching

Grigri works like Tinder or Happn, for climbing: swipe right for yes, left
for no (or tap ✓ and ✕). What people match on is a **plan**, not just a
person, and a plan can take a whole group.

## Profiles and plans are separate

- A **profile** ([Climber](../grigri_app/lib/model/climber.dart)) is about
  the person: a **photo** (or their initials), name, age (optional:
  without it, cards show just the name), a bio, and:
  - **grades per discipline** (what they climb): sport, trad and gym on
    the route scale, bouldering on the boulder scale. Each scale is
    written in my **grade system**, like Celsius and Fahrenheit:
    **European** (French 4a–9a for routes, Fontainebleau 3–8B for
    boulders) or **American** (YDS 5.5–5.14d, the V scale VB–V13). The
    two write the same grades, index for index; switching changes how
    grades read everywhere in the app, never the grades themselves;
  - **gear** they can bring: rope, quickdraws, trad rack, crash pad, car,
    and up to 6 **photos of their gear**.

  When and where are only the plan's: a profile has no availability,
  places, home area or years climbing.
- A **plan** ([Plan](../grigri_app/lib/model/plan.dart)) is one outing:
  discipline, where (a sector, crag or gym: picked from the
  [sector index](sectors.md), with where it is, or typed in), the day and
  its time range (from and to), the grades it's for, and notes. It has
  no title: it's called by its place. Its members are its **group**,
  organizer first, and the group has **no size limit**: it's as big as
  the people who match. Plans saved before keep their length as the time
  range, and lose their title and group size.

## The deck

- **Discover**: plans to join. Upcoming plans that I'm
  not in and haven't swiped on: first those whose grades overlap my grades
  for the plan's discipline, then the rest, each soonest first. Each card
  shows **the plan first, highlighted**, with a "Your grades" badge when
  they fit, then the organizer's profile (without the gear) and the rest
  of the group.
  - Right / ✓: I ask to join (a join request).
  - Left / ✕: I pass; the plan leaves my deck.

Cards are dragged (they tilt, and stamp JOIN / PASS),
or thrown by the buttons. A drag past 28% of the width, or a quick flick,
counts.

## Join requests, in the group chat

Someone asking to join a plan shows up in its **group chat** as a card
("Asked to join" and when): their photo, name and age (tap for their
whole profile), their grade for the plan's discipline (marked when it
fits), and who in the group has said yes and who it's waiting for. Until
I've answered it has **Decline** and **Accept**; then it shows "You said
yes" and who it's still waiting for, **Joined**, or **Declined**. The
organizer and **every member** are notified ("<name> wants to join"), and
a newcomer is notified of the requests still open when they join. Chats
marks each chat with how many requests wait for my answer, and the Chats
tab's badge counts them all. The plan's screen lists them too, with
"Answer in the chat".

## The group decides

- A newcomer joins a plan when **every current member** has accepted
  them. **One "no" turns them down.**
- When someone joins, the members who are still to decide on other open
  requests now include them: the group as it is then decides.
- When a member leaves, the requests stop waiting for them. The organizer
  leaving hands the plan to the next member; the last member leaving ends
  the plan, its requests and its chat. A plan I left never comes back to
  my deck.

## My request: pending, accepted or declined

Swiping right on a plan makes it **pending** ("Asked to join: pending…").
Plans lists it under **Asked to join**, tagged **Pending**, with who it's
still waiting for. When the whole group has said yes, it moves up to the
plans I'm in, tagged **Accepted**. When one member says no, it's tagged
**Declined** until I dismiss it (✕); it doesn't come back to my deck. Its
plan screen shows the same status.

## Matches

When someone joins a plan I'm in, or I join one, **"It's a match!"** opens
over the screen: the plan, highlighted, the group's avatars and names, and
**Open the group chat** or **Keep swiping**. That includes a group's yes
that arrives while I'm doing something else. A group's no shows "Not this
time: … said no" at the bottom of the screen.

## Notifications

The **Notifications** tab, with a badge counting the unread ones, lists
newest first, with when it happened:

- **"<name> wants to join"** a plan I'm in (tap for its group chat, to
  answer);
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

## For now: on the device

There's no backend yet, so everything runs and is kept on the device
([GrigriStore](../grigri_app/lib/data/grigri_store.dart), saved as JSON
with shared_preferences: local storage on the web). Photos are kept in
it too, downsized as they're picked (my photo to 640 px, gear photos to
1080 px, JPEG quality 75), which is why a profile keeps at most 6 gear
photos. The made-up climbers have no photos. The app starts with
demo data ([seed.dart](../grigri_app/lib/data/seed.dart)): my profile
("You", to edit), eight made-up climbers with their plans, dates always in
the coming days, two people asking to join my plan, and a bouldering group
I'm in where Noa waits only for my yes; their request cards in the chats
and unread notifications for the three requests, and the (read)
notification that I was accepted into the bouldering group. The made-up climbers answer requests by a fixed
policy: accept everyone, accept only overlapping grades, never decide (the
request waits), or turn everyone down. They answer 10 seconds after I ask
(the app checks every 2 seconds), so my request is pending first; tests
make them answer at once. Profile →
⋯ → **Reset the demo data** starts over.

A backend would take the store's place behind the same operations (like,
pass, accept, reject, dismiss, create, update, leave, send, the
notifications), with real people's decisions instead of the policies, and
push notifications instead of the 2-second check.
