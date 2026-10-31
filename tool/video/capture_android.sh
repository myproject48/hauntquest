#!/bin/sh
# Opt-in capture of actual Android Flutter frames through legal UI input.
# Exports during the test because flutter test uninstalls its app afterward.
set -eu
cd "$(dirname "$0")/../.."
HQ_DEVICE="${1:-emulator-5554}"
HQ_ADB="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}/platform-tools/adb"
if command -v adb >/dev/null 2>&1; then HQ_ADB="$(command -v adb)"; fi
if [ ! -x "$HQ_ADB" ]; then
  echo 'Android Platform Tools adb is required; set ANDROID_HOME or put adb on PATH.' >&2
  exit 1
fi
mkdir -p build/video
python3 tool/video/export_server.py > build/video/export-server.log 2>&1 &
HQ_EXPORT_PID=$!
cleanup() {
  kill "$HQ_EXPORT_PID" 2>/dev/null || true
  "$HQ_ADB" -s "$HQ_DEVICE" reverse --remove tcp:8765 >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM
"$HQ_ADB" -s "$HQ_DEVICE" reverse tcp:8765 tcp:8765
flutter test integration_test/video_capture_test.dart -d "$HQ_DEVICE" \
  --dart-define=HQ_CAPTURE_VIDEO=true --dart-define=HQ_REVIEW_TOOLS=false \
  --reporter expanded > build/video/capture-export.log 2>&1
test -s build/video/android/manifest.json
printf '%s\n' 'Actual Android frames exported to build/video/android/'
