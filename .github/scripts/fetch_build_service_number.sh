#!/usr/bin/env bash
set -euo pipefail

platform="${1:-android}"

if [[ -z "${BUILD_SERVICE_TOKEN:-}" || -z "${BUILD_SERVICE_URL:-}" ]]; then
  echo "::error::BUILD_SERVICE_TOKEN and BUILD_SERVICE_URL must be set"
  exit 1
fi

URL="https://${BUILD_SERVICE_URL}/v1/build-number?platform=${platform}"
echo "Calling build service at $URL"
RESPONSE=$(curl -sS -X POST "$URL" \
  -H "Authorization: Bearer $BUILD_SERVICE_TOKEN")
RESPONSE_ONE_LINE=$(printf '%s' "$RESPONSE" | tr -d '\n')
BUILD_NUMBER=$(printf '%s\n' "$RESPONSE_ONE_LINE" | sed -n 's/.*"buildNumber"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')
if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "::error::Invalid or missing buildNumber in response: $RESPONSE"
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "build_number=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"
else
  echo "$BUILD_NUMBER"
fi
