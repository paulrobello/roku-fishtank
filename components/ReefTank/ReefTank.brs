sub init()
    ' Stored settings (P5.3) first; the preview ?density= param still wins in reefTankInitFish.
    settingsApplyToScene(m.top, settingsRegistryStore())
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
    if m.global.hasField("previewDebug") and m.global.previewDebug > 0 then reefTankDebugOverlay(camera)
    reefTankBuildDrift()
    print "REEFTANK ready: "; dr.width; "x"; dr.height; " layers="; m.sceneCfg.layers.count(); " decor="; decor.count()
    reefTankInitFish()
    m.top.findNode("night").callFunc("nightStart", { camera: camera, fill: fill, scene: m.sceneCfg })
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
        behOver = { population: entry.groups, caves: pop.caves, rocks: pop.rocks, band: pop.band }
        weave = sceneCfgWeavePlan(cfg, lane.id)
        if weave <> invalid then behOver.weave = weave
        brain.behaviorOverride = behOver
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

' Preview ?debug=1 (P1.8): translucent boxes over the occlusion data, drawn last in the
' Group they belong to so they drift with it. Occluders (red) go in their decor layer,
' the avoidance ellipses (yellow, as horizontal slices) and the mandarin band (green)
' in the back lane, whose rect the brains share in design pixels.
sub reefTankDebugOverlay(camera as object)
    pop = m.sceneCfg.population
    if pop = invalid then return
    if sceneCfgIsObject(pop.occluders) then
        for each layer in m.sceneCfg.layers
            rects = pop.occluders[layer.id]
            if rects <> invalid then
                for each r in rects
                    reefTankDebugRect(camera.findNode(layer.id), r.left, r.top, r.right - r.left, r.bottom - r.top, &hFF303070)
                end for
            end if
        end for
    end if
    host = camera.findNode("backLane")
    if host = invalid then return
    for each e in pop.ellipses
        n = 8
        for k = 0 to n - 1
            yc = -1 + (k + 0.5) * 2 / n
            hw = e.rx * Sqr(1 - yc * yc)
            reefTankDebugRect(host, e.cx - hw, e.cy - e.ry + k * 2 * e.ry / n, 2 * hw, 2 * e.ry / n, &hFFE03060)
        end for
    end for
    b = pop.band
    reefTankDebugRect(host, b.left, b.top, b.right - b.left, b.bottom - b.top, &h30FF3070)
end sub

sub reefTankDebugRect(parent as object, x as float, y as float, w as float, h as float, color as integer)
    if parent = invalid then return
    r = parent.createChild("Rectangle")
    r.translation = [x, y]
    r.width = w
    r.height = h
    r.color = color
end sub
