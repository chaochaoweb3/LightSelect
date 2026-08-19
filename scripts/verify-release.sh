#!/usr/bin/env bash
set -euo pipefail
export LANG=C
export LC_ALL=C

app_path="${1:-}"

fail() {
  echo "RELEASE_VERIFY_FAILED: $*" >&2
  exit 1
}

[[ -n "$app_path" ]] || fail "usage: scripts/verify-release.sh <app-path>"
[[ -d "$app_path" ]] || fail "app bundle not found: $app_path"

contents="$app_path/Contents"
resources="$contents/Resources"
info="$contents/Info.plist"
executable="$contents/MacOS/LightSelect"

require_file() {
  [[ -f "$1" ]] || fail "missing file: ${1#"$app_path"/}"
}

require_value() {
  local key="$1"
  local expected="$2"
  local actual
  actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$info" 2>/dev/null)" || fail "missing plist key: $key"
  [[ "$actual" == "$expected" ]] || fail "$key is '$actual', expected '$expected'"
}

require_file "$info"
require_file "$executable"
require_value CFBundleShortVersionString 2.0.0
require_value CFBundleVersion 200
require_value CFBundleIdentifier local.ccw3.LightSelect
require_value CFBundleIconFile LightSelect.icns
require_file "$resources/LightSelect.icns"

for entry in toolbar action settings; do
  require_file "$resources/Web/$entry.html"
done

require_file "$resources/LICENSE"
require_file "$resources/NOTICE"
require_file "$resources/Fixtures/action-response.md"
require_file "$resources/ThirdParty/CherryStudio/LICENSE"
require_file "$resources/ThirdParty/CherryStudio/UPSTREAM.md"
require_file "$resources/ThirdParty/CherryStudio/manifest.txt"
require_file "$resources/ThirdParty/SelectionHook/LICENSE"
require_file "$resources/ThirdParty/SelectionHook/UPSTREAM.md"
require_file "$resources/ThirdParty/SelectionHook/manifest.txt"

codesign --verify --deep --strict "$app_path" 2>/dev/null || fail "code signature verification failed"
identifier="$(codesign -d --verbose=4 "$app_path" 2>&1 | awk -F= '/^Identifier=/{print $2}')"
[[ "$identifier" == "local.ccw3.LightSelect" ]] || fail "signed identifier is '$identifier'"

size_kib="$(du -sk "$app_path" | awk '{print $1}')"
(( size_kib < 25 * 1024 )) || fail "bundle is ${size_kib} KiB, limit is 25600 KiB"

forbidden_files="$(find "$app_path" -type f -print | rg -i '/(electron|chromium|node([^/]*\.)|sqlite|ocr|cherry[-_ ]?(chat|knowledge|paintings|providers?))' || true)"
[[ -z "$forbidden_files" ]] || fail "forbidden bundled files found: $forbidden_files"

forbidden_links="$(otool -L "$executable" | tail -n +2 | rg -i '(electron|chromium|libnode|sqlite|ocr)' || true)"
[[ -z "$forbidden_links" ]] || fail "forbidden linked libraries found: $forbidden_links"

echo "RELEASE_VERIFY_OK version=2.0.0 build=200 size_kib=$size_kib identifier=$identifier"
