#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-PressToSpeak}"
PRODUCTION_ENV_FILE="${PRODUCTION_ENV_FILE:-.env.production}"
PRODUCTION_PROXY_URL="${PRODUCTION_PROXY_URL:-}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

TMP_ENV_FILE="$(mktemp "${TMPDIR:-/tmp}/${APP_NAME}-production-env.XXXXXX")"
cleanup() {
  rm -f "${TMP_ENV_FILE}"
}
trap cleanup EXIT

if [[ -f "${PRODUCTION_ENV_FILE}" ]]; then
  cp "${PRODUCTION_ENV_FILE}" "${TMP_ENV_FILE}"
else
  touch "${TMP_ENV_FILE}"
fi

upsert_env_value() {
  local key="$1"
  local value="$2"
  sed -i '' "/^[[:space:]]*${key}[[:space:]]*=/d" "${TMP_ENV_FILE}"
  printf "%s=%s\n" "${key}" "${value}" >> "${TMP_ENV_FILE}"
}

if [[ -n "${PRODUCTION_PROXY_URL}" ]]; then
  upsert_env_value "TRANSCRIPTION_PROXY_URL" "${PRODUCTION_PROXY_URL}"
fi

# Production export always disables mock auth.
upsert_env_value "PRESS_TO_SPEAK_MOCK_ACCOUNT_AUTH" "false"

if ! grep -Eq '^[[:space:]]*TRANSCRIPTION_PROXY_URL[[:space:]]*=[[:space:]]*[^[:space:]#]+' "${TMP_ENV_FILE}"; then
  echo "TRANSCRIPTION_PROXY_URL is required for production export." >&2
  echo "Set it in ${PRODUCTION_ENV_FILE} or pass PRODUCTION_PROXY_URL=..." >&2
  exit 1
fi

echo "Packaging production app with env from ${PRODUCTION_ENV_FILE}"
if [[ -n "${PRODUCTION_PROXY_URL}" ]]; then
  echo "Using PRODUCTION_PROXY_URL override: ${PRODUCTION_PROXY_URL}"
fi

APP_ENV_FILE="${TMP_ENV_FILE}" \
APP_ENV_REQUIRED="true" \
CODESIGN_IDENTITY="${CODESIGN_IDENTITY}" \
./scripts/package_app.sh

./scripts/build_release_artifacts.sh

echo "Production export complete:"
echo "- dist/release/${APP_NAME}-<version>-macOS.zip"
echo "- dist/release/${APP_NAME}-<version>-macOS.dmg"
