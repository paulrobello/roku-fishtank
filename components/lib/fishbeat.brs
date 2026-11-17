' Fins keep their original timing. Tails follow actual travel speed independently.
function fishBeatPeriods(speed as float) as object
    finSpeed = speed
    if finSpeed < 1 then finSpeed = 1
    period = 60.0 / finSpeed
    if period < 0.35 then period = 0.35
    if period > 3.0 then period = 3.0
    return { fin: period, tail: fishBeatTailPeriod(speed) }
end function

function fishBeatTailPeriod(speed as float) as float
    if speed < 0 then speed = 0
    frequency = 0.12 + speed / 140.0
    if frequency > 2.1 then frequency = 2.1
    return 1.0 / frequency
end function

' Elapsed wall time, not callback count, advances the continuous phase.
function fishBeatPhase(phase as float, elapsed as float, period as float) as float
    if elapsed > 0 and period > 0 then phase = phase + elapsed / period
    phase = phase - Int(phase)
    if phase < 0 then phase = phase + 1
    return phase
end function

function fishBeatShouldRetime(previous as float, nextPeriod as float) as boolean
    if previous <= 0 then return true
    return Abs(nextPeriod - previous) / previous >= 0.1
end function

' Rotate the same piecewise sine curve, preserving its interpolated start value.
' Both rotation and foreshortening use 16 subdivisions; no Animation fraction write.
function fishBeatTailCurve(phase as float, amplitude as float, depth as float) as object
    phase = fishBeatPhase(phase, 0, 1)
    steps = 16
    keys = [0.0]
    rotations = []
    scales = []
    start = fishBeatTailSample(phase, amplitude, depth)
    rotations.push(start.rotation)
    scales.push(start.scale)
    first = Int(phase * steps) + 1
    for i = first to first + steps - 1
        key = i / steps - phase
        if key < 1.0 then
            sample = fishBeatTailSample(i / steps, amplitude, depth)
            keys.push(key)
            rotations.push(sample.rotation)
            scales.push(sample.scale)
        end if
    end for
    keys.push(1.0)
    rotations.push(start.rotation)
    scales.push(start.scale)
    return { keys: keys, rotations: rotations, scales: scales }
end function

' Match linear interpolation between canonical sine knots, including sin-squared sway.
function fishBeatTailSample(phase as float, amplitude as float, depth as float) as object
    phase = fishBeatPhase(phase, 0, 1)
    x = phase * 16
    i = Int(x)
    u = x - i
    a = Sin(i * 6.2831853 / 16)
    b = Sin((i + 1) * 6.2831853 / 16)
    return {
        rotation: amplitude * (a + (b - a) * u)
        scale: [1.0 - depth * (a * a + (b * b - a * a) * u), 1.0]
    }
end function

' Resume on an already running Roku Animation restarts it. Emit only transitions.
function fishBeatPauseAction(wasPaused as boolean, wantPaused as boolean) as string
    if wasPaused = wantPaused then return ""
    if wantPaused then return "pause"
    return "resume"
end function
