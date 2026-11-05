' Night light organs (flashlight fish), pure logic for components/Fish. A species json
' "night" block gives the blink timing; see config/species/flashlight_fish.json _notes.

' One blink loop drawn from rng: { duration (s), keys (0..1), values (opacity 0..1) }.
' The organ is lit at both ends (values[0] = values[last] = 1), so the repeating
' Animation closes. Lit spans last blinkOnSec, shut spans blinkOffSec, each fade
' blinkFadeSec; blinks are added while a whole one still fits before the loop ends.
function glowBlinkPlan(cfg as object, rng as object) as object
    loopLo = glowRangeLo(cfg.blinkLoopSec, 10.0)
    loopHi = glowRangeHi(cfg.blinkLoopSec, loopLo)
    onLo = glowRangeLo(cfg.blinkOnSec, 2.0)
    onHi = glowRangeHi(cfg.blinkOnSec, onLo)
    offLo = glowRangeLo(cfg.blinkOffSec, 0.2)
    offHi = glowRangeHi(cfg.blinkOffSec, offLo)
    fade = 0.06
    if cfg.blinkFadeSec <> invalid then fade = cfg.blinkFadeSec
    duration = prngRange(rng, loopLo, loopHi)
    times = [0.0]
    values = [1.0]
    t = 0.0
    while true
        lit = prngRange(rng, onLo, onHi)
        shut = prngRange(rng, offLo, offHi)
        if t + lit + 2 * fade + shut + onLo > duration then exit while
        t = t + lit
        times.push(t)
        values.push(1.0)
        times.push(t + fade)
        values.push(0.0)
        times.push(t + fade + shut)
        values.push(0.0)
        t = t + 2 * fade + shut
        times.push(t)
        values.push(1.0)
    end while
    times.push(duration)
    values.push(1.0)
    keys = []
    for each v in times
        keys.push(v / duration)
    end for
    return { duration: duration, keys: keys, values: values, phase: prngRange(rng, 0, 1) }
end function

' The plan started `phase` (0..1) of a loop in, as keys that still run 0..1 and close,
' so fish that start together do not blink together. glowBlinkAt(rotated, t) equals
' glowBlinkAt(plan, t + phase x duration).
function glowRotatePlan(plan as object, phase as float) as object
    v0 = glowBlinkAt(plan, phase * plan.duration)
    keys = [0.0]
    values = [v0]
    last = plan.keys.count() - 1
    for i = 1 to last
        k = plan.keys[i] - phase
        if k > 0.000001 and k < 0.999999 then
            keys.push(k)
            values.push(plan.values[i])
        end if
    end for
    for i = 1 to last
        k = plan.keys[i] + 1.0 - phase
        if k > keys[keys.count() - 1] + 0.000001 and k < 0.999999 then
            keys.push(k)
            values.push(plan.values[i])
        end if
    end for
    keys.push(1.0)
    values.push(v0)
    return { duration: plan.duration, keys: keys, values: values, phase: 0.0 }
end function

' Opacity of a plan at t seconds after the loop started (the pose under ?freeze).
function glowBlinkAt(plan as object, t as float) as float
    f = t / plan.duration
    f = f - Int(f)
    keys = plan.keys
    values = plan.values
    last = keys.count() - 1
    if f <= keys[0] then return values[0]
    if f >= keys[last] then return values[last]
    i = 0
    while i < last - 1 and f > keys[i + 1]
        i = i + 1
    end while
    span = keys[i + 1] - keys[i]
    u = 0.0
    if span > 0 then u = (f - keys[i]) / span
    return values[i] + (values[i + 1] - values[i]) * u
end function

' A night-only fish at night level `level` (0 day .. 1 night, components/Night's
' 2 x blend - 1): fully hidden at 0 so it costs no fill by day, fading in above it.
function glowNightShow(level as float) as object
    if level <= 0 then return { visible: false, opacity: 0.0 }
    if level > 1 then level = 1.0
    return { visible: true, opacity: level }
end function

function glowRangeLo(r as dynamic, fallback as float) as float
    if type(r) = "roArray" and r.count() > 0 then return r[0]
    return fallback
end function

function glowRangeHi(r as dynamic, fallback as float) as float
    if type(r) = "roArray" and r.count() > 1 then return r[1]
    return fallback
end function
