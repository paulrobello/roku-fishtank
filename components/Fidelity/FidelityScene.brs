' P0.5 fidelity scene, animated half (cells 6 and 7) plus the fraction probe.
'
' Determinism: every Animation starts in init() and a Timer pauses them all at
' PAUSE_SECONDS. Durations are 4x, 2x and 4/3x the pause time, so the nominal
' linear time fraction at the pause is 0.25, 0.5 and 0.75. Pause jitter (a
' frame or two) is removed from the verdict by reading back each interpolator's
' fraction after the pause: each position is judged against the keyValue lerp
' at its own fraction, and each inOutCubic lane against inOutCubic(fraction of
' its linear partner of the same duration). Results print to the console as
' FIDELITY lines every 3 s, and a summary shows in the on-screen report Label.
sub init()
    m.pauseSeconds = 4.0
    m.laneX0 = 200.0
    m.laneX1 = 1400.0
    m.clock = createObject("roTimespan")
    m.clock.mark()
    m.anims = []
    m.lanes = []
    m.swatches = []
    lanes = m.top.findNode("lanes")

    durations = [16.0, 8.0, 16.0 / 3.0]
    names = ["16", "8", "5"]
    for i = 0 to 2
        addLane(lanes, "io" + names[i], "inOutCubic", durations[i], 580 + 60 * i, i)
    end for
    for i = 0 to 2
        addLane(lanes, "li" + names[i], "linear", durations[i], 780 + 60 * i, i)
    end for

    ' Cell 7: ColorFieldInterpolator red -> blue, linear Animations, plus endpoint references.
    addRect(lanes, "", &hFF0000FF, 140, 960, 120, 60)
    addRect(lanes, "", &h0000FFFF, 1100, 960, 120, 60)
    swatchX = [300, 600, 900]
    for i = 0 to 2
        addSwatch(lanes, "c" + names[i], durations[i], swatchX[i], i)
    end for

    addFractionProbe(lanes)

    m.pauseTimer = createObject("roSGNode", "Timer")
    m.pauseTimer.duration = m.pauseSeconds
    m.pauseTimer.repeat = false
    m.pauseTimer.observeField("fire", "onPause")
    m.top.appendChild(m.pauseTimer)

    for each anim in m.anims
        anim.control = "start"
    end for
    m.pauseTimer.control = "start"
    print "FIDELITY scene started"
end sub

function addRect(parent as object, id as string, color as integer, x as float, y as float, w as float, h as float) as object
    r = createObject("roSGNode", "Rectangle")
    if id <> "" then r.id = id
    r.color = color
    r.translation = [x, y]
    r.width = w
    r.height = h
    parent.appendChild(r)
    return r
end function

' One moving 24x24 marker per lane from x=200 to x=1400, with grey ticks at the
' start and end and a light tick at the expected centre x at the nominal pause.
sub addLane(parent as object, name as string, ease as string, duration as float, y as float, partner as integer)
    tau = m.pauseSeconds / duration
    f = fidEase(tau, ease)
    xExp = m.laneX0 + (m.laneX1 - m.laneX0) * f
    addRect(parent, "", &h505050FF, m.laneX0 + 11, y - 8, 2, 40)
    addRect(parent, "", &h505050FF, m.laneX1 + 11, y - 8, 2, 40)
    addRect(parent, "", &hA0A0A0FF, xExp + 11, y - 8, 2, 40)
    marker = addRect(parent, "lane_" + name, &hFFFF00FF, m.laneX0, y, 24, 24)

    anim = createObject("roSGNode", "Animation")
    anim.duration = duration
    anim.repeat = false
    anim.easeFunction = ease
    interp = createObject("roSGNode", "Vector2DFieldInterpolator")
    interp.fieldToInterp = [marker.id + ".translation"]
    interp.key = [0.0, 1.0]
    interp.keyValue = [[m.laneX0, y], [m.laneX1, y]]
    anim.appendChild(interp)
    parent.appendChild(anim)
    m.anims.push(anim)
    m.lanes.push({ name: name, ease: ease, duration: duration, marker: marker, interp: interp, partner: partner })
end sub

' One 120x60 swatch whose color runs red -> blue, with a 16 px strip of the
' expected HSV color at the nominal pause fraction underneath.
sub addSwatch(parent as object, name as string, duration as float, x as float, idx as integer)
    rect = addRect(parent, "swatch_" + name, &hFF0000FF, x, 960, 120, 60)
    addRect(parent, "", fidHsvRedToBlue(m.pauseSeconds / duration), x, 1024, 120, 16)

    anim = createObject("roSGNode", "Animation")
    anim.duration = duration
    anim.repeat = false
    anim.easeFunction = "linear"
    interp = createObject("roSGNode", "ColorFieldInterpolator")
    interp.fieldToInterp = [rect.id + ".color"]
    interp.key = [0.0, 1.0]
    interp.keyValue = [&hFF0000FF, &h0000FFFF]
    anim.appendChild(interp)
    parent.appendChild(anim)
    m.anims.push(anim)
    m.swatches.push({ name: name, duration: duration, rect: rect, interp: interp, idx: idx })
end sub

' Unscored probe: a bare Vector2DFieldInterpolator (no Animation) with fraction
' set to 0.5. If the platform interpolates on a direct fraction write, the white
' marker sits on the light tick at x=1650; otherwise it stays at x=1500.
sub addFractionProbe(parent as object)
    addRect(parent, "", &h505050FF, 1511, 592, 2, 40)
    addRect(parent, "", &hA0A0A0FF, 1661, 592, 2, 40)
    marker = addRect(parent, "fracProbe", &hFFFFFFFF, 1500, 600, 24, 24)
    interp = createObject("roSGNode", "Vector2DFieldInterpolator")
    interp.fieldToInterp = [marker.id + ".translation"]
    interp.key = [0.0, 1.0]
    interp.keyValue = [[1500.0, 600.0], [1800.0, 600.0]]
    parent.appendChild(interp)
    interp.fraction = 0.5
    m.fracProbe = marker
end sub

sub onPause()
    for each anim in m.anims
        anim.control = "pause"
    end for
    m.pausedMs = m.clock.totalMilliseconds()
    report()
    m.reportTimer = createObject("roSGNode", "Timer")
    m.reportTimer.duration = 3.0
    m.reportTimer.repeat = true
    m.reportTimer.observeField("fire", "report")
    m.top.appendChild(m.reportTimer)
    m.reportTimer.control = "start"
end sub

sub report()
    print "FIDELITY_PAUSED elapsed_ms="; m.pausedMs; " pause_s="; m.pauseSeconds
    summary = "paused " + m.pausedMs.toStr() + " ms" + chr(10)
    for each lane in m.lanes
        f = lane.interp.fraction
        x = lane.marker.translation[0]
        partner = m.lanes[3 + lane.partner].interp.fraction
        expF = fidEase(partner, lane.ease)
        expX = m.laneX0 + (m.laneX1 - m.laneX0) * expF
        lerpX = m.laneX0 + (m.laneX1 - m.laneX0) * f
        print "FIDELITY lane="; lane.name; " frac="; f; " x="; x; " lerp_x="; lerpX; " exp_frac="; expF; " exp_x="; expX
        summary = summary + lane.name + " x" + fidFmt(x) + " e" + fidFmt(expX) + chr(10)
    end for
    for each sw in m.swatches
        f = sw.interp.fraction
        got = fidHex(sw.rect.color)
        expHsv = fidHex(fidHsvRedToBlue(f))
        print "FIDELITY swatch="; sw.name; " frac="; f; " color="; got; " exp_hsv="; expHsv
        summary = summary + sw.name + " " + mid(got, 3, 6) + " e" + mid(expHsv, 3, 6) + chr(10)
    end for
    px = m.fracProbe.translation[0]
    print "FIDELITY fraction_probe x="; px; " (1650 = direct fraction drives, 1500 = ignored)"
    summary = summary + "probe x" + fidFmt(px)
    m.top.findNode("report").text = summary
end sub

function fidEase(f as float, ease as string) as float
    if f < 0 then f = 0
    if f > 1 then f = 1
    if lCase(ease) = "inoutcubic" then
        if f < 0.5 then return 4 * f * f * f
        return 4 * (f - 1) * (f - 1) * (f - 1) + 1
    end if
    return f
end function

' HSV shortest-hue path from red (h=360) to blue (h=240), s=v=1, alpha 255.
function fidHsvRedToBlue(f as float) as integer
    h = 360 - 120 * f
    r = 255
    b = 255
    if h >= 300 then
        b = int((360 - h) / 60 * 255 + 0.5)
    else
        r = int((h - 240) / 60 * 255 + 0.5)
    end if
    return (r << 24) or (b << 8) or 255
end function

function fidHex(c as integer) as string
    digits = "0123456789ABCDEF"
    s = "0x"
    for shift = 24 to 0 step -8
        v = (c >> shift) and 255
        s = s + mid(digits, (v >> 4) + 1, 1) + mid(digits, (v and 15) + 1, 1)
    end for
    return s
end function

function fidFmt(v as float) as string
    return str(int(v * 10 + 0.5) / 10.0).trim()
end function
