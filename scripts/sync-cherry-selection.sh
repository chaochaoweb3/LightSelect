#!/usr/bin/env bash
set -euo pipefail
export LANG=C
export LC_ALL=C

readonly cherry_repository="CherryHQ/cherry-studio"
readonly cherry_commit_expected="83d9d6325f7a00ab03a59eea31d0c943b3acf530"
readonly selection_hook_repository="0xfullex/selection-hook"
readonly selection_hook_commit="ff85000e98ab65ab111e2274c385eb3b86c7e19f"

if [[ $# -ne 1 || ! "$1" =~ ^[0-9a-f]{40}$ ]]; then
  echo "usage: $0 <40-character Cherry Studio commit>" >&2
  exit 64
fi

readonly cherry_commit="$1"
if [[ "$cherry_commit" != "$cherry_commit_expected" ]]; then
  echo "refusing unreviewed Cherry Studio commit: $cherry_commit" >&2
  exit 65
fi

command -v gh >/dev/null
command -v shasum >/dev/null

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cherry_root="$repo_root/Vendor/CherryStudioSelection"
selection_hook_root="$repo_root/Vendor/SelectionHookNative"
staging="$(mktemp -d "${TMPDIR:-/tmp}/lightselect-vendor.XXXXXX")"
trap 'rm -rf "$staging"' EXIT

fetch_file() {
  local repository="$1"
  local commit="$2"
  local relative_path="$3"
  local destination_root="$4"
  local destination="$destination_root/$relative_path"

  mkdir -p "$(dirname "$destination")"
  gh api \
    "repos/$repository/contents/$relative_path?ref=$commit" \
    --jq '.content' | tr -d '\n' | base64 -D > "$destination"
}

cherry_staging="$staging/cherry"
cherry_manifest_staging="$staging/cherry-manifest.txt"
mkdir -p "$cherry_staging"
: > "$cherry_manifest_staging"

while IFS= read -r relative_path; do
  [[ -n "$relative_path" ]] || continue
  fetch_file "$cherry_repository" "$cherry_commit" "$relative_path" "$cherry_staging"
  digest="$(shasum -a 256 "$cherry_staging/$relative_path" | awk '{print $1}')"
  printf '%s\t%s\n' "$digest" "$relative_path" >> "$cherry_manifest_staging"
done <<'CHERRY_FILES'
LICENSE
packages/ui/src/styles/contract.css
packages/ui/src/styles/product.css
packages/ui/src/styles/shadcn.css
packages/ui/src/styles/theme-input.css
packages/ui/src/styles/theme.css
packages/ui/src/styles/tokens.css
packages/ui/src/styles/tokens/colors/primitive.css
packages/ui/src/styles/tokens/colors/providers.css
packages/ui/src/styles/tokens/colors/status-legacy.css
packages/ui/src/styles/tokens/index.css
packages/ui/src/styles/tokens/radius.css
packages/ui/src/styles/tokens/spacing.css
packages/ui/src/styles/tokens/typography.css
src/main/services/selection/SelectionService.ts
src/main/services/selection/selectionConfig.ts
src/renderer/assets/images/logo.png
src/renderer/assets/styles/tailwind.css
src/renderer/components/selection/DynamicSelectionActionIcon.tsx
src/renderer/components/selection/SelectionActionIcon.tsx
src/renderer/components/selection/SelectionToolbarView.tsx
src/renderer/components/selection/__tests__/SelectionActionIcon.test.tsx
src/renderer/components/selection/__tests__/SelectionToolbarView.test.tsx
src/renderer/pages/settings/SelectionAssistantSettings/SelectionAssistantSettings.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/ActionsList.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/ActionsListDivider.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/ActionsListItem.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionActionSearchModal.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionActionUserModal.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionActionsList.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionFilterListModal.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/SettingsActionsListHeader.tsx
src/renderer/pages/settings/SelectionAssistantSettings/hooks/useSettingsActionsList.ts
src/renderer/windows/selection/action/ActionWindow.tsx
src/renderer/windows/selection/action/SelectionActionApp.tsx
src/renderer/windows/selection/action/__tests__/ActionWindow.test.tsx
src/renderer/windows/selection/action/__tests__/SelectionActionApp.test.tsx
src/renderer/windows/selection/action/__tests__/errorMessage.test.ts
src/renderer/windows/selection/action/components/ActionGeneral.tsx
src/renderer/windows/selection/action/components/ActionResultContent.tsx
src/renderer/windows/selection/action/components/ActionTranslate.tsx
src/renderer/windows/selection/action/components/WindowFooter.tsx
src/renderer/windows/selection/action/components/__tests__/ActionGeneral.test.tsx
src/renderer/windows/selection/action/components/__tests__/ActionTranslate.test.tsx
src/renderer/windows/selection/action/components/__tests__/WindowFooter.test.tsx
src/renderer/windows/selection/action/entryPoint.tsx
src/renderer/windows/selection/action/errorMessage.ts
src/renderer/windows/selection/action/index.html
src/renderer/windows/selection/toolbar/SelectionToolbar.tsx
src/renderer/windows/selection/toolbar/SelectionToolbarApp.tsx
src/renderer/windows/selection/toolbar/__tests__/SelectionToolbar.test.tsx
src/renderer/windows/selection/toolbar/__tests__/SelectionToolbarApp.test.tsx
src/renderer/windows/selection/toolbar/entryPoint.tsx
src/renderer/windows/selection/toolbar/index.html
src/shared/data/preference/preferenceSchemas.ts
src/shared/data/preference/preferenceTypes.ts
CHERRY_FILES

selection_hook_staging="$staging/selection-hook"
selection_hook_manifest_staging="$staging/selection-hook-manifest.txt"
mkdir -p "$selection_hook_staging"
: > "$selection_hook_manifest_staging"

while IFS= read -r relative_path; do
  [[ -n "$relative_path" ]] || continue
  fetch_file "$selection_hook_repository" "$selection_hook_commit" "$relative_path" "$selection_hook_staging"
  digest="$(shasum -a 256 "$selection_hook_staging/$relative_path" | awk '{print $1}')"
  printf '%s\t%s\n' "$digest" "$relative_path" >> "$selection_hook_manifest_staging"
done <<'SELECTION_HOOK_FILES'
LICENSE
src/mac/lib/clipboard.h
src/mac/lib/clipboard.mm
src/mac/lib/keyboard.h
src/mac/lib/keyboard.mm
src/mac/lib/utils.h
src/mac/lib/utils.mm
src/mac/selection_hook.mm
SELECTION_HOOK_FILES

mkdir -p "$cherry_root" "$selection_hook_root"
rm -rf "$cherry_root/upstream" "$selection_hook_root/upstream"
mv "$cherry_staging" "$cherry_root/upstream"
mv "$selection_hook_staging" "$selection_hook_root/upstream"
LC_ALL=C sort -k2,2 "$cherry_manifest_staging" > "$cherry_root/manifest.txt"
LC_ALL=C sort -k2,2 "$selection_hook_manifest_staging" > "$selection_hook_root/manifest.txt"
cp "$cherry_root/upstream/LICENSE" "$cherry_root/LICENSE"
cp "$selection_hook_root/upstream/LICENSE" "$selection_hook_root/LICENSE"

{
  printf '# Cherry Studio Selection Sources\n\n'
  printf -- '- Repository: https://github.com/CherryHQ/cherry-studio\n'
  printf -- '- Commit: `%s`\n' "$cherry_commit"
  printf -- '- Retrieved: 2026-08-14\n'
  printf -- '- License: GNU Affero General Public License v3.0\n\n'
  printf 'Files in `upstream/` are exact copies whose hashes are recorded in `manifest.txt`. '\
'LightSelect adapters live outside this directory.\n'
} > "$cherry_root/UPSTREAM.md"

{
  printf '# selection-hook macOS Sources\n\n'
  printf -- '- Repository: https://github.com/0xfullex/selection-hook\n'
  printf -- '- npm release: `selection-hook@2.0.3`\n'
  printf -- '- Commit: `%s`\n' "$selection_hook_commit"
  printf -- '- Retrieved: 2026-08-14\n'
  printf -- '- License: MIT\n\n'
  printf 'Files in `upstream/` are exact copies whose hashes are recorded in `manifest.txt`. '\
'The native adapter removes N-API bindings while retaining the macOS selection implementation.\n'
} > "$selection_hook_root/UPSTREAM.md"

echo "SYNC_OK cherry=$cherry_commit selection-hook=$selection_hook_commit"
