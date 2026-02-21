#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-PressToSpeak}"
APP_DIR="dist/${APP_NAME}.app"
RELEASE_DIR="dist/release"
NOTARY_PROFILE="${NOTARY_PROFILE:-${APPLE_NOTARY_PROFILE:-}}"

if [[ -z "${NOTARY_PROFILE}" ]]; then
  echo "Missing NOTARY_PROFILE (or APPLE_NOTARY_PROFILE)." >&2
  echo "Example: NOTARY_PROFILE=press-to-speak-notary make notarized-release" >&2
  exit 1
fi

if [[ ! -d "${APP_DIR}" ]]; then
  echo "Missing ${APP_DIR}. Run make release-artifacts first." >&2
  exit 1
fi

APP_VERSION="${APP_VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_DIR}/Contents/Info.plist" 2>/dev/null || echo "0.1.0")}"
DMG_PATH="${RELEASE_DIR}/${APP_NAME}-${APP_VERSION}-macOS.dmg"

if [[ ! -f "${DMG_PATH}" ]]; then
  echo "Missing DMG artifact ${DMG_PATH}. Run make release-artifacts first." >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun not found. Install Xcode Command Line Tools." >&2
  exit 1
fi

echo "Submitting for notarization: ${DMG_PATH}"
xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait

echo "Stapling notarization ticket"
xcrun stapler staple "${APP_DIR}"
xcrun stapler staple "${DMG_PATH}"

echo "Notarization complete: ${DMG_PATH}"
