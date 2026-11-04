sub init()
    m.rig = m.top.findNode("rig")
    m.body = m.top.findNode("body")
    m.tail = m.top.findNode("tail")
    m.fin = m.top.findNode("fin")
    m.swimAnim = m.top.findNode("swimAnim")
    m.tailInterp = m.top.findNode("tailInterp")
    m.finInterp = m.top.findNode("finInterp")
    m.turnAnim = m.top.findNode("turnAnim")
    m.turnInterp = m.top.findNode("turnInterp")

    ' Interpolators resolve their target by node id, so each instance renames its rig
    ' nodes to ids that are unique across the scene.
    if not m.global.hasField("fishSerial") then m.global.addFields({ fishSerial: 0 })
    serial = m.global.fishSerial + 1
    m.global.fishSerial = serial
    prefix = "fish" + serial.toStr() + "_"
    m.prefix = prefix
    m.rig.id = prefix + "rig"
    m.body.id = prefix + "body"
    m.tail.id = prefix + "tail"
    m.fin.id = prefix + "fin"
    m.tailInterp.fieldToInterp = [m.tail.id + ".rotation"]
    m.finInterp.fieldToInterp = [m.fin.id + ".rotation"]
    m.turnInterp.fieldToInterp = [m.rig.id + ".scale"]

    m.extras = []
    m.turnSquash = 0.05
    m.artFacing = 1
    m.shownFacing = 1
    m.loaded = false
    m.turnAnim.observeField("state", "onTurnState")
end sub

sub onSpeciesChanged()
    name = m.top.species
    spec = fishReadJson("pkg:/config/species/" + name + ".json")
    rig = fishReadJson("pkg:/config/species/" + name + ".rig.json")
    if spec = invalid or rig = invalid then
        print "Fish ERROR: cannot read rig data for species '"; name; "'"
        return
    end if

    ' Art drawn facing left mirrors every displayed facing.
    m.artFacing = 1
    if spec.facing = "left" then m.artFacing = -1

    layers = rig.layers
    fishSetLayer(m.body, layers.body)
    fishSetLayer(m.tail, layers.tail)
    fishSetLayer(m.fin, layers.fin)
    m.rig.scaleRotateCenter = rig.mirror_center

    m.shownFacing = fishSign(m.top.facing)
    m.rig.scale = [m.shownFacing * m.artFacing, 1.0]
    fishBuildSwimKeys(layers.tail.swing_deg, layers.fin.swing_deg)
    fishBuildExtras(rig)
    m.loaded = true
    fishStartSwim()
end sub

sub onSwimSpeedChanged()
    if m.loaded then fishStartSwim()
end sub

' Turns about mirror_center: scale.x runs from the current value through 0 to the new
' facing while scale.y dips by turnSquash at the midpoint.
sub onFacingChanged()
    if not m.loaded then return
    target = fishSign(m.top.facing)
    if target = m.shownFacing then return
    startX = m.rig.scale[0]
    endX = target * m.artFacing
    m.turnAnim.control = "stop"
    m.turnInterp.keyValue = [[startX, 1.0], [(startX + endX) / 2.0, 1.0 - m.turnSquash], [endX, 1.0]]
    m.shownFacing = target
    m.top.turning = true
    m.turnAnim.control = "start"
end sub

sub onTurnState()
    if m.turnAnim.state = "stopped" then m.top.turning = false
end sub

' Poster size is set explicitly from the rig (Posters draw at natural size otherwise).
' Tail and fin pivots become scaleRotateCenter, in each layer's own pixels.
sub fishSetLayer(poster as object, layer as object)
    poster.uri = layer.uri
    poster.width = layer.width
    poster.height = layer.height
    poster.translation = layer.offset
    if layer.pivot <> invalid then poster.scaleRotateCenter = layer.pivot
end sub

' One swim cycle: a sampled sine with the tail extremes at fractions 0.25 and 0.75.
' The fin lags the tail by a quarter cycle. Rotation is in radians.
sub fishBuildSwimKeys(tailDeg as float, finDeg as float)
    toRad = 3.14159265 / 180.0
    keys = []
    tailValues = []
    for i = 0 to 8
        a = i * 6.2831853 / 8.0
        keys.push(i / 8.0)
        tailValues.push(tailDeg * toRad * sin(a))
    end for
    m.tailInterp.key = keys
    m.tailInterp.keyValue = tailValues
    m.finInterp.key = keys
    m.finInterp.keyValue = fishFinValues(finDeg)
end sub

function fishFinValues(swingDeg as float) as object
    toRad = 3.14159265 / 180.0
    values = []
    for i = 0 to 8
        values.push(-swingDeg * toRad * cos(i * 6.2831853 / 8.0))
    end for
    return values
end function

' Extra swinging layers (rig extra_layers, e.g. lionfish dorsal spines): one Poster per
' entry at its draw_order position in the rig, swinging in phase with the pectoral fin by
' its own swing_deg (as tools/art/rig.py renders the rig check).
sub fishBuildExtras(rig as object)
    for each extra in m.extras
        m.rig.removeChild(extra.poster)
        m.swimAnim.removeChild(extra.interp)
    end for
    m.extras = []
    if rig.extra_layers = invalid or rig.draw_order = invalid then return

    byName = {}
    for each layer in rig.extra_layers
        byName[layer.name] = layer
    end for
    for i = 0 to rig.draw_order.count() - 1
        layer = byName[rig.draw_order[i]]
        if layer <> invalid then
            poster = createObject("roSGNode", "Poster")
            poster.id = m.prefix + layer.name
            fishSetLayer(poster, layer)
            m.rig.insertChild(poster, i)
            interp = createObject("roSGNode", "FloatFieldInterpolator")
            interp.fieldToInterp = [poster.id + ".rotation"]
            interp.key = m.finInterp.key
            interp.keyValue = fishFinValues(layer.swing_deg)
            m.swimAnim.appendChild(interp)
            m.extras.push({ poster: poster, interp: interp })
        end if
    end for
end sub

' Beat period is 1 s at 60 px/s and scales inversely with speed, clamped to 0.35-3 s.
' A running Animation's duration is only changed across a stop/start.
sub fishStartSwim()
    speed = m.top.swimSpeed
    if speed < 1 then speed = 1
    period = 60.0 / speed
    if period < 0.35 then period = 0.35
    if period > 3.0 then period = 3.0
    m.swimAnim.control = "stop"
    m.swimAnim.duration = period
    m.swimAnim.control = "start"
end sub

function fishSign(value as integer) as integer
    if value < 0 then return -1
    return 1
end function

function fishReadJson(path as string) as object
    text = ReadAsciiFile(path)
    if text = "" then return invalid
    return ParseJson(text)
end function
