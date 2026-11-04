#!/usr/bin/env bash
# Deploys dist/probe.zip, captures the screensaver console (8087) while
# sampling texture/CPU/memory from the developer console (8080), then exits
# the screensaver and restores the regular channel.
# Usage: ROKU_HOST=<ip> ROKU_PASSWORD=<pw> tools/perf/run_probe.sh <out-dir>
set -euo pipefail
: "${ROKU_HOST:?set ROKU_HOST}" "${ROKU_PASSWORD:?set ROKU_PASSWORD (repo .env)}"
out="${1:-docs/perf/raw}"
stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out"
console="$out/probe-$stamp-console.log"
samples="$out/probe-$stamp-samples.log"
run_seconds="${PROBE_SECONDS:-140}"

dev() { # dev <command> [wait-seconds]: one port-8080 command, prompt line stripped
    { printf '%s\n' "$1"; sleep "${2:-2}"; } | curl -s -m $(( ${2:-2} + 3 )) "telnet://$ROKU_HOST:8080" 2>/dev/null | sed '1d' || true
}

echo "exit any running screensaver (deploying under a live instance wedges it)"
dev "press k" 1 > /dev/null
sleep 2

echo "deploy dist/probe.zip"
resp="$(curl -sS --digest --user "rokudev:$ROKU_PASSWORD" -F "mysubmit=1" -F "archive=@dist/probe.zip" "http://$ROKU_HOST/plugin_install")"
grep -q "Install Success\|Identical to previous version" <<<"$resp" || { echo "install failed"; grep -o '<font color="red">[^<]*' <<<"$resp" || true; exit 1; }

wait_s="${SCREENSAVER_WAIT:-600}"
echo "wait for screensaver console on 8087 (max ${wait_s}s): start it on the TV with"
echo "Settings > Theme > Screensavers > dev > Preview, or let the idle wait time expire"
deadline=$(( $(date +%s) + wait_s ))
# 8087 can stay open after a screensaver exits, so wait for ECP active-app to list it.
until curl -s -m 3 "http://$ROKU_HOST:8060/query/active-app" | grep -q '<screensaver id="dev"'; do
    [ "$(date +%s)" -lt "$deadline" ] || { echo "screensaver never started"; exit 1; }
    sleep 1
done
{ sleep "$run_seconds"; } | curl -s -m $(( run_seconds + 5 )) "telnet://$ROKU_HOST:8087" > "$console" 2>&1 &
cap=$!

end=$(( $(date +%s) + run_seconds ))
while [ "$(date +%s)" -lt "$end" ]; do
    {
        echo "== $(date +%H:%M:%S)"
        dev r2d2_bitmaps 2 | grep -E "Available texture memory|pkg:/images/" || true
        dev chanperf 2 | grep -E "channel:" || true
    } >> "$samples"
    sleep 2
done
wait "$cap" || true

echo "exit the probe screensaver"
dev "press k" 1 > /dev/null
grep -E "PROBE" "$console" | tail -5 || true
echo "console: $console"
echo "samples: $samples"
