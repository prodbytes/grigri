# Logging

The app logs what helps developers fix problems, on every platform. It's
for developers only: the app never shows it to its users. Nothing is sent
anywhere.

## The log

[lib/log.dart](../grigri_app/lib/log.dart) (`AppLog`, used as `log`):

- **Lines**: time, level (`INFO`, `WARN`, `ERROR`), a tag (`start`,
  `auth`, `api`, `live`, `flutter`, `uncaught`) and the message.
- **Where they go**, in debug and release builds alike:
  - **Web**: the browser's console (developer tools).
  - **Android**: logcat, tag `flutter`; `devbox run android-log`
    (`scripts/android-log.sh`). Also the log file.
  - **iOS**: the device log (Xcode's console for debug runs), and the log
    file, which `devbox run ios-log` (`scripts/ios-log.sh`) copies off
    the iPhone attached by USB with `xcrun devicectl` (`--follow` keeps
    printing new lines, `--previous` shows the older file;
    `IOS_DEVICE=<udid>` with several). Release builds' lines don't reach
    a USB log stream on recent iOS, so the file is the way to read them.
- **The log file** (Android and iOS, [log_file_io.dart](../grigri_app/lib/log_file_io.dart)):
  `grigri.log` in the app's support directory (iOS: the app container's
  `Library/Application Support`), appended line by line so the lines
  before a crash are kept, across restarts. Past 512 KB it's moved to
  `grigri.log.1` when the app starts (at most about 1 MB). Lines logged
  before it opens are written to it first.

## What's logged

- **Start**: the version, stage, platform, the API's site, the sign-in
  method and the Google client IDs (public identifiers) the build has, or
  `none`.
- **Sign-in**: each step (initialized, the button pressed, a Google ID
  token received, the API's session started) and each failure with its
  error type and message (Google's error code and description, the
  API's answer).
- **API calls that fail**: method and path, then the status and the
  server's message, a timeout, or the site unreachable. Never bodies or
  headers.
- **Live updates**: an MQTT connection that fails (the error's type
  only, as its message may quote the URL, which carries the token) or is
  refused (its return code).
- **Uncaught errors**: Flutter's (`FlutterError.onError`, still reported
  as before) and the rest (`PlatformDispatcher.onError`), with their
  stacks.

## Privacy

Every line is scrubbed before it's printed or written: emails become
`<email>`, JWTs (Google ID tokens) `<jwt>`, and bearer tokens
`Bearer <token>`. Session tokens are never logged ([sign-in](sign-in.md)).
The file stays in the app's own storage.

## Tests

`test/log_test.dart`: the in-memory cap, the scrubbing, the line format,
and the file getting the earlier lines, then every new one.
