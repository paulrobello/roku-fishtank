' Fish brain logic: turns steer.brs steering into Animation segments. Pure
' functions over plain AAs with no SceneGraph dependency, so FishBrain and
' brs-cli unit tests share it.
'
' Time is a brain tick counter. One tick is cfg.tick seconds of scene time
' (0.125 s, 8 Hz), and every segment lasts a whole number of ticks. A segment
' is a polyline of steps + 1 points; each point is one steerMove sub-step of
' cfg.tick seconds, so every rendered piece is a straight move that steerMove
' approved, and a fish never crosses an ellipse along its drawn path.
'
' Per fish state (from brainNewFish):
'   agent      steer.brs agent; after planning it sits at the segment end
'   rng        per-fish prng.brs state, so fish never perturb each other
'   points     [[x, y], ...] the current segment, steps + 1 points
'   startTick  tick at which points[0] is drawn
'   steps      segment length in ticks
'   dart       true while the current segment is a dart
'   facing     1 (right) or -1 (left)
'   lockFacing 0, or +/-1 to pin facing whatever the segment's direction
'   speed      bucketed swim speed in px/s for the Fish tail beat
'
' Config fields used (see config/brain.json): tick, segMinSec, segMaxSec,
' minSpeed, maxSpeed, wanderJitter, wanderAccel, avoidMargin, avoidAccel,
' laneBand, laneAccel, dartChance, dartSpeed, dartTurn, dartSteps,
' facingDeadband, speedBucket, spawnMargin.

' Returns a fish spawned at a random point inside lane and outside every
' ellipse inflated by cfg.spawnMargin (a fish spawned inside an ellipse could
' never leave it). Returns invalid when 1000 tries find no free point.
function brainNewFish(cfg as object, seed as integer, lane as object, ellipses as object) as object
    rng = prngNew(seed)
    grow = 1 + cfg.spawnMargin
    for tries = 1 to 1000
        x = prngRange(rng, lane.left, lane.right)
        y = prngRange(rng, lane.top, lane.bottom)
        if brainClearOf(ellipses, x, y, grow * grow) then
            heading = 0.0
            if prngNextFloat(rng) < 0.5 then heading = 3.14159265
            heading = heading + prngRange(rng, -0.4, 0.4)
            speed = prngRange(rng, cfg.minSpeed, cfg.maxSpeed)
            agent = steerNewAgent(x, y, heading, speed)
            facing = 1
            if agent.vx < 0 then facing = -1
            return { agent: agent, rng: rng, points: [[x, y]], startTick: 0, steps: 0, dart: false, facing: facing, lockFacing: 0, speed: brainBucket(speed, cfg.speedBucket), beh: invalid }
        end if
    end for
    return invalid
end function

' True when (x, y) has normalized distance squared >= minNorm2 from every
' ellipse (minNorm2 = 1 means outside or on the outline).
function brainClearOf(ellipses as object, x as float, y as float, minNorm2 as float) as boolean
    for each e in ellipses
        if steerEllipseNorm2(e, x, y) < minNorm2 then return false
    end for
    return true
end function

' Number of ticks in a cruise segment: uniform in
' [ceil(segMinSec / tick), floor(segMaxSec / tick)].
function brainCruiseSteps(cfg as object, rng as object) as integer
    lo = Int(cfg.segMinSec / cfg.tick + 0.999)
    hi = Int(cfg.segMaxSec / cfg.tick + 0.001)
    if hi < lo then hi = lo
    return lo + Int(prngNextFloat(rng) * (hi - lo + 1))
end function

' Plans a cruise segment of `steps` ticks from the agent's position: per
' sub-step wander -> avoid -> lane-keep -> clamp -> steerMove, the order
' steer.brs documents. Returns the polyline; the agent ends at its last point.
function brainPlanCruise(fish as object, cfg as object, lane as object, ellipses as object, steps as integer) as object
    agent = fish.agent
    dt = cfg.tick
    points = [[agent.x, agent.y]]
    for i = 1 to steps
        steerWander(agent, fish.rng, cfg.wanderJitter, cfg.wanderAccel, dt)
        steerAvoidEllipses(agent, ellipses, cfg.avoidMargin, cfg.avoidAccel, dt)
        steerLaneKeep(agent, lane, cfg.laneBand, cfg.laneAccel, dt)
        steerClampSpeed(agent, cfg.minSpeed, cfg.maxSpeed)
        steerMove(agent, ellipses, dt)
        points.push([agent.x, agent.y])
    end for
    return points
end function

' Plans a dart of cfg.dartSteps ticks: the heading turns by up to +/-
' cfg.dartTurn rad and the speed jumps to cfg.dartSpeed, then each sub-step
' runs avoid -> lane-keep -> clamp -> steerMove. Afterwards the agent is
' slowed back to cruise speed along its new heading.
function brainPlanDart(fish as object, cfg as object, lane as object, ellipses as object) as object
    agent = fish.agent
    dt = cfg.tick
    heading = brainHeading(agent, fish.facing) + prngRange(fish.rng, -cfg.dartTurn, cfg.dartTurn)
    agent.vx = Cos(heading) * cfg.dartSpeed
    agent.vy = Sin(heading) * cfg.dartSpeed
    agent.wanderAngle = heading
    points = [[agent.x, agent.y]]
    for i = 1 to cfg.dartSteps
        steerAvoidEllipses(agent, ellipses, cfg.avoidMargin, cfg.avoidAccel, dt)
        steerLaneKeep(agent, lane, cfg.laneBand, cfg.laneAccel, dt)
        steerClampSpeed(agent, cfg.minSpeed, cfg.dartSpeed)
        steerMove(agent, ellipses, dt)
        points.push([agent.x, agent.y])
    end for
    steerClampSpeed(agent, cfg.minSpeed, cfg.maxSpeed)
    return points
end function

' Heading of the agent's velocity in radians; a stopped agent heads along
' its facing.
function brainHeading(agent as object, facing as integer) as float
    if agent.vx = 0 and agent.vy = 0 then
        if facing < 0 then return 3.14159265
        return 0.0
    end if
    return brainAtan2(agent.vy, agent.vx)
end function

' atan2 from Atn, which BrightScript lacks.
function brainAtan2(y as float, x as float) as float
    pi = 3.14159265
    if x > 0 then return Atn(y / x)
    if x < 0 then
        if y >= 0 then return Atn(y / x) + pi
        return Atn(y / x) - pi
    end if
    if y > 0 then return pi / 2
    if y < 0 then return -pi / 2
    return 0.0
end function

' Facing after a segment with net horizontal travel dx: flips only when the
' fish travels more than deadband px against its current facing, so
' near-vertical segments do not flip it back and forth.
function brainFacing(current as integer, dx as float, deadband as float) as integer
    if dx > deadband then return 1
    if dx < -deadband then return -1
    return current
end function

' Rounds speed to the nearest multiple of bucket (at least one bucket), so the
' Fish tail beat, which restarts on every swimSpeed write, changes rarely.
function brainBucket(speed as float, bucket as float) as float
    n = Int(speed / bucket + 0.5)
    if n < 1 then n = 1
    return n * bucket
end function

' Mean speed of a polyline drawn over `steps` ticks, in px/s.
function brainPathSpeed(points as object, tickSec as float) as float
    length = 0.0
    for i = 1 to points.count() - 1
        dx = points[i][0] - points[i - 1][0]
        dy = points[i][1] - points[i - 1][1]
        length = length + Sqr(dx * dx + dy * dy)
    end for
    steps = points.count() - 1
    if steps < 1 then return 0.0
    return length / (steps * tickSec)
end function

' One brain tick for one fish at tick `now`. Starts a new segment when the
' current one has ended, otherwise rolls for a dart (cruise segments only).
' A dart starts from points[now - startTick], the exact steerMove output the
' cruise segment reaches at this tick. Returns "segment", "dart" or "".
function brainTickFish(fish as object, cfg as object, lane as object, ellipses as object, now as integer) as string
    if now >= fish.startTick + fish.steps then
        steps = brainCruiseSteps(cfg, fish.rng)
        fish.points = brainPlanCruise(fish, cfg, lane, ellipses, steps)
        brainStartSegment(fish, cfg, now, steps, false)
        return "segment"
    end if
    if fish.dart then return ""
    if prngNextFloat(fish.rng) >= cfg.dartChance then return ""
    at = fish.points[now - fish.startTick]
    fish.agent.x = at[0]
    fish.agent.y = at[1]
    fish.points = brainPlanDart(fish, cfg, lane, ellipses)
    brainStartSegment(fish, cfg, now, cfg.dartSteps, true)
    return "dart"
end function

sub brainStartSegment(fish as object, cfg as object, now as integer, steps as integer, dart as boolean)
    fish.startTick = now
    fish.steps = steps
    fish.dart = dart
    last = fish.points[fish.points.count() - 1]
    if fish.lockFacing <> 0 then
        fish.facing = fish.lockFacing
    else
        fish.facing = brainFacing(fish.facing, last[0] - fish.points[0][0], cfg.facingDeadband)
    end if
    fish.speed = brainBucket(brainPathSpeed(fish.points, cfg.tick), cfg.speedBucket)
end sub

' Point on the polyline at eased fraction f in [0, 1], keys spaced evenly.
function brainPolylineAt(points as object, f as float) as object
    last = points.count() - 1
    if last < 1 or f <= 0 then return [points[0][0], points[0][1]]
    if f >= 1 then return [points[last][0], points[last][1]]
    s = f * last
    i = Int(s)
    u = s - i
    a = points[i]
    b = points[i + 1]
    return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u]
end function

' outCubic, the dart ease (fast start, slow finish), matching Roku's curve.
function brainOutCubic(f as float) as float
    g = f - 1
    return g * g * g + 1
end function

' ---------------------------------------------------------------------------
' Per-species behaviours (P2.6). A behaviour config (config/behavior.json)
' maps each species to a kind, and each kind is a small state machine:
'   cruise  no state machine: the P2.3 cruise + dart path, unchanged
'   grazer  cruise -> approach (a rock point) -> graze (pecks and pauses) -> cruise
'   cave    hover (at a cave mouth) -> retreat (tail first into the den)
'           -> hide -> emerge -> hover; facing is pinned to the cave's opening
'   bottom  graze (pause) <-> hop, inside the rock/sand band
'   hover   drift (slow wander, no darts) <-> hang (near-still)
' Every state plans per-tick sub-steps that end in steerMove, so the ellipse
' guard holds in every state. Modes change only when a segment ends. Each
' change is recorded on the fish as trFrom/trTo (the caller logs and clears
' it); a fish starts in mode "spawn" and leaves it on its first tick.
'
' Behaviour fish fields, on top of brainNewFish's: species, kind, beh (the
' kind's parameters), mode, modeEnd (tick the mode ends), motion (the brain
' config with per-mode overrides), motion2 (hover kind: the hang motion),
' cave (cave kind: { mouth, den, out }), target ([x, y]), peck (grazer:
' next graze segment is a peck), trFrom, trTo.

' The world a population moves in. beh may be invalid (P2.3 cruise only).
function brainNewWorld(cfg as object, beh as object) as object
    world = { lane: cfg.lane, ellipses: cfg.ellipses, caves: [], rocks: [], band: invalid, arriveTime: 0.6, arriveResponse: 6.0 }
    if beh <> invalid then
        world.caves = beh.caves
        world.rocks = beh.rocks
        world.band = beh.band
        world.arriveTime = beh.arriveTime
        world.arriveResponse = beh.arriveResponse
    end if
    return world
end function

' The population as [{ species, count }]: beh.population when present,
' otherwise the brain config's single species.
function brainPopulation(cfg as object, beh as object) as object
    if beh <> invalid and beh.population <> invalid then return beh.population
    return [{ species: cfg.species, count: cfg.count }]
end function

' Spawns the whole population from one master seed, in population order.
' Returns [{ species, state }], state invalid when no spawn point was free.
' Without a behaviour config every fish is brainNewFish(cfg, ...) exactly as
' in P2.3, so seeds give the same tank.
function brainSpawnAll(cfg as object, beh as object, world as object, seed as integer) as object
    master = prngNew(seed)
    out = []
    kindCount = {}
    for each group in brainPopulation(cfg, beh)
        for k = 1 to group.count
            fishSeed = brainFishSeed(master)
            state = invalid
            if beh = invalid then
                state = brainNewFish(cfg, fishSeed, world.lane, world.ellipses)
            else
                kind = brainKindOf(beh, group.species)
                nth = 0
                if kindCount.doesExist(kind) then nth = kindCount[kind]
                kindCount[kind] = nth + 1
                state = brainNewBehaviorFish(cfg, beh, world, group.species, fishSeed, nth)
            end if
            out.push({ species: group.species, state: state })
        end for
    end for
    return out
end function

' A non-zero per-fish seed drawn from the master PRNG.
function brainFishSeed(master as object) as integer
    s = prngNextU32(master)
    if s = 0 then s = 1
    return s
end function

function brainKindOf(beh as object, species as string) as string
    if beh.species.doesExist(species) then return beh.species[species]
    return "cruise"
end function

' Spawns one fish of `species` with its behaviour. nth counts earlier fish
' of the same kind, so cave fish take caves in turn.
function brainNewBehaviorFish(cfg as object, beh as object, world as object, species as string, seed as integer, nth as integer) as object
    kind = brainKindOf(beh, species)
    lane = world.lane
    if kind = "bottom" then lane = world.band
    fish = brainNewFish(cfg, seed, lane, world.ellipses)
    if fish = invalid then return invalid
    fish.species = species
    fish.kind = kind
    fish.beh = invalid
    if beh.kinds.doesExist(kind) then fish.beh = beh.kinds[kind]
    fish.mode = "spawn"
    fish.modeEnd = 0
    fish.trFrom = ""
    fish.trTo = ""
    fish.target = invalid
    fish.peck = true
    fish.cave = invalid
    fish.motion = cfg
    fish.motion2 = cfg
    if fish.beh = invalid then
        fish.kind = "cruise"
    else if kind = "hover" then
        fish.motion = brainMerge(cfg, fish.beh.drift)
        fish.motion2 = brainMerge(cfg, fish.beh.hang)
    else if kind = "cave" then
        cave = world.caves[nth mod world.caves.count()]
        fish.cave = cave
        a = fish.agent
        a.x = cave.mouth[0]
        a.y = cave.mouth[1]
        a.vx = 0
        a.vy = 0
        fish.points = [[a.x, a.y]]
        fish.lockFacing = cave.out
        fish.facing = cave.out
    end if
    return fish
end function

' Shallow copy of base with every key of over set on it.
function brainMerge(base as object, over as object) as object
    out = {}
    for each k in base
        out[k] = base[k]
    end for
    for each k in over
        out[k] = over[k]
    end for
    return out
end function

' Whole ticks for a [minSec, maxSec] range, at least 1.
function brainSecTicks(rng as object, range as object, tick as float) as integer
    n = Int(prngRange(rng, range[0], range[1]) / tick + 0.5)
    if n < 1 then n = 1
    return n
end function

sub brainSetMode(fish as object, mode as string, modeEnd as integer)
    fish.trFrom = fish.mode
    fish.trTo = mode
    fish.mode = mode
    fish.modeEnd = modeEnd
end sub

' One brain tick for any fish: P2.3 fish go straight to brainTickFish. A
' behaviour fish only rolls for darts mid-segment in cruise mode; when its
' segment has ended it may change mode, then plans the next segment.
function brainTickBehavior(fish as object, cfg as object, world as object, now as integer) as string
    if fish.beh = invalid then return brainTickFish(fish, cfg, world.lane, world.ellipses, now)
    if now < fish.startTick + fish.steps then
        if fish.mode = "cruise" then return brainTickFish(fish, fish.motion, world.lane, world.ellipses, now)
        return ""
    end if
    if fish.kind = "grazer" then return brainTickGrazer(fish, cfg, world, now)
    if fish.kind = "cave" then return brainTickCave(fish, cfg, world, now)
    if fish.kind = "bottom" then return brainTickBottom(fish, cfg, world, now)
    return brainTickHover(fish, cfg, world, now)
end function

function brainTickGrazer(fish as object, cfg as object, world as object, now as integer) as string
    b = fish.beh
    a = fish.agent
    tick = cfg.tick
    if fish.mode = "spawn" then
        brainSetMode(fish, "cruise", now + brainSecTicks(fish.rng, b.cruiseSec, tick))
    else if fish.mode = "cruise" then
        if now >= fish.modeEnd and world.rocks.count() > 0 then
            fish.target = brainNearest(world.rocks, a.x, a.y)
            brainSetMode(fish, "approach", now + Int(b.approachSec / tick))
        end if
    else if fish.mode = "approach" then
        if brainDist(a, fish.target) <= b.arriveRadius then
            ' Grazing opens with a pause, which stops the fish, so pecks start still.
            fish.peck = true
            brainSetMode(fish, "graze", now + brainSecTicks(fish.rng, b.grazeSec, tick))
        else if now >= fish.modeEnd then
            brainSetMode(fish, "cruise", now + brainSecTicks(fish.rng, b.cruiseSec, tick))
        end if
    else if fish.mode = "graze" and now >= fish.modeEnd then
        brainLeave(fish, world.ellipses)
        brainSetMode(fish, "cruise", now + brainSecTicks(fish.rng, b.cruiseSec, tick))
    end if

    if fish.mode = "cruise" then return brainTickFish(fish, fish.motion, world.lane, world.ellipses, now)
    steps = 4
    if fish.mode = "approach" then
        fish.points = brainPlanArrive(fish, world, fish.target[0], fish.target[1], b.approachSpeed, steps, tick)
    else
        ' graze: a slow peck to a point near the rock, then a pause, alternating
        fish.peck = not fish.peck
        if fish.peck then
            steps = brainSecTicks(fish.rng, b.peckSec, tick)
            tx = fish.target[0] + prngRange(fish.rng, -b.peckRadius, b.peckRadius)
            ty = fish.target[1] + prngRange(fish.rng, -b.peckRadius, b.peckRadius)
            fish.points = brainPlanArrive(fish, world, tx, ty, b.peckSpeed, steps, tick)
        else
            steps = brainSecTicks(fish.rng, b.pauseSec, tick)
            fish.points = brainPlanHold(fish, world.ellipses, steps, tick)
        end if
    end if
    brainStartSegment(fish, cfg, now, steps, false)
    return "segment"
end function

function brainTickCave(fish as object, cfg as object, world as object, now as integer) as string
    b = fish.beh
    a = fish.agent
    cave = fish.cave
    tick = cfg.tick
    if fish.mode = "spawn" then
        brainSetMode(fish, "hover", now + brainSecTicks(fish.rng, b.hoverSec, tick))
    else if fish.mode = "hover" then
        if now >= fish.modeEnd then brainSetMode(fish, "retreat", now + Int(b.retreatSec / tick))
    else if fish.mode = "retreat" then
        if brainDist(a, cave.den) <= b.arriveRadius or now >= fish.modeEnd then brainSetMode(fish, "hide", now + brainSecTicks(fish.rng, b.hideSec, tick))
    else if fish.mode = "hide" then
        if now >= fish.modeEnd then brainSetMode(fish, "emerge", now + Int(b.emergeSec / tick))
    else if fish.mode = "emerge" then
        if brainDist(a, cave.mouth) <= b.arriveRadius or now >= fish.modeEnd then brainSetMode(fish, "hover", now + brainSecTicks(fish.rng, b.hoverSec, tick))
    end if

    steps = 4
    if fish.mode = "hover" then
        steps = brainSecTicks(fish.rng, b.hoverSegSec, tick)
        tx = cave.mouth[0] + prngRange(fish.rng, -b.hoverRadius, b.hoverRadius)
        ty = cave.mouth[1] + prngRange(fish.rng, -b.hoverRadius, b.hoverRadius)
        fish.points = brainPlanArrive(fish, world, tx, ty, b.hoverSpeed, steps, tick)
    else if fish.mode = "retreat" then
        fish.points = brainPlanArrive(fish, world, cave.den[0], cave.den[1], b.backSpeed, steps, tick)
    else if fish.mode = "hide" then
        steps = brainAtLeastOne(fish.modeEnd - now)
        fish.points = brainPlanHold(fish, world.ellipses, steps, tick)
    else
        fish.points = brainPlanArrive(fish, world, cave.mouth[0], cave.mouth[1], b.emergeSpeed, steps, tick)
    end if
    brainStartSegment(fish, cfg, now, steps, false)
    return "segment"
end function

function brainTickBottom(fish as object, cfg as object, world as object, now as integer) as string
    b = fish.beh
    a = fish.agent
    band = world.band
    tick = cfg.tick
    if fish.mode = "spawn" then
        brainSetMode(fish, "graze", now + brainSecTicks(fish.rng, b.pauseSec, tick))
    else if fish.mode = "graze" then
        if now >= fish.modeEnd then
            dir = 1
            if prngNextFloat(fish.rng) < 0.5 then dir = -1
            hop = prngRange(fish.rng, b.hopPx[0], b.hopPx[1])
            if a.x + dir * hop > band.right or a.x + dir * hop < band.left then dir = -dir
            tx = a.x + dir * hop
            if tx > band.right then tx = band.right
            if tx < band.left then tx = band.left
            fish.target = [tx, prngRange(fish.rng, band.top, band.bottom)]
            brainSetMode(fish, "hop", now + Int(b.hopSec / tick))
        end if
    else if fish.mode = "hop" then
        if brainDist(a, fish.target) <= b.arriveRadius or now >= fish.modeEnd then brainSetMode(fish, "graze", now + brainSecTicks(fish.rng, b.pauseSec, tick))
    end if

    steps = 4
    if fish.mode = "hop" then
        fish.points = brainPlanArrive(fish, world, fish.target[0], fish.target[1], b.hopSpeed, steps, tick)
    else
        steps = brainAtLeastOne(fish.modeEnd - now)
        fish.points = brainPlanHold(fish, world.ellipses, steps, tick)
    end if
    brainStartSegment(fish, cfg, now, steps, false)
    return "segment"
end function

function brainTickHover(fish as object, cfg as object, world as object, now as integer) as string
    b = fish.beh
    tick = cfg.tick
    if fish.mode = "spawn" then
        brainSetMode(fish, "drift", now + brainSecTicks(fish.rng, b.driftSec, tick))
    else if fish.mode = "drift" and now >= fish.modeEnd then
        brainSetMode(fish, "hang", now + brainSecTicks(fish.rng, b.hangSec, tick))
    else if fish.mode = "hang" and now >= fish.modeEnd then
        brainSetMode(fish, "drift", now + brainSecTicks(fish.rng, b.driftSec, tick))
    end if
    motion = fish.motion
    if fish.mode = "hang" then motion = fish.motion2
    ' The old segment has ended, so brainTickFish plans a cruise segment with
    ' the slow motion's speeds (its dartChance is 0).
    return brainTickFish(fish, motion, world.lane, world.ellipses, now)
end function

function brainAtLeastOne(n as integer) as integer
    if n < 1 then return 1
    return n
end function

' Arrive steering: the desired velocity points at (tx, ty) with speed
' dist / arriveTime capped at maxSpeed, and the velocity closes on it at
' arriveResponse per second. Changes velocity only.
sub brainArrive(agent as object, world as object, tx as float, ty as float, maxSpeed as float, dt as float)
    dx = tx - agent.x
    dy = ty - agent.y
    dist = Sqr(dx * dx + dy * dy)
    wx = 0.0
    wy = 0.0
    if dist > 0 then
        speed = dist / world.arriveTime
        if speed > maxSpeed then speed = maxSpeed
        wx = dx / dist * speed
        wy = dy / dist * speed
    end if
    k = world.arriveResponse * dt
    if k > 1 then k = 1
    agent.vx = agent.vx + (wx - agent.vx) * k
    agent.vy = agent.vy + (wy - agent.vy) * k
end sub

' Velocity limit that keeps the next sub-step inside rect r (the bottom
' band): a component that would cross an edge is cut to land on it.
sub brainKeepInRect(agent as object, r as object, dt as float)
    nx = agent.x + agent.vx * dt
    ny = agent.y + agent.vy * dt
    if nx > r.right then agent.vx = (r.right - agent.x) / dt
    if nx < r.left then agent.vx = (r.left - agent.x) / dt
    if ny > r.bottom then agent.vy = (r.bottom - agent.y) / dt
    if ny < r.top then agent.vy = (r.top - agent.y) / dt
end sub

' Plans `steps` arrive sub-steps toward (tx, ty), each ending in steerMove.
' Bottom fish are also held inside the band.
function brainPlanArrive(fish as object, world as object, tx as float, ty as float, maxSpeed as float, steps as integer, dt as float) as object
    agent = fish.agent
    points = [[agent.x, agent.y]]
    for i = 1 to steps
        brainArrive(agent, world, tx, ty, maxSpeed, dt)
        if fish.kind = "bottom" then brainKeepInRect(agent, world.band, dt)
        steerMove(agent, world.ellipses, dt)
        points.push([agent.x, agent.y])
    end for
    return points
end function

' Plans `steps` still sub-steps: zero velocity, still through steerMove.
function brainPlanHold(fish as object, ellipses as object, steps as integer, dt as float) as object
    agent = fish.agent
    agent.vx = 0
    agent.vy = 0
    points = [[agent.x, agent.y]]
    for i = 1 to steps
        steerMove(agent, ellipses, dt)
        points.push([agent.x, agent.y])
    end for
    return points
end function

' Leaving a graze: head away from the nearest rock at cruise minSpeed.
sub brainLeave(fish as object, ellipses as object)
    a = fish.agent
    best = -1
    bestN = 0.0
    for i = 0 to ellipses.count() - 1
        n = steerEllipseNorm2(ellipses[i], a.x, a.y)
        if best < 0 or n < bestN then
            best = i
            bestN = n
        end if
    end for
    if best < 0 then return
    e = ellipses[best]
    dx = a.x - e.cx
    dy = a.y - e.cy
    d = Sqr(dx * dx + dy * dy)
    if d <= 0 then return
    a.vx = dx / d * fish.motion.minSpeed
    a.vy = dy / d * fish.motion.minSpeed
    a.wanderAngle = brainAtan2(dy, dx)
end sub

function brainNearest(points as object, x as float, y as float) as object
    best = points[0]
    bestD = -1.0
    for each p in points
        dx = p[0] - x
        dy = p[1] - y
        d = dx * dx + dy * dy
        if bestD < 0 or d < bestD then
            best = p
            bestD = d
        end if
    end for
    return best
end function

function brainDist(agent as object, p as object) as float
    dx = p[0] - agent.x
    dy = p[1] - agent.y
    return Sqr(dx * dx + dy * dy)
end function
