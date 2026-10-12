# Matching

Grigri works like Tinder or Happn, for climbing: swipe right for yes, left
for no (or tap ✓ and ✕). What people match on is a **plan**, not just a
person, and a plan can take a whole group.

## Profiles and plans are separate

- A **profile** ([Climber](../grigri_app/lib/model/climber.dart)) is about
  the person: name, age, home area, years climbing, a bio, and how they
  climb:
  - **grades per discipline**: sport, trad and gym on the French scale
    (4a–9a), bouldering on the V scale (VB–V13);
  - **when**: weekdays × morning (before 12:00), afternoon (12:00–17:00),
    evening (from 17:00);
  - **where**: crags and gyms they like;
  - **gear** they can bring: rope, quickdraws, trad rack, crash pad, car.
- A **plan** ([Plan](../grigri_app/lib/model/plan.dart)) is one outing:
  title, discipline, crag or gym and area, date, start time and length,
  the grades it's for, the group size (2–12, the organizer included), and
  notes. Its members are its **group**, organizer first.

## The two decks

- **Discover**: plans to join. Upcoming plans with a spot open, that I'm
  not in and haven't swiped on, best fits first: my grades for the plan's
  discipline overlap its grades (counts double), it's at one of my times,
  it's at one of my places; then the soonest. Each card shows **the plan
  first, highlighted**, with badges for what fits ("Your grades", "Your
  time", "Your place"), then the organizer's profile and the rest of the
  group.
  - Right / ✓: I ask to join (a join request).
  - Left / ✕: I pass; the plan leaves my deck.
- **Requests**: people who asked to join a plan I'm in, that I haven't
  answered. Each card shows the plan they want ("Wants to join"), who in
  the group has said yes and who hasn't, then **their profile**, with
  their grade for the plan's discipline marked when it fits.
  - Right / ✓: I accept them. Left / ✕: I turn them down.
  - The plan's screen lists them too, with ✓ and ✕ for each one I haven't
    answered.

Cards are dragged (they tilt, and stamp JOIN / PASS or ACCEPT / DECLINE),
or thrown by the buttons. A drag past 28% of the width, or a quick flick,
counts.

## The group decides

- A newcomer joins a plan when **every current member** has accepted
  them, and the plan has a spot open. **One "no" turns them down.**
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

A bell on every tab's bar opens **Notifications**, with a badge counting
the unread ones. Each one is a group's answer to my request: **"You're
in: <plan>"** (tap for the plan) or **"Not this time: <plan>"**, with when
it happened, newest first. Opening the screen marks them read; the ones
that were new stay highlighted ("New") while it's open. Only the person who
asked is notified.

## Group chat

Each plan has one chat for its whole group, with the plan pinned on top.
It notes who joined and who left. Chats lists them, most recent first.

## For now: on the device

There's no backend yet, so everything runs and is kept on the device
([GrigriStore](../grigri_app/lib/data/grigri_store.dart), saved as JSON
with shared_preferences: local storage on the web). The app starts with
demo data ([seed.dart](../grigri_app/lib/data/seed.dart)): my profile
("You", to edit), eight made-up climbers with their plans, dates always in
the coming days, two people asking to join my plan, and a bouldering group
I'm in where Noa waits only for my yes, and the (read) notification that
I was accepted into it. The made-up climbers answer requests by a fixed
policy: accept everyone, accept only overlapping grades, never decide (the
request waits), or turn everyone down. They answer 10 seconds after I ask
(the app checks every 2 seconds), so my request is pending first; tests
make them answer at once. Profile →
⋯ → **Reset the demo data** starts over.

A backend would take the store's place behind the same operations (like,
pass, accept, reject, dismiss, create, update, leave, send, the
notifications), with real people's decisions instead of the policies, and
push notifications instead of the 2-second check.
