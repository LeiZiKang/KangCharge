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

TEAM_ID="${KC_DEVELOPMENT_TEAM:-}"
BUNDLE_PREFIX="${KC_BUNDLE_ID_PREFIX:-com.example}"
BUILD_NUM="${CI_BUILD_NUMBER:-2}"

cat > Config/Local.xcconfig <<EOF
DEVELOPMENT_TEAM = ${TEAM_ID}
BUNDLE_ID_PREFIX = ${BUNDLE_PREFIX}
CURRENT_PROJECT_VERSION = ${BUILD_NUM}
SWIFT_ACTIVE_COMPILATION_CONDITIONS = \$(inherited) APP_STORE
EOF

echo "Configured Config/Local.xcconfig for Xcode Cloud build #${BUILD_NUM}."

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi
