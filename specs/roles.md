# Roles

The user's roles come from [rbacr](https://github.com/prodbytes/rbacr)
(https://rbacr.nu01.com), prodbytes' role manager: it records which roles
each identity holds in each system. Grigri's system in rbacr is `grigri`.

- **Who asks rbacr**: only Grigri's API, never the app. The API holds an
  rbacr root's API token (template parameter `RbacrToken`, from the
  repository secret `GRIGRI_RBACR_TOKEN` when deployed; locally `.env`'s
  `RBACR_TOKEN`, the local rbacr's) and asks about the caller's verified
  email ([api.md](api.md), Admin and Roles). So no rbacr token is ever in
  the app, and rbacr needs no CORS or OAuth audience for Grigri.
- **My roles**: `GET /api/me`'s `roles`: my effective roles in the
  `grigri` system plus my global roles (`root` for rbacr's roots), sorted,
  without duplicates; roles in other systems aren't shown. `null` when
  rbacr can't say (no token, an error, a timeout). Kept 60 s per API
  instance; the app reads them when it loads my profile, and again on
  **Retry**.
- **Where**: the end of the [Profile](screens.md) tab, in a Roles card:
  - my roles as tags;
  - "No roles in Grigri yet." when I hold none;
  - "Couldn't get your roles from rbacr." with **Retry** when the API
    couldn't say (Retry asks `GET /api/me` again, which also refreshes
    whether I'm an admin).
- **Every role is rbacr's**: Grigri keeps no role of its own. The
  `grigri` system's roles:

  | Role | Who holds it | Set by |
  |---|---|---|
  | `admin` | the Admin tab's people ([admin.md](admin.md)); implies `premium` and `premium-rc` | a root, in rbacr |
  | `premium` | Premium subscribers ([premium.md](premium.md)), until their paid period's end plus two days | the Stripe webhook (grant and revoke); a root, for a comp |
  | `blocked` | people an admin blocked ([admin.md](admin.md#blocking)) | the Admin tab's Block/Unblock; a root |
  | `premium-rc`, `blocked-rc` | the same, on the RC, which asks production's rbacr too: its test payments and blocks never reach production | the RC's API |

  The stage's own roles are the template's `RoleSuffix` (`-rc` on the
  RC, none elsewhere). The API asks about people by their verified
  email, kept privately per climber ([backend.md](backend.md)).
- **Setting it up**: [scripts/rbacr-setup.sh](../scripts/rbacr-setup.sh)
  makes the `grigri` system and its roles when missing and has `admin`
  imply both Premiums (keeping whatever else it implies); idempotent. Run
  by every deploy (production's rbacr, with `GRIGRI_RBACR_TOKEN`) and,
  locally, by `devbox services up` (`7-rbacr-setup`, the local rbacr,
  with `.env`'s `RBACR_TOKEN`).
- **Granting**: the API grants and revokes with rbacr's grants API
  (`POST`/`DELETE /api/systems/grigri/grants {role, grantee, endsAt?}`,
  roots only, so the same root token), and lists a role's holders with
  `GET /api/systems/grigri/grants` (kept a minute).
- **The client**: every call goes through rbacr's TypeScript client,
  [rbacr-lib](https://github.com/prodbytes/rbacr/tree/main/rbacr-lib)
  (`grigri_api/package.json` pins its release tarball by URL and the
  lockfile by integrity), wrapped by
  [grigri_api/src/rbacr.ts](../grigri_api/src/rbacr.ts): one client per
  function instance, shared by the admin check, the role lookups and the
  grants, so a grant drops what that instance kept about the person.
  Answers are kept a minute (a "yes" never past its grant's end), errors
  never (rbacr's rule C6: rbacr not knowing the `grigri` system is "no",
  asked again next time); rbacr's error answers and outages are logged.
- **Admin** (the Admin tab, [admin.md](admin.md)) is rbacr's too: the API asks
  rbacr whether my verified email holds the `admin` role of the `grigri`
  system (roots do). rbacr needs the `grigri` system and its `admin` role
  for anyone but roots to be one. There's no admin list in Grigri.
- **Deployed stages need `GRIGRI_RBACR_TOKEN`**: without the repository
  secret, the API can't ask rbacr: everyone's roles show the failure and
  nobody is an admin (the deploy warns).
- **Tests**: the API's tests cover the lookup (the request, caching,
  failures as `null`) and `GET /api/me`'s `roles`; the app's widget tests
  cover roles shown, none, and the failure with Retry.
