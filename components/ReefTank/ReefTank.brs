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
