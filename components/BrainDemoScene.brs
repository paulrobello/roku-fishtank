sub init()
    dr = m.top.currentDesignResolution
    water = m.top.findNode("water")
    water.width = dr.width
    water.height = dr.height

    uri = "pkg:/config/brain.json"
    cfg = ParseJson(ReadAsciiFile(uri))
    if cfg <> invalid then demoDrawMarkers(m.top.findNode("markers"), cfg)
    m.top.findNode("brain").configUri = uri
end sub

' Faint dots on each ellipse outline and along the lane rect (the anchor's swim area).
sub demoDrawMarkers(layer as object, cfg as object)
    for each e in cfg.ellipses
        for i = 0 to 23
            a = i * 6.2831853 / 24.0
            demoDot(layer, e.cx + e.rx * Cos(a), e.cy + e.ry * Sin(a), &hFFD08A60)
        end for
    end for
    lane = cfg.lane
    for x = lane.left to lane.right step 80
        demoDot(layer, x, lane.top, &h8FD0FF40)
        demoDot(layer, x, lane.bottom, &h8FD0FF40)
    end for
    for y = lane.top to lane.bottom step 80
        demoDot(layer, lane.left, y, &h8FD0FF40)
        demoDot(layer, lane.right, y, &h8FD0FF40)
    end for
end sub

sub demoDot(layer as object, x as float, y as float, color as integer)
    dot = layer.createChild("Rectangle")
    dot.width = 6
    dot.height = 6
    dot.translation = [x - 3, y - 3]
    dot.color = color
end sub
