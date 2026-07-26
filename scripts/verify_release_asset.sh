#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: bash scripts/verify_release_asset.sh <zip-path> <expected-version> [expected-sha256]" >&2
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 64
fi

ZIP_PATH=$1
EXPECTED_VERSION=$2
EXPECTED_SHA=${3:-}

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Release asset does not exist: $ZIP_PATH" >&2
  exit 66
fi

if [[ -n "$EXPECTED_SHA" ]]; then
  ACTUAL_SHA=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
  if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
    echo "SHA-256 mismatch: expected $EXPECTED_SHA, got $ACTUAL_SHA" >&2
    exit 1
  fi
fi

ENTRY_LIST=$(mktemp)
EXTRACT_DIR=$(mktemp -d)
cleanup() {
  rm -f "$ENTRY_LIST"
  rm -rf "$EXTRACT_DIR"
}
trap cleanup EXIT

unzip -Z1 "$ZIP_PATH" > "$ENTRY_LIST"

if [[ ! -s "$ENTRY_LIST" ]]; then
  echo "Release asset is empty." >&2
  exit 1
fi

if awk -F/ 'NF > 0 && $1 != "MLXServerManager.app" { exit 1 }' "$ENTRY_LIST"; then
  :
else
  echo "Release asset contains an unexpected root entry." >&2
  exit 1
fi

FORBIDDEN_PATTERN='(^|/)(__MACOSX|DerivedData|build|logs|models|\.venv)(/|$)|(^|/)\._|\.dSYM(/|$)|settings\.json$|models\.json$|session-recovery\.json$|\.safetensors$|\.gguf$|\.onnx$|\.mlx$|(^|/)\.env$|(^|/)HF_TOKEN$'
if grep -E "$FORBIDDEN_PATTERN" "$ENTRY_LIST" >/dev/null; then
  echo "Release asset contains a forbidden entry:" >&2
  grep -E "$FORBIDDEN_PATTERN" "$ENTRY_LIST" >&2
  exit 1
fi

unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"
APP_PATH="$EXTRACT_DIR/MLXServerManager.app"
PLIST_PATH="$APP_PATH/Contents/Info.plist"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/MLXServerManager"

if [[ ! -d "$APP_PATH" || ! -f "$PLIST_PATH" || ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Extracted app bundle is incomplete." >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST_PATH")
MINIMUM_SYSTEM=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST_PATH")
ARCHITECTURE=$(file "$EXECUTABLE_PATH")

if [[ "$VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "Version mismatch: expected $EXPECTED_VERSION, got $VERSION" >&2
  exit 1
fi

if [[ "$MINIMUM_SYSTEM" != "15.0" ]]; then
  echo "Minimum macOS mismatch: expected 15.0, got $MINIMUM_SYSTEM" >&2
  exit 1
fi

if [[ "$ARCHITECTURE" != *"arm64"* ]]; then
  echo "Release executable is not arm64: $ARCHITECTURE" >&2
  exit 1
fi

codesign --verify --deep --strict "$APP_PATH"

printf 'Verified release asset\n'
printf '  Zip: %s\n' "$ZIP_PATH"
printf '  Version: %s\n' "$VERSION"
printf '  Minimum macOS: %s\n' "$MINIMUM_SYSTEM"
printf '  Architecture: arm64\n'
if [[ -n "$EXPECTED_SHA" ]]; then
  printf '  SHA-256: %s\n' "$EXPECTED_SHA"
fi
