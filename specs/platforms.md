# Platforms

The app is built with Flutter 3.47 for Android, iOS and the web.

| | Android | iOS | Web |
|---|---|---|---|
| Built by | `make android` (release APK) | `make ios` (unsigned unless `IOS_CODESIGN=1`) | `make web` |
| Released as | `grigri-<tag>-android.apk` | `grigri-<tag>-ios-unsigned.zip` | `grigri-<tag>-web.zip`, and [deployed](deploy.md) |

App IDs: `com.nu01.grigri` (Android application ID and iOS bundle ID).
The app is named **Grigri** everywhere.

**Icon**: an orange grigri (the belay device) over sage and slate
mountains, on the night of the [theme](theme.md). The source art is
[grigri_app/assets/icon/source.png](../grigri_app/assets/icon/source.png)
(transparent background). `uv run scripts/make-icon.py` clears the stray
yellow pixels the art has in its transparent areas and writes two 1024 px
PNGs next to it: `icon.png` (the art filling 84% of the width, on
`#161A16`) and `icon-foreground.png` (the art alone, transparent, kept
inside the circle Android's adaptive icon masks may cut; shown over
`#1C211B`). Then `flutter pub run flutter_launcher_icons` in
`grigri_app/` makes every size for Android, iOS and the web (favicon, PWA
icons, and the manifest's colors, `#161A16`) from the
`flutter_launcher_icons` settings in `pubspec.yaml`. It also changes
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` in the iOS
project; undo that change before committing. Finally, copy
`grigri_app/web/favicon.png` to `grigri_index/site/favicon.png`, the
favicon of the site root's redirect page.

**iOS signing**: automatic, with each developer's own team:
`IOS_DEVELOPMENT_TEAM` in `.env` (a free Personal Team works) is written by
`scripts/dart-defines.sh` to the git-ignored
`grigri_app/ios/Flutter/Private.xcconfig`, which `Debug.xcconfig` and
`Release.xcconfig` include; no team is committed. Without it, iOS builds
are unsigned (CI's are). `bash scripts/flutter-run.sh -d <iPhone id>
--release` builds, signs and installs it.

The Android release APK is signed with the debug key until a release key
is set up.

**Google sign-in** ([sign-in](sign-in.md#per-platform)): Android needs no
app setting (the Google Cloud project's Android OAuth client for
`com.nu01.grigri` and the signing key's SHA-1; the debug key's for now);
iOS takes its client ID and URL scheme from `Info.plist`, filled from
`Private.xcconfig` like the team; the web renders Google's button, which
the site's CSP allows.

**Photos** (profile and gear, and the chat's photos and videos) come
from [image_picker](https://pub.dev/packages/image_picker): Android's photo
picker and camera app (no permissions to declare), iOS's with
`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` and, for the
sound of recorded videos, `NSMicrophoneUsageDescription` in `Info.plist`,
and a file chooser on the web (the site's CSP already allows `data:` and
`blob:` images). They're uploaded to the backend's photo store
([matching](matching.md#data-the-backend-api)).

**The route finder's camera** ([route-finder.md](route-finder.md)) is
the [camera](https://pub.dev/packages/camera) plugin (Flutter's own:
CameraX on Android, which declares the camera permission itself;
AVFoundation on iOS, with `NSCameraUsageDescription`; `getUserMedia` on
the web, allowed by the site's `Permissions-Policy: camera=(self)`).
Phones stream frames (YUV on Android, BGRA on iOS) to the recognizer; the
web, which gives none, takes photos.

**Chat videos** play with [video_player](https://pub.dev/packages/video_player)
(Flutter's own plugin: ExoPlayer on Android, AVPlayer on iOS, a `<video>`
element on the web), streamed from the site's `/photos/` (same origin on
the web, so the CSP's `default-src 'self'` covers it). It adds no
native-assets hook, so `flutter test` still runs under devbox.
