# Meditation Timer

A meditation timer for iPhone (and, with one build command, Android) built
with Flutter.

## What it does

- **Timer with gong** — set a length, press Begin; a synthesized gong sounds
  when time is up.
- **Overtime stopwatch** — after the gong, a stopwatch counts up until you
  press Stop. You then choose whether to add that overtime to the timed
  amount.
- **Early abort** — pressing Stop before the gong records the time actually
  sat (shorter than the timer length) and marks the session aborted.
- **Post-session questions** — configurable questions after each session;
  answers are logged with the session.
- **Google Sheets logging** — start/stop time, planned timer length,
  meditated minutes, overtime, abort flag, your answers, and heart data are
  appended as a row to your sheet.
- **Heart rate / HRV (optional)** — connect a BLE strap (Polar H10 etc.).
  If connected when a session starts, the app records heart rate and the raw
  RR (beat-to-beat) intervals, and computes RMSSD, SDNN, ln(RMSSD) and an
  Elite-HRV-style 0-100 score. Raw RR data goes to the sheet too.
- **Toggl** — the session block (start → stop wall-clock time) is logged as
  a Toggl Track time entry tagged `meditation`.
- **Metronome** — optional repeating pattern of up to 4 tones with a
  configurable gap after each, playing throughout the session.

## Project layout

The code is split so an Android release is just a build, and even a
non-Flutter port would only replace the thin outer layers:

- `lib/core/` — **pure Dart, no platform code**: session state machine
  (`session_engine.dart`), metronome scheduler, HRV math, BLE heart-rate
  packet parser, models, and service interfaces.
- `lib/infra/` — implementations of those interfaces: audioplayers audio,
  flutter_blue_plus BLE, Google Sheets webhook, Toggl v9 API, settings
  storage.
- `lib/controllers/` — `SessionController` wires the engine to audio,
  metronome, HR recording, and logging.
- `lib/ui/` — the screens (home, session, questionnaire, settings).
- `test/` — unit tests for all the core logic.

## Building

Prereqs (macOS): [Flutter](https://docs.flutter.dev/get-started/install)
(`brew install --cask flutter`), and for iOS: full Xcode from the App Store
plus CocoaPods (`brew install cocoapods`).

```sh
flutter pub get
flutter test          # runs without Xcode
flutter run           # to a connected iPhone / simulator
flutter build apk     # the Android version
```

First iOS device build: open `ios/Runner.xcworkspace` in Xcode once to set
your signing team (Runner target → Signing & Capabilities), then
`flutter run`.

## Integration setup

### Google Sheets (~2 min)

1. Create a Google Sheet.
2. Extensions → Apps Script → paste `docs/apps_script.gs`.
3. Deploy → New deployment → Web app, execute as **Me**, access **Anyone**.
4. Copy the `/exec` URL into the app: Settings → Google Sheets.

Rows are appended with headers created automatically, including one column
per question. Failed uploads (no network) are queued on the phone and
retried on the next launch/session.

### Toggl

Settings → Toggl → paste your API token from
[track.toggl.com/profile](https://track.toggl.com/profile). The default
workspace is discovered automatically; the entry description is
configurable (default "Meditation").

### Heart rate strap

Wear the strap (most only advertise while worn), then Settings → Heart rate
monitor (or the chip on the home screen) → pick the device. If it's
connected when you press Begin, the session records HR/HRV automatically.

## Notes

- Keep the phone unlocked during a session (the app holds a wakelock and
  dims nothing itself). iOS suspends timers of backgrounded apps, so the
  gong may be delayed if you lock the screen; the elapsed-time math stays
  correct because it's computed from wall-clock time, not tick counting.
- Audio assets in `assets/audio/` are synthesized (script preserved in
  `tool/gen_sounds.py`); regenerate or replace them with your own recordings
  freely — same filenames.
