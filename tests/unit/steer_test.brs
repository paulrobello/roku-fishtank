' Unit tests for components/lib/steer.brs.
' Simulations use a fixed brain tick of dt = 0.125 s (8 Hz). "Inside an
' ellipse" is computed here from the raw formula, not through steer.brs, so a
' broken library helper cannot also break the check.
'
' Lane tolerance: steerLaneKeep zeroes outward velocity once an agent is past
' an edge, so it can overshoot by at most one step, maxSpeed * dt
' (120 * 0.125 = 15 px). Tests allow exactly that.

function steerTestSuite() as object
    return {
        name: "steer"
        tests: [
            { name: "neverEntersEllipses10k", fn: steerTest_neverEntersEllipses10k }
            { name: "guardStopsHeadOnSeek", fn: steerTest_guardStopsHeadOnSeek }
            { name: "guardBlocksTunneling", fn: steerTest_guardBlocksTunneling }
            { name: "sameSeedSamePath", fn: steerTest_sameSeedSamePath }
            { name: "differentSeedDifferentPath", fn: steerTest_differentSeedDifferentPath }
            { name: "laneKeepStaysInBand", fn: steerTest_laneKeepStaysInBand }
            { name: "laneOvershootWithinTolerance", fn: steerTest_laneOvershootWithinTolerance }
            { name: "clampSpeed", fn: steerTest_clampSpeed }
            { name: "seekApproachesTarget", fn: steerTest_seekApproachesTarget }
            { name: "wanderJitterBounded", fn: steerTest_wanderJitterBounded }
        ]
    }
end function

function steerTest_dt() as float
    return 0.125
end function

function steerTest_maxSpeed() as float
    return 120
end function

' One tank lane: full 1920 px swim extent, a 400 px band.
function steerTest_lane() as object
    return { left: 0, top: 300, right: 1920, bottom: 700 }
end function

' Rock and coral in the lane, kept clear of the lane edges.
function steerTest_ellipses() as object
    return [
        { cx: 300, cy: 500, rx: 120, ry: 80 }
        { cx: 750, cy: 470, rx: 90, ry: 100 }
        { cx: 1150, cy: 540, rx: 160, ry: 60 }
        { cx: 1550, cy: 460, rx: 70, ry: 70 }
        { cx: 1750, cy: 580, rx: 50, ry: 40 }
    ]
end function

' One full brain tick in the documented order. Returns steerMove's result.
function steerTest_tick(agent as object, rng as object, ellipses as object, lane as object) as boolean
    dt = steerTest_dt()
    steerWander(agent, rng, 3.0, 80, dt)
    steerAvoidEllipses(agent, ellipses, 0.5, 300, dt)
    steerLaneKeep(agent, lane, 60, 400, dt)
    steerClampSpeed(agent, 30, steerTest_maxSpeed())
    return steerMove(agent, ellipses, dt)
end function

function steerTest_norm2(e as object, x as float, y as float) as float
    ux = (x - e.cx) / e.rx
    uy = (y - e.cy) / e.ry
    return ux * ux + uy * uy
end function

sub steerTest_neverEntersEllipses10k(t as object)
    ellipses = steerTest_ellipses()
    lane = steerTest_lane()
    tol = steerTest_maxSpeed() * steerTest_dt()
    rng = prngNew(2026)
    agent = steerNewAgent(100, 340, 0, 60)
    nearSteps = 0
    guarded = 0
    for stepNum = 1 to 10000
        if steerTest_tick(agent, rng, ellipses, lane) then guarded = guarded + 1
        for each e in ellipses
            n2 = steerTest_norm2(e, agent.x, agent.y)
            if n2 < 1 then
                assertTrue(t, false, "step " + stepNum.toStr() + ": inside ellipse at " + e.cx.toStr() + "," + e.cy.toStr() + " (norm2 " + n2.toStr() + ")")
                return
            end if
            if n2 < 2.25 then nearSteps = nearSteps + 1
        end for
        if agent.y < lane.top - tol or agent.y > lane.bottom + tol then
            assertTrue(t, false, "step " + stepNum.toStr() + ": y " + agent.y.toStr() + " left the lane band")
            return
        end if
    end for
    ' Non-vacuous: the agent spent real time within the avoid margin.
    assertTrue(t, nearSteps > 500, "steps within the avoid margin = " + nearSteps.toStr())
    assertTrue(t, guarded > 0, "steerMove never had to deflect the agent")
    print "  steer 10k: steps near an ellipse = " + nearSteps.toStr() + ", guard deflections = " + guarded.toStr()
end sub

' Seek straight at an ellipse's center with no soft avoid: only steerMove
' stands between the agent and the ellipse.
sub steerTest_guardStopsHeadOnSeek(t as object)
    ellipses = [{ cx: 300, cy: 500, rx: 120, ry: 80 }]
    e = ellipses[0]
    dt = steerTest_dt()
    agent = steerNewAgent(20, 500, 0, 0)
    blocked = 0
    for stepNum = 1 to 400
        steerSeek(agent, e.cx, e.cy, 300, dt)
        steerClampSpeed(agent, 30, steerTest_maxSpeed())
        if steerMove(agent, ellipses, dt) then blocked = blocked + 1
        n2 = steerTest_norm2(e, agent.x, agent.y)
        if n2 < 1 then
            assertTrue(t, false, "step " + stepNum.toStr() + ": inside ellipse (norm2 " + n2.toStr() + ")")
            return
        end if
    end for
    assertTrue(t, blocked > 100, "guard blocks = " + blocked.toStr())
    ' It pressed up against the outline rather than stalling far away.
    assertTrue(t, steerTest_norm2(e, agent.x, agent.y) < 1.5, "agent should end near the outline")
end sub

' A single move whose endpoints are both outside a thin ellipse but whose
' path crosses it must be blocked.
sub steerTest_guardBlocksTunneling(t as object)
    ellipses = [{ cx: 300, cy: 500, rx: 10, ry: 80 }]
    agent = steerNewAgent(250, 500, 0, 800)
    assertTrue(t, steerTest_norm2(ellipses[0], 350, 500) >= 1, "endpoint is outside")
    assertTrue(t, steerMove(agent, ellipses, steerTest_dt()), "move should report a block")
    assertTrue(t, agent.x < 290, "agent crossed the ellipse: x = " + agent.x.toStr())
    ' A clear move goes through untouched.
    free = steerNewAgent(250, 300, 0, 800)
    assertEqual(t, steerMove(free, ellipses, steerTest_dt()), false, "clear move")
    assertNear(t, free.x, 350, 0.001, "clear move x")
end sub

sub steerTest_sameSeedSamePath(t as object)
    ellipses = steerTest_ellipses()
    lane = steerTest_lane()
    rngA = prngNew(1234)
    rngB = prngNew(1234)
    a = steerNewAgent(100, 340, 0, 60)
    b = steerNewAgent(100, 340, 0, 60)
    for stepNum = 1 to 5000
        steerTest_tick(a, rngA, ellipses, lane)
        steerTest_tick(b, rngB, ellipses, lane)
        if not assertEqual(t, a.x, b.x, "x at step " + stepNum.toStr()) then return
        if not assertEqual(t, a.y, b.y, "y at step " + stepNum.toStr()) then return
    end for
end sub

sub steerTest_differentSeedDifferentPath(t as object)
    ellipses = steerTest_ellipses()
    lane = steerTest_lane()
    rngA = prngNew(1234)
    rngB = prngNew(4321)
    a = steerNewAgent(100, 340, 0, 60)
    b = steerNewAgent(100, 340, 0, 60)
    differ = 0
    for stepNum = 1 to 2000
        steerTest_tick(a, rngA, ellipses, lane)
        steerTest_tick(b, rngB, ellipses, lane)
        if a.x <> b.x or a.y <> b.y then differ = differ + 1
    end for
    assertTrue(t, differ > 1900, "steps where the paths differ = " + differ.toStr())
    dx = a.x - b.x
    dy = a.y - b.y
    assertTrue(t, Sqr(dx * dx + dy * dy) > 1, "final positions should differ")
end sub

' Wander only, no ellipses: the agent stays in the lane (plus the one-step
' tolerance) and actually tests the edges.
sub steerTest_laneKeepStaysInBand(t as object)
    lane = steerTest_lane()
    noEllipses = []
    tol = steerTest_maxSpeed() * steerTest_dt()
    rng = prngNew(77)
    agent = steerNewAgent(960, 500, -1.2, 120)
    edgeSteps = 0
    worst = 0.0
    for stepNum = 1 to 10000
        steerTest_tick(agent, rng, noEllipses, lane)
        over = lane.top - agent.y
        if agent.y - lane.bottom > over then over = agent.y - lane.bottom
        if over > worst then worst = over
        if over > tol or agent.x < lane.left - tol or agent.x > lane.right + tol then
            assertTrue(t, false, "step " + stepNum.toStr() + ": (" + agent.x.toStr() + ", " + agent.y.toStr() + ") beyond the lane by more than " + tol.toStr())
            return
        end if
        if agent.y < lane.top + 60 or agent.y > lane.bottom - 60 then edgeSteps = edgeSteps + 1
    end for
    assertTrue(t, edgeSteps > 500, "steps inside the edge band = " + edgeSteps.toStr())
    print "  steer lane: worst excursion past band = " + worst.toStr() + " px (tolerance " + tol.toStr() + ")"
end sub

' Driven straight at the top edge at max speed: the agent overshoots, but by
' no more than the one-step tolerance, and comes back.
sub steerTest_laneOvershootWithinTolerance(t as object)
    lane = steerTest_lane()
    noEllipses = []
    tol = steerTest_maxSpeed() * steerTest_dt()
    rng = prngNew(3)
    agent = steerNewAgent(960, lane.top + 1, -1.5707963, steerTest_maxSpeed())
    worst = 0.0
    for stepNum = 1 to 20
        steerTest_tick(agent, rng, noEllipses, lane)
        if lane.top - agent.y > worst then worst = lane.top - agent.y
    end for
    assertTrue(t, worst > 0, "agent should overshoot the top edge")
    assertTrue(t, worst <= tol, "overshoot " + worst.toStr() + " exceeds " + tol.toStr())
    assertTrue(t, agent.y >= lane.top, "agent should be back inside: y = " + agent.y.toStr())
    print "  steer lane: forced overshoot = " + worst.toStr() + " px (tolerance " + tol.toStr() + ")"
end sub

sub steerTest_clampSpeed(t as object)
    fast = { x: 0, y: 0, vx: 300, vy: 400, wanderAngle: 0 }
    steerClampSpeed(fast, 30, 120)
    assertNear(t, fast.vx, 72, 0.001, "fast vx")
    assertNear(t, fast.vy, 96, 0.001, "fast vy")
    slow = { x: 0, y: 0, vx: -3, vy: 4, wanderAngle: 0 }
    steerClampSpeed(slow, 30, 120)
    assertNear(t, slow.vx, -18, 0.001, "slow vx")
    assertNear(t, slow.vy, 24, 0.001, "slow vy")
    ok = { x: 0, y: 0, vx: 60, vy: 0, wanderAngle: 0 }
    steerClampSpeed(ok, 30, 120)
    assertNear(t, ok.vx, 60, 0.001, "in-range vx unchanged")
    still = { x: 0, y: 0, vx: 0, vy: 0, wanderAngle: 0 }
    steerClampSpeed(still, 30, 120)
    assertEqual(t, still.vx, 0, "zero vx stays zero")
    assertEqual(t, still.vy, 0, "zero vy stays zero")
end sub

sub steerTest_seekApproachesTarget(t as object)
    dt = steerTest_dt()
    agent = steerNewAgent(0, 0, 0, 0)
    noEllipses = []
    prev = 500.0
    for stepNum = 1 to 30
        steerSeek(agent, 500, 0, 200, dt)
        steerClampSpeed(agent, 0, steerTest_maxSpeed())
        steerMove(agent, noEllipses, dt)
        d = Abs(500 - agent.x)
        if not assertTrue(t, d < prev, "distance did not shrink at step " + stepNum.toStr()) then return
        prev = d
    end for
    assertNear(t, agent.y, 0, 0.001, "seek along x keeps y")
    assertTrue(t, agent.x > 300, "agent covered ground: x = " + agent.x.toStr())
    ' At the target, seek is a no-op.
    at = steerNewAgent(500, 0, 0, 0)
    steerSeek(at, 500, 0, 200, dt)
    assertEqual(t, at.vx, 0, "no push at target")
end sub

sub steerTest_wanderJitterBounded(t as object)
    dt = steerTest_dt()
    rng = prngNew(5)
    agent = steerNewAgent(0, 0, 0, 0)
    for stepNum = 1 to 1000
        before = agent.wanderAngle
        steerWander(agent, rng, 3.0, 80, dt)
        if not assertTrue(t, Abs(agent.wanderAngle - before) <= 3.0 * dt + 0.00001, "jitter too large at step " + stepNum.toStr()) then return
    end for
    speed = Sqr(agent.vx * agent.vx + agent.vy * agent.vy)
    assertTrue(t, speed > 0, "wander accelerates the agent")
end sub
