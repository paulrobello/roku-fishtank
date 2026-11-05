' Night controller implementation (P3.3-P3.6); the interface and the pure logic are
' documented in Night.xml and components/lib/night.brs. Everything the scene needs is
' built once in nightStart(): no node is created or removed after that.

sub init()
    m.started = false
    m.state = invalid
    m.freezeT = 0.0
    m.tick = m.top.findNode("nightTick")
    m.tick.observeField("fire", "onTick")
    m.retint = m.top.findNode("nightRetint")
    m.retint.observeField("fire", "onRetint")
    m.forceTint = false
    m.running = {}
end sub

sub onModeChange()
    if m.started then nightEvaluate(false)
end sub

' ReefTank calls this once its layers, decor and fish exist. args:
'   camera - the camera Group that holds the layer Groups (id = scene.json layer id)
'   fill   - the full-screen background Rectangle
'   scene  - the parsed config/scene.json
sub nightStart(args as object)
    if m.started then return
    m.started = true
    cfg = ParseJson(ReadAsciiFile("pkg:/config/night.json"))
    if not sceneCfgIsObject(cfg) or not sceneCfgIsObject(args) or not sceneCfgIsObject(args.scene) then
        print "NIGHT config error: config/night.json or nightStart args missing"
        return
    end if
    m.camera = args.camera
    m.fill = args.fill
    m.cfg = cfg
    m.dayBackground = sceneCfgParseColor(args.scene.backgroundColor, &h0B2F55FF)
    m.nightBackground = sceneCfgParseColor(cfg.background, m.dayBackground)

    if m.global.hasField("previewFreeze") then m.freezeT = m.global.previewFreeze
    speed = 1.0
    if m.global.hasField("previewSpeed") and m.global.previewSpeed > 0 then speed = m.global.previewSpeed
    ' The preview ?night param forces the mode until the settings wiring (P5) sets
    ' ReefTank.nightMode from the stored setting.
    forced = ""
    if m.global.hasField("previewNight") then forced = LCase(m.global.previewNight)
    if forced = "1" or forced = "true" then m.top.mode = "night"
    if forced = "0" or forced = "false" then m.top.mode = "day"

    m.clock = CreateObject("roTimespan")
    m.state = nightMakeState(args.scene, speed, m.freezeT)

    ' Per layer: the moonlight tint target. Each Poster keeps its own day colour in a
    ' nightBase field (nightTintGroup), so nodes inserted, removed or moved between
    ' layers never shift another Poster's base. Code that restyles a Poster sets
    ' nightBase too and sets m.global.nightRetint (components/lib/tint.brs), which
    ' re-tints every layer within nightRetint's duration instead of the next tick.
    m.layers = {}
    for each layer in args.scene.layers
        group = m.camera.findNode(layer.id)
        if group <> invalid then
            base = &hFFFFFFFF
            if sceneCfgIsObject(layer.lane) and layer.lane.tint <> invalid then base = sceneCfgParseColor(layer.lane.tint, base)
            tint = base
            if sceneCfgIsObject(cfg.tints) and cfg.tints[layer.id] <> invalid then tint = sceneCfgParseColor(cfg.tints[layer.id], base)
            m.layers[layer.id] = { group: group, tint: tint, mult: &hFFFFFFFF, count: -1 }
        end if
    end for

    m.dayMaster = nightBuildShafts(cfg.dayShafts, "nightDayShaft", m.freezeT)
    m.moonMaster = nightBuildShafts(cfg.moonShafts, "nightMoonShaft", m.freezeT)
    m.glowMasters = nightBuildGlow(cfg.glow, m.freezeT)
    m.sparkleMaster = nightBuildSparkles(cfg.sparkles, m.freezeT)

    if not m.global.hasField("nightRetint") then m.global.addField("nightRetint", "boolean", true)
    m.global.observeField("nightRetint", "onRetintRequest")

    m.shown = 0.0
    m.tick.duration = nightNum(cfg.evalSeconds, 2.0)
    nightEvaluate(true)
    if m.freezeT <= 0 then m.tick.control = "start"
    print "NIGHT ready: layers="; m.layers.count(); " glow="; m.glowMasters.count(); " mode="; m.top.mode; " phase="; m.top.phase; " blend="; m.top.blend
end sub

function nightMakeState(scene as object, speed as float, freeze as float) as object
    minutes = 0.0
    year = 0
    month = 0
    day = 0
    timeText = ""
    parsed = invalid
    if m.global.hasField("previewTime") then timeText = m.global.previewTime
    if timeText <> "" then
        parsed = nightParseClock(timeText)
        if parsed <> invalid then
            minutes = parsed.minutes
            year = parsed.year
            month = parsed.month
            day = parsed.day
        end if
    end if
    if year = 0 then
        dt = CreateObject("roDateTime")
        dt.ToLocalTime()
        ' A time-only ?time keeps its minutes on today's date. Otherwise, under ?freeze
        ' with no ?time and no ?night the clock starts at noon, so the frozen frame is
        ' the same day tank whatever the wall clock says (noon is inside (sunrise,
        ' sunset) on every Woodland date); live runs use the clock.
        if parsed = invalid then
            minutes = 720.0
            if freeze <= 0 then minutes = dt.GetHours() * 60.0 + dt.GetMinutes() + dt.GetSeconds() / 60.0
        end if
        year = dt.GetYear()
        month = dt.GetMonth()
        day = dt.GetDayOfMonth()
    end if
    loc = scene.location
    ' ?seed in the preview; a fixed seed under ?freeze without one, so the frozen
    ' frame is stable; otherwise derived from the wall clock (the Bubbles rule).
    seed = 0
    if m.global.hasField("previewSeed") and m.global.previewSeed > 0 then seed = m.global.previewSeed
    if seed = 0 then
        if freeze > 0 then
            seed = 1
        else
            now = CreateObject("roDateTime")
            seed = now.AsSeconds() + now.GetMilliseconds() * 7919
        end if
    end if
    ' The solar times stay those of the start date: over a run that crosses local
    ' midnight they go stale by one day of sunset drift (about a minute).
    return {
        start: minutes
        speed: speed
        rng: prngNew(seed)
        solar: solarTimes(loc.latitude, loc.longitude, year, month, day, nightUtcOffsetMinutes())
    }
end function

' Local minus UTC in minutes right now, so the OS handles DST. Read from one
' roDateTime before and after ToLocalTime(), wrapped to (-720, 720].
function nightUtcOffsetMinutes() as integer
    dt = CreateObject("roDateTime")
    utc = dt.GetHours() * 60 + dt.GetMinutes()
    dt.ToLocalTime()
    local = dt.GetHours() * 60 + dt.GetMinutes()
    d = local - utc
    if d > 720 then d = d - 1440
    if d <= -720 then d = d + 1440
    return d
end function

sub onTick()
    nightEvaluate(false)
    m.tick.control = "start"
end sub

' A restyle burst (fish spawning or changing lane) restarts the short timer, so the
' re-tint runs once after the burst.
sub onRetintRequest()
    m.retint.control = "stop"
    m.retint.control = "start"
end sub

sub onRetint()
    m.forceTint = true
    nightApply()
end sub

' Reads the clock, maps it to a phase and blend, eases the shown blend toward it
' and applies everything. snap=true (start, or a forced jump) skips the easing.
sub nightEvaluate(snap as boolean)
    if m.state = invalid then return
    elapsed = m.clock.TotalMilliseconds() / 1000.0
    if m.freezeT > 0 then elapsed = m.freezeT
    minutes = nightClockMinutes(m.state.start, elapsed, m.state.speed)
    st = daynightPhase(minutes, m.state.solar, m.top.mode)
    if snap then
        m.shown = st.blend
    else
        m.shown = nightStep(m.shown, st.blend, m.tick.duration, nightNum(m.cfg.easeSeconds, 3.0))
    end if
    m.top.blend = m.shown
    m.top.phase = st.phase
    m.top.isNight = nightIsNight(m.shown)
    nightApply()
end sub

sub nightApply()
    shown = m.shown
    if m.fill <> invalid then m.fill.color = nightLerpColor(m.dayBackground, m.nightBackground, shown)
    dayLevel = nightDayLevel(shown)
    nightLevel = nightNightLevel(shown)
    if m.dayMaster <> invalid then m.dayMaster.opacity = dayLevel
    if m.moonMaster <> invalid then m.moonMaster.opacity = nightLevel
    for each g in m.glowMasters
        g.opacity = nightLevel
    end for
    if m.sparkleMaster <> invalid then m.sparkleMaster.opacity = nightLevel
    ' An invisible overlay keeps its Animations running unless they are paused, and each
    ' running interpolator costs render time on the device (docs/perf.md), so the overlays
    ' that are off (level 0) are paused. Under ?freeze nothing runs.
    if m.freezeT <= 0 then
        nightRunOverlay("day", m.dayMaster, dayLevel > 0)
        nightRunOverlay("moon", m.moonMaster, nightLevel > 0)
        nightRunOverlay("spark", m.sparkleMaster, nightLevel > 0)
        for i = 0 to m.glowMasters.count() - 1
            nightRunOverlay("glow" + i.toStr(), m.glowMasters[i], nightLevel > 0)
        end for
    end if
    ' The reef extras (caustics, ripple) are built after nightStart, so look the node up lazily.
    if m.extras = invalid then m.extras = m.top.getParent().findNode("reefExtras")
    if m.extras <> invalid then m.extras.nightLevel = nightLevel
    ' The arch swimmer is built before nightStart, so it is found at once.
    if m.arch = invalid then m.arch = m.top.getParent().findNode("archSwimmer")
    if m.arch <> invalid then m.arch.nightLevel = nightLevel
    ' The bubble column is built before nightStart too.
    if m.bubbles = invalid then m.bubbles = m.top.getParent().findNode("bubbleColumn")
    if m.bubbles <> invalid then m.bubbles.nightLevel = nightLevel
    ' Night-only fish (flashlight fish, components/Fish) observe this.
    if not m.global.hasField("nightLevel") then m.global.addFields({ nightLevel: 0.0 })
    if m.global.nightLevel <> nightLevel then m.global.nightLevel = nightLevel
    force = m.forceTint
    m.forceTint = false
    for each id in m.layers
        info = m.layers[id]
        mult = nightLerpColor(&hFFFFFFFF, info.tint, shown)
        if force or mult <> info.mult or info.group.getChildCount() <> info.count then
            info.mult = mult
            info.count = info.group.getChildCount()
            nightTintGroup(info.group, mult)
        end if
    end for
end sub

' Pauses or resumes every Animation under master, only when its on/off state changes.
sub nightRunOverlay(key as string, master as dynamic, on as boolean)
    if master = invalid then return
    if m.running.doesExist(key) and m.running[key] = on then return
    m.running[key] = on
    nightRunAnims(master, on)
end sub

sub nightRunAnims(node as object, on as boolean)
    if node.subtype() = "Animation" then
        if on then
            node.control = "resume"
        else
            node.control = "pause"
        end if
    end if
    for i = 0 to node.getChildCount() - 1
        nightRunAnims(node.getChild(i), on)
    end for
end sub

' Sets every Poster under group to base x mult. Posters whose id starts with
' "night" are Night's own overlays and stay untinted (the glow colour is baked in).
' A Poster's base is its blendColor the first time it is seen, kept in its own
' nightBase field; the field is only ever written here and by tintSetBase.
sub nightTintGroup(group as object, mult as integer)
    for i = 0 to group.getChildCount() - 1
        node = group.getChild(i)
        if Left(node.id, 5) <> "night" then
            if node.subtype() = "Poster" then
                if not node.hasField("nightBase") then
                    node.addField("nightBase", "integer", false)
                    node.nightBase = node.blendColor
                end if
                want = nightMultiplyColor(node.nightBase, mult)
                if node.blendColor <> want then node.blendColor = want
            end if
            nightTintGroup(node, mult)
        end if
    end for
end sub

' One shaft pair (day or moon) inside a master Group whose opacity the phase
' drives. Each shaft is a Group pivoted at its top centre holding the Poster: the
' Group breathes (opacity) on one repeating Animation, and a second one, the
' shimmer, sways the Group (rotation), wobbles its width (scale.x) and flickers
' the Poster's opacity, each an irregular nightWaveKeys curve over shimmer.loopSec.
function nightBuildShafts(block as object, prefix as string, freeze as float) as dynamic
    if not sceneCfgIsObject(block) or not sceneCfgIsArray(block.items) then return invalid
    master = m.camera.findNode(block.layer).createChild("Group")
    master.id = prefix + "s"
    master.opacity = 0
    blend = sceneCfgParseColor(block.blendColor, &hFFFFFFFF)
    sh = block.shimmer
    if not sceneCfgIsObject(sh) then sh = {}
    loopSec = nightNum(sh.loopSec, 21.0)
    perCycle = Int(nightNum(sh.keysPerCycle, 8))
    depth = nightNum(sh.flickerDepth, 0.0)
    wobble = nightNum(sh.widthWobble, 0.0)
    flickerCycles = sh.flickerCycles
    if not sceneCfgIsArray(flickerCycles) then flickerCycles = []
    swayCycles = sh.swayCycles
    if not sceneCfgIsArray(swayCycles) then swayCycles = []
    widthCycles = sh.widthCycles
    if not sceneCfgIsArray(widthCycles) then widthCycles = []
    for i = 0 to block.items.count() - 1
        item = block.items[i]
        shaft = master.createChild("Group")
        shaft.id = prefix + i.toStr()
        shaft.translation = [item.x + item.width / 2.0, item.y]
        shaft.opacity = 0
        poster = shaft.createChild("Poster")
        poster.id = prefix + "Ray" + i.toStr()
        poster.uri = item.uri
        poster.width = item.width
        poster.height = item.height
        poster.translation = [-item.width / 2.0, 0]
        poster.blendColor = blend
        lo = nightNum(item.opacityMin, 0.4)
        hi = nightNum(item.opacityMax, 0.6)
        period = nightNum(item.period, 10.0)
        phase = nightNum(item.phaseDeg, 0.0)
        ' Sway is given as px at the bottom edge; the Group turns about its top.
        swayRad = nightNum(sh.swayPx, 0.0) / item.height
        flicker = nightWaveKeys(flickerCycles, phase + 200, perCycle)
        sway = nightWaveKeys(swayCycles, phase, perCycle)
        width = nightWaveKeys(widthCycles, phase + 90, perCycle)
        if freeze > 0 then
            shaft.opacity = nightBreathAt(lo, hi, phase, freeze, period)
            f = freeze / loopSec - Int(freeze / loopSec)
            poster.opacity = 1 - depth * (0.5 + 0.5 * nightKeyAt(flicker.keys, flicker.values, f))
            shaft.rotation = swayRad * nightKeyAt(sway.keys, sway.values, f)
            shaft.scale = [1 + wobble * nightKeyAt(width.keys, width.values, f), 1]
        else
            anim = master.createChild("Animation")
            anim.id = prefix + "Breathe" + i.toStr()
            anim.repeat = true
            anim.easeFunction = "linear"
            anim.duration = period
            fade = anim.createChild("FloatFieldInterpolator")
            fade.fieldToInterp = [shaft.id + ".opacity"]
            keys = nightBreathKeys(lo, hi, phase, 9)
            fade.key = keys.keys
            fade.keyValue = keys.values
            anim.control = "start"

            shim = master.createChild("Animation")
            shim.id = prefix + "Shimmer" + i.toStr()
            shim.repeat = true
            shim.easeFunction = "linear"
            shim.duration = loopSec
            values = []
            for each v in flicker.values
                values.push(1 - depth * (0.5 + 0.5 * v))
            end for
            glint = shim.createChild("FloatFieldInterpolator")
            glint.fieldToInterp = [poster.id + ".opacity"]
            glint.key = flicker.keys
            glint.keyValue = values
            values = []
            for each v in sway.values
                values.push(swayRad * v)
            end for
            turn = shim.createChild("FloatFieldInterpolator")
            turn.fieldToInterp = [shaft.id + ".rotation"]
            turn.key = sway.keys
            turn.keyValue = values
            values = []
            for each v in width.values
                values.push([1 + wobble * v, 1])
            end for
            stretch = shim.createChild("Vector2DFieldInterpolator")
            stretch.fieldToInterp = [shaft.id + ".scale"]
            stretch.key = width.keys
            stretch.keyValue = values
            shim.control = "start"
        end if
    end for
    return master
end function

' The coral glow overlays (P3.5): one master Group per target layer, Posters at
' the placement-proposal positions (copied into night.json by tools/art/night_config.py).
' Only the groups listed in glow.groups are built (front clumps by default, for
' fill rate; see docs/art/placement-proposal.md).
function nightBuildGlow(block as object, freeze as float) as object
    masters = []
    if not sceneCfgIsObject(block) then return masters
    lo = nightNum(block.opacityMin, 0.55)
    hi = nightNum(block.opacityMax, 0.85)
    items = nightGlowItems(block)
    for i = 0 to items.count() - 1
        item = items[i]
        group = m.camera.findNode(item.layer)
        if group <> invalid then
            ' One master per glowing decor, drawn right after that decor, so plants and
            ' decor drawn later in the layer stay in front of the glow.
            master = invalid
            for each g in masters
                if g.id = "nightGlow" + item.over then master = g
            end for
            if master = invalid then
                master = CreateObject("roSGNode", "Group")
                master.id = "nightGlow" + item.over
                master.opacity = 0
                group.insertChild(master, nightChildIndex(group, item.over) + 1)
                masters.push(master)
            end if
            poster = master.createChild("Poster")
            poster.id = "nightGlow_" + item.id
            poster.uri = item.uri
            poster.width = Int(item.width * item.scale)
            poster.height = Int(item.height * item.scale)
            poster.translation = [item.x, item.y]
            poster.opacity = 0
            period = prngRange(m.state.rng, nightNum(block.periodMin, 5.0), nightNum(block.periodMax, 9.0))
            phase = prngRange(m.state.rng, 0, 360)
            if freeze > 0 then
                poster.opacity = nightBreathAt(lo, hi, phase, freeze, period)
            else
                anim = master.createChild("Animation")
                anim.id = "nightGlowBreathe" + i.toStr()
                anim.repeat = true
                anim.easeFunction = "linear"
                anim.duration = period
                fade = anim.createChild("FloatFieldInterpolator")
                fade.fieldToInterp = [poster.id + ".opacity"]
                keys = nightBreathKeys(lo, hi, phase, 9)
                fade.key = keys.keys
                fade.keyValue = keys.values
                anim.control = "start"
            end if
        end if
    end for
    print "NIGHT glow posters="; items.count(); " of "; block.items.count()
    return masters
end function

'Index of the child of group whose id is id, or the last index when there is none (so
' the caller inserts at the end).
function nightChildIndex(group as object, id as string) as integer
    n = group.getChildCount()
    for i = 0 to n - 1
        if group.getChild(i).id = id then return i
    end for
    return n - 1
end function

' The pooled sparkles (P3.6): a fixed pool of Posters in the bubbles layer, each
' looping its own drift and twinkle. Under ?freeze the poses come from
' nightSparklePose at the freeze time and nothing animates.
function nightBuildSparkles(cfg as object, freeze as float) as dynamic
    if not sceneCfgIsObject(cfg) then return invalid
    master = m.camera.findNode(cfg.layer).createChild("Group")
    master.id = "nightSparkles"
    master.opacity = 0
    blend = sceneCfgParseColor(cfg.blendColor, &h96FFE6FF)
    slots = nightSparkleSlots(cfg, m.state.rng)
    for i = 0 to slots.count() - 1
        s = slots[i]
        poster = master.createChild("Poster")
        poster.id = "nightSparkle" + i.toStr()
        poster.uri = cfg.uri
        poster.width = s.size
        poster.height = s.size
        poster.blendColor = blend
        poster.opacity = 0
        if freeze > 0 then
            pose = nightSparklePose(s, freeze)
            poster.translation = pose.translation
            poster.opacity = pose.opacity
        else
            anim = master.createChild("Animation")
            anim.id = "nightSparkleLoop" + i.toStr()
            anim.repeat = true
            anim.easeFunction = "linear"
            anim.duration = s.period
            anim.delay = s.delay
            move = anim.createChild("Vector2DFieldInterpolator")
            move.fieldToInterp = [poster.id + ".translation"]
            move.key = [0.0, 1.0]
            move.keyValue = [[s.x, s.y], [s.x + s.dx, s.y + s.dy]]
            fade = anim.createChild("FloatFieldInterpolator")
            fade.fieldToInterp = [poster.id + ".opacity"]
            twinkle = nightTwinkleKeys(s.peak)
            fade.key = twinkle.keys
            fade.keyValue = twinkle.values
            anim.control = "start"
        end if
    end for
    print "NIGHT sparkle pool="; slots.count()
    return master
end function
