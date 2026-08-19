#!/usr/bin/env bash
set -euo pipefail
export LANG=C
export LC_ALL=C

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_path="${1:-$root_dir/build/LightSelect.app}"
binary="$app_path/Contents/MacOS/LightSelect"
output_dir="$root_dir/artifacts/ui"

if [[ ! -x "$binary" ]]; then
  "$root_dir/scripts/build-app.sh" >/dev/null
fi

mkdir -p "$output_dir"
for appearance in light dark; do
  for kind in toolbar action; do
    output="$output_dir/$appearance-$kind.png"
    "$binary" --ui-test "$kind" --appearance "$appearance" --output "$output"
    [[ -s "$output" ]]
  done
done

for language in zh-CN en-US; do
  language_slug="${language%%-*}"
  for appearance in light dark; do
    output="$output_dir/settings-$language_slug-$appearance.png"
    "$binary" --ui-test settings --appearance "$appearance" --language "$language" \
      --width 900 --height 700 --output "$output"
    [[ -s "$output" ]]
  done
  output="$output_dir/settings-$language_slug-narrow.png"
  "$binary" --ui-test settings --appearance light --language "$language" \
    --width 520 --height 760 --output "$output"
  [[ -s "$output" ]]
done

pinned="$output_dir/pinned-cherry-toolbar.png"
[[ -s "$pinned" ]] || {
  echo "CAPTURE_UI_FAILED: missing pinned renderer image: $pinned" >&2
  exit 1
}

{
  echo "LightSelect 2.0 UI comparison"
  echo "Pinned Cherry source: 83d9d6325f7a00ab03a59eea31d0c943b3acf530"
  echo "Renderer baseline: Chromium 1440x900, Translate hover, toolbar element"
  echo "Candidate renderer: system WKWebView, light toolbar fixture"
  swift "$root_dir/scripts/pixel-diff.swift" "$pinned" "$output_dir/light-toolbar.png"
} > "$output_dir/comparison.txt"

echo "CAPTURE_UI_OK $output_dir"
