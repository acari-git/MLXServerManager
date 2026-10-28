#!/usr/bin/env bash
#
# Generate the macOS AppIcon asset catalog images from one square source PNG.
#
# Usage:
#   scripts/generate_app_icon.sh [source.png] [appiconset-dir]
#
# Defaults:
#   source        scripts/icon/MLX-source.png   (square, >= 1024px, with transparent padding)
#   appiconset    MLXServerManager/Assets.xcassets/AppIcon.appiconset
#
# Requires macOS (uses the built-in `sips`). Output is deterministic, so the
# generated PNGs and Contents.json can be committed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${1:-$ROOT/scripts/icon/MLX-source.png}"
ICONSET="${2:-$ROOT/MLXServerManager/Assets.xcassets/AppIcon.appiconset}"

die() { echo "error: $*" >&2; exit 1; }

command -v sips >/dev/null 2>&1 || die "sips not found (this script needs macOS)"
[[ -f "$SOURCE" ]] || die "source image not found: $SOURCE"
[[ -d "$ICONSET" ]] || die "appiconset directory not found: $ICONSET"

width="$(sips -g pixelWidth  "$SOURCE" | awk '/pixelWidth/  {print $2}')"
height="$(sips -g pixelHeight "$SOURCE" | awk '/pixelHeight/ {print $2}')"
[[ "$width" == "$height" ]] || die "source must be square (got ${width}x${height})"
(( width >= 1024 )) || die "source must be at least 1024x1024 (got ${width}x${height})"

# "<point size> <scale>" — the ten slots a macOS AppIcon set needs.
SLOTS=(
  "16 1" "16 2"
  "32 1" "32 2"
  "128 1" "128 2"
  "256 1" "256 2"
  "512 1" "512 2"
)

rm -f "$ICONSET"/icon_*.png

images_json=""
for slot in "${SLOTS[@]}"; do
  size="${slot% *}"
  scale="${slot#* }"
  px=$(( size * scale ))
  suffix=""
  [[ "$scale" == "2" ]] && suffix="@2x"
  name="icon_${size}x${size}${suffix}.png"

  sips -s format png -z "$px" "$px" "$SOURCE" --out "$ICONSET/$name" >/dev/null
  echo "  $name (${px}px)"

  entry="$(printf '    {\n      "filename" : "%s",\n      "idiom" : "mac",\n      "scale" : "%sx",\n      "size" : "%sx%s"\n    }' \
    "$name" "$scale" "$size" "$size")"
  images_json="${images_json:+$images_json,
}$entry"
done

cat > "$ICONSET/Contents.json" <<JSON
{
  "images" : [
$images_json
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Wrote $(basename "$ICONSET") from $(basename "$SOURCE")"
