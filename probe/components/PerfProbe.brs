' Perf probe: ramps rigged-fish and full-width-layer counts in stages and
' logs measured frames/sec per second to the screensaver console (8087).
' Frame counting: an interpolator changes ticker.opacity every rendered
' frame; each observer callback counts one frame.
sub init()
    dr = m.top.currentDesignResolution
    m.w = dr.width
    m.h = dr.height
    water = m.top.findNode("water")
    water.width = m.w
    water.height = m.h
    m.layerGroup = m.top.findNode("layers")
    m.fishGroup = m.top.findNode("fish")

    ' Layers-only ramp, then fish-only ramp, so fill rate and node count are
    ' measured separately (run 1 changed both at once).
    m.stages = [
        { fish: 0, layers: 0 },
        { fish: 0, layers: 1 },
        { fish: 0, layers: 2 },
        { fish: 0, layers: 3 },
        { fish: 0, layers: 4 },
        { fish: 0, layers: 6 },
        { fish: 0, layers: 8 },
        { fish: 0, layers: 0, clearLayers: true },
        { fish: 20, layers: 0 },
        { fish: 40, layers: 0 },
        { fish: 80, layers: 0 },
        { fish: 140, layers: 0 }
    ]
    m.stageSeconds = 10
    m.stageIndex = -1
    m.secondsInStage = 0
    m.frames = 0
    m.fishCount = 0
    m.layerCount = 0

    ticker = m.top.findNode("ticker")
    ticker.observeField("opacity", "onTick")
    tickAnim = createObject("roSGNode", "Animation")
    tickAnim.duration = 1.0
    tickAnim.repeat = true
    tickAnim.easeFunction = "linear"
    interp = createObject("roSGNode", "FloatFieldInterpolator")
    interp.fieldToInterp = ["ticker.opacity"]
    interp.key = [0.0, 1.0]
    interp.keyValue = [0.02, 0.98]
    tickAnim.appendChild(interp)
    m.top.appendChild(tickAnim)
    tickAnim.control = "start"

    m.clock = createObject("roSGNode", "Timer")
    m.clock.duration = 1.0
    m.clock.repeat = true
    m.clock.observeField("fire", "onSecond")
    m.top.appendChild(m.clock)
    m.clock.control = "start"
    print "PROBE start design="; m.w; "x"; m.h
    advanceStage()
end sub

sub onTick()
    m.frames = m.frames + 1
end sub

sub onSecond()
    print "PROBE stage="; m.stageIndex; " fish="; m.fishCount; " layers="; m.layerCount; " fps="; m.frames
    m.frames = 0
    m.secondsInStage = m.secondsInStage + 1
    if m.secondsInStage >= m.stageSeconds then advanceStage()
end sub

sub advanceStage()
    if m.stageIndex + 1 >= m.stages.count() then
        if m.stageIndex >= 0 then print "PROBE done"
        m.secondsInStage = -100000
        return
    end if
    m.stageIndex = m.stageIndex + 1
    m.secondsInStage = 0
    target = m.stages[m.stageIndex]
    if target.clearLayers = true then
        m.layerGroup.removeChildrenIndex(m.layerGroup.getChildCount(), 0)
        m.layerCount = 0
    end if
    while m.layerCount < target.layers
        addLayer(m.layerCount + 1)
        m.layerCount = m.layerCount + 1
    end while
    while m.fishCount < target.fish
        addFish(m.fishCount)
        m.fishCount = m.fishCount + 1
    end while
    print "PROBE stage_begin="; m.stageIndex; " fish="; m.fishCount; " layers="; m.layerCount
end sub

sub addLayer(n as integer)
    layer = createObject("roSGNode", "Poster")
    layer.id = "layer" + n.toStr()
    layer.uri = "pkg:/images/layer_" + n.toStr() + ".png"
    layer.width = 2400
    layer.height = m.h
    layer.opacity = 0.25
    m.layerGroup.appendChild(layer)
    drift = createObject("roSGNode", "Animation")
    drift.duration = 20 + n * 3
    drift.repeat = true
    drift.easeFunction = "inOutQuad"
    interp = createObject("roSGNode", "Vector2DFieldInterpolator")
    interp.fieldToInterp = [layer.id + ".translation"]
    interp.key = [0.0, 0.5, 1.0]
    interp.keyValue = [[0, 0], [m.w - 2400, 0], [0, 0]]
    drift.appendChild(interp)
    m.top.appendChild(drift)
    drift.control = "start"
end sub

sub addFish(i as integer)
    id = i.toStr()
    rig = createObject("roSGNode", "Group")
    rig.id = "f" + id
    body = createObject("roSGNode", "Poster")
    body.uri = "pkg:/images/fish_blue.png"
    body.width = 240
    body.height = 140
    tail = createObject("roSGNode", "Poster")
    tail.id = "t" + id
    tail.uri = "pkg:/images/fish_orange.png"
    tail.width = 96
    tail.height = 56
    tail.translation = [-80, 42]
    tail.scaleRotateCenter = [96, 28]
    fin = createObject("roSGNode", "Poster")
    fin.id = "p" + id
    fin.uri = "pkg:/images/fish_blue.png"
    fin.width = 60
    fin.height = 35
    fin.translation = [110, 80]
    fin.scaleRotateCenter = [0, 0]
    rig.appendChild(tail)
    rig.appendChild(body)
    rig.appendChild(fin)
    m.fishGroup.appendChild(rig)

    wiggle = createObject("roSGNode", "Animation")
    wiggle.duration = 0.5 + (i mod 5) * 0.08
    wiggle.repeat = true
    wiggle.easeFunction = "inOutQuad"
    t = createObject("roSGNode", "FloatFieldInterpolator")
    t.fieldToInterp = ["t" + id + ".rotation"]
    t.key = [0.0, 0.5, 1.0]
    t.keyValue = [-0.35, 0.35, -0.35]
    wiggle.appendChild(t)
    p = createObject("roSGNode", "FloatFieldInterpolator")
    p.fieldToInterp = ["p" + id + ".rotation"]
    p.key = [0.0, 0.5, 1.0]
    p.keyValue = [0.25, -0.25, 0.25]
    wiggle.appendChild(p)
    m.top.appendChild(wiggle)
    wiggle.control = "start"

    y = 60 + ((i * 97) mod (m.h - 260))
    swim = createObject("roSGNode", "Animation")
    swim.duration = 8 + (i mod 7) * 2
    swim.repeat = true
    swim.easeFunction = "linear"
    s = createObject("roSGNode", "Vector2DFieldInterpolator")
    s.fieldToInterp = ["f" + id + ".translation"]
    s.key = [0.0, 0.5, 1.0]
    s.keyValue = [[-260, y], [m.w * 0.5, y + 60], [m.w + 260, y]]
    swim.appendChild(s)
    m.top.appendChild(swim)
    swim.control = "start"
end sub
