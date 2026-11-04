sub init()
    m.rig = m.top.findNode("rig")
    m.swimAnim = m.top.findNode("swimAnim")
    m.turnAnim = m.top.findNode("turnAnim")
    m.turnInterp = m.top.findNode("turnInterp")
    ' Set 0 draws the rig's layers as authored, set 1 its pre-mirrored layers.
    m.sets = [
        fishFindSet("base", "body", "tail", "fin", "tailInterp", "finInterp", "baseFade"),
        fishFindSet("mirrored", "mBody", "mTail", "mFin", "mTailInterp", "mFinInterp", "mirroredFade")
    ]

    ' Interpolators resolve their target by node id, so each instance renames its rig
    ' nodes to ids that are unique across the scene.
    if not m.global.hasField("fishSerial") then m.global.addFields({ fishSerial: 0 })
    serial = m.global.fishSerial + 1
    m.global.fishSerial = serial
    prefix = "fish" + serial.toStr() + "_"
    m.prefix = prefix
    m.rig.id = prefix + "rig"
    for each set in m.sets
        set.group.id = prefix + set.name
        set.body.id = prefix + set.name + "_body"
        set.tail.id = prefix + set.name + "_tail"
        set.fin.id = prefix + set.name + "_fin"
        set.tailInterp.fieldToInterp = [set.tail.id + ".rotation"]
        set.finInterp.fieldToInterp = [set.fin.id + ".rotation"]
        set.fade.fieldToInterp = [set.group.id + ".opacity"]
    end for
    m.turnInterp.fieldToInterp = [m.rig.id + ".scale"]

    m.turnSquash = 0.05
    m.turnNarrow = 0.05
    m.artFacing = 1
    m.shownFacing = 1
    m.loaded = false
    m.turnAnim.observeField("state", "onTurnState")
end sub

function fishFindSet(name as string, body as string, tail as string, fin as string, tailInterp as string, finInterp as string, fade as string) as object
    return {
        name: name,
        group: m.top.findNode(name),
        body: m.top.findNode(body),
        tail: m.top.findNode(tail),
        fin: m.top.findNode(fin),
        tailInterp: m.top.findNode(tailInterp),
        finInterp: m.top.findNode(finInterp),
        fade: m.top.findNode(fade),
        extras: []
    }
end function

sub onSpeciesChanged()
    name = m.top.species
    spec = fishReadJson("pkg:/config/species/" + name + ".json")
    rig = fishReadJson("pkg:/config/species/" + name + ".rig.json")
    if spec = invalid or rig = invalid then
        print "Fish ERROR: cannot read rig data for species '"; name; "'"
        return
    end if
    if rig.mirrored = invalid then
        print "Fish ERROR: rig for species '"; name; "' has no mirrored set (rerun make art)"
        return
    end if

    ' Art drawn facing left shows the mirrored set when facing right.
    m.artFacing = 1
    if spec.facing = "left" then m.artFacing = -1

    m.turnAnim.control = "stop"
    fishLoadSet(m.sets[0], rig.layers, rig.extra_layers, rig.draw_order)
    fishLoadSet(m.sets[1], rig.mirrored.layers, rig.mirrored.extra_layers, rig.draw_order)
    m.rig.scaleRotateCenter = rig.mirror_center
    m.rig.scale = [1.0, 1.0]
    m.shownFacing = fishSign(m.top.facing)
    fishShowSet(fishSetFor(m.shownFacing))
    m.top.turning = false
    m.loaded = true
    fishStartSwim()
end sub

sub onSwimSpeedChanged()
    if m.loaded then fishStartSwim()
end sub

' The set index that shows `facing` (1 right, -1 left).
function fishSetFor(facing as integer) as integer
    if facing * m.artFacing > 0 then return 0
    return 1
end function

' The set drawn now: the one more than half opaque.
function fishDrawnSet() as integer
    if m.sets[1].group.opacity >= 0.5 then return 1
    return 0
end function

sub fishShowSet(index as integer)
    for i = 0 to m.sets.count() - 1
        m.sets[i].group.visible = (i = index)
        if i = index then m.sets[i].group.opacity = 1.0 else m.sets[i].group.opacity = 0.0
    end for
end sub

' Turns about mirror_center: scale.x narrows to turnNarrow (never below 0) while scale.y
' dips by turnSquash, the drawn set swaps to the other facing's art there, then scale.x
' widens back to 1. The swap is two opacity interpolators stepping across the midpoint
' of the same Animation as the scale, so it lands on the narrowest frame on the render
' thread; a second Animation chained from a state observer would land a frame late and
' would not seek correctly under the preview's ?freeze.
sub onFacingChanged()
    if not m.loaded then return
    target = fishSign(m.top.facing)
    if target = m.shownFacing then return
    m.shownFacing = target
    want = fishSetFor(target)
    m.turnAnim.control = "stop"
    drawn = fishDrawnSet()
    other = 1 - drawn
    s = m.rig.scale
    if drawn = want then
        ' Reversed before the narrowest point: widen again with the same art.
        m.turnInterp.keyValue = [[s[0], s[1]], [(s[0] + 1.0) / 2.0, (s[1] + 1.0) / 2.0], [1.0, 1.0]]
        m.sets[drawn].fade.keyValue = [1.0, 1.0, 1.0, 1.0]
        m.sets[other].fade.keyValue = [0.0, 0.0, 0.0, 0.0]
    else
        m.turnInterp.keyValue = [[s[0], s[1]], [m.turnNarrow, 1.0 - m.turnSquash], [1.0, 1.0]]
        m.sets[drawn].fade.keyValue = [1.0, 1.0, 0.0, 0.0]
        m.sets[other].fade.keyValue = [0.0, 0.0, 1.0, 1.0]
    end if
    m.sets[0].group.visible = true
    m.sets[1].group.visible = true
    m.top.turning = true
    m.turnAnim.control = "start"
end sub

' Hides the set that is not drawn once a turn has finished. A stale "stopped" from an
' interrupted turn finds the new turn's art not yet drawn and leaves both sets up.
sub onTurnState()
    if m.turnAnim.state <> "stopped" then return
    drawn = fishDrawnSet()
    if drawn <> fishSetFor(m.shownFacing) or m.rig.scale[0] < 0.999 then return
    fishShowSet(drawn)
    m.top.turning = false
end sub

sub fishLoadSet(set as object, layers as object, extras as object, drawOrder as object)
    fishSetLayer(set.body, layers.body)
    fishSetLayer(set.tail, layers.tail)
    fishSetLayer(set.fin, layers.fin)
    fishBuildSwimKeys(set, layers.tail.swing_deg, layers.fin.swing_deg)
    fishBuildExtras(set, extras, drawOrder)
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
' The fin lags the tail by a quarter cycle. Rotation is in radians. The mirrored set's
' swing_deg is negated in the rig, so both sets beat the same way on screen.
sub fishBuildSwimKeys(set as object, tailDeg as float, finDeg as float)
    toRad = 3.14159265 / 180.0
    keys = []
    tailValues = []
    for i = 0 to 8
        a = i * 6.2831853 / 8.0
        keys.push(i / 8.0)
        tailValues.push(tailDeg * toRad * sin(a))
    end for
    set.tailInterp.key = keys
    set.tailInterp.keyValue = tailValues
    set.finInterp.key = keys
    set.finInterp.keyValue = fishFinValues(finDeg)
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
' entry at its draw_order position in the set, swinging in phase with the pectoral fin by
' its own swing_deg (as tools/art/rig.py renders the rig check).
sub fishBuildExtras(set as object, extras as object, drawOrder as object)
    for each extra in set.extras
        set.group.removeChild(extra.poster)
        m.swimAnim.removeChild(extra.interp)
    end for
    set.extras = []
    if extras = invalid or drawOrder = invalid then return

    byName = {}
    for each layer in extras
        byName[layer.name] = layer
    end for
    for i = 0 to drawOrder.count() - 1
        layer = byName[drawOrder[i]]
        if layer <> invalid then
            poster = createObject("roSGNode", "Poster")
            poster.id = m.prefix + set.name + "_" + layer.name
            fishSetLayer(poster, layer)
            set.group.insertChild(poster, i)
            interp = createObject("roSGNode", "FloatFieldInterpolator")
            interp.fieldToInterp = [poster.id + ".rotation"]
            interp.key = set.finInterp.key
            interp.keyValue = fishFinValues(layer.swing_deg)
            m.swimAnim.appendChild(interp)
            set.extras.push({ poster: poster, interp: interp })
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
