# Roles

The user's roles come from [rbacr](https://github.com/prodbytes/rbacr)
(https://rbacr.nu01.com), prodbytes' role manager: it records which roles
each identity holds in each system. Grigri's system in rbacr is `grigri`.

- **Client**: rbacr's Dart client (package `rbacr`, from
  `prodbytes/rbacr`'s `rbacr-flutter`, a git dependency pinned to a
  commit in [pubspec.yaml](../grigri_app/pubspec.yaml)), wrapped by
  [roles.dart](../grigri_app/lib/data/roles.dart). It asks rbacr's
  `GET /api/me` as the token's owner.
- **My roles**: my roles in the `grigri` system plus my global roles
  (`root` for rbacr's roots), sorted, without duplicates. Roles in other
  systems aren't shown.
- **Who is asking**: Grigri has no sign-in yet, so the only token is the
  local rbacr's dev token (`RBACR_TOKEN`, see
  [Development environment](dev-environment.md)). Without it, nobody is
  signed in and the app doesn't call rbacr. Once sign-in exists, the app
  will ask as the signed-in user, with their Google ID token (rbacr accepts
  it for `/api/me` when its OAuth client is in rbacr's
  `RBACR_GOOGLE_AUDIENCES`, and on the web when the app's origin is in
  `RBACR_CORS_ORIGINS`).
- **Where**: the end of the [Profile](screens.md) tab, in a Roles card:
  - my roles as tags, and "As <the email rbacr knows me by>";
  - "No roles in Grigri yet." when I hold none;
  - a spinner while rbacr answers;
  - "Couldn't get your roles from rbacr." with **Retry** when it can't
    answer (unreachable, timed out after 10 s, or the token refused);
  - "Not signed in: your roles show here once you sign in." without a
    token.
- **Never in a built release**: `RBACR_TOKEN` reaches the app only from
  the dev run scripts (`flutter-web.sh`, `flutter-run.sh`), when
  `RBACR_URL` is a localhost rbacr and no deploy stage is set
  ([dart-defines.sh](../scripts/dart-defines.sh)); never from `make`,
  `android-install.sh` or a deploy. The local dev server's token is a
  root's.
- **Tests**: widget tests cover the roles shown, nobody signed in, and the
  failure with Retry, with a fake rbacr (no network).
