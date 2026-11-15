' Sample the animation fraction, not rounded pixels: slow motion and turnarounds
' are healthy. Three unchanged samples (15 seconds) are required before recovery.
function driftGuardStep(previous as dynamic, fraction as float, unchanged as integer, enabled as boolean, state as string) as object
    if not enabled then return { fraction: invalid, unchanged: 0, restart: false }
    if state = "paused" then return { fraction: invalid, unchanged: 0, restart: false }
    if state <> "running" then return { fraction: fraction, unchanged: 0, restart: true }
    if previous = invalid then return { fraction: fraction, unchanged: 0, restart: false }
    if Abs(fraction - previous) > 0.00001 then return { fraction: fraction, unchanged: 0, restart: false }
    unchanged += 1
    if unchanged >= 3 then return { fraction: invalid, unchanged: 0, restart: true }
    return { fraction: fraction, unchanged: unchanged, restart: false }
end function
