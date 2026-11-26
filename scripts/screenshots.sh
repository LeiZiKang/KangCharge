#!/bin/bash
# Renders light & dark README/website screenshots from sample data (no device needed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
DD="$ROOT/build/ScreenshotsDD"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

xcodebuild -project "$ROOT/KangCharge.xcodeproj" -scheme KangCharge -configuration Debug \
  -derivedDataPath "$DD" CODE_SIGN_ENTITLEMENTS=Config/Screenshots.entitlements \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build -quiet

APP="$DD/Build/Products/Debug/SugarWatt.app"
TMP="$(mktemp -d)"
pkill -f "SugarWatt.app/Contents/MacOS" || true
"$APP/Contents/MacOS/SugarWatt" -kcSnapshot YES -kcDemo YES -kcSnapshotDir "$TMP" &
PID=$!
for _ in $(seq 1 40); do [ -f "$TMP/widget-heatmap-medium-dark.png" ] && break; sleep 0.5; done
sleep 1
kill "$PID" 2>/dev/null || true

mkdir -p "$OUT"
for f in "$TMP"/*.png; do
  [ -f "$f" ] && cp "$f" "$OUT/$(basename "$f")"
done
# Keep canonical aliases for README compatibility
[ -f "$OUT/dashboard-light.png" ] && cp "$OUT/dashboard-light.png" "$OUT/dashboard.png"
[ -f "$OUT/menubar-light.png" ] && cp "$OUT/menubar-light.png" "$OUT/menubar.png"
[ -f "$OUT/widget-small-light.png" ] && cp "$OUT/widget-small-light.png" "$OUT/widget-small.png"
[ -f "$OUT/widget-medium-light.png" ] && cp "$OUT/widget-medium-light.png" "$OUT/widget-medium.png"
[ -f "$OUT/widget-large-light.png" ] && cp "$OUT/widget-large-light.png" "$OUT/widget-large.png"

rm -rf "$TMP"
echo "Screenshots written to $OUT"
ls -lh "$OUT"
