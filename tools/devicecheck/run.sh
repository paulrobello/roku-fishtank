#!/usr/bin/env bash
# Sideloads a package, waits for its screensaver (ECP active-app), captures the
# 8087 console for N seconds, tries a device screenshot, then exits the screensaver.
# Usage: ROKU_HOST=<ip> ROKU_PASSWORD=<pw> tools/devicecheck/run.sh <zip> <out-prefix> [seconds]
set -euo pipefail
: "${ROKU_HOST:?set ROKU_HOST}" "${ROKU_PASSWORD:?set ROKU_PASSWORD (repo .env)}"
zip="$1"
prefix="$2"
seconds="${3:-90}"
mkdir -p "$(dirname "$prefix")"

dev() { # dev <command> [wait-seconds]: one port-8080 developer console command
    { printf '%s\n' "$1"; sleep "${2:-2}"; } | curl -s -m $(( ${2:-2} + 3 )) "telnet://$ROKU_HOST:8080" 2>/dev/null | sed '1d' || true
}
running() { curl -s -m 3 "http://$ROKU_HOST:8060/query/active-app" | grep -q '<screensaver id="dev"'; }

echo "exit any running screensaver (deploying under a live instance wedges it)"
dev "press k" 1 > /dev/null
sleep 2
echo "deploy $zip"
resp="$(curl -sS --digest --user "rokudev:$ROKU_PASSWORD" -F "mysubmit=1" -F "archive=@$zip" "http://$ROKU_HOST/plugin_install")"
grep -q "Install Success\|Identical to previous version" <<<"$resp" || { echo "install failed"; grep -o '<font color="red">[^<]*' <<<"$resp" || true; exit 1; }

wait_s="${SCREENSAVER_WAIT:-600}"
echo "wait up to ${wait_s}s for the screensaver: Settings > Theme > Screensavers > dev > Preview, or idle"
deadline=$(( $(date +%s) + wait_s ))
until running; do
    [ "$(date +%s)" -lt "$deadline" ] || { echo "screensaver never started"; exit 1; }
    sleep 1
done
echo "capture ${seconds}s of console"
{ sleep "$seconds"; } | curl -s -m $(( seconds + 5 )) "telnet://$ROKU_HOST:8087" 2>/dev/null | tr -d '\r' > "$prefix-console.log" || true

page="$(curl -sS -m 20 --digest --user "rokudev:$ROKU_PASSWORD" -F "mysubmit=Screenshot" -F "archive=" "http://$ROKU_HOST/plugin_inspect" || true)"
url="$(grep -oE "[\"'](pkgs/dev\.(jpg|png)\?[^\"']+)[\"']" <<<"$page" | head -1 | tr -d "\"'" || true)"
if [ -n "$url" ]; then
    ext="${url%%\?*}"
    ext="${ext##*.}"
    if curl -sS -f -m 20 --digest --user "rokudev:$ROKU_PASSWORD" -o "$prefix-device.$ext" "http://$ROKU_HOST/$url"; then
        echo "screenshot: $prefix-device.$ext"
    else
        echo "screenshot download failed"
    fi
else
    echo "no device screenshot (screensaver is not the foreground dev app)"
fi
if running; then echo "screensaver still running after capture"; else echo "screensaver exited during capture"; fi
dev "press k" 1 > /dev/null
grep -E "^FPS " "$prefix-console.log" | awk '{n++; s+=$2; if(min==""||$2<min)min=$2} END{if(n) printf "FPS samples %d mean %.1f min %d\n", n, s/n, min}' || true
echo "console: $prefix-console.log"
