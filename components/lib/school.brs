' Green chromis school logic (P2.5): boids (separation, alignment, cohesion)
' around a virtual leader that wanders via steer.brs. Pure functions over
' plain AAs with no SceneGraph dependency, so the School component and
' brs-cli unit tests share it. Self-contained apart from prng.brs and
' steer.brs: every helper here is school-prefixed.
'
' The whole school moves in lockstep. One sub-step (schoolStep) is cfg.tick
' seconds of scene time and moves every member once, so boid forces always
' see all members at the same instant. schoolTick keeps the simulation
' cfg.segSteps sub-steps ahead of the drawn tick, runs one sub-step per tick
' (an even CPU load), and every cfg.segSteps ticks cuts each member's next
' segment: a polyline of segSteps + 1 steerMove outputs.
'
' Guarantees, for every sub-step point of every member:
'   - outside every ellipse: steerMove is the only position writer;
'   - at least cfg.minDist from every other member: members move in a fixed
'     order, each move is tried on a scratch agent first and adopted only
'     when its end point keeps minDist from the others (new positions for
'     members already moved, old for the rest); otherwise the member holds
'     still with zero velocity, which is always safe by the same argument.
'
' The leader is never drawn. It steers against the ellipses padded by
' cfg.leaderPad px and a lane inset by cfg.leaderInset px, so the school it
' pulls detours around rocks as a group instead of splitting around them.
'
' State (from schoolNew):
'   leader     steer.brs agent
'   members    [{ agent, points, seg, facing, speed }]
'                points: sub-step points from tick segStart + segSteps on
'                seg:    the current segment, segSteps + 1 points
'   rng        prng.brs state (spawn and leader wander)
'   simTick    sub-steps simulated so far
'   segStart, segSteps   tick and length of the current segment
'   holds      count of moves refused by the spacing guard
'
' Config fields (see config/school.json): count, tick, segSteps, minSpeed,
' maxSpeed, viewRadius, sepRadius, sepAccel, minDist, alignRate,
' cohesionAccel, followAccel, followRange, avoidMargin, avoidAccel, laneBand,
' laneAccel, leaderMinSpeed, leaderMaxSpeed, leaderJitter, leaderAccel,
' leaderPad, leaderInset, leaderLeash, leaderLeashAccel, spawnRadius,
' spawnMargin, facingDeadband, speedBucket.

' Returns a new school, or invalid when no clear spawn is found.
function schoolNew(cfg as object, seed as integer, lane as object, ellipses as object) as object
    rng = prngNew(seed)
    leaderLane = schoolInsetLane(lane, cfg.leaderInset)
    leaderEllipses = schoolPadEllipses(ellipses, cfg.leaderPad)
    leader = invalid
    heading = 0.0
    spawnLane = leaderLane
    if lane.spawnLeft <> invalid then spawnLane = schoolInsetLane({ left: lane.spawnLeft, top: lane.top, right: lane.spawnRight, bottom: lane.bottom }, cfg.leaderInset)
    for tries = 1 to 1000
        x = prngRange(rng, spawnLane.left, spawnLane.right)
        y = prngRange(rng, leaderLane.top, leaderLane.bottom)
        if schoolClearOf(leaderEllipses, x, y, 1.0) then
            if prngNextFloat(rng) < 0.5 then heading = 3.14159265
            heading = heading + prngRange(rng, -0.4, 0.4)
            leader = steerNewAgent(x, y, heading, cfg.leaderMinSpeed)
            exit for
        end if
    end for
    if leader = invalid then return invalid

    grow = (1 + cfg.spawnMargin) * (1 + cfg.spawnMargin)
    spawn2 = cfg.minDist * cfg.minDist * 1.5625
    members = []
    for i = 0 to cfg.count - 1
        member = invalid
        for tries = 1 to 1000
            x = leader.x + prngRange(rng, -cfg.spawnRadius, cfg.spawnRadius)
            y = leader.y + prngRange(rng, -cfg.spawnRadius, cfg.spawnRadius)
            inLane = x >= lane.left and x <= lane.right and y >= lane.top and y <= lane.bottom
            if inLane and schoolClearOf(ellipses, x, y, grow) and schoolSpacedFrom(members, -1, x, y, spawn2) then
                agent = steerNewAgent(x, y, heading + prngRange(rng, -0.2, 0.2), prngRange(rng, cfg.minSpeed, cfg.leaderMaxSpeed))
                facing = 1
                if agent.vx < 0 then facing = -1
                member = { agent: agent, points: [[x, y]], seg: [[x, y]], facing: facing, speed: schoolBucket(cfg.leaderMinSpeed, cfg.speedBucket) }
                exit for
            end if
        end for
        if member = invalid then return invalid
        members.push(member)
    end for

    n = members.count()
    return {
        leader: leader
        leaderLane: leaderLane
        leaderEllipses: leaderEllipses
        members: members
        rng: rng
        simTick: 0
        segStart: 0
        segSteps: 0
        holds: 0
        probe: { x: 0.0, y: 0.0, vx: 0.0, vy: 0.0, wanderAngle: 0.0 }
        sx: schoolZeros(n)
        sy: schoolZeros(n)
        svx: schoolZeros(n)
        svy: schoolZeros(n)
    }
end function

function schoolZeros(n as integer) as object
    a = []
    for i = 1 to n
        a.push(0.0)
    end for
    return a
end function

function schoolInsetLane(lane as object, inset as float) as object
    return { left: lane.left + inset, top: lane.top + inset, right: lane.right - inset, bottom: lane.bottom - inset }
end function

function schoolPadEllipses(ellipses as object, pad as float) as object
    out = []
    for each e in ellipses
        out.push({ cx: e.cx, cy: e.cy, rx: e.rx + pad, ry: e.ry + pad })
    end for
    return out
end function

' True when (x, y) has normalized distance squared >= minNorm2 from every
' ellipse (minNorm2 = 1 means outside or on the outline).
function schoolClearOf(ellipses as object, x as float, y as float, minNorm2 as float) as boolean
    for each e in ellipses
        if steerEllipseNorm2(e, x, y) < minNorm2 then return false
    end for
    return true
end function

' True when (x, y) is at least sqrt(min2) from every member except index skip.
function schoolSpacedFrom(members as object, skip as integer, x as float, y as float, min2 as float) as boolean
    for j = 0 to members.count() - 1
        if j <> skip then
            a = members[j].agent
            dx = x - a.x
            dy = y - a.y
            if dx * dx + dy * dy < min2 then return false
        end if
    end for
    return true
end function

' Accelerates the agent toward (tx, ty), ramping from 0 at the target to
' accel px/s^2 at range px and beyond.
sub schoolPull(agent as object, tx as float, ty as float, accel as float, range as float, dt as float)
    dx = tx - agent.x
    dy = ty - agent.y
    dist = Sqr(dx * dx + dy * dy)
    if dist <= 0 then return
    w = dist / range
    if w > 1 then w = 1
    k = accel * w * dt / dist
    agent.vx = agent.vx + dx * k
    agent.vy = agent.vy + dy * k
end sub

' One lockstep sub-step: snapshot, leader, member forces, guarded moves.
' Appends each member's new position to its points.
sub schoolStep(school as object, cfg as object, lane as object, ellipses as object)
    dt = cfg.tick
    members = school.members
    n = members.count()
    sx = school.sx
    sy = school.sy
    svx = school.svx
    svy = school.svy
    cx = 0.0
    cy = 0.0
    for i = 0 to n - 1
        a = members[i].agent
        sx[i] = a.x
        sy[i] = a.y
        svx[i] = a.vx
        svy[i] = a.vy
        cx = cx + a.x
        cy = cy + a.y
    end for
    cx = cx / n
    cy = cy / n

    ' Leader: wander, held on a leash to the school centroid, steering
    ' against the padded ellipses and the inset lane.
    leader = school.leader
    if cfg.wanderPull <> invalid then
        pullTarget = 0.0
        if leader.vx < 0 then pullTarget = 3.14159265
        steerWanderPull(leader, pullTarget, cfg.wanderPull, dt)
    end if
    steerWander(leader, school.rng, cfg.leaderJitter, cfg.leaderAccel, dt)
    dx = cx - leader.x
    dy = cy - leader.y
    if dx * dx + dy * dy > cfg.leaderLeash * cfg.leaderLeash then schoolPull(leader, cx, cy, cfg.leaderLeashAccel, cfg.leaderLeash, dt)
    steerAvoidEllipses(leader, school.leaderEllipses, cfg.avoidMargin, cfg.avoidAccel, dt)
    steerLaneKeep(leader, school.leaderLane, cfg.laneBand, cfg.laneAccel, dt)
    steerClampSpeed(leader, cfg.leaderMinSpeed, cfg.leaderMaxSpeed)
    steerMove(leader, school.leaderEllipses, dt)

    ' Member forces from the snapshot.
    view2 = cfg.viewRadius * cfg.viewRadius
    sep2 = cfg.sepRadius * cfg.sepRadius
    for i = 0 to n - 1
        agent = members[i].agent
        sepX = 0.0
        sepY = 0.0
        sumVx = 0.0
        sumVy = 0.0
        sumX = 0.0
        sumY = 0.0
        seen = 0
        for j = 0 to n - 1
            if j <> i then
                ox = sx[i] - sx[j]
                oy = sy[i] - sy[j]
                d2 = ox * ox + oy * oy
                if d2 < view2 then
                    seen = seen + 1
                    sumVx = sumVx + svx[j]
                    sumVy = sumVy + svy[j]
                    sumX = sumX + sx[j]
                    sumY = sumY + sy[j]
                    if d2 < sep2 and d2 > 0 then
                        d = Sqr(d2)
                        w = (cfg.sepRadius - d) / (cfg.sepRadius * d)
                        sepX = sepX + ox * w
                        sepY = sepY + oy * w
                    end if
                end if
            end if
        end for
        agent.vx = agent.vx + sepX * cfg.sepAccel * dt
        agent.vy = agent.vy + sepY * cfg.sepAccel * dt
        if seen > 0 then
            agent.vx = agent.vx + (sumVx / seen - agent.vx) * cfg.alignRate * dt
            agent.vy = agent.vy + (sumVy / seen - agent.vy) * cfg.alignRate * dt
            steerSeek(agent, sumX / seen, sumY / seen, cfg.cohesionAccel, dt)
        end if
        schoolPull(agent, leader.x, leader.y, cfg.followAccel, cfg.followRange, dt)
        steerAvoidEllipses(agent, ellipses, cfg.avoidMargin, cfg.avoidAccel, dt)
        steerLaneKeep(agent, lane, cfg.laneBand, cfg.laneAccel, dt)
        steerClampSpeed(agent, cfg.minSpeed, cfg.maxSpeed)
    end for

    ' Guarded moves in fixed order.
    min2 = cfg.minDist * cfg.minDist
    probe = school.probe
    for i = 0 to n - 1
        member = members[i]
        agent = member.agent
        probe.x = agent.x
        probe.y = agent.y
        probe.vx = agent.vx
        probe.vy = agent.vy
        steerMove(probe, ellipses, dt)
        if schoolSpacedFrom(members, i, probe.x, probe.y, min2) then
            steerMove(agent, ellipses, dt)
        else
            agent.vx = 0
            agent.vy = 0
            school.holds = school.holds + 1
        end if
        member.points.push([agent.x, agent.y])
    end for
    school.simTick = school.simTick + 1
end sub

' One school tick at drawn tick `now`; call with now = 0, 1, 2, ... in order.
' Runs sub-steps until the simulation is cfg.segSteps ahead of now, then at
' each segment boundary cuts every member's next segment. Returns true when
' a new segment starts at `now`.
function schoolTick(school as object, cfg as object, lane as object, ellipses as object, now as integer) as boolean
    while school.simTick < now + cfg.segSteps
        schoolStep(school, cfg, lane, ellipses)
    end while
    if now < school.segStart + school.segSteps then return false
    for each member in school.members
        seg = member.points
        last = seg[seg.count() - 1]
        member.seg = seg
        member.points = [last]
        member.facing = schoolFacing(member.facing, last[0] - seg[0][0], cfg.facingDeadband)
        member.speed = schoolBucket(schoolPathSpeed(seg, cfg.tick), cfg.speedBucket)
    end for
    school.segStart = now
    school.segSteps = cfg.segSteps
    return true
end function

' Facing after a segment with net horizontal travel dx: flips only past the
' deadband, so near-vertical segments do not flip a fish back and forth.
function schoolFacing(current as integer, dx as float, deadband as float) as integer
    if dx > deadband then return 1
    if dx < -deadband then return -1
    return current
end function

' Rounds speed to the nearest multiple of bucket (at least one bucket), so the
' Fish tail beat, which restarts on every swimSpeed write, changes rarely.
function schoolBucket(speed as float, bucket as float) as float
    n = Int(speed / bucket + 0.5)
    if n < 1 then n = 1
    return n * bucket
end function

' Mean speed of a polyline of one point per tick, in px/s.
function schoolPathSpeed(points as object, tickSec as float) as float
    steps = points.count() - 1
    if steps < 1 then return 0.0
    length = 0.0
    for i = 1 to steps
        dx = points[i][0] - points[i - 1][0]
        dy = points[i][1] - points[i - 1][1]
        length = length + Sqr(dx * dx + dy * dy)
    end for
    return length / (steps * tickSec)
end function

' Point on the polyline at fraction f in [0, 1], keys spaced evenly.
function schoolPolylineAt(points as object, f as float) as object
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
