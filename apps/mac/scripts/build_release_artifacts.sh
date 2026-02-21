#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-PressToSpeak}"
APP_DIR="dist/${APP_NAME}.app"
RELEASE_DIR="dist/release"

if [[ ! -d "${APP_DIR}" ]]; then
  echo "Missing ${APP_DIR}. Run make package-app first." >&2
  exit 1
fi

APP_VERSION="${APP_VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_DIR}/Contents/Info.plist" 2>/dev/null || echo "0.1.0")}"
ZIP_PATH="${RELEASE_DIR}/${APP_NAME}-${APP_VERSION}-macOS.zip"
DMG_PATH="${RELEASE_DIR}/${APP_NAME}-${APP_VERSION}-macOS.dmg"

mkdir -p "${RELEASE_DIR}"
rm -f "${ZIP_PATH}" "${DMG_PATH}"

# Zip artifact for website delivery.
ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"

# DMG artifact with /Applications shortcut for drag-and-drop install.
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${APP_NAME}-dmg.XXXXXX")"
trap 'rm -rf "${STAGING_DIR}"' EXIT

cp -R "${APP_DIR}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

echo "Created release artifacts:"
echo "- ${ZIP_PATH}"
echo "- ${DMG_PATH}"
