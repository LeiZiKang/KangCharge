#!/bin/bash
# Builds a Developer ID–signed, notarized "Kang Charge.zip" for GitHub Releases.
#
# One-time setup (stores an app-specific password in your keychain):
#   xcrun notarytool store-credentials kangcharge-notary --apple-id you@example.com --team-id ABCDE12345
# Then:
#   NOTARY_PROFILE=kangcharge-notary scripts/release.sh
#   scripts/release.sh --skip-notarize      # sign only, for a local test
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD="$ROOT/build/ReleaseDD"
OUT="$ROOT/build/release"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SKIP_NOTARIZE=0
[[ "${1:-}" == "--skip-notarize" ]] && SKIP_NOTARIZE=1

if [[ $SKIP_NOTARIZE -eq 0 && -z "${NOTARY_PROFILE:-}" ]]; then
  echo "Set NOTARY_PROFILE to a notarytool keychain profile, or pass --skip-notarize." >&2
  exit 1
fi

xcodebuild -project "$ROOT/KangCharge.xcodeproj" -scheme KangCharge -configuration Release \
  -derivedDataPath "$DD" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" \
  PROVISIONING_PROFILE_SPECIFIER= OTHER_CODE_SIGN_FLAGS=--timestamp build -quiet

APP="$DD/Build/Products/Release/Kang Charge.app"
codesign --verify --deep --strict "$APP"
rm -rf "$OUT" && mkdir -p "$OUT"
ZIP="$OUT/Kang-Charge.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ $SKIP_NOTARIZE -eq 0 ]]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm "$ZIP" && ditto -c -k --keepParent "$APP" "$ZIP"
  spctl --assess --type execute --verbose "$APP"
fi

echo "Release archive: $ZIP"
