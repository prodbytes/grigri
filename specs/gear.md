# Gear

Climbers list the gear they own on their profile, with photos, and each
plan checks its group's gear against what it needs.

## What climbers own

A profile's `gear` ([Climber](../grigri_app/lib/model/climber.dart),
[api.md](api.md)) is a set from one list, in two kinds:

- **For the group** (one does for several climbers): rope, quickdraws,
  trad rack, belay device, crash pad, car.
- **Your own** (every climber needs theirs): harness, helmet, climbing
  shoes.

The API's names are `rope`, `quickdraws`, `rack`, `belayDevice`,
`crashPad`, `car`, `harness`, `helmet`, `shoes`. An app that doesn't know
a name skips it.

A profile also keeps up to 6 **gear photos** (downsized to 1080 px,
uploaded as the profile's other photos are, see
[matching](matching.md)).

## On the Profile tab

My profile shows my gear in a **Gear** card of its own, after my
details: the chips of what I own, in the list's order, and the photos
(tap one to see it whole). **Edit gear** opens the gear editor; with
nothing listed the card says what gear is for ("Add the gear you own,
with photos: your plans' groups see it, and check they have what they
need.") and offers **Add your gear**.

The **gear editor** has the two kinds as chips under their own headings,
**For the group** ("The group shares these: a rope does for two.") and
**Your own** ("Every climber needs their own."), then **Photos** (✕
removes one, + adds one, camera or library, up to 6). Saving uploads the
new photos and saves the profile (`PUT /api/me`), keeping the rest of it.
The profile editor no longer edits gear.

Others see my gear where they see my profile (the profile sheet), and in
the plans we share.

## On a plan

A plan's screen has a **Gear** section after its group
([gear_check.dart](../grigri_app/lib/model/gear_check.dart),
[plan_gear.dart](../grigri_app/lib/ui/plan_gear.dart)). It checks what
the plan needs, by its discipline, against what its members listed:

| Discipline | For the group | Each climber's own |
|---|---|---|
| Sport | a rope, quickdraws and a belay device per pair | harness, shoes |
| Trad | a rope, a rack and a belay device per pair | harness, shoes, helmet |
| Bouldering | a crash pad (no ropes) | shoes |
| Gym | nothing: "The gym has ropes and mats, and rents the rest." | nothing |

- **Pairs**: one or two climbers are one pair; more need one for every
  two (four climbers: two ropes).
- **Guided plans**: the guide brings the group's gear, so only each
  climber's own is checked ("The guide brings the group's gear: check
  you have your own.").
- Each need is a chip: ✓ in olive when met, a hollow circle in grey when
  not, with the count when more than one is needed ("Harness 1/2").
- **The warning** is one discreet line in tan under the chips: "Some gear
  is missing: Belay device, Harness". When nothing is missing: "The group
  has all it needs."
- Then each member, with what they listed ("Rope · Quickdraws", or "No
  gear listed"), a photo icon when they have gear photos; tap one for
  their profile, gear photos included.

It's a simple check of what people listed, not a safety one: gear nobody
listed counts as missing. It needs no new API call or resource: members'
profiles come with the plan.

## Costs

None: gear is a few more names in the profile item already stored, and
gear photos were already in the photos bucket.
