#!/bin/zsh
# Builds Zroch.app (release) next to this script. Usage: ./build.sh [--run]
set -e
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Zroch"

APP="Zroch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Zroch"
cp Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"
echo "Built $(pwd)/$APP"

if [[ "$1" == "--run" ]]; then
  pkill -x Zroch 2>/dev/null || true
  open "$APP"
fi
