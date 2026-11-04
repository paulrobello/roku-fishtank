sub init()
    m.rig = m.top.findNode("rig")
    m.swimAnim = m.top.findNode("swimAnim")
    m.turnAnim = m.top.findNode("turnAnim")
    m.turnInterp = m.top.findNode("turnInterp")
    m.turnRoll = m.top.findNode("turnRoll")
    m.turnLift = m.top.findNode("turnLift")
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
    m.turnRoll.fieldToInterp = [m.rig.id + ".rotation"]
    m.turnLift.fieldToInterp = [m.rig.id + ".translation"]

    ' Turn shape: narrowest width (a fish seen head-on keeps its thickness), pitch at
    ' the swap in radians, and rise as a fraction of body height. The duration varies
    ' per fish so neighbours and school members do not turn in lockstep.
    m.turnNarrow = 0.22
    m.turnPitch = 0.14
    m.turnRise = 0.08
    m.turnAnim.duration = 0.75 + ((serial * 37) mod 21) / 100.0
    m.bodyHeight = 0.0
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
    m.rig.rotation = 0.0
    m.rig.translation = [0.0, 0.0]
    m.bodyHeight = rig.layers.body.height
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

' Turns about mirror_center in one Animation, sampled at the fractions of fishTurnKeys():
' scale.x narrows to turnNarrow and widens back with a slight overshoot, scale.y swells a
' little as the fish rolls its bulk toward the viewer, the rig pitches nose-up into the
' turn and comes out nose-down (rotation keeps one sign, so the new art leaves the swap
' tilted the other way), and it rises by turnRise of its height. The art crossfades across
' the narrowest frame: the incoming set fades in under or over the outgoing one, then the
' outgoing one fades, so coverage never dips. Everything rides the same Animation as the
' scale, so the swap lands on the render thread and seeks correctly under ?freeze; a second
' Animation chained from a state observer would land a frame late.
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
    r = m.rig.rotation
    t = m.rig.translation
    if drawn = want then
        ' Reversed before the swap: settle back to rest with the same art.
        fishSetKeys(m.turnInterp, [0.0, 1.0], [[s[0], s[1]], [1.0, 1.0]])
        fishSetKeys(m.turnRoll, [0.0, 1.0], [r, 0.0])
        fishSetKeys(m.turnLift, [0.0, 1.0], [[t[0], t[1]], [0.0, 0.0]])
        fishSetKeys(m.sets[drawn].fade, [0.0, 1.0], [1.0, 1.0])
        fishSetKeys(m.sets[other].fade, [0.0, 1.0], [0.0, 0.0])
    else
        keys = fishTurnKeys()
        pitch = m.turnPitch
        if target > 0 then pitch = -pitch
        lift = -m.turnRise * m.bodyHeight
        scales = []
        rolls = []
        lifts = []
        for i = 0 to keys.count() - 1
            u = keys[i]
            arc = sin(3.14159265 * u)
            scales.push([fishTurnWidth(u), 1.0 + 0.04 * arc])
            rolls.push(pitch * arc)
            lifts.push([0.0, lift * arc])
        end for
        ' A turn that starts mid-way (reversed after the swap) starts from where the rig is.
        scales[0] = [s[0], s[1]]
        rolls[0] = r
        lifts[0] = [t[0], t[1]]
        fishSetKeys(m.turnInterp, keys, scales)
        fishSetKeys(m.turnRoll, keys, rolls)
        fishSetKeys(m.turnLift, keys, lifts)
        fishSetKeys(m.sets[drawn].fade, [0.0, 0.5, 0.53, 1.0], [1.0, 1.0, 0.0, 0.0])
        fishSetKeys(m.sets[other].fade, [0.0, 0.47, 0.5, 1.0], [0.0, 0.0, 1.0, 1.0])
    end if
    m.sets[0].group.visible = true
    m.sets[1].group.visible = true
    m.top.turning = true
    m.turnAnim.control = "start"
end sub

function fishTurnKeys() as object
    return [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
end function

' Width at fraction u: |cos| keeps the narrow phase brief (a V at the swap, eased at the
' ends), floored at turnNarrow, overshooting 1.0 slightly around u 0.9 as the body straightens.
function fishTurnWidth(u as float) as float
    c = cos(3.14159265 * u)
    if c < 0 then c = -c
    w = m.turnNarrow + (1.0 - m.turnNarrow) * c
    if u > 0.5 and u < 1.0 then w = w + 0.08 * sin(3.14159265 * (u - 0.5) * 2.0)
    return w
end function

sub fishSetKeys(interp as object, keys as object, values as object)
    interp.key = keys
    interp.keyValue = values
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
