#!/bin/bash
# Renders README screenshots from sample data (no device needed) into docs/screenshots.
# Builds a Debug copy without the App Sandbox so the images can be written outside the container.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
DD="$ROOT/build/ScreenshotsDD"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

xcodebuild -project "$ROOT/KangCharge.xcodeproj" -scheme KangCharge -configuration Debug \
  -derivedDataPath "$DD" CODE_SIGN_ENTITLEMENTS=Config/Screenshots.entitlements \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build -quiet

APP="$DD/Build/Products/Debug/Kang Charge.app"
TMP="$(mktemp -d)"
pkill -f "Kang Charge.app/Contents/MacOS" || true
"$APP/Contents/MacOS/Kang Charge" -kcSnapshot YES -kcDemo YES -kcSnapshotDir "$TMP" &
PID=$!
for _ in $(seq 1 60); do [ -f "$TMP/widget-large.png" ] && break; sleep 1; done
sleep 1
kill "$PID" 2>/dev/null || true

mkdir -p "$OUT"
for name in dashboard port-sheet menubar widget-small widget-medium widget-large; do
  [ -f "$TMP/$name.png" ] && cp "$TMP/$name.png" "$OUT/$name.png"
done
rm -rf "$TMP"
echo "Screenshots written to $OUT"
