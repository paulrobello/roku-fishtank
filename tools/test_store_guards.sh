#!/usr/bin/env bash
# Regression fixtures for the store guard. Never edits the real source tree.
set -eu
cd "$(dirname "$0")/.."
root=$PWD
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/source" "$tmp/components" "$tmp/tools"
cp tools/api_guard.sh "$tmp/tools/"
cp manifest "$tmp/manifest"
printf 'sub RunScreenSaver()\nend sub\n' > "$tmp/source/main.brs"
bash "$tmp/tools/api_guard.sh" >/dev/null
printf 'function onKeyEvent(key, press)\nend function\n' > "$tmp/source/main.brs"
if bash "$tmp/tools/api_guard.sh" > "$tmp/result"; then
    echo 'store-guard test: shipped key handler incorrectly accepted'; exit 1
fi
grep -q 'OnKeyEvent defined' "$tmp/result"
printf 'sub RunScreenSaver()\nend sub\n' > "$tmp/source/main.brs"
sed '/^rsg_version=/d' manifest > "$tmp/manifest"
if bash "$tmp/tools/api_guard.sh" > "$tmp/result"; then
    echo 'store-guard test: missing rsg_version incorrectly accepted'; exit 1
fi
grep -q 'missing rsg_version' "$tmp/result"
cp manifest "$tmp/manifest"
(cd "$tmp" && zip -q oversize.zip manifest)
dd if=/dev/zero bs=1000000 count=4 >> "$tmp/oversize.zip" 2>/dev/null
if bash "$root/tools/zip_check.sh" "$tmp/oversize.zip" > "$tmp/result"; then
    echo 'store-guard test: oversized archive incorrectly accepted'; exit 1
fi
grep -q 'exceeds the 4,000,000-byte store limit' "$tmp/result"
printf "' bslib fixture\n" > "$tmp/source/bslib.brs"
(cd "$tmp" && zip -q missing-notice.zip manifest source/bslib.brs)
if bash "$root/tools/zip_check.sh" "$tmp/missing-notice.zip" > "$tmp/result"; then
    echo 'store-guard test: bslib without license incorrectly accepted'; exit 1
fi
grep -q 'bslib requires its MIT' "$tmp/result"
mkdir -p "$tmp/config"
cp "$root/config/THIRD_PARTY_NOTICES.txt" "$tmp/config/"
(cd "$tmp" && zip -q licensed.zip manifest source/bslib.brs config/THIRD_PARTY_NOTICES.txt)
bash "$root/tools/zip_check.sh" "$tmp/licensed.zip" >/dev/null
echo 'store guard regression tests ok'
