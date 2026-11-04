#!/usr/bin/env bash
# P0.5 device run: sideloads dist/fidelity.zip, captures the FIDELITY console
# lines from the screensaver console (8087) and tries a device screenshot.
# Usage: ROKU_HOST=<ip> ROKU_PASSWORD=<pw> tools/fidelity/run_device.sh [out-dir]
# (`make fidelity-device` builds the zip and reads both values from .env.)
#
# Screenshot: POST plugin_inspect with mysubmit=Screenshot (digest auth), then
# GET the pkgs/dev.jpg|png URL from the response; fields and URL pattern mirror
# roku-deploy's takeScreenshot (node_modules/roku-deploy/dist/RokuDeploy.js).
# It only works while the sideloaded dev app is in the foreground, which may not
# hold for a screensaver; on failure, take a TV photo instead.
set -euo pipefail
: "${ROKU_HOST:?set ROKU_HOST}" "${ROKU_PASSWORD:?set ROKU_PASSWORD (repo .env)}"
out="${1:-docs/fidelity}"
zip="dist/fidelity.zip"
console="$out/device-console.txt"
[ -f "$zip" ] || { echo "missing $zip: run make fidelity-build"; exit 1; }
mkdir -p "$out"

dev() { # dev <command> [wait-seconds]: one port-8080 developer console command
    { printf '%s\n' "$1"; sleep "${2:-2}"; } | curl -s -m $(( ${2:-2} + 3 )) "telnet://$ROKU_HOST:8080" 2>/dev/null | sed '1d' || true
}

echo "exit any running screensaver (deploying under a live instance wedges it)"
dev "press k" 1 > /dev/null
sleep 2

echo "deploy $zip"
resp="$(curl -sS --digest --user "rokudev:$ROKU_PASSWORD" -F "mysubmit=1" -F "archive=@$zip" "http://$ROKU_HOST/plugin_install")"
grep -q "Install Success\|Identical to previous version" <<<"$resp" || { echo "install failed"; grep -o '<font color="red">[^<]*' <<<"$resp" || true; exit 1; }

echo "wait for screensaver console on 8087 (max 60s)"
deadline=$(( $(date +%s) + 60 ))
until curl -s -m 2 "telnet://$ROKU_HOST:8087" </dev/null >/dev/null 2>&1; do
    [ "$(date +%s)" -lt "$deadline" ] || { echo "8087 never opened: is the screensaver running?"; exit 1; }
    sleep 1
done
# The scene pauses at 4 s and re-prints its report every 3 s, so 10 s catches at least one.
{ sleep 10; } | curl -s -m 15 "telnet://$ROKU_HOST:8087" > "$out/device-console.raw.txt" 2>&1 || true
grep "FIDELITY" "$out/device-console.raw.txt" | tr -d '\r' > "$console" || true
if [ -s "$console" ]; then
    echo "console: $console ($(wc -l < "$console" | tr -d ' ') lines)"
else
    echo "no FIDELITY lines captured; raw console in $out/device-console.raw.txt"
fi

echo "request device screenshot"
shot_ok=0
page="$(curl -sS -m 20 --digest --user "rokudev:$ROKU_PASSWORD" -F "mysubmit=Screenshot" -F "archive=" "http://$ROKU_HOST/plugin_inspect" || true)"
url="$(grep -oE "[\"'](pkgs/dev\.(jpg|png)\?[^\"']+)[\"']" <<<"$page" | head -1 | tr -d "\"'" || true)"
if [ -n "$url" ]; then
    ext="${url%%\?*}"
    ext="${ext##*.}"
    shot="$out/device.$ext"
    if curl -sS -f -m 20 --digest --user "rokudev:$ROKU_PASSWORD" -o "$shot" "http://$ROKU_HOST/$url"; then
        shot_ok=1
        echo "screenshot: $shot"
        echo "measure: uv run tools/fidelity/measure.py $shot"
    fi
fi
if [ "$shot_ok" -ne 1 ]; then
    echo "SCREENSHOT FAILED: the device returned no pkgs/dev image (the screensaver is probably not"
    echo "the foreground dev app). Fallback: photograph the TV head-on while the scene is paused"
    echo "(after 4 s) and save it as $out/device-photo.jpg."
    grep -o '<font color="red">[^<]*' <<<"$page" || true
fi

echo "the fidelity screensaver keeps running: exit it with the remote (or: press k on 8080),"
echo "then restore the channel with make deploy"
