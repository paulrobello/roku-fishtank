sub init()
    m.fishLayer = m.top.findNode("fishLayer")
    m.timer = m.top.findNode("schoolTimer")
    m.timer.observeField("fire", "onTick")
    m.items = []
end sub

sub onConfigUri()
    if m.items.count() > 0 then return
    text = ReadAsciiFile(m.top.configUri)
    cfg = invalid
    if text <> "" then cfg = ParseJson(text)
    if cfg = invalid then
        print "School ERROR: cannot read config '"; m.top.configUri; "'"
        return
    end if
    ' An unset assocarray field reads as invalid in brs-scenegraph.
    over = m.top.configOverride
    if over <> invalid then
        for each k in over
            cfg[k] = over[k]
        end for
    end if
    rig = ParseJson(ReadAsciiFile("pkg:/config/species/" + cfg.species + ".rig.json"))
    if rig = invalid then
        print "School ERROR: cannot read rig for species '"; cfg.species; "'"
        return
    end if
    m.cfg = cfg
    m.lane = cfg.lane
    m.ellipses = cfg.ellipses
    ' The steering anchor is the rig's mirror centre, so turns pivot on the tracked point.
    m.anchor = rig.mirror_center
    m.speed = schoolPreviewSpeed()

    seed = schoolSeed() + m.top.seedSalt * 1000003
    m.seed = seed
    m.school = schoolNew(cfg, seed, m.lane, m.ellipses)
    if m.school = invalid then
        print "School ERROR: no free spawn for seed "; seed
        return
    end if
    print "SCHOOL seed="; seed; " fish="; cfg.count; " speed="; m.speed

    if not m.global.hasField("schoolSerial") then m.global.addFields({ schoolSerial: 0 })
    m.global.schoolSerial = m.global.schoolSerial + 1
    prefix = "school" + m.global.schoolSerial.toStr() + "_"
    for i = 0 to m.school.members.count() - 1
        m.items.push(schoolBuildFish(prefix, i, m.school.members[i]))
    end for

    freeze = 0.0
    if m.global.hasField("previewFreeze") then freeze = m.global.previewFreeze
    if freeze > 0 then
        schoolPose(Int(freeze * m.speed / cfg.tick))
        return
    end if
    m.clock = CreateObject("roTimespan")
    m.tick = -1
    schoolAdvance(0)
    m.timer.control = "start"
end sub

' One Fish and its reused mover, created once per member. Facing is set before species
' so the spawn does not play a turn. Movers are children of this node so fieldToInterp
' finds the Fish in its subtree.
function schoolBuildFish(prefix as string, i as integer, member as object) as object
    node = m.fishLayer.createChild("Fish")
    node.id = prefix + "fish" + i.toStr()
    node.facing = member.facing
    node.swimSpeed = member.speed
    ' Members turn up to about a third of a second apart, so a reversal ripples
    ' through the school instead of every fish flipping on the same frame.
    node.turnDelay = ((i * 7) mod 9) * 0.045
    node.blinkSeed = m.seed + 7919 * (i + 1)
    node.species = m.cfg.species
    laneStyleFish(node, m.anchor, m.top.fishScale, m.top.fishTint)
    node.translation = schoolToTranslation(member.agent.x, member.agent.y)
    anim = m.top.createChild("Animation")
    anim.id = prefix + "move" + i.toStr()
    anim.repeat = false
    anim.easeFunction = "linear"
    interp = anim.createChild("Vector2DFieldInterpolator")
    interp.id = prefix + "moveInterp" + i.toStr()
    interp.fieldToInterp = [node.id + ".translation"]
    return { member: member, node: node, anim: anim, interp: interp, speed: member.speed }
end function

sub onTick()
    target = Int(m.clock.TotalMilliseconds() * m.speed / 1000.0 / m.cfg.tick)
    if target - m.tick > m.cfg.maxCatchUpTicks then target = m.tick + m.cfg.maxCatchUpTicks
    if target > m.tick then schoolAdvance(target)
end sub

' Runs every school tick up to `target` in order (one sub-step each), then, when a
' segment started on the way, writes every mover once from the sub-step reached at target.
sub schoolAdvance(target as integer)
    cut = false
    for now = m.tick + 1 to target
        if schoolTick(m.school, m.cfg, m.lane, m.ellipses, now) then cut = true
    end for
    m.tick = target
    if cut then
        for each item in m.items
            schoolIssue(item, target)
        end for
    end if
    m.top.holdCount = m.school.holds
    m.top.sceneTime = target * m.cfg.tick
end sub

sub schoolIssue(item as object, now as integer)
    seg = item.member.seg
    offset = now - m.school.segStart
    remain = m.school.segSteps - offset
    if remain < 1 then return
    keys = []
    values = []
    for k = 0 to remain
        keys.push(k / remain)
        p = seg[offset + k]
        values.push(schoolToTranslation(p[0], p[1]))
    end for
    anim = item.anim
    anim.control = "stop"
    item.interp.key = keys
    item.interp.keyValue = values
    anim.duration = remain * m.cfg.tick / m.speed
    anim.control = "start"
    facing = item.member.facing
    if item.node.facing <> facing then item.node.facing = facing
    if item.speed <> item.member.speed then
        item.speed = item.member.speed
        item.node.swimSpeed = item.speed
    end if
end sub

' Preview ?freeze: run the logic to tick `last` at once and pose every member where its
' segment is at that tick, with no mover running, so the frozen frame depends only on
' seed and freeze time.
sub schoolPose(last as integer)
    for now = 0 to last
        schoolTick(m.school, m.cfg, m.lane, m.ellipses, now)
    end for
    f = (last - m.school.segStart) / m.school.segSteps
    for each item in m.items
        p = schoolPolylineAt(item.member.seg, f)
        item.node.translation = schoolToTranslation(p[0], p[1])
        item.node.facing = item.member.facing
        item.node.swimSpeed = item.member.speed
    end for
    m.top.sceneTime = last * m.cfg.tick
    print "SCHOOL posed t="; m.top.sceneTime
end sub

function schoolToTranslation(x as float, y as float) as object
    return [x - m.anchor[0], y - m.anchor[1]]
end function

' ?seed in the preview, otherwise derived from the wall clock.
function schoolSeed() as integer
    if m.global.hasField("previewSeed") and m.global.previewSeed > 0 then return m.global.previewSeed
    now = CreateObject("roDateTime")
    return now.AsSeconds() + now.GetMilliseconds() * 7919
end function

' Scene-time scale: ?speed in the preview, 1 on the device.
function schoolPreviewSpeed() as float
    if m.global.hasField("previewSpeed") and m.global.previewSpeed > 0 then return m.global.previewSpeed
    return 1.0
end function
