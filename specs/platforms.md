# Platforms

The app is built with Flutter 3.47 for Android, iOS and the web.

| | Android | iOS | Web |
|---|---|---|---|
| Built by | `make android` (release APK) | `make ios` (unsigned unless `IOS_CODESIGN=1`) | `make web` |
| Released as | `grigri-<tag>-android.apk` | `grigri-<tag>-ios-unsigned.zip` | `grigri-<tag>-web.zip`, and [deployed](deploy.md) |

App IDs: `com.nu01.grigri` (Android application ID and iOS bundle ID).
The app is named **Grigri** everywhere.

**Icon**: mountain peaks with a snow cap and a moon, in a sand ring, on
the dark of the [theme](theme.md). The sources are SVGs in
[grigri_app/assets/icon/](../grigri_app/assets/icon):
`icon.svg` (the whole icon) and `icon-foreground.svg` (the emblem alone,
for Android's adaptive icon over `#1C211B`). Each is rendered to a
1024 px PNG next to it (`rsvg-convert -w 1024 -h 1024`, from librsvg),
and `dart run flutter_launcher_icons` in `grigri_app/` makes every size
for Android, iOS and the web (favicon, PWA icons, and the manifest's
colors, `#161A16`) from the `flutter_launcher_icons` settings in
`pubspec.yaml`. It also changes
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` in the iOS
project; undo that change before committing.

**iOS signing**: automatic, with each developer's own team:
`IOS_DEVELOPMENT_TEAM` in `.env` (a free Personal Team works) is written by
`scripts/dart-defines.sh` to the git-ignored
`grigri_app/ios/Flutter/Private.xcconfig`, which `Debug.xcconfig` and
`Release.xcconfig` include; no team is committed. Without it, iOS builds
are unsigned (CI's are). `bash scripts/flutter-run.sh -d <iPhone id>
--release` builds, signs and installs it.

The Android release APK is signed with the debug key until a release key
is set up.
