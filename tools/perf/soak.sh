#!/usr/bin/env bash
# P6.4 8-hour soak logger: samples texture memory + screensaver liveness on one
# device every SOAK_INTERVAL seconds until the SOAK_HOURS deadline, with a 1-hour
# grace beyond it (plan: 8-hour soak, 9-hour deadline). Writes a CSV plus raw
# r2d2 samples into docs/perf/raw/ and a one-line verdict at the end. The TV
# staying idle is the operator's job: any remote keypress exits the screensaver
# and the CSV records running=0 for those minutes (the verdict ignores them).
# Usage: ROKU_HOST=<ip> tools/perf/soak.sh [out-dir]
set -uo pipefail
: "${ROKU_HOST:?set ROKU_HOST}"
out="${1:-docs/perf/raw}"
interval="${SOAK_INTERVAL:-300}"
hours="${SOAK_HOURS:-8}"
grace_s=3600
mkdir -p "$out"
stamp="$(date +%Y%m%d-%H%M%S)"
csv="$out/soak-$stamp.csv"
raw="$out/soak-$stamp-r2d2.txt"
echo "epoch,time,running,tex_bytes,samples" > "$csv"

dev() { # dev <command> [wait-seconds]: one port-8080 command, prompt line stripped
    { printf '%s\n' "$1"; sleep "${2:-2}"; } | curl -s -m $(( ${2:-2} + 3 )) "telnet://$ROKU_HOST:8080" 2>/dev/null | sed '1d' || true
}
running() { curl -s -m 4 "http://$ROKU_HOST:8060/query/active-app" | grep -c 'screensaver id="dev"'; }

deadline=$(( $(date +%s) + hours * 3600 + grace_s ))
n=0
while [ "$(date +%s)" -lt "$deadline" ]; do
    r=$(running)
    bytes=""
    if [ "$r" = "1" ]; then
        sample="$(dev r2d2_bitmaps 3)"
        if [ -n "$sample" ]; then
            n=$((n + 1))
            { echo "== $(date +%H:%M:%S)"; echo "$sample"; } >> "$raw"
            # sum the `size` column (5th) over bitmap rows; header/prompt rows have no digits there
            bytes=$(echo "$sample" | awk '$1 ~ /^0x[0-9a-f]+$/ && $5 ~ /^[0-9]+$/ { s += $5 } END { print s + 0 }')
        fi
    fi
    echo "$(date +%s),$(date +%H:%M:%S),$r,${bytes:-0},$n" >> "$csv"
    sleep "$interval"
done

# verdict: flat-memory check over running samples (first vs last quartile, 15% band)
python3 - "$csv" << 'PY'
import sys
rows = [l.split(",") for l in open(sys.argv[1]).read().splitlines()[1:]]
run = [(int(r[3]), r[1]) for r in rows if r[2] == "1" and int(r[4] if len(r) > 4 else 0) >= 0 and int(r[3]) > 0]
if len(run) < 4:
    print(f"SOAK VERDICT: inconclusive — only {len(run)} usable samples (screensaver ran too little)")
    sys.exit(0)
q = len(run) // 4
first = sum(v for v, _ in run[:q]) / q
last = sum(v for v, _ in run[-q:]) / q
growth = (last - first) / first * 100
span = run[-1][1] + " - " + run[0][1]
verdict = "FLAT" if abs(growth) < 15 else "GROWING"
print(f"SOAK VERDICT: {verdict} — tex {first/1e6:.0f} -> {last/1e6:.0f} MB ({growth:+.1f}%) over {len(run)} samples, {span}")
PY
echo "csv: $csv"
