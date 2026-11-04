sub onConfig()
    if m.built = true then return
    m.built = true
    art = m.top.config.art
    stalk = m.top.config.stalk
    if art = invalid or stalk = invalid then return
    if not m.global.hasField("seaweedSerial") then m.global.addFields({ seaweedSerial: 0 })
    m.global.seaweedSerial = m.global.seaweedSerial + 1
    prefix = "seaweed" + m.global.seaweedSerial.toStr() + "_"

    m.top.translation = [stalk.x, stalk.y]
    if stalk.scale <> invalid then m.top.scale = [stalk.scale, stalk.scale]
    tint = sceneCfgParseColor(stalk.tint, &hFFFFFFFF)
    uris = art.segmentUris
    n = uris.count()
    size = art.segmentSize
    pitch = art.segmentStep
    phase0 = 0.0
    if stalk.phaseDeg <> invalid then phase0 = stalk.phaseDeg * 0.0174533
    period = art.period
    if stalk.period <> invalid then period = stalk.period

    anim = m.top.createChild("Animation")
    anim.id = prefix + "sway"
    anim.repeat = true
    anim.easeFunction = "linear"
    anim.duration = period

    keyCount = art.keyCount
    keys = []
    for j = 0 to keyCount - 1
        keys.push(j / (keyCount - 1))
    end for

    parent = m.top
    for k = 0 to n - 1
        seg = parent.createChild("Group")
        seg.id = prefix + "seg" + k.toStr()
        if k > 0 then seg.translation = [0, -pitch]
        seg.scaleRotateCenter = [0, 0]
        poster = seg.createChild("Poster")
        poster.uri = uris[k]
        poster.width = size[0]
        poster.height = size[1]
        poster.translation = [-size[0] / 2, -size[1]]
        poster.blendColor = tint
        ' Base segments bend least; amplitude ramps to the full value at the tip.
        amp = art.amplitudeDeg * 0.0174533 * (0.5 + 0.5 * k / (n - 1))
        lag = phase0 - k * art.phaseStepDeg * 0.0174533
        values = []
        for j = 0 to keyCount - 1
            values.push(amp * Sin(6.2831853 * keys[j] + lag))
        end for
        seg.rotation = values[0]
        interp = anim.createChild("FloatFieldInterpolator")
        interp.fieldToInterp = [seg.id + ".rotation"]
        interp.key = keys
        interp.keyValue = values
        parent = seg
    end for
    anim.control = "start"
end sub
