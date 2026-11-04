' Unit tests for components/lib/school.brs. The config mirrors
' config/school.json; the lane and ellipses are copied here so a config edit
' cannot silently weaken the tests.

function schoolTestSuite() as object
    return {
        name: "school"
        tests: [
            { name: "spawnIsClearAndSpaced", fn: schoolTest_spawnIsClearAndSpaced }
            { name: "longRunsStayGroupedSpacedAndClear", fn: schoolTest_longRunsStayGroupedSpacedAndClear }
            { name: "segmentsAreContinuous", fn: schoolTest_segmentsAreContinuous }
            { name: "schoolWheels", fn: schoolTest_schoolWheels }
            { name: "sameSeedSamePaths", fn: schoolTest_sameSeedSamePaths }
            { name: "polylineAt", fn: schoolTest_polylineAt }
        ]
    }
end function

function schoolTest_cfg() as object
    return {
        count: 10, tick: 0.125, segSteps: 8, minSpeed: 30, maxSpeed: 120
        viewRadius: 220, sepRadius: 70, sepAccel: 800, minDist: 42, alignRate: 1.2
        cohesionAccel: 40, followAccel: 90, followRange: 200, avoidMargin: 0.4
        avoidAccel: 300, laneBand: 60, laneAccel: 400, leaderMinSpeed: 40
        leaderMaxSpeed: 75, leaderJitter: 2.5, leaderAccel: 60, leaderPad: 70
        leaderInset: 110, leaderLeash: 120, leaderLeashAccel: 80, spawnRadius: 150
        spawnMargin: 0.3, facingDeadband: 6, speedBucket: 15, boundRadius: 260
    }
end function

function schoolTest_lane() as object
    return { left: 160, top: 200, right: 1760, bottom: 900 }
end function

function schoolTest_ellipses() as object
    return [
        { cx: 470, cy: 640, rx: 150, ry: 110 }
        { cx: 900, cy: 420, rx: 120, ry: 90 }
        { cx: 1300, cy: 700, rx: 180, ry: 100 }
        { cx: 1560, cy: 380, rx: 90, ry: 80 }
    ]
end function

' Raw inside test, independent of steer.brs helpers.
function schoolTest_inside(ellipses as object, x as float, y as float) as boolean
    for each e in ellipses
        ux = (x - e.cx) / e.rx
        uy = (y - e.cy) / e.ry
        if ux * ux + uy * uy < 1 then return true
    end for
    return false
end function

' Largest member distance from the centroid and smallest pairwise distance.
function schoolTest_shape(members as object) as object
    n = members.count()
    cx = 0.0
    cy = 0.0
    for each mb in members
        cx = cx + mb.agent.x
        cy = cy + mb.agent.y
    end for
    cx = cx / n
    cy = cy / n
    maxR2 = 0.0
    minP2 = 1e12
    for i = 0 to n - 1
        a = members[i].agent
        r2 = (a.x - cx) * (a.x - cx) + (a.y - cy) * (a.y - cy)
        if r2 > maxR2 then maxR2 = r2
        for j = i + 1 to n - 1
            b = members[j].agent
            p2 = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
            if p2 < minP2 then minP2 = p2
        end for
    end for
    return { cx: cx, cy: cy, maxR: Sqr(maxR2), minPair: Sqr(minP2) }
end function

sub schoolTest_spawnIsClearAndSpaced(t as object)
    cfg = schoolTest_cfg()
    lane = schoolTest_lane()
    ellipses = schoolTest_ellipses()
    bad = 0
    for seed = 1 to 40
        school = schoolNew(cfg, seed, lane, ellipses)
        if school = invalid then
            bad = bad + 1
        else
            if school.members.count() <> cfg.count then bad = bad + 1
            for each mb in school.members
                a = mb.agent
                if schoolTest_inside(ellipses, a.x, a.y) then bad = bad + 1
                if a.x < lane.left or a.x > lane.right or a.y < lane.top or a.y > lane.bottom then bad = bad + 1
            end for
            if schoolTest_shape(school.members).minPair < cfg.minDist then bad = bad + 1
        end if
    end for
    assertEqual(t, bad, 0, "bad spawns")
end sub

' Acceptance (P2.5): over long seeded runs every member stays within
' cfg.boundRadius of the school centroid, no two members are ever closer
' than cfg.minDist, and no point or drawn piece enters an ellipse.
sub schoolTest_longRunsStayGroupedSpacedAndClear(t as object)
    cfg = schoolTest_cfg()
    lane = schoolTest_lane()
    ellipses = schoolTest_ellipses()
    steps = 1000
    worstR = 0.0
    worstPair = 1e9
    inside = 0
    crossings = 0
    pieces = 0
    holds = 0
    for each seed in [1, 3, 7]
        school = schoolNew(cfg, seed, lane, ellipses)
        prev = []
        for each mb in school.members
            prev.push([mb.agent.x, mb.agent.y])
        end for
        for s = 1 to steps
            schoolStep(school, cfg, lane, ellipses)
            shape = schoolTest_shape(school.members)
            if shape.maxR > worstR then worstR = shape.maxR
            if shape.minPair < worstPair then worstPair = shape.minPair
            for i = 0 to school.members.count() - 1
                a = school.members[i].agent
                if schoolTest_inside(ellipses, a.x, a.y) then inside = inside + 1
                if steerFirstHit(ellipses, prev[i][0], prev[i][1], a.x, a.y) >= 0 then crossings = crossings + 1
                pieces = pieces + 1
                prev[i][0] = a.x
                prev[i][1] = a.y
            end for
        end for
        holds = holds + school.holds
    end for
    print "  school: max centroid distance " + Str(worstR).trim() + " (bound " + cfg.boundRadius.toStr() + "), min pair " + Str(worstPair).trim() + " (min " + cfg.minDist.toStr() + "), holds " + holds.toStr() + " of " + pieces.toStr() + " moves"
    assertTrue(t, worstR <= cfg.boundRadius, "member strays " + Str(worstR).trim() + " px from the centroid")
    assertTrue(t, worstPair >= cfg.minDist, "members " + Str(worstPair).trim() + " px apart")
    assertEqual(t, inside, 0, "points inside an ellipse")
    assertEqual(t, crossings, 0, "pieces crossing an ellipse")
    ' The hard guard is a backstop; soft separation should do nearly all the work.
    assertTrue(t, holds * 50 < pieces, "spacing guard holds " + holds.toStr() + " of " + pieces.toStr() + " moves")
end sub

' schoolTick cuts segments of segSteps + 1 points, each starting where the
' previous one ended, on every segSteps-th tick.
sub schoolTest_segmentsAreContinuous(t as object)
    cfg = schoolTest_cfg()
    lane = schoolTest_lane()
    ellipses = schoolTest_ellipses()
    school = schoolNew(cfg, 5, lane, ellipses)
    ends = []
    for each mb in school.members
        ends.push([mb.agent.x, mb.agent.y])
    end for
    cuts = 0
    gaps = 0
    badLen = 0
    for now = 0 to 399
        if schoolTick(school, cfg, lane, ellipses, now) then
            cuts = cuts + 1
            if now <> school.segStart or now mod cfg.segSteps <> 0 then badLen = badLen + 1
            for i = 0 to school.members.count() - 1
                seg = school.members[i].seg
                if seg.count() <> cfg.segSteps + 1 then badLen = badLen + 1
                if Abs(seg[0][0] - ends[i][0]) > 0.001 or Abs(seg[0][1] - ends[i][1]) > 0.001 then gaps = gaps + 1
                ends[i] = seg[seg.count() - 1]
            end for
        end if
        if school.simTick <> now + cfg.segSteps then badLen = badLen + 1
    end for
    assertEqual(t, cuts, 50, "segments in 400 ticks")
    assertEqual(t, badLen, 0, "segment timing or length errors")
    assertEqual(t, gaps, 0, "segment start jumps")
end sub

' The school turns as a group: its centroid velocity over 2 s windows heads
' both left and right during a run, while the members stay grouped.
sub schoolTest_schoolWheels(t as object)
    cfg = schoolTest_cfg()
    lane = schoolTest_lane()
    ellipses = schoolTest_ellipses()
    school = schoolNew(cfg, 3, lane, ellipses)
    shape = schoolTest_shape(school.members)
    left = 0
    right = 0
    for w = 1 to 60
        for s = 1 to 16
            schoolStep(school, cfg, lane, ellipses)
        end for
        after = schoolTest_shape(school.members)
        dx = after.cx - shape.cx
        if dx < -20 then left = left + 1
        if dx > 20 then right = right + 1
        shape = after
    end for
    assertTrue(t, left >= 5, "school heads left in " + left.toStr() + " windows")
    assertTrue(t, right >= 5, "school heads right in " + right.toStr() + " windows")
end sub

sub schoolTest_sameSeedSamePaths(t as object)
    cfg = schoolTest_cfg()
    lane = schoolTest_lane()
    ellipses = schoolTest_ellipses()
    a = schoolNew(cfg, 42, lane, ellipses)
    b = schoolNew(cfg, 42, lane, ellipses)
    c = schoolNew(cfg, 43, lane, ellipses)
    diffs = 0
    for s = 1 to 200
        schoolStep(a, cfg, lane, ellipses)
        schoolStep(b, cfg, lane, ellipses)
        schoolStep(c, cfg, lane, ellipses)
        for i = 0 to cfg.count - 1
            if a.members[i].agent.x <> b.members[i].agent.x or a.members[i].agent.y <> b.members[i].agent.y then diffs = diffs + 1
        end for
    end for
    assertEqual(t, diffs, 0, "same seed differs")
    pa = a.members[0].agent
    pc = c.members[0].agent
    assertTrue(t, pa.x <> pc.x or pa.y <> pc.y, "different seed gives a different path")
end sub

sub schoolTest_polylineAt(t as object)
    p = [[0, 0], [10, 0], [10, 20]]
    q = schoolPolylineAt(p, 0.25)
    assertNear(t, q[0], 5, 0.001, "x at 0.25")
    q = schoolPolylineAt(p, 0.75)
    assertNear(t, q[1], 10, 0.001, "y at 0.75")
    q = schoolPolylineAt(p, 1.5)
    assertNear(t, q[1], 20, 0.001, "clamped end")
    assertEqual(t, schoolFacing(1, -10, 6), -1, "facing flips past deadband")
    assertEqual(t, schoolFacing(1, -5, 6), 1, "facing keeps inside deadband")
    assertEqual(t, schoolBucket(53, 15), 60, "speed bucket")
end sub
