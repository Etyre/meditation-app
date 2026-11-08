# Meditation Timer

A meditation timer for iPhone (and, with one build command, Android) built
with Flutter, started 10 August 2026. It was built so one tap starts a sit
with a real gong at the end, and so every session (length, overtime, answers
to a few post-sit questions, heart-rate/HRV from a chest strap) lands in a
Google Sheet and Toggl without any typing afterwards.

## How it works

- **Two kinds of sit** — the home screen is a toggle between **Structured
  session** and **Single practice**. The choice, the selected session and
  the last practice are remembered, so the app reopens the way it was left.
- **Single practice** — pick a practice chip (or *Write in…* and type one;
  it joins the list when the sit begins) and a length, or ∞ for open-ended.
  The practice list is edited under Settings → Practices (reorder, rename,
  delete); renaming updates any structured session that uses it.
- **Structured session** — a saved protocol: an ordered list of segments,
  each a practice for a set number of minutes, e.g. 5 min following the
  breath, 5 min noting "hear", 5 min noting "feel", 5 min noting "see",
  10 min open monitoring (the built-in *Noting ladder*). Each segment has a
  **cue** that plays as it begins: any gong from the bank, the practice name
  spoken aloud (text-to-speech), both, or neither. The first segment's cue
  starts the sit (in place of the start gong); the Settings end gong rings
  when the last segment ends, then overtime counts up as usual. Interval
  gongs from Settings apply to single practices only. Design sessions under
  Settings → Structured sessions or the *Edit structured sessions* link on
  the home screen: name, drag-to-reorder segments, per-segment practice
  (type it or pick from the list), minutes, cue, and a preview button.
- **During the sit** the session screen shows the current practice; in a
  structured session also "2 of 5", the time left in this practice, what
  comes next, and the total remaining.
- **After every sit** the same post-session questionnaire runs, and the
  practice (or session name) is logged with the session: sheet columns
  `Practice` (the practice, or the protocol's name) and `Protocol` (the
  segments as "Following the breath 5 / Noting: hear 5 / …", blank for a
  single practice). History shows the practice on each row.
- **Timer with gong** — set a length, press Begin; a synthesized gong sounds
  when time is up. Settings → Gongs picks the sound for the start and end
  gongs from six options (gong, deep gong, shimmering gong, singing bowl,
  bell, chime), each with a preview button.
- **Interval gongs** — optionally add any number of extra gongs during the
  sit (Settings → Gongs → Add interval gong), each at a chosen number of
  minutes after the timer starts and with its own sound. Ones set at or past
  the timer length are skipped; in open-ended sessions they all ring.
- **Overtime stopwatch** — after the gong, a stopwatch counts up until you
  press Stop. You then choose whether to add that overtime to the timed
  amount.
- **Early abort** — pressing Stop before the gong records the time actually
  sat (shorter than the timer length) and marks the session aborted.
- **Open-ended sessions** — no timer, just a stopwatch you end yourself.
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
  appended as a row to your sheet. Rows are appended with headers created
  automatically, including one column per question. Failed uploads (no
  network) are queued on the phone and retried on the next launch/session.
- **Local history** — every session is saved on the phone first
  (offline-first); the History screen lists them and shows what is still
  pending upload.
- **Heart rate / HRV (optional)** — connect a BLE strap (Polar H10 etc.).
  If connected when a session starts, the app records heart rate and the raw
  RR (beat-to-beat) intervals, and computes RMSSD, SDNN, ln(RMSSD) and an
  Elite-HRV-style 0-100 score. Raw RR data goes to the sheet too.
- **Toggl** — the session block (start → stop wall-clock time) is logged as
  a Toggl Track time entry tagged `meditation`, filed under the chosen
  default project.
- **Metronome** — optional repeating pattern of up to 4 tones with a
  configurable gap after each, playing throughout the session.
- **Lock-screen keep-alive** — the app holds a wakelock so the screen stays
  on by default. You can lock the phone during a session: a near-silent
  audio loop plays from Begin to Stop, which (together with the `audio`
  background mode in `ios/Runner/Info.plist`) keeps iOS from suspending the
  app, so gongs ring on time with the screen off. Elapsed-time math is
  computed from wall-clock time, not tick counting, so it stays correct even
  if the app is suspended.
- **Drafts are never lost** — every text field saves on each keystroke.
  Settings fields (sheet URL, secret, Toggl token and description, countdown,
  metronome gaps, interval gong times) write straight into the persisted
  settings. Other screens save to SharedPreferences
  (`lib/infra/storage/drafts.dart`) and restore before first paint:
  the questionnaire under `draft.questionnaire.<session start>`, the question
  editor under `draft.questionEditor.<question|new>`, the home-screen
  write-in practice under `draft.home.writeIn`, the structured-session
  editor under `draft.protocolEditor.<id|new>` (name, every segment's
  practice and minutes text, cues), and the practice rename dialog under
  `draft.practiceEditor.<name|new>`. They clear only on Save / "Save & log",
  "Discard", or when the sit begins (write-in).

### Code layout

The code is split so an Android release is just a build, and even a
non-Flutter port would only replace the thin outer layers:

- `lib/core/` — **pure Dart, no platform code**: session state machine
  (`session_engine.dart`, including protocol segments), metronome scheduler,
  HRV math, BLE heart-rate packet parser, models (practices, protocols,
  session plan), and service interfaces (audio, speech, …).
- `lib/infra/` — implementations of those interfaces: audioplayers audio,
  flutter_tts speech, flutter_blue_plus BLE, Google Sheets webhook, Toggl v9
  API, settings storage, drafts.
- `lib/controllers/` — `SessionController` wires the engine to audio,
  metronome, HR recording, and logging.
- `lib/ui/` — the screens (home, session, questionnaire, settings,
  question editor, history).
- `test/` — unit tests for all the core logic.

## Files

| File | Purpose |
| --- | --- |
| `lib/main.dart` | Entry point; builds every service and wires providers. Header comment describes where config/state live |
| `lib/core/session_engine.dart` | Session state machine: countdown, timer, gongs, protocol segments, overtime, abort |
| `lib/core/metronome.dart` | Metronome scheduler |
| `lib/core/hrv/hr_recorder.dart`, `hrv_analysis.dart` | HR/RR recording and RMSSD/SDNN/score math |
| `lib/core/ble/heart_rate_parser.dart` | BLE Heart Rate Measurement packet parser |
| `lib/core/models/` | `AppSettings`, `GongConfig`, `MetronomeConfig`, `Protocol`/`ProtocolSegment`/`Cue` + defaults (`protocol.dart`), `SessionPlan`, `Question`, `SessionOutcome`, `SessionRecord`, heart-rate types |
| `lib/core/services/` | Interfaces: audio, speech (TTS), clock, heart rate, session log, sheets logger, Toggl |
| `lib/infra/audio/player_audio_service.dart` | audioplayers implementation; gong bank asset list; keep-alive loop |
| `lib/infra/speech/flutter_tts_speech.dart` | Spoken cues via flutter_tts (shared audio session, mix-with-others) |
| `lib/infra/ble/flutter_blue_hr_service.dart` | flutter_blue_plus heart-rate strap connection |
| `lib/infra/sheets/webhook_sheets_logger.dart` | POSTs rows to the Apps Script web app with the shared secret |
| `lib/infra/toggl/toggl_api_service.dart` | Toggl Track v9 API: workspace discovery, projects, time entries |
| `lib/infra/storage/settings_store.dart` | Loads/saves `AppSettings` as one JSON string in SharedPreferences |
| `lib/infra/storage/session_history_store.dart` | Local session history + pending-upload queue and retry |
| `lib/infra/storage/drafts.dart` | Save-as-you-type storage for the questionnaire, editors and write-in field |
| `lib/controllers/session_controller.dart` | Glue between engine, audio, speech, metronome, HR recorder, history; plays segment cues |
| `lib/ui/home_screen.dart` | Structured / single toggle, protocol cards, practice chips + write-in, length picker, Begin, HR chip |
| `lib/ui/session_screen.dart` | Running timer / stopwatch with current practice and segment, Stop |
| `lib/ui/questionnaire_screen.dart` | Post-session summary, overtime choice, questions, Save & log |
| `lib/ui/settings_screen.dart` | Timer, gongs, metronome, Sheets, Toggl, HR strap, questions |
| `lib/ui/questions_screen.dart` | Question list (reorder/delete) and the question editor |
| `lib/ui/protocols_screen.dart` | Structured session list (reorder/duplicate/delete) and the segment editor |
| `lib/ui/practices_screen.dart` | Practice list (reorder/rename/delete) |
| `lib/ui/history_screen.dart`, `hr_connect_sheet.dart`, `format.dart` | History list, BLE picker sheet, formatting helpers |
| `assets/audio/*.wav` | Synthesized gong bank, metronome tones, tick, near-silent keep-alive loop |
| `docs/apps_script.gs` | The Google Sheet side: appends rows, checks `SECRET`, splits oversized cells |
| `tool/gen_sounds.py` | Regenerates `assets/audio/` (stdlib only, about a minute) |
| `tool/gen_icon.swift` | Draws the app icon (partially opened lotus) into the iOS asset catalog and Android mipmaps |
| `tool/phone.sh` | backup / restore / deploy / status against the connected iPhone via `devicectl` |
| `tool/.device` | (untracked) the iPhone UDID for `phone.sh` |
| `test/*.dart` | Unit tests: engine (incl. segments), metronome, HRV, BLE parser, gong config, protocols/plans/settings, questions, history store, sheets logger, drafts |

## Runtime locations

- **Config and state (phone)**: all app state (settings incl. Sheets URL /
  Toggl token / questions / metronome / HR strap, the local session history +
  pending uploads, and `draft.*` text drafts) is one SharedPreferences plist
  in the app's data container on the device. Nothing is stored on the Mac.
- **Backups (Mac)**: `~/Library/Application Support/meditation-app-backups/<timestamp>/`
  written by `tool/phone.sh backup`. They contain the Toggl token, so they
  live outside the repo.
- **Build output**: `build/` is a symlink to `~/Library/Caches/meditation-app-build`
  (outside iCloud; see Gotchas).
- **Secrets**: none in the repo. The Sheets URL + secret and the Toggl token
  are entered in the app's Settings. `tool/.device` (UDID) is gitignored.
- **Logs**: none; failures surface as snackbars and are retried.
- **Generated**: `ios/Flutter/ephemeral/flutter_native_integration.env` and
  `.dart_tool/package_config.json` are rebuilt by every `flutter` command and
  gitignored.

## Common tasks

Prereqs (macOS): [Flutter](https://docs.flutter.dev/get-started/install)
(`brew install --cask flutter`), and for iOS: full Xcode from the App Store
plus CocoaPods (`brew install cocoapods`; needed since `flutter_tts`, which
has no Swift Package manifest, so Flutter generated `ios/Podfile`).

```sh
flutter pub get
flutter analyze
flutter test          # runs without Xcode; the end-to-end proof for the core logic
flutter run           # to a connected iPhone / simulator
flutter build apk     # the Android version
```

First iOS device build: open `ios/Runner.xcworkspace` in Xcode once to set
your signing team (Runner target → Signing & Capabilities), then
`flutter run`.

Update the phone without losing its data:

```sh
echo <UDID> > tool/.device          # once; or export MEDITATION_DEVICE_ID
tool/phone.sh status                # installed? has data?
tool/phone.sh backup                # snapshot settings + history off the phone
tool/phone.sh deploy                # backup → build release → install IN PLACE → verify
tool/phone.sh restore [dir]         # push a snapshot back (default: latest)
```

`deploy` snapshots the app's data, builds, and installs in place via
`devicectl`. Do **not** use `flutter install`, which uninstalls first and
wipes the data. `backup` / `restore` copy the app's data off/onto the phone
(everything is one SharedPreferences plist).

Regenerate the audio assets (pass filenames to redo only some):

```sh
python3 tool/gen_sounds.py
```

Regenerate the app icon after editing the drawing in `tool/gen_icon.swift`:

```sh
swift tool/gen_icon.swift
```

Try the new session model without a phone: `flutter test` covers segment
timing (`test/session_engine_test.dart`) and protocol/plan serialisation
(`test/protocol_test.dart`); the cue preview button in the session editor
plays a segment's gong + spoken name on demand.

Point `build/` outside iCloud if the symlink is lost:

```sh
rm -rf build && ln -s ~/Library/Caches/meditation-app-build build
```

### Integration setup

**Google Sheets (~2 min)**

1. Create a Google Sheet.
2. Extensions → Apps Script → paste `docs/apps_script.gs`.
3. Project Settings → Script properties → add `SECRET` with a long random
   value (the app can generate one: Settings → Google Sheets → dice icon).
   The script rejects any post that doesn't carry it, so the sheet stays
   yours even if the URL leaks.
4. Deploy → New deployment → Web app, execute as **Me**, access **Anyone**.
5. Copy the `/exec` URL and the same secret into the app: Settings →
   Google Sheets.

**Toggl**

Settings → Toggl → paste your API token from
[track.toggl.com/profile](https://track.toggl.com/profile). The default
workspace is discovered automatically; the entry description is
configurable (default "Meditation"), and a default project can be picked.

**Heart rate strap**

Wear the strap (most only advertise while worn), then Settings → Heart rate
monitor (or the chip on the home screen) → pick the device. If it's
connected when you press Begin, the session records HR/HRV automatically.

## Settings that matter

- `ios/Runner/Info.plist` has the `audio` background mode; without it iOS
  suspends the app when the phone is locked and gongs ring late.
- Xcode: signing team on the Runner target (development certificate; this
  is also what lets `tool/phone.sh` read and write the app's data container).
- Apps Script deployment: execute as **Me**, access **Anyone**, with the
  `SECRET` script property set.
- Bluetooth permission is requested on first strap connection.

## Gotchas learned

- `ios/Podfile` pins `platform :ios, '15.0'` and forces every pod target to
  15.0 in `post_install`. Flutter's template says 13.0 and `flutter_tts`'s
  podspec says 8.0; Xcode 27 refuses anything below 15.0 ("Target
  Integrity: IPHONEOS_DEPLOYMENT_TARGET is set to 13.0, but the range of
  supported deployment target versions is 15.0 to 27.2.x").
- `flutter_tts` must share the audio session with audioplayers
  (`setSharedInstance(true)` + playback category with mix-with-others,
  done in `FlutterTtsSpeech.init`). Without that, the first utterance
  reconfigures/deactivates the session and the keep-alive loop stops, so
  later gongs wait for the phone to be unlocked.
- Spoken cues start 1.5 s after their gong (`speechDelayAfterGong`) so the
  voice sits on the gong's tail rather than fighting the strike.
- The 1024 px iOS marketing icon must have no alpha channel; `gen_icon.swift`
  draws into a `noneSkipLast` CoreGraphics context for that reason (an
  `NSBitmapImageRep` with `hasAlpha: false` cannot even be made a context).
- Settings written before this feature load the default practice list and
  the built-in *Noting ladder*; an explicitly empty list stays empty.

- `flutter install` / `flutter run` after an uninstall delete the app first,
  wiping settings and history and dropping the icon at the end of the last
  home-screen page. Always update with `tool/phone.sh deploy`.
- If the project lives in an iCloud-synced folder (e.g. `~/Documents`),
  codesign may reject the Flutter framework ("detritus not allowed"). Point
  `build/` outside iCloud: `rm -rf build && ln -s ~/Library/Caches/<name> build`.
- Google Sheets cells have a size limit; `docs/apps_script.gs` splits
  oversized values (raw RR data) across continuation columns.
- Audio assets in `assets/audio/` are synthesized by `tool/gen_sounds.py`.
  Replace them with your own recordings freely — same filenames. The gong
  bank order is listed at the top of that script and in
  `lib/core/models/gong_config.dart`; keep the two in sync.
- Numeric settings fields (countdown, metronome gap, interval gong time)
  only persist when the typed value is in range, so a half-typed number is
  not written; the previous value stays.
- `Drafts.init()` must be awaited in `main()` before `runApp`; reads are
  synchronous and silently return nothing before it.
- `.git-rewrite/` is an empty leftover from the 2026-09-02 `filter-branch`
  run (below); it is untracked and safe to delete.

## Repository history note

On 2026-09-02, before the repo was made public, its history was rewritten
with `git filter-branch` to remove a personal iPhone UDID that had been
hardcoded as the default `DEVICE` in `tool/phone.sh` (commits "Countdown
start w/ HR baseline…" through "phone.sh: read device UDID…"). In the
rewritten commits that line reads `DEVICE="${MEDITATION_DEVICE_ID:-}"`;
nothing else changed, and the final tree is identical to the original.
The device ID now comes from the `MEDITATION_DEVICE_ID` environment
variable or the git-ignored `tool/.device` file.
