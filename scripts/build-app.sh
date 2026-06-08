#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/LightSelect.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$ROOT_DIR/.build/release/LightSelect" "$MACOS_DIR/LightSelect"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/cherry-logo.png" "$CONTENTS_DIR/cherry-logo.png"
chmod +x "$MACOS_DIR/LightSelect"

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="LightSelect Stable Code Signing"
  if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$SIGN_IDENTITY"; then
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
  else
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
  fi
fi

echo "$APP_DIR"
