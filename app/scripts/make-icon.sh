#!/usr/bin/env bash
# Renders the iEnvs app icon and packages it as app/Resources/AppIcon.icns.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p Resources
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift scripts/IconArt.swift "$WORK/icon-1024.png"

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

declare -a sizes=(16 32 128 256 512)
for s in "${sizes[@]}"; do
    sips -z "$s" "$s" "$WORK/icon-1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z "$d" "$d" "$WORK/icon-1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "built: Resources/AppIcon.icns"
