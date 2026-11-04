#!/usr/bin/env bash
# zip-check: the device zip may only hold manifest and the source/,
# components/, images/ and config/ trees. Preview, test, tooling and art
# source files must never ship.
# Usage: tools/zip_check.sh [path/to/channel.zip]   (default dist/channel.zip)
set -eu

zip=${1:-dist/channel.zip}
[ -f "$zip" ] || { echo "zip-check: $zip not found"; exit 1; }

entries=$(unzip -Z1 "$zip")
bad=0
while IFS= read -r e; do
    [ -n "$e" ] || continue
    case "$e" in
        source/preview.brs) echo "zip-check: $e is preview-only"; bad=$((bad + 1)) ;;
        preview/* | tests/* | tools/* | assets/*) echo "zip-check: $e must not ship"; bad=$((bad + 1)) ;;
        manifest | source/* | components/* | images/* | config/*) ;;
        *) echo "zip-check: unexpected top-level entry $e"; bad=$((bad + 1)) ;;
    esac
done <<EOF
$entries
EOF

if [ "$bad" -gt 0 ]; then
    echo "zip-check FAILED: $bad bad entr(y/ies) in $zip"
    exit 1
fi
echo "zip-check ok ($zip)"
