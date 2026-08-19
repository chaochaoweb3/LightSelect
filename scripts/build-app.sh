#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/LightSelect.app"
STAGING_DIR="$ROOT_DIR/build/.LightSelect.app.staging"

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/verify-provenance.sh"

(
  cd "$ROOT_DIR/Web"
  npm ci
  npm run typecheck
  npm test -- --run
  npm run build
  npm audit
)

swift_test_log="$(mktemp /tmp/lightselect-swift-test.XXXXXX)"
trap 'rm -f "$swift_test_log"' EXIT
if swift test >"$swift_test_log" 2>&1; then
  cat "$swift_test_log"
elif rg -q 'XCTest not available|unable to lookup.*PlatformPath' "$swift_test_log"; then
  cat "$swift_test_log" >&2
  echo "XCTest unavailable; using syntax parsing and executable self-test fallback." >&2
  swiftc -frontend -parse "$ROOT_DIR"/Tests/LightSelectCoreTests/*.swift
else
  cat "$swift_test_log" >&2
  exit 1
fi

swift build -c release
"$ROOT_DIR/.build/release/LightSelect" --self-test

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/Contents/MacOS" "$STAGING_DIR/Contents/Resources/Web"
mkdir -p "$STAGING_DIR/Contents/Resources/Fixtures"
mkdir -p "$STAGING_DIR/Contents/Resources/ThirdParty/CherryStudio"
mkdir -p "$STAGING_DIR/Contents/Resources/ThirdParty/SelectionHook"
cp "$ROOT_DIR/.build/release/LightSelect" "$STAGING_DIR/Contents/MacOS/LightSelect"
cp "$ROOT_DIR/Resources/Info.plist" "$STAGING_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/LightSelect.icns" "$STAGING_DIR/Contents/Resources/LightSelect.icns"
cp -R "$ROOT_DIR/Resources/Web/." "$STAGING_DIR/Contents/Resources/Web/"
cp "$ROOT_DIR/Resources/cherry-logo.png" "$STAGING_DIR/Contents/Resources/cherry-logo.png"
cp "$ROOT_DIR/LICENSE" "$STAGING_DIR/Contents/Resources/LICENSE"
cp "$ROOT_DIR/NOTICE" "$STAGING_DIR/Contents/Resources/NOTICE"
cp "$ROOT_DIR/Tests/Fixtures/action-response.md" "$STAGING_DIR/Contents/Resources/Fixtures/action-response.md"
cp "$ROOT_DIR/Vendor/CherryStudioSelection/LICENSE" "$STAGING_DIR/Contents/Resources/ThirdParty/CherryStudio/LICENSE"
cp "$ROOT_DIR/Vendor/CherryStudioSelection/UPSTREAM.md" "$STAGING_DIR/Contents/Resources/ThirdParty/CherryStudio/UPSTREAM.md"
cp "$ROOT_DIR/Vendor/CherryStudioSelection/manifest.txt" "$STAGING_DIR/Contents/Resources/ThirdParty/CherryStudio/manifest.txt"
cp "$ROOT_DIR/Vendor/SelectionHookNative/LICENSE" "$STAGING_DIR/Contents/Resources/ThirdParty/SelectionHook/LICENSE"
cp "$ROOT_DIR/Vendor/SelectionHookNative/UPSTREAM.md" "$STAGING_DIR/Contents/Resources/ThirdParty/SelectionHook/UPSTREAM.md"
cp "$ROOT_DIR/Vendor/SelectionHookNative/manifest.txt" "$STAGING_DIR/Contents/Resources/ThirdParty/SelectionHook/manifest.txt"

for entry in toolbar action settings; do
  source_html="$STAGING_DIR/Contents/Resources/Web/src/$entry/index.html"
  sed 's#../../assets/#assets/#g' "$source_html" > "$STAGING_DIR/Contents/Resources/Web/$entry.html"
done

chmod +x "$STAGING_DIR/Contents/MacOS/LightSelect"

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="LightSelect Stable Code Signing"
  if security find-identity -v -p codesigning 2>/dev/null | rg -Fq "$SIGN_IDENTITY"; then
    codesign --force --deep --sign "$SIGN_IDENTITY" "$STAGING_DIR" >/dev/null
  else
    codesign --force --deep --sign - "$STAGING_DIR" >/dev/null
  fi
fi

codesign --verify --deep --strict "$STAGING_DIR"
rm -rf "$APP_DIR"
mv "$STAGING_DIR" "$APP_DIR"
trap - EXIT
rm -f "$swift_test_log"

echo "$APP_DIR"
