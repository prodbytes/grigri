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
