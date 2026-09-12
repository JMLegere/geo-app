#!/bin/sh
set -eu

web_root=${1:?web output directory is required}
build_id=${2:?40-character commit SHA is required}
printf '%s' "$build_id" | grep -Eq '^[0-9a-f]{40}$'

test -d "$web_root/assets"
test -f "$web_root/flutter_bootstrap.js"
test -f "$web_root/index.html"

mkdir -p "$web_root/releases/$build_id"
mv "$web_root/assets" "$web_root/releases/$build_id/assets"
sed -i "s|main\.dart\.js|main.dart.js?v=$build_id|g" "$web_root/flutter_bootstrap.js"
sed -i "s|<meta name=\"flutter-asset-base\" content=\"\">|<meta name=\"flutter-asset-base\" content=\"releases/$build_id/\">|" "$web_root/index.html"
grep -F "<meta name=\"flutter-asset-base\" content=\"releases/$build_id/\">" "$web_root/index.html" >/dev/null
