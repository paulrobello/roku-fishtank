sub init()
    m.fishLayer = m.top.findNode("fishLayer")
    m.timer = m.top.findNode("brainTimer")
    m.timer.observeField("fire", "onTick")
    m.items = []
end sub

sub onConfigUri()
    if m.items.count() > 0 then return
    text = ReadAsciiFile(m.top.configUri)
    cfg = invalid
    if text <> "" then cfg = ParseJson(text)
    if cfg = invalid then
        print "FishBrain ERROR: cannot read config '"; m.top.configUri; "'"
        return
    end if
    rig = ParseJson(ReadAsciiFile("pkg:/config/species/" + cfg.species + ".rig.json"))
    if rig = invalid then
        print "FishBrain ERROR: cannot read rig for species '"; cfg.species; "'"
        return
    end if
    m.cfg = cfg
    m.lane = cfg.lane
    m.ellipses = cfg.ellipses
    ' The steering anchor is the rig's mirror centre, so turns pivot on the tracked point.
    m.anchor = rig.mirror_center
    m.speed = brainPreviewSpeed()
    m.nodeLogSeconds = cfg.nodeLogSeconds
    m.nextNodeLog = 0.0

    if not m.global.hasField("brainSerial") then m.global.addFields({ brainSerial: 0 })
    m.global.brainSerial = m.global.brainSerial + 1
    prefix = "brain" + m.global.brainSerial.toStr() + "_"
    seed = brainSeed()
    print "BRAIN seed="; seed; " fish="; cfg.count; " speed="; m.speed
    master = prngNew(seed)
    for i = 0 to cfg.count - 1
        state = brainNewFish(cfg, brainFishSeed(master), m.lane, m.ellipses)
        if state = invalid then
            print "FishBrain ERROR: no free spawn point for fish "; i
        else
            m.items.push(brainBuildFish(prefix, i, state))
        end if
    end for

    freeze = 0.0
    if m.global.hasField("previewFreeze") then freeze = m.global.previewFreeze
    if freeze > 0 then
        brainPose(Int(freeze * m.speed / cfg.tick))
        return
    end if
    m.clock = CreateObject("roTimespan")
    m.tick = -1
    brainAdvance(0)
    m.timer.control = "start"
end sub

' One Fish and its reused mover, created once per fish. Facing is set before species so
' the spawn does not play a turn.
function brainBuildFish(prefix as string, i as integer, state as object) as object
    node = m.fishLayer.createChild("Fish")
    node.id = prefix + "fish" + i.toStr()
    node.facing = state.facing
    node.swimSpeed = state.speed
    node.species = m.cfg.species
    node.translation = brainToTranslation(state.agent.x, state.agent.y)
    anim = m.top.createChild("Animation")
    anim.id = prefix + "move" + i.toStr()
    anim.repeat = false
    anim.easeFunction = "linear"
    interp = anim.createChild("Vector2DFieldInterpolator")
    interp.id = prefix + "moveInterp" + i.toStr()
    interp.fieldToInterp = [node.id + ".translation"]
    return { index: i, state: state, node: node, anim: anim, interp: interp, dirty: false, speed: state.speed }
end function

sub onTick()
    target = Int(m.clock.TotalMilliseconds() * m.speed / 1000.0 / m.cfg.tick)
    if target - m.tick > m.cfg.maxCatchUpTicks then target = m.tick + m.cfg.maxCatchUpTicks
    if target > m.tick then brainAdvance(target)
end sub

' Runs every brain tick up to `target` in order, then writes each changed fish's mover
' once, starting at the sub-step reached at `target`.
sub brainAdvance(target as integer)
    for now = m.tick + 1 to target
        for each item in m.items
            kind = brainTickFish(item.state, m.cfg, m.lane, m.ellipses, now)
            if kind <> "" then item.dirty = true
            if kind = "dart" then
                m.top.dartCount = m.top.dartCount + 1
                brainLogDart(item, now)
            end if
        end for
    end for
    m.tick = target
    for each item in m.items
        if item.dirty then brainIssue(item, target)
    end for
    t = target * m.cfg.tick
    m.top.sceneTime = t
    if m.nodeLogSeconds > 0 and t >= m.nextNodeLog then
        print "BRAIN nodes=" + brainCountNodes(brainRoot()).toStr() + " t=" + Int(t).toStr()
        m.nextNodeLog = m.nextNodeLog + m.nodeLogSeconds
    end if
end sub

' Logs a dart with the gap between the drawn Fish and the brain-time start point. The
' brain starts darts from its own clock, not a read-back, so paths stay seed-determined.
sub brainLogDart(item as object, now as integer)
    p = item.state.points[0]
    tr = item.node.translation
    dx = tr[0] + m.anchor[0] - p[0]
    dy = tr[1] + m.anchor[1] - p[1]
    gap = Int(Sqr(dx * dx + dy * dy) * 10 + 0.5) / 10.0
    last = item.state.points[item.state.points.count() - 1]
    at = " from=" + Int(p[0]).toStr() + "," + Int(p[1]).toStr() + " to=" + Int(last[0]).toStr() + "," + Int(last[1]).toStr()
    print "BRAIN dart fish=" + item.index.toStr() + " t=" + Str(now * m.cfg.tick).trim() + " gap=" + Str(gap).trim() + at
end sub

sub brainIssue(item as object, now as integer)
    item.dirty = false
    st = item.state
    offset = now - st.startTick
    remain = st.steps - offset
    keys = []
    values = []
    for k = 0 to remain
        keys.push(k / remain)
        p = st.points[offset + k]
        values.push(brainToTranslation(p[0], p[1]))
    end for
    ease = "linear"
    if st.dart and offset = 0 then ease = m.cfg.dartEase
    anim = item.anim
    anim.control = "stop"
    item.interp.key = keys
    item.interp.keyValue = values
    anim.duration = remain * m.cfg.tick / m.speed
    anim.easeFunction = ease
    anim.control = "start"
    if item.node.facing <> st.facing then item.node.facing = st.facing
    if item.speed <> st.speed then
        item.speed = st.speed
        item.node.swimSpeed = st.speed
    end if
end sub

' Preview ?freeze: run the logic to tick `last` at once and pose every fish where its
' segment is at that tick, with no mover running, so the frozen frame depends only on
' seed and freeze time.
sub brainPose(last as integer)
    for now = 0 to last
        for each item in m.items
            brainTickFish(item.state, m.cfg, m.lane, m.ellipses, now)
        end for
    end for
    for each item in m.items
        st = item.state
        f = (last - st.startTick) / st.steps
        if st.dart then f = brainOutCubic(f)
        p = brainPolylineAt(st.points, f)
        item.node.translation = brainToTranslation(p[0], p[1])
        item.node.facing = st.facing
        item.node.swimSpeed = st.speed
    end for
    m.top.sceneTime = last * m.cfg.tick
    print "BRAIN posed t="; m.top.sceneTime
end sub

function brainToTranslation(x as float, y as float) as object
    return [x - m.anchor[0], y - m.anchor[1]]
end function

' A non-zero per-fish seed drawn from the master PRNG.
function brainFishSeed(master as object) as integer
    s = prngNextU32(master)
    if s = 0 then s = 1
    return s
end function

' ?seed in the preview, otherwise derived from the wall clock.
function brainSeed() as integer
    if m.global.hasField("previewSeed") and m.global.previewSeed > 0 then return m.global.previewSeed
    now = CreateObject("roDateTime")
    return now.AsSeconds() + now.GetMilliseconds() * 7919
end function

' Scene-time scale: ?speed in the preview, 1 on the device.
function brainPreviewSpeed() as float
    if m.global.hasField("previewSpeed") and m.global.previewSpeed > 0 then return m.global.previewSpeed
    return 1.0
end function

function brainRoot() as object
    node = m.top
    while node.getParent() <> invalid
        node = node.getParent()
    end while
    return node
end function

function brainCountNodes(node as object) as integer
    n = 1
    for i = 0 to node.getChildCount() - 1
        n = n + brainCountNodes(node.getChild(i))
    end for
    return n
end function
