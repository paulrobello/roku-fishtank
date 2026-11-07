' Steering library for fish brains: wander, seek, ellipse avoidance, lane
' keeping, speed clamp and a guarded move. Pure functions over plain AAs with
' no SceneGraph dependency, so components include it via <script uri> and
' brs-cli unit tests run it directly.
'
' Data shapes (all coordinates in scene pixels, time in seconds):
'   agent:   { x, y, vx, vy, wanderAngle }      from steerNewAgent()
'   ellipse: { cx, cy, rx, ry }                  axis-aligned, rx and ry > 0
'   lane:    { left, top, right, bottom }        top/bottom is the lane band,
'                                                left/right the swim extent
' Randomness comes only from an injected prng.brs state and time only from
' the injected dt, so the same seed and dt sequence give the same path.
'
' Per brain tick, call in this order:
'   steerWander / steerSeek -> steerAvoidEllipses -> steerLaneKeep
'   -> steerClampSpeed -> steerMove
' steerMove is the only function that changes x/y and it is the hard
' guarantee that an agent never enters an ellipse. Nothing here allocates.

' Returns a new agent at (x, y) heading `heading` radians at `speed` px/s.
function steerNewAgent(x as float, y as float, heading as float, speed as float) as object
    return { x: x, y: y, vx: Cos(heading) * speed, vy: Sin(heading) * speed, wanderAngle: heading }
end function

' Random-walks agent.wanderAngle by up to +/- jitter rad/s and accelerates
' the agent along it by accel px/s^2 for dt seconds.
sub steerWander(agent as object, rng as object, jitter as float, accel as float, dt as float)
    agent.wanderAngle = agent.wanderAngle + prngRange(rng, -jitter, jitter) * dt
    agent.vx = agent.vx + Cos(agent.wanderAngle) * accel * dt
    agent.vy = agent.vy + Sin(agent.wanderAngle) * accel * dt
end sub

' Eases agent.wanderAngle toward `target` (radians) by pull per second, taking the short way
' round. Called before steerWander, it keeps a cruising fish swimming roughly the way it
' faces, so it reverses only when a lane edge or an ellipse pushes it.
sub steerWanderPull(agent as object, target as float, pull as float, dt as float)
    pi = 3.14159265
    d = target - agent.wanderAngle
    while d > pi
        d = d - 2.0 * pi
    end while
    while d < -pi
        d = d + 2.0 * pi
    end while
    k = pull * dt
    if k > 1.0 then k = 1.0
    agent.wanderAngle = agent.wanderAngle + d * k
end sub

' Accelerates the agent toward (tx, ty) by accel px/s^2 for dt seconds.
' No-op when the agent is already at the target.
sub steerSeek(agent as object, tx as float, ty as float, accel as float, dt as float)
    dx = tx - agent.x
    dy = ty - agent.y
    dist = Sqr(dx * dx + dy * dy)
    if dist <= 0 then return
    agent.vx = agent.vx + dx / dist * accel * dt
    agent.vy = agent.vy + dy / dist * accel * dt
end sub

' Returns ((x-cx)/rx)^2 + ((y-cy)/ry)^2: below 1 means (x, y) is inside.
function steerEllipseNorm2(e as object, x as float, y as float) as float
    ux = (x - e.cx) / e.rx
    uy = (y - e.cy) / e.ry
    return ux * ux + uy * uy
end function

' Soft avoidance. Inside the band 1 <= d < 1 + margin around each ellipse,
' where d is the normalized distance (d = 1 on the outline, margin is a
' fraction of the radii), pushes the agent outward along the ellipse normal.
' The push ramps linearly from 0 at the band's outer edge to accel px/s^2 at
' the outline. steerMove enforces the hard boundary.
sub steerAvoidEllipses(agent as object, ellipses as object, margin as float, accel as float, dt as float)
    outer = 1 + margin
    for i = 0 to ellipses.count() - 1
        e = ellipses[i]
        d = Sqr(steerEllipseNorm2(e, agent.x, agent.y))
        if d < outer then
            w = (outer - d) / margin
            if w > 1 then w = 1
            ' Gradient of the normalized distance, up to a positive factor.
            gx = (agent.x - e.cx) / (e.rx * e.rx)
            gy = (agent.y - e.cy) / (e.ry * e.ry)
            glen = Sqr(gx * gx + gy * gy)
            if glen > 0 then
                k = accel * w * dt / glen
                agent.vx = agent.vx + gx * k
                agent.vy = agent.vy + gy * k
            end if
        end if
    end for
end sub

' Keeps the agent inside the lane rect. Within `band` px of an edge it
' accelerates back inward, ramping from 0 to accel px/s^2 at the edge; past
' an edge, outward velocity is zeroed so the agent stops leaving. The worst
' excursion past an edge is therefore about one step, maxSpeed * dt.
sub steerLaneKeep(agent as object, lane as object, band as float, accel as float, dt as float)
    a = accel * dt
    if agent.y < lane.top + band then
        w = (lane.top + band - agent.y) / band
        if w > 1 then w = 1
        agent.vy = agent.vy + a * w
        if agent.y < lane.top and agent.vy < 0 then agent.vy = 0
    else if agent.y > lane.bottom - band then
        w = (agent.y - lane.bottom + band) / band
        if w > 1 then w = 1
        agent.vy = agent.vy - a * w
        if agent.y > lane.bottom and agent.vy > 0 then agent.vy = 0
    end if
    if agent.x < lane.left + band then
        w = (lane.left + band - agent.x) / band
        if w > 1 then w = 1
        agent.vx = agent.vx + a * w
        if agent.x < lane.left and agent.vx < 0 then agent.vx = 0
    else if agent.x > lane.right - band then
        w = (agent.x - lane.right + band) / band
        if w > 1 then w = 1
        agent.vx = agent.vx - a * w
        if agent.x > lane.right and agent.vx > 0 then agent.vx = 0
    end if
end sub

' Scales the velocity so its magnitude is within [minSpeed, maxSpeed],
' keeping its direction. A zero velocity stays zero.
sub steerClampSpeed(agent as object, minSpeed as float, maxSpeed as float)
    speed = Sqr(agent.vx * agent.vx + agent.vy * agent.vy)
    if speed <= 0 then return
    s = 1.0
    if speed > maxSpeed then
        s = maxSpeed / speed
    else if speed < minSpeed then
        s = minSpeed / speed
    end if
    agent.vx = agent.vx * s
    agent.vy = agent.vy * s
end sub

' Skin added to the outline in steerMove so float rounding can never leave
' an agent a hair inside an ellipse.
function steerSkin() as float
    return 0.0001
end function

' Returns true when the straight move from (x0, y0) to (x1, y1) passes inside
' ellipse e (normalized distance below 1 + skin). The ellipse maps to the unit
' circle under (x-cx)/rx, (y-cy)/ry, which keeps segments straight, so this is
' the closest point of the mapped segment to the origin.
function steerSegmentHits(e as object, x0 as float, y0 as float, x1 as float, y1 as float) as boolean
    px = (x0 - e.cx) / e.rx
    py = (y0 - e.cy) / e.ry
    dx = (x1 - x0) / e.rx
    dy = (y1 - y0) / e.ry
    dd = dx * dx + dy * dy
    t = 0.0
    if dd > 0 then
        t = - (px * dx + py * dy) / dd
        if t < 0 then t = 0
        if t > 1 then t = 1
    end if
    qx = px + dx * t
    qy = py + dy * t
    return qx * qx + qy * qy < 1 + steerSkin()
end function

' Returns the index of the first ellipse the move hits, or -1.
function steerFirstHit(ellipses as object, x0 as float, y0 as float, x1 as float, y1 as float) as integer
    for i = 0 to ellipses.count() - 1
        if steerSegmentHits(ellipses[i], x0, y0, x1, y1) then return i
    end for
    return -1
end function

' Integrates position by velocity * dt unless the straight-line move would
' pass inside any ellipse. On a hit it removes the velocity component heading
' into that ellipse (slides along it) and retries once; if the slide still
' hits, the agent holds position with zero velocity. Returns true when the
' move was deflected or blocked. Precondition: the agent starts outside all
' ellipses, which then holds after every call.
function steerMove(agent as object, ellipses as object, dt as float) as boolean
    x0 = agent.x
    y0 = agent.y
    hit = steerFirstHit(ellipses, x0, y0, x0 + agent.vx * dt, y0 + agent.vy * dt)
    if hit < 0 then
        agent.x = x0 + agent.vx * dt
        agent.y = y0 + agent.vy * dt
        return false
    end if
    e = ellipses[hit]
    gx = (x0 - e.cx) / (e.rx * e.rx)
    gy = (y0 - e.cy) / (e.ry * e.ry)
    gg = gx * gx + gy * gy
    vn = agent.vx * gx + agent.vy * gy
    if gg > 0 and vn < 0 then
        agent.vx = agent.vx - vn / gg * gx
        agent.vy = agent.vy - vn / gg * gy
    end if
    if steerFirstHit(ellipses, x0, y0, x0 + agent.vx * dt, y0 + agent.vy * dt) >= 0 then
        agent.vx = 0
        agent.vy = 0
        return true
    end if
    agent.x = x0 + agent.vx * dt
    agent.y = y0 + agent.vy * dt
    return true
end function
