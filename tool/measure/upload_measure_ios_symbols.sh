#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path_to_xcarchive> [path_to_ipa]"
  exit 1
fi

ARCHIVE_PATH="$1"
IPA_PATH="${2:-}"
resolve_measure_ios_api_key() {
  local channel="${MEASURE_RELEASE_CHANNEL:-stable}"
  if [[ "$channel" == "beta" ]]; then
    channel="stable"
  fi
  local upper
  upper="$(printf '%s' "$channel" | tr '[:lower:]' '[:upper:]')"
  local env_name="MEASURE_IOS_API_KEY_${upper}"
  local key="${!env_name:-}"
  if [[ -n "$key" ]]; then
    printf '%s' "$key"
    return 0
  fi
  if [[ -n "${MEASURE_IOS_API_KEY:-}" ]]; then
    printf '%s' "$MEASURE_IOS_API_KEY"
    return 0
  fi
  printf '%s' ""
}

API_KEY="$(resolve_measure_ios_api_key)"
API_URL="${MEASURE_API_URL:-}"

if [[ -z "$API_KEY" || -z "$API_URL" ]]; then
  echo "Measure iOS API key or MEASURE_API_URL not set; skipping Measure dSYM upload"
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UPLOAD_SCRIPT="$ROOT/tool/measure/upload_dsym_xcarchive.sh"

if [[ ! -x "$UPLOAD_SCRIPT" ]]; then
  echo "::error::Missing $UPLOAD_SCRIPT"
  exit 1
fi

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "::error::xcarchive not found at $ARCHIVE_PATH"
  exit 1
fi

if [[ -n "$IPA_PATH" ]]; then
  "$UPLOAD_SCRIPT" "$ARCHIVE_PATH" "$API_URL" "$API_KEY" "" "$IPA_PATH"
else
  "$UPLOAD_SCRIPT" "$ARCHIVE_PATH" "$API_URL" "$API_KEY"
fi
