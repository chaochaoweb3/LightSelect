#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/build/LightSelect.app"
TARGET_APP="$HOME/Applications/LightSelect.app"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null

mkdir -p "$HOME/Applications"
if [[ ! -d "$TARGET_APP" ]]; then
  cp -R "$SOURCE_APP" "$TARGET_APP"
else
  mkdir -p "$TARGET_APP/Contents/MacOS"
  cp "$SOURCE_APP/Contents/MacOS/LightSelect" "$TARGET_APP/Contents/MacOS/LightSelect"
  cp "$SOURCE_APP/Contents/Info.plist" "$TARGET_APP/Contents/Info.plist"
  cp "$SOURCE_APP/Contents/cherry-logo.png" "$TARGET_APP/Contents/cherry-logo.png"
  chmod +x "$TARGET_APP/Contents/MacOS/LightSelect"
fi

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="LightSelect Stable Code Signing"
  if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$SIGN_IDENTITY"; then
    codesign --force --deep --sign "$SIGN_IDENTITY" "$TARGET_APP" >/dev/null
  else
    codesign --force --deep --sign - "$TARGET_APP" >/dev/null
  fi
fi

echo "$TARGET_APP"
