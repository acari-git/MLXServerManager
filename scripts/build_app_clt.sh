#!/usr/bin/env bash
#
# Build MLXServerManager.app WITHOUT Xcode — only the Command Line Tools
# (xcode-select --install) are needed. Compiles every .swift file with swiftc
# and assembles the .app bundle by hand.
#
# Usage:
#   scripts/build_app_clt.sh [options]
#
# Options:
#   --version <x.y.z>     CFBundleShortVersionString (default: latest git tag, else 1.0.0)
#   --bundle-id <id>      CFBundleIdentifier (default: com.mlxservermanager.app).
#                         Use the SAME id as your existing install to keep its settings:
#                         /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
#                           /Applications/MLXServerManager.app/Contents/Info.plist
#   --min-macos <x.y>     Deployment target (default: 15.0)
#   --entitlements <file> Sign with an entitlements file (default: none)
#   --swift-version <4|5|6>  Swift language mode (default: 5, like the Xcode project)
#   --debug               -Onone -g instead of -O -wmo (faster compile)
#   --icon                Regenerate icon images from scripts/icon/MLX-source.png first
#   --clean               Remove build/ before building
#   --no-zip              Skip the distributable zip + checksum
#   --open                Launch the app afterwards
#   -h, --help            Show this help
#
# Output (in build/out/): MLXServerManager.app, and unless --no-zip,
#   MLXServerManager-v<version>-unsigned.zip(.sha256)
#
# Differences from an Xcode build: the asset catalog is not compiled (the icon
# ships as AppIcon.icns instead, and the empty AccentColor falls back to the
# system accent, exactly as before), and the Info.plist below is generated
# rather than taken from the Xcode project.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="MLXServerManager"
SRC_DIR="$ROOT/$APP_NAME"
ICONSET_SRC="$SRC_DIR/Assets.xcassets/AppIcon.appiconset"
BUILD_DIR="$ROOT/build"
OUT_DIR="$BUILD_DIR/out"

VERSION=""
BUNDLE_ID="com.mlxservermanager.app"
MIN_MACOS="15.0"
SWIFT_MODE="5"
ENTITLEMENTS=""
DEBUG=0
DO_ICON=0
DO_CLEAN=0
DO_ZIP=1
DO_OPEN=0

die()  { echo "error: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }
warn() { echo "warning: $*" >&2; }
usage() { sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'; }

while (( $# )); do
  case "$1" in
    --version)      [[ $# -ge 2 ]] || die "--version needs a value";      VERSION="$2"; shift ;;
    --bundle-id)    [[ $# -ge 2 ]] || die "--bundle-id needs a value";    BUNDLE_ID="$2"; shift ;;
    --min-macos)    [[ $# -ge 2 ]] || die "--min-macos needs a value";    MIN_MACOS="$2"; shift ;;
    --swift-version) [[ $# -ge 2 ]] || die "--swift-version needs a value"; SWIFT_MODE="$2"; shift ;;
    --entitlements) [[ $# -ge 2 ]] || die "--entitlements needs a file";  ENTITLEMENTS="$2"; shift ;;
    --debug)        DEBUG=1 ;;
    --icon)         DO_ICON=1 ;;
    --clean)        DO_CLEAN=1 ;;
    --no-zip)       DO_ZIP=0 ;;
    --open)         DO_OPEN=1 ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

write_info_plist() {
  cat > "$1" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>MLX Server Manager</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>${MIN_MACOS}</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST
}

# Allow sourcing for tests without running the build.
[[ "${MLX_BUILD_SOURCE_ONLY:-0}" == "1" ]] && return 0 2>/dev/null || true

# ---- Preflight -------------------------------------------------------------
[[ "$(uname -s)" == "Darwin" ]] || die "must be run on macOS"
for tool in swiftc iconutil codesign ditto; do
  command -v "$tool" >/dev/null 2>&1 || [[ "$tool" == "swiftc" ]] || die "$tool not found"
done
xcrun --find swiftc >/dev/null 2>&1 || die "swiftc not found — run: xcode-select --install"
SDK="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)" || die "macOS SDK not found — run: xcode-select --install"
[[ -d "$SRC_DIR" ]] || die "$SRC_DIR not found (run from the repository root)"
[[ -z "$ENTITLEMENTS" || -f "$ENTITLEMENTS" ]] || die "entitlements file not found: $ENTITLEMENTS"

if [[ -z "$VERSION" ]]; then
  VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
  VERSION="${VERSION:-1.0.0}"
fi

echo "swift   : $(xcrun swiftc --version 2>&1 | head -1)"
echo "sdk     : $SDK"
echo "target  : arm64-apple-macos$MIN_MACOS   swift mode: $SWIFT_MODE"
echo "version : $VERSION   bundle id: $BUNDLE_ID"

# ---- Icon ------------------------------------------------------------------
if (( DO_ICON )) || ! ls "$ICONSET_SRC"/icon_*.png >/dev/null 2>&1; then
  step "Generating app icon images"
  "$ROOT/scripts/generate_app_icon.sh"
fi

# ---- Clean / layout --------------------------------------------------------
(( DO_CLEAN )) && { step "Cleaning $BUILD_DIR"; rm -rf "$BUILD_DIR"; }
APP="$OUT_DIR/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# ---- Compile ---------------------------------------------------------------
step "Compiling Swift sources"
SOURCES=()
while IFS= read -r -d '' f; do SOURCES+=("$f"); done < <(find "$SRC_DIR" -name '*.swift' -print0 | sort -z)
echo "${#SOURCES[@]} files"

if (( DEBUG )); then OPT=(-Onone -g); else OPT=(-O -wmo); fi

# Match the Xcode project's concurrency settings (Xcode 26 "Approachable
# Concurrency"): types are @MainActor unless marked `nonisolated`, which is why
# the source marks hundreds of types `nonisolated` explicitly.
CONCURRENCY=(
  -swift-version "$SWIFT_MODE"
  -Xfrontend -default-isolation -Xfrontend MainActor
  -enable-upcoming-feature DisableOutwardActorInference
  -enable-upcoming-feature GlobalActorIsolatedTypesUsability
  -enable-upcoming-feature InferIsolatedConformances
  -enable-upcoming-feature InferSendableFromCaptures
  -enable-upcoming-feature NonisolatedNonsendingByDefault
)

xcrun swiftc \
  "${OPT[@]}" \
  "${CONCURRENCY[@]}" \
  -parse-as-library \
  -module-name "$APP_NAME" \
  -sdk "$SDK" \
  -target "arm64-apple-macos$MIN_MACOS" \
  -o "$APP/Contents/MacOS/$APP_NAME" \
  "${SOURCES[@]}"

# ---- Bundle ----------------------------------------------------------------
step "Assembling bundle"
write_info_plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

ICONSET_TMP="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET_TMP"; mkdir -p "$ICONSET_TMP"
cp "$ICONSET_SRC"/icon_*.png "$ICONSET_TMP/"
iconutil -c icns -o "$APP/Contents/Resources/AppIcon.icns" "$ICONSET_TMP"
echo "icon    : AppIcon.icns"

# ---- Sign (ad-hoc; required for arm64 binaries to run) ---------------------
step "Signing (ad-hoc)"
SIGN_ARGS=(--force --deep --sign -)
[[ -n "$ENTITLEMENTS" ]] && SIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict "$APP" && echo "signing : ok"

# ---- Verify ----------------------------------------------------------------
[[ "$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")" == *arm64* ]] || die "binary is not arm64"
/usr/bin/plutil -lint "$APP/Contents/Info.plist" >/dev/null || die "Info.plist is invalid"

# ---- Package ---------------------------------------------------------------
if (( DO_ZIP )); then
  step "Packaging"
  ZIP_NAME="$APP_NAME-v${VERSION}-unsigned.zip"
  ZIP="$OUT_DIR/$ZIP_NAME"
  rm -f "$ZIP" "$ZIP.sha256"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  ( cd "$OUT_DIR" && shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256" )
  echo "zip     : $ZIP"
  echo "sha256  : $(cut -d' ' -f1 "$ZIP.sha256")"
fi

step "Done: $APP"
if (( DO_OPEN )); then open -n "$APP"; fi
exit 0
