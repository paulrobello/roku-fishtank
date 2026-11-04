sub init()
    dr = m.top.currentDesignResolution
    water = m.top.findNode("water")
    water.width = dr.width
    water.height = dr.height

    uri = "pkg:/config/brain.json"
    behUri = "pkg:/config/behavior.json"
    cfg = ParseJson(ReadAsciiFile(uri))
    beh = ParseJson(ReadAsciiFile(behUri))
    layer = m.top.findNode("markers")
    if cfg <> invalid then demoDrawMarkers(layer, cfg)
    if beh <> invalid then demoDrawBehavior(layer, beh)
    brain = m.top.findNode("brain")
    brain.behaviorUri = behUri
    brain.configUri = uri
end sub

' Faint dots on each ellipse outline and along the lane rect (the anchor's swim area).
sub demoDrawMarkers(layer as object, cfg as object)
    for each e in cfg.ellipses
        for i = 0 to 23
            a = i * 6.2831853 / 24.0
            demoDot(layer, e.cx + e.rx * Cos(a), e.cy + e.ry * Sin(a), 6, &hFFD08A60)
        end for
    end for
    lane = cfg.lane
    for x = lane.left to lane.right step 80
        demoDot(layer, x, lane.top, 6, &h8FD0FF40)
        demoDot(layer, x, lane.bottom, 6, &h8FD0FF40)
    end for
    for y = lane.top to lane.bottom step 80
        demoDot(layer, lane.left, y, 6, &h8FD0FF40)
        demoDot(layer, lane.right, y, 6, &h8FD0FF40)
    end for
end sub

' Cave mouths (yellow) and dens (violet) joined by small dots, rock graze points (green)
' and the bottom band outline (sand).
sub demoDrawBehavior(layer as object, beh as object)
    for each c in beh.caves
        for k = 1 to 5
            f = k / 6.0
            demoDot(layer, c.mouth[0] + (c.den[0] - c.mouth[0]) * f, c.mouth[1] + (c.den[1] - c.mouth[1]) * f, 4, &hFFFFFF80)
        end for
        demoDot(layer, c.mouth[0], c.mouth[1], 12, &hFFE040C0)
        demoDot(layer, c.den[0], c.den[1], 12, &hB060FFC0)
    end for
    for each r in beh.rocks
        demoDot(layer, r[0], r[1], 10, &h60E070C0)
    end for
    band = beh.band
    for x = band.left to band.right step 40
        demoDot(layer, x, band.top, 5, &hE0C08080)
        demoDot(layer, x, band.bottom, 5, &hE0C08080)
    end for
end sub

sub demoDot(layer as object, x as float, y as float, size as integer, color as integer)
    dot = layer.createChild("Rectangle")
    dot.width = size
    dot.height = size
    dot.translation = [x - size / 2, y - size / 2]
    dot.color = color
end sub
