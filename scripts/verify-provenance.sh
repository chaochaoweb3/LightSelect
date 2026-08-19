#!/usr/bin/env bash
set -euo pipefail
export LANG=C
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cherry_root="$repo_root/Vendor/CherryStudioSelection"
selection_hook_root="$repo_root/Vendor/SelectionHookNative"
manifest="$cherry_root/manifest.txt"
selection_hook_manifest="$selection_hook_root/manifest.txt"

test -f "$cherry_root/LICENSE"
test -f "$selection_hook_root/LICENSE"
test -f "$manifest"
test -f "$selection_hook_manifest"

rg -q '83d9d6325f7a00ab03a59eea31d0c943b3acf530' "$cherry_root/UPSTREAM.md"
rg -q 'ff85000e98ab65ab111e2274c385eb3b86c7e19f' "$selection_hook_root/UPSTREAM.md"
test "$(cut -f2 "$manifest")" = "$(cut -f2 "$manifest" | LC_ALL=C sort)"
test "$(cut -f2 "$selection_hook_manifest")" = "$(cut -f2 "$selection_hook_manifest" | LC_ALL=C sort)"

while IFS=$'\t' read -r digest relative_path; do
  test -n "$digest"
  test -n "$relative_path"
  source_file="$cherry_root/upstream/$relative_path"
  test -f "$source_file"
  actual="$(shasum -a 256 "$source_file" | awk '{print $1}')"
  test "$actual" = "$digest"
done < "$manifest"

while IFS=$'\t' read -r digest relative_path; do
  test -n "$digest"
  test -n "$relative_path"
  source_file="$selection_hook_root/upstream/$relative_path"
  test -f "$source_file"
  actual="$(shasum -a 256 "$source_file" | awk '{print $1}')"
  test "$actual" = "$digest"
done < "$selection_hook_manifest"

echo "PROVENANCE_OK"
