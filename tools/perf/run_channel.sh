#!/usr/bin/env bash
# Measures the real channel's frame rate on a device (docs/perf.md "Measuring the
# channel"). Builds dist/perf.zip with a temporary config/perf.json (fpsLog, forceMode),
# deploys it, waits for the screensaver to start (idle timeout or a manual Preview),
# captures the 8087 console's PERF lines and one r2d2_bitmaps sample, then exits the
# screensaver. Deploy the normal dist/channel.zip afterwards (make deploy).
# Usage: ROKU_HOST=<ip> ROKU_PASSWORD=<pw> tools/perf/run_channel.sh <day|night|auto> [out-dir]
# PERF_TOGGLE=<seconds> flips day/night that often (crossfade check); r2d2 is then
# sampled every 10 s instead of once. PERF_ABLATE="id1,id2,..." with PERF_ABLATE_SEC=<s>
# hides one layer id (or @night) per segment after a baseline segment; PERF_SECONDS must
# cover (count + 2) segments. Summarize with tools/perf/ablate_summary.py <console>.
set -euo pipefail
: "${ROKU_HOST:?set ROKU_HOST}" "${ROKU_PASSWORD:?set ROKU_PASSWORD (repo .env)}"
mode="${1:?mode: day, night or auto}"
out="${2:-docs/perf/raw}"
run_seconds="${PERF_SECONDS:-120}"
wait_s="${SCREENSAVER_WAIT:-900}"
stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out" dist
console="$out/channel-$stamp-$mode-console.log"
bitmaps="$out/channel-$stamp-$mode-r2d2.txt"

dev() { # dev <command> [wait-seconds]: one port-8080 command, prompt line stripped
    { printf '%s\n' "$1"; sleep "${2:-2}"; } | curl -s -m $(( ${2:-2} + 3 )) "telnet://$ROKU_HOST:8080" 2>/dev/null | sed '1d' || true
}

force=""
[ "$mode" = "auto" ] || force=", \"forceMode\": \"$mode\""
[ -z "${PERF_TOGGLE:-}" ] || force="$force, \"toggleSec\": $PERF_TOGGLE"
if [ -n "${PERF_ABLATE:-}" ]; then
    list="$(printf '"%s", ' ${PERF_ABLATE//,/ })"
    force="$force, \"ablate\": [${list%, }], \"ablateSec\": ${PERF_ABLATE_SEC:-15}"
fi
printf '{ "fpsLog": true%s }\n' "$force" > config/perf.json
cp manifest dist/manifest.perf-bak
trap 'rm -f config/perf.json; cp dist/manifest.perf-bak manifest' EXIT
# PERF_UI=hd builds with ui_resolutions=hd only (the scene then renders at 1280x720).
[ -z "${PERF_UI:-}" ] || sed -i.bak "s/^ui_resolutions=.*/ui_resolutions=$PERF_UI/" manifest
node_modules/.bin/bsc --project bsconfig.json --create-package --out-file dist/perf.zip > dist/bsc-perf.log 2>&1 || { cat dist/bsc-perf.log; exit 1; }
rm -f config/perf.json manifest.bak
cp dist/manifest.perf-bak manifest

echo "exit any running screensaver (deploying under a live instance wedges it)"
dev "press k" 1 > /dev/null
sleep 2
resp="$(curl -sS --digest --user "rokudev:$ROKU_PASSWORD" -F "mysubmit=1" -F "archive=@dist/perf.zip" "http://$ROKU_HOST/plugin_install")"
grep -q "Install Success\|Identical to previous version" <<<"$resp" || { echo "install failed"; exit 1; }

echo "wait for the screensaver (max ${wait_s}s)"
deadline=$(( $(date +%s) + wait_s ))
until curl -s -m 3 "http://$ROKU_HOST:8060/query/active-app" | grep -q '<screensaver id="dev"'; do
    [ "$(date +%s)" -lt "$deadline" ] || { echo "screensaver never started"; exit 1; }
    sleep 2
done
echo "screensaver up; capturing ${run_seconds}s"
{ sleep "$run_seconds"; } | curl -s -m $(( run_seconds + 5 )) "telnet://$ROKU_HOST:8087" > "$console" 2>&1 &
cap=$!
if [ -n "${PERF_TOGGLE:-}" ]; then
    end=$(( $(date +%s) + run_seconds - 5 ))
    while [ "$(date +%s)" -lt "$end" ]; do
        { echo "== $(date +%H:%M:%S)"; dev r2d2_bitmaps 3; } >> "$bitmaps"
        sleep 7
    done
else
    sleep $(( run_seconds / 2 ))
    dev r2d2_bitmaps 3 > "$bitmaps"
fi
wait "$cap" || true
dev "press k" 1 > /dev/null

fps="$(grep -o 'fps= *[0-9]*' "$console" | grep -o '[0-9]*$' | sed '1,10d' | sort -n || true)"
n="$(printf '%s\n' "$fps" | grep -c . || true)"
if [ "$n" -gt 0 ]; then
    echo "mode=$mode samples=$n min=$(printf '%s\n' "$fps" | head -1) median=$(printf '%s\n' "$fps" | sed -n "$(( (n + 1) / 2 ))p") max=$(printf '%s\n' "$fps" | tail -1) (first 10 s skipped)"
else
    echo "no PERF lines captured"
fi
echo "console: $console"
echo "bitmaps: $bitmaps"
