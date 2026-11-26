#!/bin/sh
set -e

# Xcode Cloud post-clone hook for SugarWatt (macOS).
# Injects git-ignored signing settings from Xcode Cloud environment variables,
# auto-increments CFBundleVersion from CI_BUILD_NUMBER, and enables APP_STORE
# compilation flag when archiving for Mac App Store distribution.

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"

defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES

TEAM_ID="${KC_DEVELOPMENT_TEAM:-${CI_TEAM_ID:-}}"
BUNDLE_PREFIX="${KC_BUNDLE_ID_PREFIX:-io.github.leizikang}"
BUILD_NUM="${CI_BUILD_NUMBER:-2}"

if [ -z "$TEAM_ID" ]; then
  echo "error: KC_DEVELOPMENT_TEAM is not set. Add KC_DEVELOPMENT_TEAM in Xcode Cloud Workflow -> Environment." >&2
  exit 1
fi

cat > Config/Local.xcconfig <<EOF
DEVELOPMENT_TEAM = ${TEAM_ID}
BUNDLE_ID_PREFIX = ${BUNDLE_PREFIX}
CODE_SIGN_STYLE = Automatic
CURRENT_PROJECT_VERSION = ${BUILD_NUM}
SWIFT_ACTIVE_COMPILATION_CONDITIONS = \$(inherited) APP_STORE
EOF

echo "Configured Config/Local.xcconfig for Xcode Cloud macOS build #${BUILD_NUM} (${BUNDLE_PREFIX}.kangcharge)."

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi
