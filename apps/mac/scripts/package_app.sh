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
ICON_NAME="AppIcon"
ICON_FILE="${RESOURCES_DIR}/${ICON_NAME}.icns"
ICON_APPICONSET_SOURCE="Sources/PressToSpeakApp/Resources/Branding/AppIcon.appiconset"
ICON_SVG_SOURCE="Sources/PressToSpeakApp/Resources/Branding/logo-dark.svg"
ICON_PNG_SOURCE="Sources/PressToSpeakApp/Resources/Branding/logo-dark.png"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
APP_ENV_FILE="${APP_ENV_FILE:-.env}"
APP_ENV_REQUIRED="${APP_ENV_REQUIRED:-false}"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-1}"

generate_app_icon() {
  local iconset_dir
  local working_dir
  local source_png
  local source_filename

  # Prefer explicit appiconset assets if present.
  if [[ -d "${ICON_APPICONSET_SOURCE}" ]] && command -v iconutil >/dev/null 2>&1; then
    working_dir="$(mktemp -d)"
    iconset_dir="${working_dir}/${ICON_NAME}.iconset"
    mkdir -p "${iconset_dir}"

    cp "${ICON_APPICONSET_SOURCE}/16.png" "${iconset_dir}/icon_16x16.png"
    cp "${ICON_APPICONSET_SOURCE}/32.png" "${iconset_dir}/icon_16x16@2x.png"
    cp "${ICON_APPICONSET_SOURCE}/32.png" "${iconset_dir}/icon_32x32.png"
    cp "${ICON_APPICONSET_SOURCE}/64.png" "${iconset_dir}/icon_32x32@2x.png"
    cp "${ICON_APPICONSET_SOURCE}/128.png" "${iconset_dir}/icon_128x128.png"
    cp "${ICON_APPICONSET_SOURCE}/256.png" "${iconset_dir}/icon_128x128@2x.png"
    cp "${ICON_APPICONSET_SOURCE}/256.png" "${iconset_dir}/icon_256x256.png"
    cp "${ICON_APPICONSET_SOURCE}/512.png" "${iconset_dir}/icon_256x256@2x.png"
    cp "${ICON_APPICONSET_SOURCE}/512.png" "${iconset_dir}/icon_512x512.png"
    cp "${ICON_APPICONSET_SOURCE}/1024.png" "${iconset_dir}/icon_512x512@2x.png"

    iconutil -c icns "${iconset_dir}" -o "${ICON_FILE}"
    echo "Generated app icon from ${ICON_APPICONSET_SOURCE}"
    rm -rf "${working_dir}"
    return
  fi

  working_dir="$(mktemp -d)"
  iconset_dir="${working_dir}/${ICON_NAME}.iconset"
  mkdir -p "${iconset_dir}"

  if [[ -f "${ICON_SVG_SOURCE}" ]] && command -v qlmanage >/dev/null 2>&1; then
    qlmanage -t -s 1024 -o "${working_dir}" "${ICON_SVG_SOURCE}" >/dev/null 2>&1 || true
    source_filename="$(basename "${ICON_SVG_SOURCE}").png"
    if [[ -f "${working_dir}/${source_filename}" ]]; then
      source_png="${working_dir}/${source_filename}"
    fi
  fi

  if [[ -z "${source_png:-}" && -f "${ICON_PNG_SOURCE}" ]]; then
    source_png="${ICON_PNG_SOURCE}"
  fi

  if [[ -z "${source_png:-}" ]]; then
    echo "Warning: no branding icon source found at ${ICON_SVG_SOURCE} or ${ICON_PNG_SOURCE}; skipping app icon generation."
    rm -rf "${working_dir}"
    return
  fi

  if ! command -v sips >/dev/null 2>&1 || ! command -v iconutil >/dev/null 2>&1; then
    echo "Warning: sips or iconutil not available; skipping app icon generation."
    rm -rf "${working_dir}"
    return
  fi

  sips -z 16 16 "${source_png}" --out "${iconset_dir}/icon_16x16.png" >/dev/null
  sips -z 32 32 "${source_png}" --out "${iconset_dir}/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "${source_png}" --out "${iconset_dir}/icon_32x32.png" >/dev/null
  sips -z 64 64 "${source_png}" --out "${iconset_dir}/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "${source_png}" --out "${iconset_dir}/icon_128x128.png" >/dev/null
  sips -z 256 256 "${source_png}" --out "${iconset_dir}/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "${source_png}" --out "${iconset_dir}/icon_256x256.png" >/dev/null
  sips -z 512 512 "${source_png}" --out "${iconset_dir}/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "${source_png}" --out "${iconset_dir}/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "${source_png}" --out "${iconset_dir}/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "${iconset_dir}" -o "${ICON_FILE}"
  rm -rf "${working_dir}"
}

swift build -c release --product "${PRODUCT}"

if [[ ! -f "${BUILD_BINARY}" ]]; then
  echo "Release binary not found: ${BUILD_BINARY}" >&2
  exit 1
fi

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_BINARY}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy SwiftPM resource bundles for runtime asset loading.
for resource_bundle in .build/release/*.bundle; do
  if [[ -d "${resource_bundle}" ]]; then
    cp -R "${resource_bundle}" "${RESOURCES_DIR}/"
  fi
done

generate_app_icon

# Package environment for installed app use.
if [[ -n "${APP_ENV_FILE}" && -f "${APP_ENV_FILE}" ]]; then
  cp "${APP_ENV_FILE}" "${RESOURCES_DIR}/app.env"
  echo "Bundled app environment from ${APP_ENV_FILE}"
elif [[ "${APP_ENV_REQUIRED}" == "true" ]]; then
  echo "Missing required APP_ENV_FILE: ${APP_ENV_FILE}" >&2
  exit 1
else
  echo "No app environment bundled (APP_ENV_FILE not found: ${APP_ENV_FILE})"
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
  <key>CFBundleIconFile</key>
  <string>${ICON_NAME}</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${APP_BUILD}</string>
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
