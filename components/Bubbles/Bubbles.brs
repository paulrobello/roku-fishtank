sub init()
    m.slots = []
    m.pending = []
    m.parked = []
    m.halved = false
    m.restartTimer = m.top.findNode("restartTimer")
    m.restartTimer.observeField("fire", "onRestart")
end sub

sub onConfig()
    if m.slots.count() > 0 then return
    cfg = m.top.config
    if not m.global.hasField("bubblesSerial") then m.global.addFields({ bubblesSerial: 0 })
    m.global.bubblesSerial = m.global.bubblesSerial + 1
    prefix = "bubbles" + m.global.bubblesSerial.toStr() + "_"

    freeze = 0.0
    if m.global.hasField("previewFreeze") then freeze = m.global.previewFreeze
    m.pool = bubblesNewPool(cfg, bubblesSeed(freeze))
    uri = "pkg:/images/decor/bubble.png"
    if cfg.uri <> invalid then uri = cfg.uri
    m.byId = {}
    for i = 0 to m.pool.slots.count() - 1
        poster = m.top.createChild("Poster")
        poster.id = prefix + "b" + i.toStr()
        poster.uri = uri
        anim = m.top.createChild("Animation")
        anim.id = prefix + "rise" + i.toStr()
        anim.repeat = false
        anim.easeFunction = "linear"
        move = anim.createChild("Vector2DFieldInterpolator")
        move.fieldToInterp = [poster.id + ".translation"]
        fade = anim.createChild("FloatFieldInterpolator")
        fade.fieldToInterp = [poster.id + ".opacity"]
        m.slots.push({ poster: poster, anim: anim, move: move, fade: fade })
        m.byId[anim.id] = i
    end for
    print "BUBBLES pool="; m.slots.count(); " sources="; m.pool.cfg.sources.count()

    if freeze > 0 then
        bubblesAdvanceTo(m.pool, freeze)
        for i = 0 to m.slots.count() - 1
            c = m.pool.slots[i].cycle
            p = bubblesPoseAt(m.pool, c, freeze)
            s = m.slots[i]
            s.poster.width = c.size
            s.poster.height = c.size
            s.poster.translation = p.translation
            s.poster.opacity = p.opacity
        end for
        return
    end if
    m.clock = CreateObject("roTimespan")
    for i = 0 to m.slots.count() - 1
        bubblesStart(i)
        m.slots[i].anim.observeField("state", "onRiseState")
    end for
end sub

' Loads slot i's current cycle into its Poster and Animation and starts it.
sub bubblesStart(i as integer)
    s = m.slots[i]
    c = m.pool.slots[i].cycle
    kf = bubblesKeyframes(m.pool, c)
    s.poster.width = c.size
    s.poster.height = c.size
    s.poster.translation = kf.translations[0]
    s.poster.opacity = 0
    s.move.key = kf.keys
    s.move.keyValue = kf.translations
    s.fade.key = kf.keys
    s.fade.keyValue = kf.opacities
    s.anim.delay = c.delay
    s.anim.duration = c.duration
    s.anim.control = "start"
end sub

sub onRiseState(event as object)
    if event.getData() <> "stopped" then return
    i = m.byId[event.getNode()]
    if i = invalid then return
    m.pending.push(i)
    m.restartTimer.control = "start"
end sub

' Restarts the slots that stopped since the last fire. Deferred to a Timer because
' brs-scenegraph runs the state observer inside Animation.stop(), which dequeues the
' Animation after the observer returns, so a restart from the observer would be undone.
sub onRestart()
    pending = m.pending
    m.pending = []
    now = m.clock.TotalMilliseconds() / 1000.0
    for each i in pending
        if m.halved and i mod 2 = 1 then
            ' Half the column rests at night: each running Animation costs render time.
            m.slots[i].poster.opacity = 0
            m.parked.push(i)
        else
            bubblesRecycle(m.pool, i, now)
            bubblesStart(i)
        end if
    end for
    m.top.recycles = m.pool.recycles
end sub

sub onNightLevel()
    ' Group opacity multiplies every bubble's own fade, so the column dims as night eases in.
    nightOpacity = 0.45
    if m.top.config <> invalid and m.top.config.nightOpacity <> invalid then nightOpacity = m.top.config.nightOpacity
    m.top.opacity = 1.0 - (1.0 - nightOpacity) * m.top.nightLevel
    halved = m.top.nightLevel > 0.5
    if halved = m.halved then return
    m.halved = halved
    if halved or m.parked.count() = 0 or m.clock = invalid then return
    now = m.clock.TotalMilliseconds() / 1000.0
    for each i in m.parked
        bubblesRecycle(m.pool, i, now)
        bubblesStart(i)
    end for
    m.parked = []
end sub

' ?seed in the preview; a fixed seed under ?freeze without one, so the frozen frame is
' stable; otherwise derived from the wall clock.
function bubblesSeed(freeze as float) as integer
    if m.global.hasField("previewSeed") and m.global.previewSeed > 0 then return m.global.previewSeed
    if freeze > 0 then return 1
    now = CreateObject("roDateTime")
    return now.AsSeconds() + now.GetMilliseconds() * 7919
end function
