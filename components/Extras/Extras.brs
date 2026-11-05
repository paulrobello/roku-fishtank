sub init()
    m.built = false
    m.caustics = []
    m.ripples = []
end sub

sub onConfigUri()
    if m.built then return
    cfg = ParseJson(ReadAsciiFile(m.top.configUri))
    if cfg = invalid then
        print "EXTRAS ERROR: cannot read config '"; m.top.configUri; "'"
        return
    end if
    m.built = true
    m.cfg = cfg
    if not m.global.hasField("extrasSerial") then m.global.addFields({ extrasSerial: 0 })
    m.global.extrasSerial = m.global.extrasSerial + 1
    m.prefix = "extras" + m.global.extrasSerial.toStr() + "_"
    m.serial = 0
    m.speed = 1.0
    if m.global.hasField("previewSpeed") and m.global.previewSpeed > 0 then m.speed = m.global.previewSpeed
    freeze = 0.0
    if m.global.hasField("previewFreeze") then freeze = m.global.previewFreeze
    previewSeed = 0
    if m.global.hasField("previewSeed") then previewSeed = m.global.previewSeed
    now = CreateObject("roDateTime")
    m.seed = extrasSeed(previewSeed, freeze, now.AsSeconds() + now.GetMilliseconds() * 7919)
    m.scene = m.top.getScene()

    for each c in cfg.chains
        layer = m.scene.findNode(c.layer)
        if layer <> invalid then extrasChain(layer.createChild("Group"), cfg.chainArt[c.art], c)
    end for
    extrasBuildAnemone(cfg.anemone)
    extrasBuildRipple(cfg.ripple)
    extrasBuildCaustics(cfg.caustics)
    ' Night (components/Night) may have started first and only pushes nightLevel on its
    ' next evaluation, so start from the level it already published.
    if m.global.hasField("nightLevel") then m.top.nightLevel = m.global.nightLevel
    onNightLevel()
    ' Likewise ask Night to moonlight-tint the critters and plants just built.
    if m.global.hasField("nightRetint") then m.global.nightRetint = true
    print "EXTRAS ready seed="; m.seed; " chains="; cfg.chains.count(); " tentacles="; cfg.anemone.tentacles.count()
end sub

function extrasId(name as string) as string
    m.serial = m.serial + 1
    return m.prefix + name + m.serial.toStr()
end function

' A repeating linear Animation under holder; its targets must sit under holder too.
function extrasLoop(holder as object, name as string, seconds as float) as object
    anim = holder.createChild("Animation")
    anim.id = extrasId(name)
    anim.repeat = true
    anim.easeFunction = "linear"
    anim.duration = seconds / m.speed
    return anim
end function

sub extrasInterp(anim as object, kind as string, target as object, field as string, keys as object, values as object)
    interp = anim.createChild(kind)
    interp.fieldToInterp = [target.id + "." + field]
    interp.key = keys
    interp.keyValue = values
end sub

' ---- Sway chains (P4.1 tentacles, P4.2 sea fan and soft coral) ----

' Builds chain c (x, y = base pivot, optional phaseDeg and scale) of art under root.
' Segment k's Group sits on segment k-1's attach point and rotates about its own pivot.
sub extrasChain(root as object, art as object, c as object)
    deg = 0.0174533
    cur = m.cfg.current
    root.translation = [c.x, c.y]
    if c.scale <> invalid then root.scale = [c.scale, c.scale]
    period = cur.period * art.periodScale
    anim = extrasLoop(root, "sway", period)
    keys = extrasLoopKeys(cur.keyCount)
    phase0 = extrasCurrentPhase(cur, c.x)
    if c.phaseDeg <> invalid then phase0 = phase0 + c.phaseDeg * deg
    parent = root
    segs = art.segments
    for k = 0 to segs.count() - 1
        s = segs[k]
        seg = parent.createChild("Group")
        seg.id = extrasId("seg")
        if k > 0 then
            prev = segs[k - 1]
            seg.translation = [prev.attach[0] - prev.pivot[0], prev.attach[1] - prev.pivot[1]]
        end if
        seg.scaleRotateCenter = [0, 0]
        poster = seg.createChild("Poster")
        poster.uri = s.uri
        poster.width = s.width
        poster.height = s.height
        poster.translation = [-s.pivot[0], -s.pivot[1]]
        lag = phase0 - 6.2831853 * k * art.lagSec / period
        values = extrasSwayValues(art.amplitudeDeg[k] * deg, lag, cur.keyCount)
        seg.rotation = values[0]
        extrasInterp(anim, "FloatFieldInterpolator", seg, "rotation", keys, values)
        parent = seg
    end for
    anim.control = "start"
end sub

' ---- Anemone and critters (P4.1, P4.3) ----

sub extrasBuildAnemone(an as object)
    lane = m.scene.findNode(an.layer)
    if lane = invalid then return
    back = CreateObject("roSGNode", "Group")
    back.id = extrasId("anemoneBack")
    lane.insertChild(back, 0)
    b = an.body
    body = back.createChild("Poster")
    body.uri = b.uri
    body.width = b.width
    body.height = b.height
    body.translation = [b.x, b.y]
    extrasBuildCritters(back, m.cfg.critters)

    front = lane.createChild("Group")
    front.id = extrasId("anemoneFront")
    m.frontAnims = []
    art = m.cfg.chainArt[an.tentacleArt]
    for each t in an.tentacles
        root = front.createChild("Group")
        extrasChain(root, art, t)
        m.frontAnims.push(root.getChild(0))
    end for
    m.lane = lane
    m.front = front
    timer = m.top.findNode("reorderTimer")
    timer.observeField("fire", "onReorder")
    timer.control = "start"
end sub

' Keeps the tentacles last in the lane, so a FishBrain rebuilt by a density change still
' draws its fish between the anemone body and the tentacles.
sub onReorder()
    n = m.lane.getChildCount()
    if n = 0 or m.lane.getChild(n - 1).isSameNode(m.front) then return
    m.lane.removeChild(m.front)
    m.lane.appendChild(m.front)
    for each anim in m.frontAnims
        anim.control = "start"
    end for
end sub

sub extrasBuildCritters(holder as object, cr as object)
    if cr = invalid then return
    if cr.shrimp <> invalid then
        ' A shrimp with its own layer walks there at layerIndex (default 0), behind the
        ' children drawn after it.
        shrimpHolder = holder
        if cr.shrimp.layer <> invalid then
            lane = m.scene.findNode(cr.shrimp.layer)
            if lane <> invalid then
                shrimpHolder = CreateObject("roSGNode", "Group")
                shrimpHolder.id = extrasId("shrimpLane")
                idx = 0
                if cr.shrimp.layerIndex <> invalid then idx = cr.shrimp.layerIndex
                lane.insertChild(shrimpHolder, idx)
            end if
        end if
        extrasBuildShrimp(shrimpHolder, cr.shrimp)
    end if
    if cr.crab <> invalid then
        ' A crab with its own layer walks there at index layerIndex, on the sand lip and
        ' behind the tufts drawn after it.
        crabHolder = holder
        if cr.crab.layer <> invalid then
            lane = m.scene.findNode(cr.crab.layer)
            if lane <> invalid then
                crabHolder = CreateObject("roSGNode", "Group")
                crabHolder.id = extrasId("crabLane")
                lane.insertChild(crabHolder, cr.crab.layerIndex)
            end if
        end if
        extrasBuildCrab(crabHolder, cr.crab)
    end if
    if cr.starfish <> invalid then
        sf = cr.starfish
        root = extrasWalker(holder, sf.walk, 2)
        star = extrasSprite(root, sf.uri, sf.width, sf.height)
        star.id = extrasId("starfish")
        star.scaleRotateCenter = [sf.width / 2, sf.height / 2]
        anim = extrasLoop(root, "starTurn", sf.rotateSec)
        values = extrasSwayValues(sf.rotateDeg * 0.0174533, 0, 9)
        star.rotation = values[0]
        extrasInterp(anim, "FloatFieldInterpolator", star, "rotation", extrasLoopKeys(9), values)
        anim.control = "start"
    end if
end sub

' The crab walks sideways on its legs: each side's legs rock about their hip with the
' same rotation, which on the mirrored sides lifts one side while the other plants, one swing per stridePx of travel and still while it pauses, with a
' small bob, all keyed on the walk Animation. The claws sway on their own slow loop.
sub extrasBuildCrab(holder as object, cb as object)
    root = extrasWalker(holder, cb.walk, 1)
    path = m.lastPath
    walkAnim = m.lastAnim
    bob = root.createChild("Group")
    bob.id = extrasId("crabBob")
    L = cb.layers
    toRad = 0.0174533
    for each leg in [{ uri: L.legsL, pivot: cb.legPivotL, side: 1.0 }, { uri: L.legsR, pivot: cb.legPivotR, side: 1.0 }]
        p = extrasSprite(bob, leg.uri, cb.width, cb.height)
        p.id = extrasId("crabLegs")
        p.scaleRotateCenter = leg.pivot
        g = extrasGait(path, cb.stridePx, cb.legDeg * toRad, leg.side)
        extrasInterp(walkAnim, "FloatFieldInterpolator", p, "rotation", g.keys, g.values)
    end for
    extrasSprite(bob, L.body, cb.width, cb.height)
    g = extrasGait(path, cb.stridePx / 2, cb.bobPx, 1.0)
    lift = []
    for each v in g.values
        lift.push([0, -Abs(v)])
    end for
    extrasInterp(walkAnim, "Vector2DFieldInterpolator", bob, "translation", g.keys, lift)
    sway = extrasLoop(root, "crabClaws", cb.clawSec)
    keys = extrasLoopKeys(9)
    for each claw in [{ uri: L.clawL, pivot: cb.clawPivotL, side: 1.0, phase: 0.0 }, { uri: L.clawR, pivot: cb.clawPivotR, side: -1.0, phase: 1.3 }]
        p = extrasSprite(bob, claw.uri, cb.width, cb.height)
        p.id = extrasId("crabClaw")
        p.scaleRotateCenter = claw.pivot
        values = []
        for each v in extrasSwayValues(cb.clawDeg * toRad, claw.phase, 9)
            values.push(claw.side * v)
        end for
        p.rotation = values[0]
        extrasInterp(sway, "FloatFieldInterpolator", p, "rotation", keys, values)
    end for
    sway.control = "start"
end sub

function extrasSprite(parent as object, uri as string, w as integer, h as integer) as object
    p = parent.createChild("Poster")
    p.uri = uri
    p.width = w
    p.height = h
    return p
end function

' A Group walking the seeded loop of walk under holder; salt separates the critters.
function extrasWalker(holder as object, walk as object, salt as integer) as object
    root = holder.createChild("Group")
    root.id = extrasId("walker")
    path = extrasWalkPath(walk, m.seed + salt * 7919)
    root.translation = path.points[0]
    anim = extrasLoop(holder, "walk", path.duration)
    extrasInterp(anim, "Vector2DFieldInterpolator", root, "translation", path.keys, path.points)
    anim.control = "start"
    m.lastPath = path
    m.lastAnim = anim
    return root
end function

' The shrimp walks on two leg sets rocking in opposite phase (keyed on the walk, still
' while it pauses), paddles its swimmerets, wiggles its antennae, and turns like a fish:
' a turn Group narrows about its centre while the right and left art swap.
sub extrasBuildShrimp(holder as object, sh as object)
    root = extrasWalker(holder, sh.walk, 0)
    path = m.lastPath
    walkAnim = m.lastAnim
    turn = root.createChild("Group")
    turn.id = extrasId("shrimpTurn")
    turn.scaleRotateCenter = [sh.width / 2, sh.height / 2]
    track = extrasTurnTrack(path, sh.turnNarrow)
    extrasInterp(walkAnim, "Vector2DFieldInterpolator", turn, "scale", track.keys, track.scale)
    wiggle = extrasLoop(root, "antennae", sh.antennaSec)
    paddle = extrasLoop(root, "swimmerets", sh.swimSec)
    wkeys = extrasLoopKeys(9)
    wvalues = extrasSwayValues(sh.antennaDeg * 0.0174533, 0, 9)
    toRad = 0.0174533
    for each side in [{ art: sh.right, facing: 1, opacity: track.right }, { art: sh.left, facing: -1, opacity: track.left }]
        g = turn.createChild("Group")
        g.id = extrasId("shrimpFace")
        a = side.art
        mirror = side.facing * 1.0
        for each leg in [{ uri: a.legsRear, pivot: a.legsRearPivot, phase: 1.0 }, { uri: a.legsFront, pivot: a.legsFrontPivot, phase: -1.0 }]
            p = extrasSprite(g, leg.uri, sh.width, sh.height)
            p.id = extrasId("shrimpLegs")
            p.scaleRotateCenter = leg.pivot
            gait = extrasGait(path, sh.stridePx, sh.legDeg * toRad, leg.phase * mirror)
            extrasInterp(walkAnim, "FloatFieldInterpolator", p, "rotation", gait.keys, gait.values)
        end for
        swim = extrasSprite(g, a.swim, sh.width, sh.height)
        swim.id = extrasId("shrimpSwim")
        swim.scaleRotateCenter = a.swimPivot
        svalues = []
        for each v in extrasSwayValues(sh.swimDeg * toRad, 0, 9)
            svalues.push(mirror * v)
        end for
        swim.rotation = svalues[0]
        extrasInterp(paddle, "FloatFieldInterpolator", swim, "rotation", wkeys, svalues)
        extrasSprite(g, a.body, sh.width, sh.height)
        ant = extrasSprite(g, a.antennae, sh.width, sh.height)
        ant.id = extrasId("antennae")
        ant.scaleRotateCenter = a.pivot
        ant.rotation = wvalues[0]
        extrasInterp(wiggle, "FloatFieldInterpolator", ant, "rotation", wkeys, wvalues)
        ' The facing interpolator lives on the walk Animation, so turns stay in step with the path.
        g.opacity = side.opacity[0]
        extrasInterp(walkAnim, "FloatFieldInterpolator", g, "opacity", track.keys, side.opacity)
    end for
    wiggle.control = "start"
    paddle.control = "start"
end sub

' ---- Ripple (P4.4) and caustics (P4.5) ----

sub extrasBuildRipple(r as object)
    if r = invalid then return
    layer = m.scene.findNode(r.layer)
    if layer = invalid then return
    holder = layer.createChild("Group")
    bob = holder.createChild("Group")
    bob.id = extrasId("rippleBob")
    scroll = bob.createChild("Group")
    scroll.id = extrasId("rippleScroll")
    for i = 0 to r.copies - 1
        p = extrasSprite(scroll, r.uri, r.width, r.height)
        p.translation = [r.x0 + i * r.width, r.y]
        m.ripples.push(p)
    end for
    anim = extrasLoop(holder, "rippleScroll", r.periodSec)
    extrasInterp(anim, "Vector2DFieldInterpolator", scroll, "translation", [0.0, 1.0], [[0, 0], [-r.width, 0]])
    anim.control = "start"
    bobAnim = extrasLoop(holder, "rippleBob", r.bobSec)
    values = []
    for each v in extrasSwayValues(r.bobPx, 0, 9)
        values.push([0, v])
    end for
    bob.translation = values[0]
    extrasInterp(bobAnim, "Vector2DFieldInterpolator", bob, "translation", extrasLoopKeys(9), values)
    bobAnim.control = "start"
end sub

sub extrasBuildCaustics(c as object)
    if c = invalid then return
    layer = m.scene.findNode(c.layer)
    if layer = invalid then return
    clip = CreateObject("roSGNode", "Group")
    if c.layerIndex <> invalid then
        layer.insertChild(clip, c.layerIndex)
    else
        layer.appendChild(clip)
    end if
    clip.id = extrasId("caustics")
    clip.clippingRect = [c.clip.x, c.clip.y, c.clip.width, c.clip.height]
    for each t in c.tiles
        scroll = clip.createChild("Group")
        scroll.id = extrasId("causticScroll")
        for each o in extrasTileGrid(c.clip, c.tile, t.dir)
            p = extrasSprite(scroll, t.uri, c.tile, c.tile)
            p.translation = o
        end for
        anim = extrasLoop(clip, "causticScroll", t.periodSec)
        extrasInterp(anim, "Vector2DFieldInterpolator", scroll, "translation", [0.0, 1.0], [[0, 0], [t.dir[0] * c.tile, t.dir[1] * c.tile]])
        anim.control = "start"
        m.caustics.push({ node: scroll, opacity: t.opacity })
    end for
end sub

sub onNightLevel()
    if not m.built then return
    n = m.top.nightLevel
    hideAt = m.cfg.caustics.hideAt
    for each c in m.caustics
        o = extrasNightOpacity(c.opacity, n, hideAt)
        c.node.opacity = o
        c.node.visible = o > 0
    end for
    r = m.cfg.ripple
    if r = invalid then return
    tint = extrasLerpColor(sceneCfgParseColor(r.dayTint), sceneCfgParseColor(r.nightTint), n)
    opacity = r.dayOpacity + (r.nightOpacity - r.dayOpacity) * n
    for each p in m.ripples
        p.blendColor = tint
        p.opacity = opacity
    end for
end sub
