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
    reefTankAddArch()
    m.top.findNode("night").callFunc("nightStart", { camera: camera, fill: fill, scene: m.sceneCfg })
    reefTankAddExtras()
    reefTankPerf()
end sub

' Device perf runs (docs/perf.md "Measuring the channel"): pkg:/config/perf.json is an
' inert {} in the shipped channel and holds the run's settings only in a perf build. fpsLog prints the rendered frames
' of each second to the 8087 console; forceMode ("day" or "night") overrides the setting;
' toggleSec flips the forced mode every toggleSec seconds, to measure the crossfade;
' ablate (array of layer ids, "@night" for every night* overlay) with ablateSec hides one
' target at a time, each for ablateSec seconds after a baseline segment, and tags the PERF
' lines with cut=<id>, to find what the frame rate costs. A target starting with "+" is
' cumulative (it stays hidden for the rest of the run), "#anim" pauses every Animation
' under the camera, "$Subtype" hides every node of that SceneGraph subtype (Seaweed, Bubbles,
' FishBrain, School, ...), "~prefix" hides every node whose id starts with prefix, and
' "#anim:Subtype" pauses only the Animations under nodes of that subtype ("#anim:~prefix"
' by id prefix). "!rmstopped" detaches every Animation that is not running, "!white:$Subtype" and
' "!flat:$Subtype" strip the tint or the scale and rotation of those nodes (all one-way).
sub reefTankPerf()
    ' roFileSystem cannot be created on the render thread, so the file always exists.
    cfg = ParseJson(ReadAsciiFile("pkg:/config/perf.json"))
    if cfg = invalid then return
    if cfg.forceMode <> invalid then m.top.nightMode = cfg.forceMode
    if cfg.toggleSec <> invalid and cfg.toggleSec > 0 then
        flip = m.top.createChild("Timer")
        flip.duration = cfg.toggleSec
        flip.repeat = true
        flip.observeField("fire", "onPerfFlip")
        flip.control = "start"
    end if
    m.perfLabel = "none"
    if cfg.nodeReport = true then perfNodeReport()
    if cfg.ablate <> invalid and cfg.ablateSec <> invalid and cfg.ablateSec > 0 then
        m.ablateList = cfg.ablate
        m.ablateIdx = -1
        cut = m.top.createChild("Timer")
        cut.duration = cfg.ablateSec
        cut.repeat = true
        cut.observeField("fire", "onPerfAblate")
        cut.control = "start"
    end if
    if cfg.fpsLog <> true then return
    ' One interpolator changes ticker.opacity every rendered frame; each change is a frame.
    ticker = m.top.createChild("Rectangle")
    ticker.id = "perfTicker"
    ticker.width = 1
    ticker.height = 1
    ticker.color = &h00000000
    ticker.observeField("opacity", "onPerfFrame")
    anim = m.top.createChild("Animation")
    anim.duration = 1.0
    anim.repeat = true
    anim.easeFunction = "linear"
    interp = anim.createChild("FloatFieldInterpolator")
    interp.fieldToInterp = ["perfTicker.opacity"]
    interp.key = [0.0, 1.0]
    interp.keyValue = [0.0, 1.0]
    anim.control = "start"
    m.perfFrames = 0
    m.perfSeconds = 0
    timer = m.top.createChild("Timer")
    timer.duration = 1.0
    timer.repeat = true
    timer.observeField("fire", "onPerfSecond")
    timer.control = "start"
end sub

' Prints the node count by layer and by SceneGraph subtype (NODES lines), after a short delay
' so the fish and extras are built. Every node counts, including Animations and interpolators.
sub perfNodeReport()
    camera = m.top.findNode("camera")
    total = 0
    for i = 0 to camera.getChildCount() - 1
        layer = camera.getChild(i)
        counts = {}
        n = perfCount(layer, counts)
        total = total + n
        line = "NODES layer=" + layer.id + " total=" + n.toStr()
        for each k in counts
            line = line + " " + k + "=" + counts[k].toStr()
        end for
        print line
    end for
    print "NODES all=" + total.toStr()
end sub

function perfCount(node as object, counts as object) as integer
    t = node.subtype()
    if counts.doesExist(t) then
        counts[t] = counts[t] + 1
    else
        counts[t] = 1
    end if
    n = 1
    for i = 0 to node.getChildCount() - 1
        n = n + perfCount(node.getChild(i), counts)
    end for
    return n
end function

sub perfSetCut(target as string, visible as boolean)
    camera = m.top.findNode("camera")
    if Left(target, 1) = "!" and visible then return
    if target = "!rmstopped" then
        ' One-way test: detach every Animation that is not running, to see what idle nodes cost.
        victims = []
        perfCollectIdle(camera, victims)
        for each v in victims
            v.getParent().removeChild(v)
        end for
        print "PERF removed="; victims.count()
    else if Left(target, 7) = "!white:" or Left(target, 6) = "!flat:" then
        ' One-way: every Fish of the subtype loses its tint (white) or its scale and rotation (flat).
        perfFishStyle(camera, Mid(target, InStr(1, target, ":") + 1), Left(target, 6) = "!flat:")
    else if target = "#anim" then
        perfPauseAnims(camera, visible)
    else if Left(target, 6) = "#anim:" then
        perfEach(camera, Mid(target, 7), "pause", visible)
    else if Left(target, 1) = "$" or Left(target, 1) = "~" then
        perfEach(camera, target, "hide", visible)
    else if Left(target, 1) = "@" then
        for i = 0 to camera.getChildCount() - 1
            layer = camera.getChild(i)
            for j = 0 to layer.getChildCount() - 1
                if Left(layer.getChild(j).id, 5) = "night" then layer.getChild(j).visible = visible
            end for
        end for
    else
        node = camera.findNode(target)
        if node <> invalid then node.visible = visible
    end if
end sub

' Applies action ("hide" sets visible, "pause" pauses or resumes the Animations below) to
' every node matching spec ("$Subtype" or "~idprefix") under node. A match is not descended into.
sub perfEach(node as object, spec as string, action as string, on as boolean)
    for i = 0 to node.getChildCount() - 1
        child = node.getChild(i)
        hit = false
        if Left(spec, 1) = "$" and child.subtype() = Mid(spec, 2) then hit = true
        if Left(spec, 1) = "~" and Left(child.id, Len(spec) - 1) = Mid(spec, 2) then hit = true
        if hit then
            if action = "hide" then
                child.visible = on
            else
                perfPauseAnims(child, on)
            end if
        else
            perfEach(child, spec, action, on)
        end if
    end for
end sub

sub perfFishStyle(node as object, spec as string, flat as boolean)
    for i = 0 to node.getChildCount() - 1
        child = node.getChild(i)
        if "$" + child.subtype() = spec then
            if flat then
                child.scale = [1.0, 1.0]
                child.rotation = 0.0
            else
                perfWhite(child)
            end if
        else
            perfFishStyle(child, spec, flat)
        end if
    end for
end sub

sub perfWhite(node as object)
    if node.subtype() = "Poster" then node.blendColor = &hFFFFFFFF
    for i = 0 to node.getChildCount() - 1
        perfWhite(node.getChild(i))
    end for
end sub

sub perfCollectIdle(node as object, out as object)
    for i = 0 to node.getChildCount() - 1
        child = node.getChild(i)
        if child.subtype() = "Animation" and child.state <> "running" then
            out.push(child)
        else
            perfCollectIdle(child, out)
        end if
    end for
end sub

sub perfPauseAnims(node as object, playing as boolean)
    if node.subtype() = "Animation" then
        if playing then
            node.control = "resume"
        else
            node.control = "pause"
        end if
    end if
    for i = 0 to node.getChildCount() - 1
        perfPauseAnims(node.getChild(i), playing)
    end for
end sub

' Each tick restores the previous cut and applies the next; past the last, back to baseline.
sub onPerfAblate()
    if m.ablateIdx >= 0 and m.ablateIdx < m.ablateList.count() then
        prev = m.ablateList[m.ablateIdx]
        if Left(prev, 1) <> "+" then perfSetCut(prev, true)
    end if
    m.ablateIdx = m.ablateIdx + 1
    if m.ablateIdx < m.ablateList.count() then
        m.perfLabel = m.ablateList[m.ablateIdx]
        cutId = m.perfLabel
        if Left(cutId, 1) = "+" then cutId = Mid(cutId, 2)
        perfSetCut(cutId, false)
    else
        m.perfLabel = "none"
    end if
    print "PERF cut="; m.perfLabel
end sub

sub onPerfFlip()
    if m.top.nightMode = "night" then
        m.top.nightMode = "day"
    else
        m.top.nightMode = "night"
    end if
    print "PERF flip mode="; m.top.nightMode
end sub

sub onPerfFrame()
    m.perfFrames = m.perfFrames + 1
end sub

sub onPerfSecond()
    m.perfSeconds = m.perfSeconds + 1
    print "PERF t="; m.perfSeconds; " fps="; m.perfFrames; " mode="; m.top.nightMode; " blend="; m.top.nightBlend; " cut="; m.perfLabel
    m.perfFrames = 0
end sub

' P4 reef extras (components/Extras, config/extras.json). Built after the fish, so the
' anemone tentacles land after the front lane's FishBrain. reefExtras.nightLevel
' (0 day .. 1 night) dims the caustics and ripple; the night phase owner sets it.
sub reefTankAddExtras()
    extras = m.top.createChild("Extras")
    extras.id = "reefExtras"
    extras.configUri = "pkg:/config/extras.json"
end sub

' Arch swimmer (components/Arch, config/arch.json). After the tank fish, so their creation
' serials are unchanged, and before Night, which tints the layer's Posters at start.
sub reefTankAddArch()
    arch = m.top.createChild("ArchSwimmer")
    arch.id = "archSwimmer"
    arch.configUri = "pkg:/config/arch.json"
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
    ' The night-only flashlight fish go last, so every day fish keeps its seed and
    ' creation serial (Fish turn timing) whatever the night group holds.
    nightCount = 0
    if plan.nightSchool <> invalid then
        lane = plan.nightSchool.lane
        school = camera.findNode(lane.id).createChild("School")
        school.id = lane.id + "NightSchool"
        school.seedSalt = salt + 1
        school.fishScale = lane.scale
        school.fishTint = lane.tint
        school.configOverride = { lane: sceneCfgLaneRect(lane), ellipses: pop.ellipses, count: plan.nightSchool.count }
        school.configUri = pop.nightSchoolUri
        m.tankNodes.push(school)
        nightCount = plan.nightSchool.count
    end if
    print "REEFTANK fish density="; sceneCfgDensityName(cfg, name); " fish="; total; " school="; schoolCount; " night="; nightCount; " brains="; plan.lanes.count()
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

' Preview only: a click on the page sends OK, which flips between day and night. On a
' device any key exits the screensaver before the scene sees it.
function onKeyEvent(key as string, press as boolean) as boolean
    if not press or key <> "OK" or not m.global.hasField("previewNight") then return false
    if m.top.isNight then
        m.top.nightMode = "day"
    else
        m.top.nightMode = "night"
    end if
    return true
end function
