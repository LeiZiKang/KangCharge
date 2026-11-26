# Xcode Cloud Setup (SugarWatt)

Both `KangCharge` (macOS) and `KangCharge-iOS` (iOS + watchOS) include ready-to-run Xcode Cloud hooks at `ci_scripts/ci_post_clone.sh`.

## Required Xcode Cloud Environment Variables

Because `Config/Local.xcconfig` is git-ignored in our public MIT repositories, configure these two environment variables in **App Store Connect → Xcode Cloud → Manage Workflows → Environment**:

| Name | Value | Secret? |
| --- | --- | --- |
| `KC_DEVELOPMENT_TEAM` | Your 10-character Apple Developer Team ID | Yes |
| `KC_BUNDLE_ID_PREFIX` | Your reverse-DNS prefix (e.g. `io.github.yourname`) | No |

## What `ci_post_clone.sh` Automates
1. **Generates `Config/Local.xcconfig`** on the runner before Xcode resolves signing.
2. **Auto-increments `CURRENT_PROJECT_VERSION`** using Xcode Cloud's `CI_BUILD_NUMBER`, preventing duplicate TestFlight/App Store build-number rejections on frequent releases.
3. **Skips SPM macro fingerprint prompts** for unattended headless builds.
4. **Mac App Store compliance (`APP_STORE` flag)**: On macOS Xcode Cloud builds, defines `APP_STORE` so the external GitHub Releases update checker is automatically excluded per App Store Review Guideline 2.4.5.
