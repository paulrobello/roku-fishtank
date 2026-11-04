sub init()
    dr = m.top.currentDesignResolution
    fill = m.top.findNode("fill")
    fill.width = dr.width
    fill.height = dr.height

    m.sceneCfg = reefTankLoadConfig("pkg:/config/scene.json")
    if m.sceneCfg = invalid then return
    fill.color = sceneCfgParseColor(m.sceneCfg.backgroundColor, fill.color)

    ' scene.json is authored at the 1920x1080 design size; the hd UI resolution scales it down.
    camera = m.top.findNode("camera")
    s = sceneCfgDesignScale(m.sceneCfg, dr.width)
    camera.scale = [s, s]

    for each layer in m.sceneCfg.layers
        group = camera.createChild("Group")
        group.id = layer.id
    end for
    decor = m.sceneCfg.decor
    if decor = invalid then decor = []
    for each d in decor
        poster = camera.findNode(d.layer).createChild("Poster")
        poster.id = d.id
        poster.uri = d.uri
        poster.width = d.width
        poster.height = d.height
        poster.translation = [d.x, d.y]
    end for
    reefTankAddAmbient(camera)
    reefTankBuildDrift()
    print "REEFTANK ready: "; dr.width; "x"; dr.height; " layers="; m.sceneCfg.layers.count(); " decor="; decor.count()
    reefTankInitFish()
end sub

' ---------------------------------------------------------------------------
' Fish population (P2.7): one FishBrain per lane with fish and the chromis School,
' all built from scene.json "population" for the selected density.

sub reefTankInitFish()
    m.tankNodes = []
    m.tankDensity = ""
    if m.sceneCfg.population = invalid then return
    name = m.top.density
    if m.global.hasField("previewDensity") and m.global.previewDensity <> "" then name = m.global.previewDensity
    reefTankBuildFish(name)
    if m.top.density <> name then m.top.density = name
end sub

sub onDensityChanged()
    if m.tankNodes = invalid then return
    if m.top.density <> m.tankDensity then reefTankBuildFish(m.top.density)
end sub

sub reefTankBuildFish(name as string)
    ' A removed brain or school would keep its timer ticking, so stop it first.
    for each node in m.tankNodes
        for each timerId in ["brainTimer", "schoolTimer"]
            timer = node.findNode(timerId)
            if timer <> invalid then timer.control = "stop"
        end for
        node.getParent().removeChild(node)
    end for
    m.tankNodes = []
    m.tankDensity = name
    cfg = m.sceneCfg
    pop = cfg.population
    camera = m.top.findNode("camera")
    plan = sceneCfgDensityPlan(cfg, name)
    salt = 0
    total = 0
    for each entry in plan.lanes
        lane = entry.lane
        brain = camera.findNode(lane.id).createChild("FishBrain")
        brain.id = lane.id + "Brain"
        brain.seedSalt = salt
        brain.fishScale = lane.scale
        brain.fishTint = lane.tint
        brain.configOverride = { lane: sceneCfgLaneRect(lane), ellipses: pop.ellipses }
        brain.behaviorOverride = { population: entry.groups, caves: pop.caves, rocks: pop.rocks, band: pop.band }
        brain.behaviorUri = pop.behaviorUri
        brain.configUri = pop.brainUri
        m.tankNodes.push(brain)
        salt = salt + 1
        for each g in entry.groups
            total = total + g.count
        end for
    end for
    schoolCount = 0
    if plan.school <> invalid then
        lane = plan.school.lane
        school = camera.findNode(lane.id).createChild("School")
        school.id = lane.id + "School"
        school.seedSalt = salt
        school.fishScale = lane.scale
        school.fishTint = lane.tint
        school.configOverride = { lane: sceneCfgLaneRect(lane), ellipses: pop.ellipses, count: plan.school.count }
        school.configUri = pop.schoolUri
        m.tankNodes.push(school)
        schoolCount = plan.school.count
    end if
    print "REEFTANK fish density="; sceneCfgDensityName(cfg, name); " fish="; total; " school="; schoolCount; " brains="; plan.lanes.count()
end sub

' ---- Camera drift (P1.2) ----

' One looping Animation moves every layer Group with parallax > 0 along the shared drift path,
' scaled by its parallax. Skipped when scene.json has no drift block. The `drift` field
' (default true, and scene.json drift.enabled must also be true) starts and stops it.
sub reefTankBuildDrift()
    drift = m.sceneCfg.drift
    if not sceneCfgIsObject(drift) then return
    anim = m.top.createChild("Animation")
    anim.id = "cameraDrift"
    anim.repeat = true
    anim.easeFunction = "linear"
    anim.duration = drift.periodSeconds / reefTankDriftSpeed()
    keys = sceneCfgDriftKeys(drift)
    for each layer in m.sceneCfg.layers
        if layer.parallax > 0 then
            interp = anim.createChild("Vector2DFieldInterpolator")
            interp.fieldToInterp = [layer.id + ".translation"]
            interp.key = keys
            interp.keyValue = sceneCfgDriftValues(drift, layer.parallax)
        end if
    end for
    m.driftAnim = anim
    reefTankApplyDrift()
end sub

' ?speed in the preview speeds the loop; 1 on the device.
function reefTankDriftSpeed() as float
    if m.global.hasField("previewSpeed") and m.global.previewSpeed > 0 then return m.global.previewSpeed
    return 1.0
end function

sub onDriftChange()
    reefTankApplyDrift()
end sub

sub reefTankApplyDrift()
    if m.driftAnim = invalid then return
    if m.top.drift and sceneCfgDriftEnabled(m.sceneCfg) then
        m.driftAnim.control = "start"
    else
        m.driftAnim.control = "stop"
        for each layer in m.sceneCfg.layers
            node = m.top.findNode(layer.id)
            if node <> invalid then node.translation = [0, 0]
        end for
    end if
end sub

' P1.3 bubbles and P1.4 seaweed: own components, configured by the scene.json
' "bubbles" and "seaweed" blocks and placed in their layers.
sub reefTankAddAmbient(camera as object)
    cfg = m.sceneCfg
    if cfg.bubbles <> invalid then
        bubbles = camera.findNode("bubbles").createChild("Bubbles")
        bubbles.id = "bubbleColumn"
        bubbles.config = cfg.bubbles
    end if
    if cfg.seaweed <> invalid then
        for each stalk in cfg.seaweed.stalks
            weed = camera.findNode(stalk.layer).createChild("Seaweed")
            weed.id = stalk.id
            weed.config = { art: cfg.seaweed, stalk: stalk }
        end for
    end if
end sub

' Parsed and validated scene config, or invalid after printing every problem.
function reefTankLoadConfig(uri as string) as dynamic
    cfg = ParseJson(ReadAsciiFile(uri))
    errors = sceneCfgValidate(cfg)
    if errors.count() = 0 then return cfg
    for each e in errors
        print "REEFTANK config error ("; uri; "): "; e
    end for
    return invalid
end function
