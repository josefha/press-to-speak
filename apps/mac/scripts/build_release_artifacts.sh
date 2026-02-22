#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-PressToSpeak}"
APP_DIR="dist/${APP_NAME}.app"
RELEASE_DIR="dist/release"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOL_NAME="${DMG_VOLUME_NAME:-${APP_NAME}}"
DMG_BACKGROUND_IMAGE="${DMG_BACKGROUND_IMAGE:-}"
DEFAULT_DMG_BACKGROUND_IMAGE="${SCRIPT_DIR}/assets/dmg-background.svg"
DMG_WINDOW_BOUNDS="${DMG_WINDOW_BOUNDS:-{140, 120, 960, 620}}"
DMG_APP_POSITION="${DMG_APP_POSITION:-{260, 320}}"
DMG_APPLICATIONS_POSITION="${DMG_APPLICATIONS_POSITION:-{700, 320}}"
DMG_ICON_SIZE="${DMG_ICON_SIZE:-120}"

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

# Styled DMG artifact with /Applications shortcut and fixed icon layout.
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${APP_NAME}-dmg.XXXXXX")"
STAGING_DIR="${WORK_DIR}/staging"
RW_DMG_PATH="${WORK_DIR}/${APP_NAME}-${APP_VERSION}-temp.dmg"
BACKGROUND_PNG="${WORK_DIR}/background.png"
MOUNT_POINT="/Volumes/${VOL_NAME}"
ATTACHED_DEVICE=""
HAS_BACKGROUND_IMAGE="false"

cleanup() {
  set +e
  if [[ -n "${ATTACHED_DEVICE}" ]]; then
    hdiutil detach "${ATTACHED_DEVICE}" >/dev/null 2>&1 || true
  fi
  if [[ -d "${MOUNT_POINT}" ]]; then
    hdiutil detach "${MOUNT_POINT}" -force >/dev/null 2>&1 || true
  fi
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

prepare_background_image() {
  local source_image="${DMG_BACKGROUND_IMAGE:-${DEFAULT_DMG_BACKGROUND_IMAGE}}"
  local source_extension=""
  local quicklook_output=""

  if [[ -z "${source_image}" || ! -f "${source_image}" ]]; then
    return
  fi

  source_extension="${source_image##*.}"
  source_extension="$(echo "${source_extension}" | tr '[:upper:]' '[:lower:]')"

  case "${source_extension}" in
    png|jpg|jpeg)
      cp "${source_image}" "${BACKGROUND_PNG}"
      HAS_BACKGROUND_IMAGE="true"
      ;;
    svg)
      if ! command -v qlmanage >/dev/null 2>&1; then
        echo "Warning: qlmanage not found; skipping DMG background SVG conversion." >&2
        return
      fi
      qlmanage -t -s 1400 -o "${WORK_DIR}" "${source_image}" >/dev/null 2>&1 || {
        echo "Warning: failed to render DMG background from ${source_image}; continuing without background image." >&2
        return
      }
      quicklook_output="${WORK_DIR}/$(basename "${source_image}").png"
      if [[ -f "${quicklook_output}" ]]; then
        cp "${quicklook_output}" "${BACKGROUND_PNG}"
        HAS_BACKGROUND_IMAGE="true"
      fi
      ;;
    *)
      echo "Warning: unsupported DMG background format (${source_extension}); expected png/jpg/svg." >&2
      ;;
  esac
}

apply_dmg_layout() {
  local background_alias=""

  if [[ "${HAS_BACKGROUND_IMAGE}" == "true" ]]; then
    mkdir -p "${MOUNT_POINT}/.background"
    cp "${BACKGROUND_PNG}" "${MOUNT_POINT}/.background/background.png"
    background_alias=".background:background.png"
  fi

  if [[ -n "${background_alias}" ]]; then
    osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "${VOL_NAME}"
    open
    set containerWindow to container window
    set current view of containerWindow to icon view
    set toolbar visible of containerWindow to false
    set statusbar visible of containerWindow to false
    set bounds of containerWindow to ${DMG_WINDOW_BOUNDS}
    set iconOptions to icon view options of containerWindow
    set arrangement of iconOptions to not arranged
    set icon size of iconOptions to ${DMG_ICON_SIZE}
    set text size of iconOptions to 13
    set background picture of iconOptions to file "${background_alias}"
    set position of item "${APP_NAME}.app" of containerWindow to ${DMG_APP_POSITION}
    set position of item "Applications" of containerWindow to ${DMG_APPLICATIONS_POSITION}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT
  else
    osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "${VOL_NAME}"
    open
    set containerWindow to container window
    set current view of containerWindow to icon view
    set toolbar visible of containerWindow to false
    set statusbar visible of containerWindow to false
    set bounds of containerWindow to ${DMG_WINDOW_BOUNDS}
    set iconOptions to icon view options of containerWindow
    set arrangement of iconOptions to not arranged
    set icon size of iconOptions to ${DMG_ICON_SIZE}
    set text size of iconOptions to 13
    set position of item "${APP_NAME}.app" of containerWindow to ${DMG_APP_POSITION}
    set position of item "Applications" of containerWindow to ${DMG_APPLICATIONS_POSITION}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT
  fi
}

prepare_background_image
mkdir -p "${STAGING_DIR}"

cp -R "${APP_DIR}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

STAGING_SIZE_KB="$(du -sk "${STAGING_DIR}" | awk '{print $1}')"
DMG_SIZE_MB="$(( (STAGING_SIZE_KB / 1024) + 160 ))"

if [[ -d "${MOUNT_POINT}" ]]; then
  hdiutil detach "${MOUNT_POINT}" -force >/dev/null 2>&1 || true
fi

hdiutil create \
  -srcfolder "${STAGING_DIR}" \
  -volname "${VOL_NAME}" \
  -fs HFS+ \
  -format UDRW \
  -size "${DMG_SIZE_MB}m" \
  -ov \
  "${RW_DMG_PATH}" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen -mountpoint "${MOUNT_POINT}" "${RW_DMG_PATH}")"
ATTACHED_DEVICE="$(echo "${ATTACH_OUTPUT}" | awk '/\/Volumes\// { print $1; exit }')"

if [[ -z "${ATTACHED_DEVICE}" ]]; then
  echo "Failed to mount temporary DMG at ${MOUNT_POINT}" >&2
  exit 1
fi

apply_dmg_layout
sync
hdiutil detach "${ATTACHED_DEVICE}" >/dev/null
ATTACHED_DEVICE=""

hdiutil convert "${RW_DMG_PATH}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" >/dev/null

echo "Created release artifacts:"
echo "- ${ZIP_PATH}"
echo "- ${DMG_PATH}"
