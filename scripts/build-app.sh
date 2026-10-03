#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
app_dir="$project_dir/dist/Grokbot Monitor.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
swift build -c release

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp ".build/release/Grokbot" "$contents_dir/MacOS/Grokbot"
cp "Resources/Info.plist" "$contents_dir/Info.plist"

signing_identity="${GROKBOT_CODESIGN_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
    signing_identity="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)"
fi
if [[ -n "$signing_identity" ]]; then
    codesign --force --deep --options runtime --timestamp=none --sign "$signing_identity" "$app_dir"
else
    codesign --force --deep --sign - "$app_dir"
fi
echo "$app_dir"
