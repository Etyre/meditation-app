#!/usr/bin/env bash
# Back up / restore the app's on-device data, and deploy to the phone
# without losing it.
#
#   tool/phone.sh backup            snapshot settings + local history off the phone
#   tool/phone.sh restore [dir]     push a snapshot back (default: latest)
#   tool/phone.sh deploy            backup → build release → install IN PLACE → verify
#   tool/phone.sh status            is the app installed, does it have data?
#
# `deploy` installs IN PLACE (`devicectl device install app`), which iOS
# treats as an app update: data container, home-screen position and folder
# all stay put. `flutter install` / `flutter run` after an uninstall would
# delete the app first — wiping data and dropping the icon at the end of the
# last home-screen page. Never use those for updates.
#
# All app state (settings incl. Sheets URL / Toggl token / questions /
# metronome / HR strap, and the local session history + pending uploads) is
# one SharedPreferences plist in the app's data container. Reading/writing
# it works because the app is signed with a development certificate.
#
# Backups go OUTSIDE the repo (they contain the Toggl token):
#   ~/Library/Application Support/meditation-app-backups/<timestamp>/
set -euo pipefail

# Device UDID: from $MEDITATION_DEVICE_ID, else the untracked tool/.device
# file (one line, the UDID from Finder or `xcrun devicectl list devices`).
ROOT_EARLY="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${MEDITATION_DEVICE_ID:-$(cat "$ROOT_EARLY/tool/.device" 2>/dev/null || true)}"
[ -n "$DEVICE" ] || { echo "Set MEDITATION_DEVICE_ID or put the device UDID in tool/.device" >&2; exit 1; }
BUNDLE="com.elityre.meditationTimer"
PLIST_REL="Library/Preferences/$BUNDLE.plist"
BACKUP_ROOT="$HOME/Library/Application Support/meditation-app-backups"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

dc() { xcrun devicectl "$@"; }
container() {
  dc device info files --device "$DEVICE" --domain-type appDataContainer \
     --domain-identifier "$BUNDLE" "$@"
}

cmd_status() {
  echo "== installed app =="
  dc device info apps --device "$DEVICE" 2>/dev/null | grep -i "$BUNDLE" || echo "(not installed)"
  echo "== preferences on device =="
  container --subdirectory Library/Preferences 2>/dev/null | grep -v "^[0-9:]* " || true
}

cmd_backup() {
  local stamp dir
  stamp="$(date +%Y-%m-%d_%H%M%S)"
  dir="$BACKUP_ROOT/$stamp"
  mkdir -p "$dir"
  if ! dc device copy from --device "$DEVICE" --domain-type appDataContainer \
        --domain-identifier "$BUNDLE" --source "$PLIST_REL" \
        --destination "$dir/prefs.plist" >/dev/null 2>&1; then
    rmdir "$dir"
    echo "No preferences file on the device yet (app has never saved anything)." >&2
    echo "Nothing to back up." >&2
    return 1
  fi
  # Human-readable copies alongside the raw plist.
  plutil -convert xml1 -o "$dir/prefs.xml" "$dir/prefs.plist"
  python3 - "$dir" <<'PY'
import json, plistlib, sys, pathlib
d = pathlib.Path(sys.argv[1])
prefs = plistlib.load(open(d / "prefs.plist", "rb"))
settings = json.loads(prefs.get("flutter.app_settings", "{}") or "{}")
history = [json.loads(x) for x in prefs.get("flutter.session_history", [])]
json.dump(settings, open(d / "settings.json", "w"), indent=2)
json.dump(history, open(d / "session_history.json", "w"), indent=2)
redacted = dict(settings)
for k in ("togglApiToken", "sheetsSecret"):
    if redacted.get(k):
        redacted[k] = "<set, %d chars>" % len(redacted[k])
print("settings:", json.dumps(redacted, indent=2))
print("local sessions:", len(history))
PY
  ln -sfn "$dir" "$BACKUP_ROOT/latest"
  echo "Backed up to $dir (also: $BACKUP_ROOT/latest)"
}

cmd_restore() {
  local dir="${1:-$BACKUP_ROOT/latest}"
  [[ -f "$dir/prefs.plist" ]] || { echo "No prefs.plist in $dir" >&2; exit 1; }
  echo "Restoring $dir/prefs.plist → device ($PLIST_REL)"
  echo "(Force-quit the app on the phone first if it is running, so it"
  echo " reads the restored file on next launch.)"
  dc device copy to --device "$DEVICE" --domain-type appDataContainer \
     --domain-identifier "$BUNDLE" --source "$dir/prefs.plist" \
     --destination "$PLIST_REL" >/dev/null
  echo "Restored. Launch the app to check."
}

cmd_deploy() {
  echo "== 1/4 backup =="
  cmd_backup || echo "(continuing without a backup)"
  echo "== 2/4 build =="
  (cd "$ROOT" && flutter build ios --release)
  echo "== 3/4 install in place (keeps app data) =="
  dc device install app --device "$DEVICE" "$ROOT/build/ios/iphoneos/Runner.app"
  echo "== 4/4 verify =="
  cmd_status
}

case "${1:-}" in
  backup)  cmd_backup ;;
  restore) shift; cmd_restore "$@" ;;
  deploy)  cmd_deploy ;;
  status)  cmd_status ;;
  *) sed -n '2,20p' "$0"; exit 1 ;;
esac
