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
            return { agent: agent, rng: rng, points: [[x, y]], startTick: 0, steps: 0, dart: false, facing: facing, speed: brainBucket(speed, cfg.speedBucket) }
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
    fish.facing = brainFacing(fish.facing, last[0] - fish.points[0][0], cfg.facingDeadband)
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
