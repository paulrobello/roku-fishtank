#!/usr/bin/env bash
# api-guard: reject device-source constructs that Roku OS 15.3.4 or the
# screensaver rules forbid. brs-engine simulates OS 16.0, so the browser
# preview would accept these silently while the device fails.
#
# Scans manifest, source/** and components/** (*.brs, *.bs, *.xml), except
# source/preview.brs (the preview-only Main shim, excluded from the device
# build in bsconfig.json). Prints file:line for every hit, exits 1 on any.
#
# OS 16.0+ only APIs, banned as whole words, case-insensitive. Checked live
# on 2026-11-04 against:
#   https://developer.roku.com/docs/developer-program/release-notes/roku-os-release-notes.md
#   https://developer.roku.com/docs/references/scenegraph/renderable-nodes/poster.md
#   https://developer.roku.com/docs/references/scenegraph/renderable-nodes/effect.md
#   effect                       Effect node, and the Poster/Rectangle effect field
#   shaderCompatible             Poster field
#   FloatArrayFieldInterpolator  node
#   focusFeedbackPoster          ArrayGrid field
#   GetRokuCustomerId            ChannelStore command
#   roSSEvent, roWebSocket       BrightScript components
#   AsyncGetSSEvents, SSELastEventId, SSERetry, SSEClearLastEventId
#                                ifUrlTransfer functions
#   SetDrawable                  roTextureRequest function
# Effect sub-fields (borderRadius, gradientColors, ...) are not listed: they
# only exist on an Effect node, which "effect" already catches.
#
# Also rejected:
#   a sub/function definition named Main or RunUserInterface (screensavers
#   may only define RunScreenSaver / RunScreenSaverSettings);
#   a manifest title= line, or a manifest without screensaver_title=.
#
# Comment handling (known limitations): full-line BrightScript comments (' and
# rem), single-line XML <!-- --> comments and manifest # lines are skipped.
# Trailing ' comments after code, multi-line XML comments and comments inside
# inline <script> CDATA are still scanned, so a banned word there is a false
# positive: reword the comment.
set -eu

cd "$(dirname "$0")/.."

files=$(find source components -type f \( -name '*.brs' -o -name '*.bs' -o -name '*.xml' \) \
    ! -path 'source/preview.brs' 2>/dev/null | LC_ALL=C sort)

# shellcheck disable=SC2086
awk '
BEGIN {
    nb = split("effect shadercompatible floatarrayfieldinterpolator focusfeedbackposter " \
               "getrokucustomerid rossevent rowebsocket asyncgetssevents sselasteventid " \
               "sseretry sseclearlasteventid setdrawable", banned, " ")
    hits = 0
}
function report(why) {
    printf "%s:%d: %s: %s\n", FILENAME, FNR, why, $0
    hits++
}
{
    line = tolower($0)
    if (FILENAME == "manifest") {
        if (line ~ /^[[:space:]]*#/) next
        if (line ~ /^[[:space:]]*title[[:space:]]*=/) report("manifest title= (screensavers use screensaver_title only)")
        if (line ~ /^[[:space:]]*screensaver_title[[:space:]]*=/) has_ss_title = 1
    } else if (FILENAME ~ /\.xml$/) {
        gsub(/<!--.*-->/, "", line)
    } else {
        if (line ~ /^[[:space:]]*'"'"'/ || line ~ /^[[:space:]]*rem([[:space:]]|$)/) next
    }
    for (i = 1; i <= nb; i++) {
        if (line ~ ("(^|[^a-z0-9_])" banned[i] "([^a-z0-9_]|$)")) report("OS 16.0+ API \"" banned[i] "\" (device runs 15.3.4)")
    }
    if (line ~ /^[[:space:]]*(sub|function)[[:space:]]+(main|runuserinterface)[[:space:]]*\(/) report("Main/RunUserInterface defined in device sources (screensaver entry is RunScreenSaver)")
}
END {
    if (!has_ss_title) { print "manifest: missing screensaver_title="; hits++ }
    if (hits > 0) { printf "api-guard FAILED: %d problem(s)\n", hits; exit 1 }
    print "api-guard ok"
}
' manifest $files
