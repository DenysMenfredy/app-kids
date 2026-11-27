#!/usr/bin/env bash
#
# Physical-device evidence capture for the G1 flow (Letrando / Lelê).
#
# Refuses emulators, records non-PII device/build metadata, installs a debug
# APK, records logcat while the tester walks the checklist, captures one
# screenshot per step and writes a pass/fail matrix. Raw evidence stays
# outside the repository by default because it can contain PII.
#
# Usage:
#   docs/evidence/g1/android-g1-evidence.sh \
#     --apk lele/build/app/outputs/flutter-apk/app-debug.apk
#
# Options:
#   --apk PATH      APK to install (default: lele/build/app/outputs/flutter-apk/app-debug.apk)
#   --serial ID     adb serial, required when more than one device is attached
#   --out DIR       evidence directory (default: $TMPDIR/g1-evidence-<timestamp>)
#   --fresh         clear app data before the run (wipes only br.com.lele.lele)
#   --no-wizard     only start/stop logcat around a manual run, no step prompts
#   -h, --help      show this help

set -euo pipefail

PACKAGE="br.com.lele.lele"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

APK=""
SERIAL=""
OUT=""
FRESH=0
WIZARD=1

usage() {
  sed -n '3,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk) APK="${2:?--apk needs a path}"; shift 2 ;;
    --serial) SERIAL="${2:?--serial needs an id}"; shift 2 ;;
    --out) OUT="${2:?--out needs a path}"; shift 2 ;;
    --fresh) FRESH=1; shift ;;
    --no-wizard) WIZARD=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

APK="${APK:-$REPO_ROOT/lele/build/app/outputs/flutter-apk/app-debug.apk}"
OUT="${OUT:-${TMPDIR:-/tmp}/g1-evidence-$(date +%Y%m%d-%H%M%S)}"

ADB="${ADB:-}"
if [[ -z "$ADB" ]]; then
  if command -v adb >/dev/null 2>&1; then
    ADB="$(command -v adb)"
  elif [[ -x "$HOME/Android/Sdk/platform-tools/adb" ]]; then
    ADB="$HOME/Android/Sdk/platform-tools/adb"
  else
    echo "adb not found on PATH or at ~/Android/Sdk/platform-tools/adb" >&2
    exit 1
  fi
fi

if [[ ! -f "$APK" ]]; then
  echo "APK not found: $APK" >&2
  echo "Build it with: flutter build apk --debug --dart-define-from-file=config/firebase.dev.json" >&2
  exit 1
fi

if [[ ! -t 0 ]]; then
  echo "Run this script from an interactive terminal." >&2
  exit 2
fi

mapfile -t DEVICES < <("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1 }')

if [[ -n "$SERIAL" ]]; then
  if ! printf '%s\n' "${DEVICES[@]}" | grep -qx "$SERIAL"; then
    echo "Device $SERIAL is not attached in state 'device'." >&2
    "$ADB" devices -l >&2
    exit 1
  fi
elif [[ ${#DEVICES[@]} -eq 1 ]]; then
  SERIAL="${DEVICES[0]}"
elif [[ ${#DEVICES[@]} -eq 0 ]]; then
  echo "No Android device attached. Connect a physical device with USB debugging." >&2
  "$ADB" devices -l >&2
  exit 1
else
  echo "More than one device attached; pass --serial." >&2
  "$ADB" devices -l >&2
  exit 1
fi

prop() {
  "$ADB" -s "$SERIAL" shell getprop "$1" | tr -d '\r'
}

QEMU="$(prop ro.kernel.qemu)"
CHARACTERISTICS="$(prop ro.build.characteristics)"
BOOT_QEMU="$(prop ro.boot.qemu)"
if [[ "$QEMU" == "1" || "$BOOT_QEMU" == "1" || "$CHARACTERISTICS" == *emulator* ]]; then
  echo "Refusing to run: $SERIAL is an emulator. A physical device is required." >&2
  exit 1
fi

mkdir -p "$OUT/screenshots"
LOGCAT_PID=""

cleanup() {
  if [[ -n "$LOGCAT_PID" ]] && kill -0 "$LOGCAT_PID" 2>/dev/null; then
    kill "$LOGCAT_PID" 2>/dev/null || true
    wait "$LOGCAT_PID" 2>/dev/null || true
  fi
}
trap 'cleanup; exit 130' INT TERM
trap cleanup EXIT

APK_SHA="$(sha256sum "$APK" | awk '{print $1}')"
APP_VERSION="$(grep -m1 '^version:' "$REPO_ROOT/lele/pubspec.yaml" | awk '{print $2}')"
GIT_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"

{
  echo "captured_at=$(date -Iseconds)"
  echo "git_commit=$GIT_COMMIT"
  echo "apk=$APK"
  echo "apk_sha256=$APK_SHA"
  echo "app_version=$APP_VERSION"
  echo "manufacturer=$(prop ro.product.manufacturer)"
  echo "model=$(prop ro.product.model)"
  echo "device=$(prop ro.product.device)"
  echo "android_release=$(prop ro.build.version.release)"
  echo "android_sdk=$(prop ro.build.version.sdk)"
  echo "build_id=$(prop ro.build.id)"
  echo "fingerprint=$(prop ro.build.fingerprint)"
  echo "abi=$(prop ro.product.cpu.abi)"
  echo "security_patch=$(prop ro.build.version.security_patch)"
} > "$OUT/device-info.txt"

echo "Device: $(prop ro.product.manufacturer) $(prop ro.product.model), Android $(prop ro.build.version.release) (SDK $(prop ro.build.version.sdk))"
echo "APK SHA-256: $APK_SHA"
echo "Evidence directory: $OUT"

echo
echo "Installing $APK"
"$ADB" -s "$SERIAL" install -r "$APK"

if [[ "$FRESH" -eq 1 ]]; then
  echo "Clearing app data for $PACKAGE (test device only)"
  "$ADB" -s "$SERIAL" shell pm clear "$PACKAGE" >/dev/null
fi

{
  echo "package=$PACKAGE"
  "$ADB" -s "$SERIAL" shell dumpsys package "$PACKAGE" \
    | grep -E 'versionName=|versionCode=|firstInstallTime=|lastUpdateTime=' \
    | sed 's/^[[:space:]]*//' || true
} > "$OUT/app-info.txt"

"$ADB" -s "$SERIAL" logcat -c
"$ADB" -s "$SERIAL" logcat -v threadtime > "$OUT/logcat.txt" 2>&1 &
LOGCAT_PID=$!

"$ADB" -s "$SERIAL" shell monkey -p "$PACKAGE" \
  -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true

if [[ "$WIZARD" -eq 1 ]]; then
  cat > "$OUT/results.csv" <<'CSV'
step,title,result,screenshot
CSV

  titles=(
    "Cold start: splash and welcome carousel"
    "Registration: synthetic parent name, e-mail and password"
    "E-mail verification: link opened, Já confirmei, child setup opens"
    "Child creation: name, age, avatar, Continuar"
    "Assessment: Vamos lá, three questions, placement shown"
    "Child home: journey, streak, coins, XP"
    "Lesson: tap, match, trace, listen, story complete"
    "Reward: XP/coins/streak increment, back navigation"
    "Book: free book pages turn, read-aloud, return to shelf"
    "Stability: relaunch, session persists, no crash"
  )

  echo
  echo "Walk the checklist on the device. For each step, finish it, then"
  echo "capture the result here before moving on. Screenshots are taken"
  echo "automatically after you answer."
  echo

  for i in "${!titles[@]}"; do
    step=$((i + 1))
    printf '[%d/%d] %s\n' "$step" "${#titles[@]}" "${titles[$i]}"
    result=""
    while [[ -z "$result" ]]; do
      read -r -p "  Result [p]ass / [f]ail / [s]kip: " answer
      case "${answer,,}" in
        p|pass) result="PASS" ;;
        f|fail) result="FAIL" ;;
        s|skip) result="SKIP" ;;
        *) echo "  Answer p, f or s." ;;
      esac
    done

    read -r -p "  Press Enter to take the screenshot..." _
    shot="$OUT/screenshots/$(printf '%02d' "$step").png"
    if ! "$ADB" -s "$SERIAL" exec-out screencap -p > "$shot" 2>/dev/null || [[ ! -s "$shot" ]]; then
      echo "  Screenshot failed; capture it manually and note the filename." >&2
      shot=""
      rm -f "$shot"
    fi
    printf '%s,"%s",%s,%s\n' "$step" "${titles[$i]}" "$result" "${shot:-none}" >> "$OUT/results.csv"
    echo
  done
else
  echo
  echo "Logging now. Run the checklist in docs/evidence/g1/android-physical-2026-11-27.md."
  read -r -p "Press Enter when the flow is complete..." _
fi

cleanup
LOGCAT_PID=""

"$ADB" -s "$SERIAL" logcat -d -b crash -v threadtime > "$OUT/crash.txt" 2>/dev/null || true

{
  echo "finished_at=$(date -Iseconds)"
  echo "logcat_lines=$(wc -l < "$OUT/logcat.txt" | tr -d ' ')"
  echo "crash_lines=$(wc -l < "$OUT/crash.txt" | tr -d ' ')"
  echo "screenshots=$(find "$OUT/screenshots" -type f | wc -l | tr -d ' ')"
} >> "$OUT/device-info.txt"

echo
echo "Done. Evidence saved to $OUT"
echo "Before attaching anything:"
echo "  - review logcat.txt for e-mail addresses and UIDs;"
echo "  - mask parent/child names and e-mails in screenshots;"
echo "  - never commit raw evidence containing PII."
echo "Files: device-info.txt, app-info.txt, results.csv, logcat.txt, crash.txt, screenshots/"
