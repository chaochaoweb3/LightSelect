#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/build/LightSelect.app"
TARGET_DIR="$HOME/Applications"
TARGET_APP="$TARGET_DIR/LightSelect.app"
STAGING_APP="$TARGET_DIR/.LightSelect.app.staging"
BACKUP_APP="$TARGET_DIR/.LightSelect.app.previous"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null
"$ROOT_DIR/scripts/verify-release.sh" "$SOURCE_APP"

mkdir -p "$TARGET_DIR"
rm -rf "$STAGING_APP" "$BACKUP_APP"
ditto "$SOURCE_APP" "$STAGING_APP"
"$ROOT_DIR/scripts/verify-release.sh" "$STAGING_APP"

if [[ -d "$TARGET_APP" ]]; then
  mv "$TARGET_APP" "$BACKUP_APP"
fi
if mv "$STAGING_APP" "$TARGET_APP"; then
  rm -rf "$BACKUP_APP"
else
  if [[ -d "$BACKUP_APP" ]]; then
    mv "$BACKUP_APP" "$TARGET_APP"
  fi
  exit 1
fi

"$ROOT_DIR/scripts/verify-release.sh" "$TARGET_APP"
echo "$TARGET_APP"
