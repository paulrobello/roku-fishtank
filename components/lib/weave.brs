' Lane weaving (P2.4). Pure logic over brain.brs fish, so FishBrain and the
' brs-cli tests share it. A weaving fish stays owned by the FishBrain that spawned
' it; only its lane (rect, scale, tint, drawing parent) changes.
'
' world.weave is sceneCfgWeavePlan's result. A fish may weave when its species is
' listed and it is cruising. At the end of a segment, after a cooldown, it rolls
' weave.chance; on a hit it picks an adjacent lane and the nearest hide region: a
' gap rect (already shrunk for drift) shrunk again by the fish's half box at the
' larger of the two lane scales. It then:
'   seek  arrives toward that region (gives up after seekSec)
'   hold  switches lane the tick its anchor is inside the region (the whole body is
'         then behind the occluder in both lanes), and holds still for holdSec while
'         hidden, so the scale and tint change is never seen
' and cruises on in the new lane. Weave rolls use the fish's own weave PRNG, so
' fish that never weave keep their paths.
'
' Fish fields added by weaveAttach: laneIdx, laneSwitch (true on the tick the lane
' changes; the caller restyles and reparents, then clears it), box { hw, hh } (half
' extents about the anchor at scale 1, symmetric for the mirrored art), world (the
' fish's lane world once it leaves its home lane), wv { mode, dest, region, until,
' next, rng } (dest is the lane index it is weaving to).

' Gives a fish its weave state when world.weave lists its species. bounds is the
' rig bounds { x, y, width, height } and anchor the rig mirror_center.
sub weaveAttach(fish as object, world as object, species as string, bounds as object, anchor as object, seed as integer)
    w = world.weave
    if w = invalid or fish = invalid then return
    if not w.species.doesExist(species) or w.home < 0 then return
    l = bounds.x - anchor[0]
    t = bounds.y - anchor[1]
    hw = -l
    if l + bounds.width > hw then hw = l + bounds.width
    hh = -t
    if t + bounds.height > hh then hh = t + bounds.height
    fish.box = { hw: hw, hh: hh }
    fish.laneIdx = w.home
    fish.laneSwitch = false
    fish.world = invalid
    fish.wv = { mode: "", dest: -1, region: invalid, until: 0, next: 0, rng: prngNew(seed) }
end sub

' Runs before the fish's own behaviour at each tick. Returns "segment" when it
' planned the fish's next segment, "" to let the behaviour run.
function weaveTick(fish as object, cfg as object, world as object, now as integer) as string
    if now < fish.startTick + fish.steps then return ""
    w = fish.wv
    plan = world.weave
    tick = cfg.tick
    if w.mode = "seek" then
        if weaveInside(w.region, fish.agent.x, fish.agent.y) then
            fish.laneIdx = w.dest
            fish.laneSwitch = true
            fish.world = brainMerge(world, { lane: plan.lanes[w.dest].rect })
            w.mode = "hold"
            steps = Int(plan.holdSec / tick + 0.5)
            if steps < 1 then steps = 1
            fish.points = brainPlanHold(fish, world.ellipses, steps, tick)
            brainStartSegment(fish, cfg, now, steps, false)
            return "segment"
        end if
        if now >= w.until then
            weaveRest(w, plan, now, tick)
            return ""
        end if
        return weaveSeekSegment(fish, cfg, world, now)
    end if
    if w.mode = "hold" then
        weaveRest(w, plan, now, tick)
        return ""
    end if
    if fish.beh <> invalid and fish.mode <> "cruise" then return ""
    if now < w.next then return ""
    if prngNextFloat(w.rng) >= plan.chance then return ""
    choices = []
    for each dest in [fish.laneIdx - 1, fish.laneIdx + 1]
        if dest >= 0 and dest < plan.lanes.count() then
            region = weaveRegion(fish, plan, dest)
            if region <> invalid then choices.push({ dest: dest, region: region })
        end if
    end for
    if choices.count() = 0 then
        weaveRest(w, plan, now, tick)
        return ""
    end if
    pick = choices[Int(prngNextFloat(w.rng) * choices.count())]
    w.mode = "seek"
    w.dest = pick.dest
    w.region = pick.region
    w.until = now + Int(plan.seekSec / tick + 0.5)
    return weaveSeekSegment(fish, cfg, world, now)
end function

sub weaveRest(w as object, plan as object, now as integer, tick as float)
    w.mode = ""
    w.region = invalid
    w.next = now + Int(plan.cooldownSec / tick + 0.5)
end sub

' A 4-tick arrive toward the nearest point of the region, pulled 2 px inside so
' the arrive (which only approaches its target) ends inside.
function weaveSeekSegment(fish as object, cfg as object, world as object, now as integer) as string
    r = fish.wv.region
    tx = weaveClamp(fish.agent.x, r.left + 2, r.right - 2)
    ty = weaveClamp(fish.agent.y, r.top + 2, r.bottom - 2)
    fish.points = brainPlanArrive(fish, world, tx, ty, world.weave.seekSpeed, 4, cfg.tick)
    brainStartSegment(fish, cfg, now, 4, false)
    return "segment"
end function

' The anchor region that hides the whole fish for a switch to lane `dest`: the
' nearest gap rect shrunk by the half box at the larger lane scale, or invalid.
function weaveRegion(fish as object, plan as object, dest as integer) as dynamic
    gapIdx = fish.laneIdx
    if dest < gapIdx then gapIdx = dest
    s = plan.lanes[fish.laneIdx].scale
    if plan.lanes[dest].scale > s then s = plan.lanes[dest].scale
    hw = fish.box.hw * s
    hh = fish.box.hh * s
    best = invalid
    bestD = -1.0
    for each g in plan.gaps[gapIdx]
        r = { left: g.left + hw, top: g.top + hh, right: g.right - hw, bottom: g.bottom - hh }
        if r.right > r.left + 4 and r.bottom > r.top + 4 then
            dx = weaveClamp(fish.agent.x, r.left, r.right) - fish.agent.x
            dy = weaveClamp(fish.agent.y, r.top, r.bottom) - fish.agent.y
            d = dx * dx + dy * dy
            if bestD < 0 or d < bestD then
                best = r
                bestD = d
            end if
        end if
    end for
    return best
end function

function weaveInside(r as object, x as float, y as float) as boolean
    return x >= r.left and x <= r.right and y >= r.top and y <= r.bottom
end function

function weaveClamp(v as float, lo as float, hi as float) as float
    if v < lo then return lo
    if v > hi then return hi
    return v
end function

' True when the fish's body at `scale` lies inside some rect of gap gapIdx.
function weaveHidden(fish as object, plan as object, gapIdx as integer, scale as float) as boolean
    hw = fish.box.hw * scale
    hh = fish.box.hh * scale
    x = fish.agent.x
    y = fish.agent.y
    for each g in plan.gaps[gapIdx]
        if x - hw >= g.left and x + hw <= g.right and y - hh >= g.top and y + hh <= g.bottom then return true
    end for
    return false
end function
