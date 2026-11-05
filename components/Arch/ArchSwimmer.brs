sub init()
    m.built = false
end sub

sub onConfigUri()
    if m.built then return
    cfg = ParseJson(ReadAsciiFile(m.top.configUri))
    if cfg = invalid then
        print "ARCH ERROR: cannot read config '"; m.top.configUri; "'"
        return
    end if
    layer = m.top.getScene().findNode(cfg.layer)
    rig = ParseJson(ReadAsciiFile("pkg:/config/species/" + cfg.species + ".rig.json"))
    if layer = invalid or rig = invalid then
        print "ARCH ERROR: no layer '"; cfg.layer; "' or rig for '"; cfg.species; "'"
        return
    end if
    m.built = true
    m.freeze = 0.0
    speed = 1.0
    if m.global.hasField("previewSpeed") and m.global.previewSpeed > 0 then speed = m.global.previewSpeed
    freeze = 0.0
    if m.global.hasField("previewFreeze") then freeze = m.global.previewFreeze
    m.freeze = freeze
    previewSeed = 0
    if m.global.hasField("previewSeed") then previewSeed = m.global.previewSeed
    now = CreateObject("roDateTime")
    seed = archSeed(previewSeed, freeze, now.AsSeconds() + now.GetMilliseconds() * 7919)
    plan = archPlan(cfg, prngNew(seed))

    root = layer.createChild("Group")
    root.id = "archSwim"
    c = archClip(cfg)
    clip = root.createChild("Group")
    clip.id = "archClip"
    clip.clippingRect = [c.x, c.y, c.width, c.height]
    anim = root.createChild("Animation")
    anim.id = "archSwimAnim"
    anim.repeat = true
    anim.easeFunction = "linear"
    anim.duration = plan.duration / speed
    anchor = rig.mirror_center
    tint = sceneCfgParseColor(cfg.tint)
    facings = [1, -1]
    for i = 0 to 1
        track = plan.tracks[i]
        fish = clip.createChild("Fish")
        fish.id = "archFish" + i.toStr()
        fish.facing = facings[i]
        fish.swimSpeed = cfg.swimSpeed
        fish.species = cfg.species
        laneStyleFish(fish, anchor, cfg.scale, tint)
        moves = archTranslations(track.points, anchor)
        fish.translation = moves[0]
        fish.rotation = track.rots[0]
        archInterp(anim, "Vector2DFieldInterpolator", fish.id + ".translation", track.keys, moves)
        archInterp(anim, "FloatFieldInterpolator", fish.id + ".rotation", track.keys, track.rots)
    end for
    o = cfg.overlay
    overlay = root.createChild("Poster")
    overlay.id = "archOverlay"
    overlay.uri = o.uri
    overlay.width = o.width
    overlay.height = o.height
    overlay.translation = [o.x, o.y]
    anim.control = "start"
    m.root = root
    m.anim = anim
    m.running = true
    m.fish = [clip.findNode("archFish0"), clip.findNode("archFish1")]
    if m.global.hasField("nightLevel") then m.top.nightLevel = m.global.nightLevel
    onNightLevel()
    print "ARCH ready seed="; seed; " passages="; plan.passages.count(); " loop="; plan.duration; " first="; plan.passages[0].start
end sub

sub archInterp(anim as object, kind as string, target as string, keys as object, values as object)
    interp = anim.createChild(kind)
    interp.fieldToInterp = [target]
    interp.key = keys
    interp.keyValue = values
end sub

' Fades with the night level and, once fully night, stops: a hidden group keeps its
' Animations running, and the arch is not worth its frame time in the dark. Under
' ?freeze nothing runs, so only the fade is applied.
sub onNightLevel()
    if not m.built or m.root = invalid then return
    n = m.top.nightLevel
    m.root.opacity = 1.0 - n
    m.root.visible = n < 1.0
    if m.freeze > 0 then return
    shouldRun = n < 1.0
    if m.running <> shouldRun then
        m.running = shouldRun
        if shouldRun then
            m.anim.control = "resume"
        else
            m.anim.control = "pause"
        end if
        for each f in m.fish
            f.paused = not shouldRun
        end for
    end if
end sub
