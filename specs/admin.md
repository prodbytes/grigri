# Admin

The **Admin** tab, for [admins](roles.md) only (rbacr's `admin` role of
the `grigri` system; the API checks on every request). A sub-navigation
(tabs under its title, "Admin") holds **Users**, everyone, to block or
unblock (below), **Ads**, to approve or reject Premium climbers' ads
and set how often the deck shows them ([ads.md](ads.md#admin--ads)), and
**Reports**, what people reported, to dismiss, remove or block within 24
hours ([moderation.md](moderation.md#answering-reports-admins)). The
refresh button reloads the open one. A "New reports to review"
notification opens Admin on Reports.

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
404 for no such climber) → `{"blocked": bool}`. Blocked is a role in
[rbacr](roles.md), like every role: they grant or revoke the `grigri`
system's `blocked` role (`blocked-rc` on the RC) to the climber's
verified email (kept privately; for climbers from before, read from
their sign-in sessions). 409 when Grigri knows no verified email for
them; 503 without rbacr. Nothing else changes (plans, requests and chats
stay as they were). Granting or revoking `blocked` in rbacr directly does
the same.

A blocked climber:

- gets **403 `blocked`** from every route but signing out
  (`DELETE /api/session`, `DELETE /api/sessions`), `GET /api/me`
  included;
- can't unblock themselves: only an admin (or an rbacr root) changes
  the role;
- disappears from everyone's Discover: plans they organize leave the
  deck, and their ads too;
- in the app, sees only "Your account is blocked" with **Sign out** and
  **Try again** (which loads the app if they've been unblocked), from
  the first 403 `blocked`, at sign-in or while using it.

Others never see whether someone is blocked: `blocked` is left out of
every profile the API shares, except the admin's list.

This is the admin's block. Anyone can also block someone for themselves
([moderation.md](moderation.md#blocking-someone)), which only keeps the
two of them apart.

## Cost

Nothing new to run: the list is one query of the `CLIMBERS` index
partition (one read unit per 4 KB of profiles), and blocking is one
conditional write. Reports are one query of the open-reports index
([moderation.md](moderation.md#data-and-cost)). Hiding blocked organizers' plans reuses the deck's
profile reads.

**How the API knows**: it lists who holds `blocked` in rbacr (`GET
/api/systems/grigri/grants`, one call for everyone) and keeps the list a
minute per function instance, so a block reaches every request within a
minute, and at once on the instance that made it. If rbacr can't answer,
nobody counts as blocked (logged), rather than everyone being locked out.
