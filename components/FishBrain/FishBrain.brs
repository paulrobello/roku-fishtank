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
    beh = invalid
    if m.top.behaviorUri <> "" then
        beh = ParseJson(ReadAsciiFile(m.top.behaviorUri))
        if beh = invalid then print "FishBrain ERROR: cannot read behaviour config '"; m.top.behaviorUri; "'"
    end if
    ' An unset assocarray field reads as invalid in brs-scenegraph.
    over = m.top.configOverride
    if over <> invalid then cfg = brainMerge(cfg, over)
    over = m.top.behaviorOverride
    if beh <> invalid and over <> invalid then beh = brainMerge(beh, over)
    m.cfg = cfg
    m.world = brainNewWorld(cfg, beh)
    m.speed = brainPreviewSpeed()
    m.nodeLogSeconds = cfg.nodeLogSeconds
    m.nextNodeLog = 0.0
    m.rigs = {}

    if not m.global.hasField("brainSerial") then m.global.addFields({ brainSerial: 0 })
    m.global.brainSerial = m.global.brainSerial + 1
    prefix = "brain" + m.global.brainSerial.toStr() + "_"
    seed = brainSeed() + m.top.seedSalt * 1000003
    spawned = brainSpawnAll(cfg, beh, m.world, seed)
    brainAttachHosts(spawned)
    print "BRAIN seed="; seed; " fish="; spawned.count(); " speed="; m.speed
    for i = 0 to spawned.count() - 1
        s = spawned[i]
        ' The steering anchor is the rig's mirror centre, so turns pivot on the tracked point.
        rig = brainRig(s.species)
        if s.state = invalid then
            print "FishBrain ERROR: no free spawn point for fish "; i
        else if rig = invalid then
            print "FishBrain ERROR: cannot read rig for species '"; s.species; "'"
        else
            weaveAttach(s.state, m.world, s.species, rig.bounds, rig.mirror_center, seed + 7919 * (i + 1))
            m.items.push(brainBuildFish(prefix, i, s.species, rig.mirror_center, s.state))
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

' P4.1 anemone hosting: config/extras.json anemone.host names a lane and species;
' those fish in this brain's lane start nestling at the anemone (components/lib/host.brs).
sub brainAttachHosts(spawned as object)
    parent = m.top.getParent()
    if parent = invalid then return
    extras = ParseJson(ReadAsciiFile("pkg:/config/extras.json"))
    if extras = invalid or extras.anemone = invalid then return
    for each s in spawned
        host = hostFor(extras.anemone.host, parent.id, s.species)
        if host <> invalid and s.state <> invalid then hostAttach(s.state, host, m.world, m.cfg)
    end for
end sub

' One Fish and its reused mover, created once per fish inside a holder Group. Facing is
' set before species so the spawn does not play a turn. An interpolator finds its target
' in the subtree of its Animation's parent, so the mover lives in the holder with the Fish
' and both move together when a weaving fish (P2.4) changes lane Group.
function brainBuildFish(prefix as string, i as integer, species as string, anchor as object, state as object) as object
    holder = m.fishLayer.createChild("Group")
    holder.id = prefix + "holder" + i.toStr()
    node = holder.createChild("Fish")
    node.id = prefix + "fish" + i.toStr()
    node.facing = state.facing
    node.swimSpeed = state.speed
    node.species = species
    laneStyleFish(node, anchor, m.top.fishScale, m.top.fishTint)
    node.translation = brainToTranslation(anchor, state.agent.x, state.agent.y)
    anim = holder.createChild("Animation")
    anim.id = prefix + "move" + i.toStr()
    anim.repeat = false
    anim.easeFunction = "linear"
    interp = anim.createChild("Vector2DFieldInterpolator")
    interp.id = prefix + "moveInterp" + i.toStr()
    interp.fieldToInterp = [node.id + ".translation"]
    return { index: i, species: species, anchor: anchor, state: state, node: node, holder: holder, anim: anim, interp: interp, dirty: false, speed: state.speed }
end function

' Rig JSON per species, read once.
function brainRig(species as string) as object
    if not m.rigs.doesExist(species) then m.rigs[species] = ParseJson(ReadAsciiFile("pkg:/config/species/" + species + ".rig.json"))
    return m.rigs[species]
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
            kind = brainTickBehavior(item.state, m.cfg, m.world, now)
            if kind <> "" then item.dirty = true
            if item.state.beh <> invalid then
                if item.state.trTo <> "" then brainLogBehavior(item, now)
            end if
            if kind = "dart" then
                m.top.dartCount = m.top.dartCount + 1
                brainLogDart(item, now)
            end if
            if item.state.wv <> invalid then
                if item.state.laneSwitch then brainSwitchLane(item, now)
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
    dx = tr[0] + item.anchor[0] - p[0]
    dy = tr[1] + item.anchor[1] - p[1]
    gap = Int(Sqr(dx * dx + dy * dy) * 10 + 0.5) / 10.0
    last = item.state.points[item.state.points.count() - 1]
    at = " from=" + Int(p[0]).toStr() + "," + Int(p[1]).toStr() + " to=" + Int(last[0]).toStr() + "," + Int(last[1]).toStr()
    print "BRAIN dart fish=" + item.index.toStr() + " t=" + Str(now * m.cfg.tick).trim() + " gap=" + Str(gap).trim() + at
end sub

sub brainLogBehavior(item as object, now as integer)
    st = item.state
    print "BEHAVIOR fish=" + item.index.toStr() + " species=" + item.species + " " + st.trFrom + "->" + st.trTo + " t=" + Str(now * m.cfg.tick).trim()
    st.trFrom = ""
    st.trTo = ""
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
        values.push(brainToTranslation(item.anchor, p[0], p[1]))
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
            brainTickBehavior(item.state, m.cfg, m.world, now)
            if item.state.wv <> invalid then
                ' Only the lane at `last` is drawn; keep the switch flag for the pose below.
                if item.state.laneSwitch then item.switched = true
                item.state.laneSwitch = false
            end if
        end for
    end for
    for each item in m.items
        if item.switched <> invalid then item.state.laneSwitch = true
    end for
    for each item in m.items
        st = item.state
        if st.wv <> invalid then
            if st.laneSwitch then brainSwitchLane(item, last)
        end if
        f = (last - st.startTick) / st.steps
        if st.dart then f = brainOutCubic(f)
        p = brainPolylineAt(st.points, f)
        item.node.translation = brainToTranslation(item.anchor, p[0], p[1])
        item.node.facing = st.facing
        item.node.swimSpeed = st.speed
    end for
    m.top.sceneTime = last * m.cfg.tick
    print "BRAIN posed t="; m.top.sceneTime
end sub

function brainToTranslation(anchor as object, x as float, y as float) as object
    return [x - anchor[0], y - anchor[1]]
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

' P2.4: a weaving fish has switched lane while hidden behind an occluder. Moves its
' holder (Fish and mover) into the new lane's Group and snaps the lane's scale and tint;
' brainIssue restarts the mover from the hold segment.
sub brainSwitchLane(item as object, now as integer)
    st = item.state
    st.laneSwitch = false
    lane = m.world.weave.lanes[st.laneIdx]
    camera = m.top.getParent().getParent()
    group = invalid
    if camera <> invalid then group = camera.findNode(lane.id)
    if group = invalid then
        print "FishBrain ERROR: no lane Group '"; lane.id; "'"
        return
    end if
    item.holder.getParent().removeChild(item.holder)
    group.appendChild(item.holder)
    laneSetStyle(item.node, item.anchor, lane.scale, lane.tint)
    item.dirty = true
    print "WEAVE fish=" + item.index.toStr() + " species=" + item.species + " lane=" + lane.id + " t=" + Str(now * m.cfg.tick).trim()
end sub
