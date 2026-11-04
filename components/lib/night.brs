' Night mode logic (P3.3-P3.6) for components/Night. Pure functions: the clock,
' config and random generator are passed in, so brs-cli unit tests cover them
' (tests/unit/night_test.brs). Colours are 0xRRGGBBAA integers.

' v when it is a number, else fallback.
function nightNum(v as dynamic, fallback as float) as float
    if LCase(type(v)) = "integer" or LCase(type(v)) = "float" then return v
    return fallback
end function

' Parses a preview ?time value: "HH:MM" or "YYYY-MM-DDTHH:MM" (a space also works
' as the separator). Returns { minutes, year, month, day } with year 0 when no date
' was given, or invalid when the text is not a time.
function nightParseClock(text as string) as dynamic
    s = text.trim()
    year = 0
    month = 0
    day = 0
    if Len(s) >= 16 then
        if Mid(s, 5, 1) <> "-" or Mid(s, 8, 1) <> "-" then return invalid
        year = Val(Left(s, 4))
        month = Val(Mid(s, 6, 2))
        day = Val(Mid(s, 9, 2))
        if year < 1970 or month < 1 or month > 12 or day < 1 or day > 31 then return invalid
        s = Mid(s, 12)
    end if
    parts = s.split(":")
    if parts.count() <> 2 then return invalid
    if Len(parts[0]) < 1 or Len(parts[0]) > 2 or Len(parts[1]) <> 2 then return invalid
    if not nightIsDigits(parts[0] + parts[1]) then return invalid
    hh = Val(parts[0])
    mm = Val(parts[1])
    if hh > 23 or mm > 59 then return invalid
    return { minutes: hh * 60.0 + mm, year: year, month: month, day: day }
end function

function nightIsDigits(s as string) as boolean
    for i = 1 to Len(s)
        c = Asc(Mid(s, i, 1))
        if c < 48 or c > 57 then return false
    end for
    return true
end function

' Clock minutes after local midnight, elapsed seconds after the start at the
' given speed (the preview ?speed). Not wrapped: daynightPhase wraps.
function nightClockMinutes(startMinutes as float, elapsedSeconds as float, speed as float) as float
    return startMinutes + elapsedSeconds * speed / 60.0
end function

function nightClamp01(x as float) as float
    if x < 0 then return 0.0
    if x > 1 then return 1.0
    return x
end function

' The shown blend moves toward target by at most dt / easeSeconds, so a jump
' (a nightMode change) eases over easeSeconds while the slow solar blend is
' followed exactly. easeSeconds <= 0 snaps.
function nightStep(current as float, target as float, dt as float, easeSeconds as float) as float
    if easeSeconds <= 0 then return target
    maxStep = dt / easeSeconds
    d = target - current
    if d > maxStep then return current + maxStep
    if d < -maxStep then return current - maxStep
    return target
end function

' Day shafts fade out over the first half of the blend and the night overlays
' (moon shafts, coral glow, sparkles) fade in over the second, so the two shaft
' pairs are never drawn at the same time.
function nightDayLevel(blend as float) as float
    return nightClamp01(1.0 - 2.0 * blend)
end function

function nightNightLevel(blend as float) as float
    return nightClamp01(2.0 * blend - 1.0)
end function

' True once the night overlays start to show. Caustics (P4.6) hide from here.
function nightIsNight(blend as float) as boolean
    return blend >= 0.5
end function

' brs-engine returns 255 for (negative >> 0) and 255, so alpha is masked unshifted.
function nightChannel(c as integer, shift as integer) as integer
    if shift = 0 then return c and 255
    return (c >> shift) and 255
end function

function nightPack(r as integer, g as integer, b as integer, a as integer) as integer
    return (r << 24) or (g << 16) or (b << 8) or a
end function

' Per-channel RGB(A) lerp from a to b at t in 0..1, rounded.
function nightLerpColor(a as integer, b as integer, t as float) as integer
    out = []
    for each shift in [24, 16, 8, 0]
        ca = nightChannel(a, shift)
        cb = nightChannel(b, shift)
        out.push(Int(ca + (cb - ca) * t + 0.5))
    end for
    return nightPack(out[0], out[1], out[2], out[3])
end function

' blendColor multiply of two colours, per channel a * b / 255 rounded. White is
' the identity, so a Poster's own tint is restored exactly at blend 0.
function nightMultiplyColor(a as integer, b as integer) as integer
    out = []
    for each shift in [24, 16, 8, 0]
        out.push((nightChannel(a, shift) * nightChannel(b, shift) + 127) \ 255)
    end for
    return nightPack(out[0], out[1], out[2], out[3])
end function

' Linear keys for one breathing cycle: opacity = lo + (hi - lo) * (0.5 + 0.5 sin),
' sampled at count keys and started phaseDeg into the cycle. First and last keys
' match, so a repeating Animation loops without a jump.
function nightBreathKeys(lo as float, hi as float, phaseDeg as float, count as integer) as object
    keys = []
    values = []
    for i = 0 to count - 1
        f = i / (count - 1.0)
        keys.push(f)
        values.push(nightBreathAt(lo, hi, phaseDeg, f, 1.0))
    end for
    return { keys: keys, values: values }
end function

' The breathing value at t seconds into a period-long cycle (nightBreathKeys is
' the same curve as keyframes). Matches a repeating Animation started at t = 0.
function nightBreathAt(lo as float, hi as float, phaseDeg as float, t as float, period as float) as float
    if period <= 0 then return lo
    f = t / period - Int(t / period)
    return lo + (hi - lo) * (0.5 + 0.5 * Sin(6.283185307 * f + phaseDeg * 0.0174532925))
end function

' Glow items whose over sprite starts with one of groups.
function nightGlowItems(glow as object) as object
    out = []
    if glow = invalid or glow.items = invalid then return out
    groups = glow.groups
    if groups = invalid then groups = []
    for each item in glow.items
        for each g in groups
            if Left(item.over, Len(g)) = g then
                out.push(item)
                exit for
            end if
        end for
    end for
    return out
end function

' The sparkle pool layout (P3.6): exactly cfg.pool slots, each { x, y, size,
' dx, dy, period, delay, peak } drawn from rng. Every slot loops its drift in
' place, so the pool never grows or shrinks after init.
function nightSparkleSlots(cfg as object, rng as object) as object
    slots = []
    area = cfg.area
    for i = 0 to cfg.pool - 1
        size = Int(prngRange(rng, cfg.sizeMin, cfg.sizeMax + 0.999))
        x = prngRange(rng, area.left, area.right - size)
        y = prngRange(rng, area.top, area.bottom - size)
        dist = prngRange(rng, cfg.driftMin, cfg.driftMax)
        angle = prngRange(rng, 0, 6.283185307)
        slots.push({
            x: Int(x)
            y: Int(y)
            size: size
            dx: dist * Cos(angle)
            dy: dist * Sin(angle) * 0.5 - dist * 0.5
            period: prngRange(rng, cfg.periodMin, cfg.periodMax)
            delay: prngRange(rng, 0, cfg.delayMax)
            peak: prngRange(rng, cfg.opacityMin, cfg.opacityMax)
        })
    end for
    return slots
end function

' Twinkle opacity keys for one sparkle cycle: dark at both ends so the drift
' can jump back to its start unseen.
function nightTwinkleKeys(peak as float) as object
    return { keys: [0.0, 0.2, 0.45, 0.6, 0.8, 1.0], values: [0.0, peak, peak * 0.35, peak, peak * 0.6, 0.0] }
end function

' Piecewise-linear keyframe value at fraction f in 0..1.
function nightKeyAt(keys as object, values as object, f as float) as float
    if keys.count() = 0 or values.count() = 0 then return 0.0
    if f <= keys[0] then return values[0]
    last = keys.count() - 1
    if values.count() - 1 < last then last = values.count() - 1
    if last < 0 then return values[0]
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

' Sparkle slot pose at t seconds after scene start: the drift is linear over the
' cycle and the twinkle comes from nightTwinkleKeys, both offset by the delay.
function nightSparklePose(slot as object, t as float) as object
    f = 0.0
    if slot.period > 0 then
        f = (t - slot.delay) / slot.period
        f = f - Int(f)
        if f < 0 then f = f + 1.0
    end if
    twinkle = nightTwinkleKeys(slot.peak)
    return {
        translation: [slot.x + slot.dx * f, slot.y + slot.dy * f]
        opacity: nightKeyAt(twinkle.keys, twinkle.values, f)
    }
end function
