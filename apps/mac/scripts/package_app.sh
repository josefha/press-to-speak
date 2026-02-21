#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PressToSpeak"
PRODUCT="PressToSpeakApp"
BUNDLE_ID="com.opensource.presstospeak"
BUILD_BINARY=".build/release/${PRODUCT}"
APP_DIR="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

swift build -c release --product "${PRODUCT}"

if [[ ! -f "${BUILD_BINARY}" ]]; then
  echo "Release binary not found: ${BUILD_BINARY}" >&2
  exit 1
fi

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_BINARY}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Package local env for installed app use (optional).
if [[ -f ".env" ]]; then
  cp ".env" "${RESOURCES_DIR}/app.env"
fi

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>PressToSpeak records audio while you hold the hotkey to transcribe and paste your speech.</string>
</dict>
</plist>
PLIST

if [[ -n "${CODESIGN_IDENTITY}" ]] && command -v codesign >/dev/null 2>&1; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"${CODESIGN_IDENTITY}\""; then
    CODESIGN_ARGS=(--force --deep --sign "${CODESIGN_IDENTITY}")
    if [[ "${CODESIGN_IDENTITY}" == Developer\ ID\ Application:* ]]; then
      CODESIGN_ARGS+=(--options runtime --timestamp)
    fi

    codesign "${CODESIGN_ARGS[@]}" "${APP_DIR}"
    echo "Signed ${APP_DIR} with identity: ${CODESIGN_IDENTITY}"
  else
    echo "Requested CODESIGN_IDENTITY was not found in keychain, skipping codesign: ${CODESIGN_IDENTITY}"
  fi
else
  echo "Skipping codesign. Set CODESIGN_IDENTITY to sign with a stable identity."
fi

echo "Packaged ${APP_DIR}"
