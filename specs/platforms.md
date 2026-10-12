# Platforms

The app is built with Flutter 3.47 for Android, iOS and the web.

| | Android | iOS | Web |
|---|---|---|---|
| Built by | `make android` (release APK) | `make ios` (unsigned unless `IOS_CODESIGN=1`) | `make web` |
| Released as | `grigri-<tag>-android.apk` | `grigri-<tag>-ios-unsigned.zip` | `grigri-<tag>-web.zip`, and [deployed](deploy.md) |

App IDs: `com.nu01.grigri` (Android application ID and iOS bundle ID).
The app is named **Grigri** everywhere.

**iOS signing**: automatic, with each developer's own team:
`IOS_DEVELOPMENT_TEAM` in `.env` (a free Personal Team works) is written by
`scripts/dart-defines.sh` to the git-ignored
`grigri_app/ios/Flutter/Private.xcconfig`, which `Debug.xcconfig` and
`Release.xcconfig` include; no team is committed. Without it, iOS builds
are unsigned (CI's are). `bash scripts/flutter-run.sh -d <iPhone id>
--release` builds, signs and installs it.

The Android release APK is signed with the debug key until a release key
is set up.

**Photos** (profile and gear) come from
[image_picker](https://pub.dev/packages/image_picker): Android's photo
picker and camera app (no permissions to declare), iOS's with
`NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` in
`Info.plist`, and a file chooser on the web (the site's CSP already allows
`data:` and `blob:` images).
