' Pure scheduling for the pooled bubble column (P1.3). No SceneGraph: the Bubbles
' component owns one Poster and one Animation per slot and asks these functions what
' each slot does next, so brs-cli unit tests can run the schedule directly.
'
' A pool is a fixed array of slots, created once. Each slot rises from its source
' (sources[i mod n]) to the source's top, then recycles: the same slot draws a new
' size, rise time, wobble and start gap from its own PRNG stream and rises again.
' Slots never get added or removed. Per-slot PRNG streams make each slot's sequence
' independent of the order in which slots finish, so a live run and a ?freeze pose
' agree on every slot's parameters.
'
' A cycle runs from progress p0 (0 = at the source, 1 = at the top) to 1. The first
' cycle of each slot starts at a random p0 so the column is full at t = 0; recycled
' cycles start at 0 after a short delay.

function bubblesNewPool(cfg as object, seed as integer) as object
    pool = { cfg: bubblesDefaults(cfg), slots: [], recycles: 0 }
    sources = pool.cfg.sources
    for i = 0 to pool.cfg.pool - 1
        rng = prngNew(seed + (i + 1) * &h9E37)
        slot = { index: i, rng: rng, source: sources[i mod sources.count()], cycle: invalid }
        slot.cycle = bubblesNewCycle(pool, slot, 0.0, prngNextFloat(rng), false)
        pool.slots.push(slot)
    end for
    return pool
end function

' Fills defaults for every optional key of the scene.json "bubbles" block.
function bubblesDefaults(cfg as object) as object
    d = {
        pool: 40
        sources: [{ x: 960, y: 1000, top: -40, spread: 6 }]
        sizeMin: 8
        sizeMax: 24
        riseMin: 6.0
        riseMax: 9.0
        wobbleMin: 3.0
        wobbleMax: 10.0
        wobbleCyclesMin: 2.0
        wobbleCyclesMax: 4.0
        gapMax: 0.5
        fadeIn: 0.04
        fadeOut: 0.12
        opacity: 0.85
        keyCount: 13
    }
    if cfg = invalid then return d
    for each k in d
        if cfg.doesExist(k) and cfg[k] <> invalid then d[k] = cfg[k]
    end for
    for each s in d.sources
        if s.spread = invalid then s.spread = 0
    end for
    return d
end function

' Draws the slot's next cycle. start is the scene time the cycle's Animation starts;
' withGap adds a random delay before the rise.
function bubblesNewCycle(pool as object, slot as object, start as float, p0 as float, withGap as boolean) as object
    c = pool.cfg
    rng = slot.rng
    src = slot.source
    delay = 0.0
    if withGap then delay = prngRange(rng, 0.0, c.gapMax)
    rise = prngRange(rng, c.riseMin, c.riseMax)
    return {
        x0: src.x + prngRange(rng, -src.spread, src.spread + 0.001)
        y0: src.y
        y1: src.top
        size: prngRange(rng, c.sizeMin, c.sizeMax + 0.001)
        rise: rise
        amp: prngRange(rng, c.wobbleMin, c.wobbleMax + 0.001)
        cycles: prngRange(rng, c.wobbleCyclesMin, c.wobbleCyclesMax + 0.001)
        phase: prngRange(rng, 0.0, 6.2831853)
        p0: p0
        start: start
        delay: delay
        duration: rise * (1 - p0)
    }
end function

function bubblesCycleEnd(cycle as object) as float
    return cycle.start + cycle.delay + cycle.duration
end function

' Recycles slot i in place: same slot, new cycle starting at now.
function bubblesRecycle(pool as object, i as integer, now as float) as object
    slot = pool.slots[i]
    slot.cycle = bubblesNewCycle(pool, slot, now, 0.0, true)
    pool.recycles = pool.recycles + 1
    return slot
end function

' Runs the schedule to time t: every cycle that ends at or before t recycles at its end.
sub bubblesAdvanceTo(pool as object, t as float)
    for i = 0 to pool.slots.count() - 1
        while bubblesCycleEnd(pool.slots[i].cycle) <= t
            bubblesRecycle(pool, i, bubblesCycleEnd(pool.slots[i].cycle))
        end while
    end for
end sub

' Bubble centre and opacity at rise progress u in [0, 1].
function bubblesAtProgress(pool as object, cycle as object, u as float) as object
    c = pool.cfg
    x = cycle.x0 + cycle.amp * Sin(6.2831853 * cycle.cycles * u + cycle.phase)
    y = cycle.y0 + (cycle.y1 - cycle.y0) * u
    a = c.opacity
    if u < c.fadeIn then a = a * u / c.fadeIn
    if u > 1 - c.fadeOut then a = a * (1 - u) / c.fadeOut
    if a < 0 then a = 0
    return { x: x, y: y, opacity: a }
end function

' Poster pose (top-left translation, opacity) of a cycle at scene time t.
function bubblesPoseAt(pool as object, cycle as object, t as float) as object
    elapsed = t - cycle.start - cycle.delay
    if elapsed < 0 then return { translation: [cycle.x0 - cycle.size / 2, cycle.y0], opacity: 0.0, u: -1.0 }
    f = elapsed / cycle.duration
    if f > 1 then f = 1
    u = cycle.p0 + (1 - cycle.p0) * f
    p = bubblesAtProgress(pool, cycle, u)
    h = cycle.size / 2
    return { translation: [p.x - h, p.y - h], opacity: p.opacity, u: u }
end function

' Linear keyframes for one cycle's Animation: key fractions, Poster translations
' (top-left) and opacities, sampled evenly from p0 to 1.
function bubblesKeyframes(pool as object, cycle as object) as object
    n = pool.cfg.keyCount
    keys = []
    places = []
    alpha = []
    h = cycle.size / 2
    for k = 0 to n - 1
        f = k / (n - 1)
        p = bubblesAtProgress(pool, cycle, cycle.p0 + (1 - cycle.p0) * f)
        keys.push(f)
        places.push([p.x - h, p.y - h])
        alpha.push(p.opacity)
    end for
    return { keys: keys, translations: places, opacities: alpha }
end function
