' Preview-only colour helper for the ?freeze shim in preview.brs (excluded from the device
' build in bsconfig.json, unit-tested by tests/unit/preview_color_test.brs).
'
' Matches the Roku 4850X (OS 15.3.4) ColorFieldInterpolator, which the preview's patched
' brs-scenegraph 0.6.2 interpolateColor also follows (preview/vite.config.ts): hue is
' lerped linearly in [0, 360) with NO shortest-path wrap (red -> blue measured yellow,
' green, cyan at 0.25 / 0.5 / 0.75, docs/fidelity F5). A gap over 180 degrees therefore
' goes the long way; that is measured only for 0 -> 240, the rest is assumed. Saturation
' and value are lerped and clamped to 0..1, alpha (0..255, not normalised) is lerped and
' clamped only when packed. toHsv/fromHsv are brs-sg's. Math is in Double to match JS.

' Colour at fraction t between 0xRRGGBBAA colours a and b, interpolated in HSV.
function previewLerpColorHsv(a as integer, b as integer, t as double) as integer
    ca = previewToHsv(a)
    cb = previewToHsv(b)
    h = previewFmod(ca.h + (cb.h - ca.h) * t + 360, 360)
    s = previewClamp(ca.s + (cb.s - ca.s) * t, 0, 1)
    v = previewClamp(ca.v + (cb.v - ca.v) * t, 0, 1)
    alpha = ca.a + (cb.a - ca.a) * t
    return previewFromHsv(h, s, v, alpha)
end function

function previewToHsv(c as integer) as object
    r = cdbl((c >> 24) and 255) / 255
    g = cdbl((c >> 16) and 255) / 255
    b = cdbl((c >> 8) and 255) / 255
    hi = r
    if g > hi then hi = g
    if b > hi then hi = b
    lo = r
    if g < lo then lo = g
    if b < lo then lo = b
    d = hi - lo
    h = cdbl(0)
    ' brs-sg applies "% 6" to (g - b) / d, a no-op because that ratio lies in [-1, 1].
    if d <> 0 then
        if hi = r then
            h = (g - b) / d * 60
        else if hi = g then
            h = 60 * ((b - r) / d + 2)
        else
            h = 60 * ((r - g) / d + 4)
        end if
    end if
    if h < 0 then h = h + 360
    s = cdbl(0)
    if hi <> 0 then s = d / hi
    return { h: h, s: s, v: hi, a: cdbl(c and 255) }
end function

function previewFromHsv(h as double, s as double, v as double, alpha as double) as integer
    c = v * s
    x = c * (1 - abs(previewFmod(h / 60, 2) - 1))
    m = v - c
    r = cdbl(0)
    g = cdbl(0)
    b = cdbl(0)
    if h < 60 then
        r = c
        g = x
    else if h < 120 then
        r = x
        g = c
    else if h < 180 then
        g = c
        b = x
    else if h < 240 then
        g = x
        b = c
    else if h < 300 then
        r = x
        b = c
    else
        r = c
        b = x
    end if
    ri = int(255 * (r + m) + 0.5) and 255
    gi = int(255 * (g + m) + 0.5) and 255
    bi = int(255 * (b + m) + 0.5) and 255
    ai = int(previewClamp(alpha, 0, 255) + 0.5) and 255
    return (ri << 24) or (gi << 16) or (bi << 8) or ai
end function

' JS-style remainder for x >= 0 (int() is floor).
function previewFmod(x as double, n as double) as double
    return x - n * int(x / n)
end function

function previewClamp(x as double, lo as double, hi as double) as double
    if x < lo then return lo
    if x > hi then return hi
    return x
end function
