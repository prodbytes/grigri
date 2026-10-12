# Grigri — software specification

The current specification of the product, one file per feature. Update the
feature files a request changes, and add a file when a request adds a
feature. [requests.md](requests.md) holds the history of requests that shaped
it.

## Product

Grigri is a matchmaking app for sports, climbing first: it will help people
find partners to climb (and train) with. For now it is a single static
screen, deployed with the full release pipeline so features can ship as
they're built.

## Features

**App**

- [Home screen](home-screen.md): the app's name, tagline and version.
- [Platforms](platforms.md): Android, iOS and the web; app IDs and iOS
  signing.

**Backend**

- [Backend](backend.md): the API, its DynamoDB table and photos bucket;
  production empty and real, RC and local seeded with made-up data;
  sign-in sessions (365 days without use); admins; local dev mode; costs.
- [API](api.md): the routes and JSON shapes the app uses, and sessions.

**Development and operations**

- [Development environment](dev-environment.md): devbox, the dev
  container, `devbox services up` and the health monitor, the run scripts.
- [Release builds](release.md): versions, tags and the Release workflow.
- [Deploy](deploy.md): the web app at https://grigri.nu01.com and the
  release candidate at https://rc.grigri.nu01.com.
