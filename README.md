# Grigri

A matchmaking app for climbing and sports: find someone to climb with.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/prodbytes/grigri)

Like Tinder or Happn, for climbing: swipe on **plans** (an outing: what,
where, when, which grades), separate from people's profiles. When everyone
in a plan's group says yes to a newcomer, it's a match, and they climb
together, with a group chat. Everyone signs in with Google, and the data
lives in the backend (its API, under `/api`). What the app does is specified in [specs/](specs/README.md).

- Production: https://grigri.nu01.com
- Release candidate: https://rc.grigri.nu01.com

## Layout

| Path | Holds |
|---|---|
| [grigri_app/](grigri_app) | The Flutter app (Android, iOS, web) |
| [grigri_index/](grigri_index) | The site root page, which redirects to `/app/` |
| [grigri_infra/](grigri_infra) | CloudFormation: the site (S3 + CloudFront) and the GitHub deploy roles |
| [scripts/](scripts) | Build, run, release and deploy scripts |
| [specs/](specs) | The specification, one file per feature, and the request log |
| [.github/workflows/](.github/workflows) | Release (binaries), Deploy (GA) and Deploy RC |

## Getting started

Click the Codespaces badge, or locally:

```bash
git clone git@github.com:prodbytes/grigri.git
code grigri   # then "Reopen in Container" when prompted
```

Inside the container (or any machine with [Devbox](https://www.jetify.com/devbox)):

```bash
devbox shell              # enter the environment
devbox services up        # web app on http://localhost:2112/app/, index on :2113
devbox run android        # run on the Android phone attached by USB
make                      # build every platform this host can (see the Makefile)
```

Private settings (deploy targets) live in the private
`prodbytes/setec-astronomy` repo; `bash scripts/link-private.sh` links its
`.env` in. See [.env.example](.env.example).

## Services

`devbox services up` starts, through [process-compose.yaml](process-compose.yaml):

- `2-flutter-web`: the app in web mode ([scripts/flutter-web.sh](scripts/flutter-web.sh));
- `5-index`: the site root ([grigri_index/](grigri_index));
- `0-health-check`: once both are ready, prints the local URLs once, then
  one line per check every 15 s (`HEALTH_CHECK_INTERVAL`), each dependency
  with its icon, label and status:

```
🧗 Grigri: http://localhost:2112/app/
🏠 index:  http://localhost:2113/ (redirects to the app)
2026-10-12 18:02:10  🏠 index ✅  🧗 web ✅
```

Stop everything with `devbox services stop`.

## Releases

`bash scripts/release-rc.sh` tags the current commit `X.Y.Z-RC` and
`bash scripts/release-ga.sh` tags `X.Y.Z-GA` (X and Y from
[version.X.txt](version.X.txt) and [version.Y.txt](version.Y.txt), Z the
time), signed. Tags start the [Release](.github/workflows/release.yml)
workflow (APK, unsigned iOS app, web zip) and deploy the web app: RC tags
to https://rc.grigri.nu01.com, GA tags to https://grigri.nu01.com. See
[specs/release.md](specs/release.md) and [specs/deploy.md](specs/deploy.md).

## How the container is built

The [Containerfile](.devcontainer/Containerfile) keeps the Microsoft
`ubuntu-24.04` devcontainer base image and layers Devbox on top:

1. Devbox (a pinned release, checked against its published SHA-256) is
   installed as root, then everything else runs as the `vscode` user so
   the Nix store ownership matches the container's `remoteUser`.
2. Nix (a pinned release, its installer checked against a hash) is
   installed in single-user mode (`--no-daemon`): containers have no
   systemd, so the multi-user Nix daemon can't run.
3. After the container is created,
   [post-create.sh](.devcontainer/post-create.sh) fetches the locked store
   paths straight from `cache.nixos.org`, then runs `devbox install`. It
   hands Codespaces' `GITHUB_TOKEN` to Nix, so GitHub API rate limits don't
   break it.

## License

[MIT](LICENSE).
