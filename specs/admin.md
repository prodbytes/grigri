# Admin

The **Admin** tab, for [admins](roles.md) only (rbacr's `admin` role of
the `grigri` system; the API checks on every request). It starts over
with one feature: everyone, to block or unblock.

## The list

`GET /api/admin/climbers` (admins only, 403 for anyone else) →
`{"climbers": [Climber & {"blocked": bool}]}`: every profile (the
`CLIMBERS` index, demo showcase included), sorted by name, without
location or areas.

The tab shows them as rows: avatar and name (tap for their profile
sheet), "Blocked" under a blocked person's name, and:

- **Block** (after a confirmation: "Block <name>?", saying they can't
  use Grigri until unblocked and their plans leave everyone's Discover);
- **Unblock** for a blocked person, at once;
- nothing on my own row: an admin can't block themselves (the API
  refuses it, 400), so nobody locks themselves out.

Pull down or the refresh button loads it again; it also loads when the
tab opens and with the rest of the app's data.

## Blocking

`POST /api/admin/climbers/{id}/block` and `…/unblock` (admins only;
404 for no such climber) → `{"blocked": bool}`. They set or clear
`blocked` on the profile item; nothing else changes (plans, requests and
chats stay as they were).

A blocked climber:

- gets **403 `blocked`** from every route but signing out
  (`DELETE /api/session`, `DELETE /api/sessions`), `GET /api/me`
  included;
- can't unblock themselves: `PUT /api/me` never sets `blocked`, and a
  profile save is conditional on the profile not being blocked, so a
  save racing a block fails (403) instead of clearing it. The demo
  showcase's refresh leaves a blocked demo climber as it is;
- disappears from everyone's Discover: plans they organize leave the
  deck;
- in the app, sees only "Your account is blocked" with **Sign out** and
  **Try again** (which loads the app if they've been unblocked), from
  the first 403 `blocked`, at sign-in or while using it.

Others never see whether someone is blocked: `blocked` is left out of
every profile the API shares, except the admin's list.

## Cost

Nothing new to run: the list is one query of the `CLIMBERS` index
partition (one read unit per 4 KB of profiles), and blocking is one
conditional write. Hiding blocked organizers' plans reuses the deck's
profile reads.
