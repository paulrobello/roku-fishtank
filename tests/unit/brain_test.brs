' Unit tests for components/lib/brain.brs. The config mirrors
' config/brain.json; the demo lane and ellipses are copied here so a config
' edit cannot silently weaken the tests.

function brainTestSuite() as object
    return {
        name: "brain"
        tests: [
            { name: "spawnOutsideEllipsesInLane", fn: brainTest_spawnOutsideEllipsesInLane }
            { name: "cruiseStepsInRange", fn: brainTest_cruiseStepsInRange }
            { name: "segmentsNeverCrossEllipses", fn: brainTest_segmentsNeverCrossEllipses }
            { name: "segmentsAreContinuous", fn: brainTest_segmentsAreContinuous }
            { name: "dartStartsOnApprovedPoint", fn: brainTest_dartStartsOnApprovedPoint }
            { name: "dartIsFastThenCruise", fn: brainTest_dartIsFastThenCruise }
            { name: "noDartWithZeroChance", fn: brainTest_noDartWithZeroChance }
            { name: "sameSeedSameSegments", fn: brainTest_sameSeedSameSegments }
            { name: "facingDeadband", fn: brainTest_facingDeadband }
            { name: "wanderPullCutsFlips", fn: brainTest_wanderPullCutsFlips }
            { name: "speedBucket", fn: brainTest_speedBucket }
            { name: "polylineAt", fn: brainTest_polylineAt }
            { name: "outCubic", fn: brainTest_outCubic }
        ]
    }
end function

function brainTest_cfg() as object
    return {
        tick: 0.125, segMinSec: 0.5, segMaxSec: 1.5, minSpeed: 35, maxSpeed: 110
        wanderJitter: 3.0, wanderAccel: 80, avoidMargin: 0.5, avoidAccel: 300
        laneBand: 80, laneAccel: 400, dartChance: 0.004, dartSpeed: 420
        dartTurn: 1.2, dartSteps: 4, facingDeadband: 6, speedBucket: 15, spawnMargin: 0.3
    }
end function

function brainTest_lane() as object
    return { left: 160, top: 200, right: 1760, bottom: 900 }
end function

function brainTest_ellipses() as object
    return [
        { cx: 470, cy: 640, rx: 150, ry: 110 }
        { cx: 900, cy: 420, rx: 120, ry: 90 }
        { cx: 1300, cy: 700, rx: 180, ry: 100 }
        { cx: 1560, cy: 380, rx: 90, ry: 80 }
    ]
end function

' Raw inside test, independent of steer.brs helpers.
function brainTest_inside(ellipses as object, x as float, y as float) as boolean
    for each e in ellipses
        ux = (x - e.cx) / e.rx
        uy = (y - e.cy) / e.ry
        if ux * ux + uy * uy < 1 then return true
    end for
    return false
end function

' Runs fish `seed` for `ticks` ticks and returns every segment issued as
' { tick, kind, points }.
function brainTest_run(seed as integer, ticks as integer, cfg as object) as object
    lane = brainTest_lane()
    ellipses = brainTest_ellipses()
    fish = brainNewFish(cfg, seed, lane, ellipses)
    out = []
    for now = 0 to ticks - 1
        kind = brainTickFish(fish, cfg, lane, ellipses, now)
        if kind <> "" then out.push({ tick: now, kind: kind, points: fish.points, startTick: fish.startTick, steps: fish.steps })
    end for
    return out
end function

sub brainTest_spawnOutsideEllipsesInLane(t as object)
    cfg = brainTest_cfg()
    lane = brainTest_lane()
    ellipses = brainTest_ellipses()
    bad = 0
    for seed = 1 to 200
        fish = brainNewFish(cfg, seed, lane, ellipses)
        if fish = invalid then
            bad = bad + 1
        else
            a = fish.agent
            if brainTest_inside(ellipses, a.x, a.y) then bad = bad + 1
            if a.x < lane.left or a.x > lane.right or a.y < lane.top or a.y > lane.bottom then bad = bad + 1
        end if
    end for
    assertEqual(t, bad, 0, "spawns inside an ellipse or outside the lane")
end sub

sub brainTest_cruiseStepsInRange(t as object)
    cfg = brainTest_cfg()
    rng = prngNew(5)
    lo = 99
    hi = 0
    for i = 1 to 2000
        s = brainCruiseSteps(cfg, rng)
        if s < lo then lo = s
        if s > hi then hi = s
    end for
    assertEqual(t, lo, 4, "min steps (0.5 s)")
    assertEqual(t, hi, 12, "max steps (1.5 s)")
end sub

' Every drawn piece of every segment, darts included, stays outside every
' ellipse: no point is inside and no straight piece passes through one.
sub brainTest_segmentsNeverCrossEllipses(t as object)
    cfg = brainTest_cfg()
    cfg.dartChance = 0.05
    ellipses = brainTest_ellipses()
    bad = 0
    pieces = 0
    for seed = 1 to 25
        for each seg in brainTest_run(seed, 1200, cfg)
            p = seg.points
            for i = 0 to p.count() - 1
                if brainTest_inside(ellipses, p[i][0], p[i][1]) then bad = bad + 1
                if i > 0 then
                    pieces = pieces + 1
                    if steerFirstHit(ellipses, p[i - 1][0], p[i - 1][1], p[i][0], p[i][1]) >= 0 then bad = bad + 1
                end if
            end for
        end for
    end for
    assertEqual(t, bad, 0, "points or pieces inside an ellipse")
    assertTrue(t, pieces > 25000, "enough pieces checked (" + pieces.toStr() + ")")
end sub

' Each segment starts where the fish is drawn at that tick: the previous
' segment's end, or for a dart the cruise point reached at the dart's tick.
sub brainTest_segmentsAreContinuous(t as object)
    cfg = brainTest_cfg()
    cfg.dartChance = 0.05
    segs = brainTest_run(9, 2000, cfg)
    gaps = 0
    for i = 1 to segs.count() - 1
        prev = segs[i - 1]
        cur = segs[i]
        idx = cur.tick - prev.startTick
        if idx > prev.steps then idx = prev.steps
        expect = prev.points[idx]
        if Abs(expect[0] - cur.points[0][0]) > 0.001 or Abs(expect[1] - cur.points[0][1]) > 0.001 then gaps = gaps + 1
    end for
    assertEqual(t, gaps, 0, "segment start jumps")
end sub

sub brainTest_dartStartsOnApprovedPoint(t as object)
    cfg = brainTest_cfg()
    cfg.dartChance = 0.05
    segs = brainTest_run(3, 2000, cfg)
    darts = 0
    midDarts = 0
    for i = 1 to segs.count() - 1
        if segs[i].kind = "dart" then
            darts = darts + 1
            prev = segs[i - 1]
            idx = segs[i].tick - prev.startTick
            if idx > 0 and idx < prev.steps then midDarts = midDarts + 1
            assertEqual(t, prev.kind, "segment", "a dart only interrupts a cruise segment")
        end if
    end for
    assertTrue(t, darts >= 10, "darts happen at 5% per tick")
    assertEqual(t, midDarts, darts, "every dart starts mid-segment")
end sub

' Most darts open far above cruise maxSpeed, and the following cruise
' segment is back within the cruise clamp.
sub brainTest_dartIsFastThenCruise(t as object)
    cfg = brainTest_cfg()
    cfg.dartChance = 0.05
    segs = brainTest_run(11, 2000, cfg)
    checked = 0
    fast = 0
    for i = 0 to segs.count() - 2
        if segs[i].kind = "dart" and segs[i + 1].kind = "segment" then
            p = segs[i].points
            dx = p[1][0] - p[0][0]
            dy = p[1][1] - p[0][1]
            v = Sqr(dx * dx + dy * dy) / cfg.tick
            if v > cfg.maxSpeed * 2 then fast = fast + 1
            q = segs[i + 1].points
            dx = q[1][0] - q[0][0]
            dy = q[1][1] - q[0][1]
            w = Sqr(dx * dx + dy * dy) / cfg.tick
            assertTrue(t, w <= cfg.maxSpeed + 0.01, "next cruise is clamped (" + w.toStr() + " px/s)")
            checked = checked + 1
        end if
    end for
    assertTrue(t, checked >= 5, "enough darts checked")
    ' Lane-keep and the ellipse guard may deflect a dart aimed at a wall, so
    ' only most darts must open at full speed.
    assertTrue(t, fast * 10 >= checked * 7, "most darts open fast (" + fast.toStr() + " of " + checked.toStr() + ")")
end sub

sub brainTest_noDartWithZeroChance(t as object)
    cfg = brainTest_cfg()
    cfg.dartChance = 0
    darts = 0
    for each seg in brainTest_run(4, 2000, cfg)
        if seg.kind = "dart" then darts = darts + 1
    end for
    assertEqual(t, darts, 0, "darts at zero chance")
end sub

sub brainTest_sameSeedSameSegments(t as object)
    cfg = brainTest_cfg()
    cfg.dartChance = 0.02
    a = brainTest_run(42, 800, cfg)
    b = brainTest_run(42, 800, cfg)
    c = brainTest_run(43, 800, cfg)
    assertEqual(t, a.count(), b.count(), "segment count")
    diffs = 0
    for i = 0 to a.count() - 1
        if a[i].tick <> b[i].tick or a[i].kind <> b[i].kind then diffs = diffs + 1
        pa = a[i].points[a[i].points.count() - 1]
        pb = b[i].points[b[i].points.count() - 1]
        if pa[0] <> pb[0] or pa[1] <> pb[1] then diffs = diffs + 1
    end for
    assertEqual(t, diffs, 0, "same seed differs")
    endA = a[a.count() - 1].points[0]
    endC = c[c.count() - 1].points[0]
    assertTrue(t, endA[0] <> endC[0] or endA[1] <> endC[1], "different seed gives a different path")
end sub

sub brainTest_facingDeadband(t as object)
    assertEqual(t, brainFacing(1, -10, 6), -1, "left past deadband flips")
    assertEqual(t, brainFacing(1, -5, 6), 1, "inside deadband keeps")
    assertEqual(t, brainFacing(-1, 3, 6), -1, "inside deadband keeps left")
    assertEqual(t, brainFacing(-1, 7, 6), 1, "right past deadband flips")
end sub

' Facing flips over 20 fish x 300 s: the wander pull and the wider deadband (config/brain.json)
' must leave a fraction of what the unpulled wander flipped.
function brainTest_flips(cfg as object) as integer
    flips = 0
    for seed = 1 to 20
        facing = 1
        for each seg in brainTest_run(seed, 2400, cfg)
            last = seg.points[seg.points.count() - 1]
            nextFacing = brainFacing(facing, last[0] - seg.points[0][0], cfg.facingDeadband)
            if nextFacing <> facing then flips = flips + 1
            facing = nextFacing
        end for
    end for
    return flips
end function

sub brainTest_wanderPullCutsFlips(t as object)
    old = brainTest_flips(brainTest_cfg())
    pulled = brainTest_cfg()
    pulled.wanderPull = 2.0
    pulled.facingDeadband = 40
    now = brainTest_flips(pulled)
    print "  brain flips over 20 fish x 300 s: unpulled = "; old; ", pulled = "; now
    assertTrue(t, now * 3 < old, "pull and deadband cut flips to under a third")
end sub

sub brainTest_speedBucket(t as object)
    assertEqual(t, brainBucket(52, 15), 45, "rounds down")
    assertEqual(t, brainBucket(53, 15), 60, "rounds up")
    assertEqual(t, brainBucket(2, 15), 15, "at least one bucket")
end sub

sub brainTest_polylineAt(t as object)
    p = [[0, 0], [10, 0], [10, 20]]
    q = brainPolylineAt(p, 0.25)
    assertNear(t, q[0], 5, 0.001, "x at 0.25")
    q = brainPolylineAt(p, 0.75)
    assertNear(t, q[0], 10, 0.001, "x at 0.75")
    assertNear(t, q[1], 10, 0.001, "y at 0.75")
    q = brainPolylineAt(p, 1.5)
    assertNear(t, q[1], 20, 0.001, "clamped end")
end sub

sub brainTest_outCubic(t as object)
    assertNear(t, brainOutCubic(0), 0, 0.0001, "start")
    assertNear(t, brainOutCubic(1), 1, 0.0001, "end")
    assertNear(t, brainOutCubic(0.5), 0.875, 0.0001, "mid is past halfway")
end sub
