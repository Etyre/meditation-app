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
- **Post-session questions** — configurable questions after each session
  (Settings → Post-session questions → Edit questions). Each question is
  either free answer or multiple choice (optionally with an "Other…" choice
  that takes a written-in answer); drag to reorder. Answers are logged with
  the session.
- **Countdown before start** — optional (Settings → Timer): pressing Begin
  first runs a countdown to settle in; at zero the gong rings and the timer
  starts. Heart rate sampled during the countdown is logged as the
  pre-meditation baseline (plus, as a fallback, the average over the first
  20 seconds of the sit).
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
- `lib/ui/` — the screens (home, session, questionnaire, settings,
  question editor).
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

To update an already-installed phone build without losing its on-device
data (settings, local history), use `tool/phone.sh deploy` — it snapshots
the app's data, builds, and installs in place via `devicectl`. Do **not**
use `flutter install`, which uninstalls first and wipes the data.
`tool/phone.sh backup` / `restore` copy the app's data off/onto the phone
(everything is one SharedPreferences plist); backups land in
`~/Library/Application Support/meditation-app-backups/`.

If the project lives in an iCloud-synced folder (e.g. `~/Documents`),
codesign may reject the Flutter framework ("detritus not allowed"). Point
`build/` outside iCloud: `rm -rf build && ln -s ~/Library/Caches/<name> build`.

## Integration setup

### Google Sheets (~2 min)

1. Create a Google Sheet.
2. Extensions → Apps Script → paste `docs/apps_script.gs`.
3. Project Settings → Script properties → add `SECRET` with a long random
   value (the app can generate one: Settings → Google Sheets → dice icon).
   The script rejects any post that doesn't carry it, so the sheet stays
   yours even if the URL leaks.
4. Deploy → New deployment → Web app, execute as **Me**, access **Anyone**.
5. Copy the `/exec` URL and the same secret into the app: Settings →
   Google Sheets.

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

## Repository history note

On 2026-09-02, before the repo was made public, its history was rewritten
with `git filter-branch` to remove a personal iPhone UDID that had been
hardcoded as the default `DEVICE` in `tool/phone.sh` (commits "Countdown
start w/ HR baseline…" through "phone.sh: read device UDID…"). In the
rewritten commits that line reads `DEVICE="${MEDITATION_DEVICE_ID:-}"`;
nothing else changed, and the final tree is identical to the original.
The device ID now comes from the `MEDITATION_DEVICE_ID` environment
variable or the git-ignored `tool/.device` file.
