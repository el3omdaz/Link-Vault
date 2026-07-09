#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICON_SOURCE="$ROOT_DIR/resources/icon.png"
SPLASH_SOURCE="$ROOT_DIR/resources/splash.png"
ASSETS_DIR="$ROOT_DIR/ios/App/App/Assets.xcassets"
ICON_DIR="$ASSETS_DIR/AppIcon.appiconset"
SPLASH_DIR="$ASSETS_DIR/Splash.imageset"

for required in "$ICON_SOURCE" "$SPLASH_SOURCE" "$ICON_DIR/Contents.json" "$SPLASH_DIR/Contents.json"; do
  if [[ ! -e "$required" ]]; then
    echo "Missing required asset or iOS asset catalog: $required" >&2
    exit 1
  fi
done

mkdir -p "$ICON_DIR" "$SPLASH_DIR"

# Use macOS' built-in image utility; this avoids the sharp/GitHub download
# previously required by @capacitor/assets during CI installation.
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICON_DIR/AppIcon-512@2x.png" >/dev/null
sips -z 2732 2732 "$SPLASH_SOURCE" --out "$SPLASH_DIR/splash-2732x2732.png" >/dev/null
cp "$SPLASH_DIR/splash-2732x2732.png" "$SPLASH_DIR/splash-2732x2732-1.png"
cp "$SPLASH_DIR/splash-2732x2732.png" "$SPLASH_DIR/splash-2732x2732-2.png"

echo "Generated iOS icon and splash assets without @capacitor/assets."
