#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"
archive="$project_dir/dist/Grokbot-Monitor-${version}-macOS.zip"
checksum="$archive.sha256"

"$script_dir/build-app.sh"
rm -f "$archive" "$checksum"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
    "$project_dir/dist/Grokbot Monitor.app" "$archive"
shasum -a 256 "$archive" > "$checksum"

codesign --verify --deep --strict "$project_dir/dist/Grokbot Monitor.app"
echo "$archive"
echo "$checksum"
