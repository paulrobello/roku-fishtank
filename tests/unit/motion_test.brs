function motionTestSuite() as object
    return {
        name: "motion"
        tests: [
            { name: "smoothPreservesWaypoints", fn: motionTest_waypoints }
            { name: "unsafeCurveFallsBack", fn: motionTest_obstacle }
            { name: "safeHandoffOnly", fn: motionTest_bridge }
            { name: "actualPathAndDartSpeed", fn: motionTest_speed }
            { name: "elapsedTimeInvariant", fn: motionTest_follow }
            { name: "schoolSpacingBetweenSamples", fn: motionTest_school }
            { name: "seededCurvesRemainClear", fn: motionTest_seeded }
            { name: "handoffDoesNotSpikeSpeed", fn: motionTest_handoffSpeed }
            { name: "wholeCorrectionIsObstacleChecked", fn: motionTest_handoffObstacle }
            { name: "handoffDartUsesWallTime", fn: motionTest_handoffDart }
        ]
    }
end function

sub motionTest_waypoints(t as object)
    original = [[0, 0], [1, 1], [2, 1], [3, -1]]
    points = motionSmoothPath(original, [])
    assertEqual(t, points.count(), 13, "four samples per interval")
    for i = 0 to original.count() - 1
        assertNear(t, points[i * 4][0], original[i][0], 0.00001, "preserve x waypoint")
        assertNear(t, points[i * 4][1], original[i][1], 0.00001, "preserve y waypoint")
    end for
    for i = 0 to 3
        assertTrue(t, points[i][0] >= 0 and points[i][0] <= 1, "no x overshoot")
        assertTrue(t, points[i][1] >= 0 and points[i][1] <= 1, "no y overshoot")
    end for
    assertTrue(t, points[2][1] > 0.5, "curve rounds toward continuous tangent")
    line = motionSmoothPath([[0, 0], [10, 0], [20, 0]], [])
    for i = 0 to 8
        assertNear(t, line[i][0], i * 2.5, 0.00001, "constant velocity remains constant")
    end for
end sub

sub motionTest_obstacle(t as object)
    original = [[0, 0], [1, 1], [2, 1]]
    rocks = [{ cx: 0.5, cy: 0.625, rx: 0.03, ry: 0.03 }]
    points = motionSmoothPath(original, rocks)
    assertNear(t, points[2][1], 0.5, 0.00001, "unsafe rounded span falls back to straight")
    for i = 1 to points.count() - 1
        a = points[i - 1]
        b = points[i]
        assertEqual(t, steerFirstHit(rocks, a[0], a[1], b[0], b[1]), -1, "every rendered chord stays clear")
    end for
end sub

sub motionTest_bridge(t as object)
    path = motionBridge([[0, 0], [2, 0]], [-0.2, 0], [], 1.0)
    assertNear(t, path[0][0], -0.2, 0.00001, "start from displayed location")
    rocks = [{ cx: 0, cy: 1, rx: 0.3, ry: 0.3 }]
    path = motionBridge([[0, 0], [1, 0]], [-1, 2], rocks, 1.0)
    assertNear(t, path[0][0], 0, 0.00001, "unsafe bridge preserves approved path")
end sub

sub motionTest_speed(t as object)
    path = [[0, 0], [10, 0], [10, 0]]
    assertNear(t, motionPathSpeed(path, 0.1, 2, false), 10, 0.00001, "local moving speed")
    assertNear(t, motionPathSpeed(path, 1.5, 2, false), 0, 0.00001, "hold stops tail propulsion")
    assertNear(t, motionPathSpeed(path, 2, 2, false), 0, 0.00001, "finished path is stationary")
    path = [[0, 0], [100, 0]]
    assertNear(t, motionPathSpeed(path, 0, 1, true), 300, 0.00001, "dart launch follows ease derivative")
    assertNear(t, motionPathSpeed(path, 0.5, 1, true), 75, 0.00001, "dart coast slows")
    assertNear(t, motionPathSpeed([[1000, -50], [1100, -50]], 0.5, 1, true), 75, 0.00001, "translation offset does not alter speed")
end sub

sub motionTest_follow(t as object)
    single = motionFollowSpeed(10, 100, 0.5)
    many = 10.0
    for i = 1 to 5
        many = motionFollowSpeed(many, 100, 0.1)
    end for
    assertNear(t, many, single, 0.0001, "attack independent of callback frequency")
    single = motionFollowSpeed(100, 0, 0.5)
    many = 100.0
    for i = 1 to 5
        many = motionFollowSpeed(many, 0, 0.1)
    end for
    assertNear(t, many, single, 0.0001, "decay independent of callback frequency")
    assertEqual(t, motionFollowSpeed(10, 100, 0), 10, "zero elapsed time")
end sub

sub motionTest_school(t as object)
    assertTrue(t, motionSchoolClear([[[0, 0], [10, 0]], [[0, 5], [10, 5]]], 4), "parallel school keeps spacing")
    assertEqual(t, motionSchoolClear([[[0, 0], [10, 0]], [[10, 0], [0, 0]]], 4), false, "crossing between samples rejected")
end sub

sub motionTest_seeded(t as object)
    cfg = brainTest_cfg()
    ellipses = brainTest_ellipses()
    for seed = 1 to 5
        segments = brainTest_run(seed, 80, cfg)
        for each segment in segments
            points = motionSmoothPath(segment.points, ellipses)
            for i = 1 to points.count() - 1
                a = points[i - 1]
                b = points[i]
                if not assertEqual(t, steerFirstHit(ellipses, a[0], a[1], b[0], b[1]), -1, "seeded rendered path stays obstacle-safe") then return
            end for
        end for
    end for
end sub

sub motionTest_handoffSpeed(t as object)
    points = []
    for i = 0 to 32
        points.push([i * 3.125, 0.0])
    end for
    corrected = motionBridge(points, [-1.0, 0.0], [], 1.0)
    assertNear(t, corrected[0][0], -1, 0.00001, "exact displayed start")
    assertNear(t, corrected[32][0], 100, 0.00001, "original final position/time")
    peak = 0.0
    for i = 1 to 32
        speed = (corrected[i][0] - corrected[i - 1][0]) / 0.03125
        if speed > peak then peak = speed
    end for
    assertTrue(t, peak < 105, "one-pixel correction adds less than 5px/s, not old 32px/s spike")
    assertNear(t, points[0][0], 0, 0.00001, "approved input path not mutated")
    assertNear(t, corrected[12][0], points[12][0], 0.00001, "correction finishes after blend window")
    coarse = [[0.0, 0.0], [12.5, 0.0], [25.0, 0.0], [37.5, 0.0], [50.0, 0.0], [62.5, 0.0], [75.0, 0.0], [87.5, 0.0], [100.0, 0.0]]
    coarse = motionBridge(coarse, [-1.0, 0.0], [], 1.0)
    for i = 0 to 8
        assertNear(t, coarse[i][0], corrected[i * 4][0], 0.00001, "correction depends on time, not sample count")
    end for
end sub

sub motionTest_handoffObstacle(t as object)
    points = [[0.0, 0.0], [1.0, 0.0], [2.0, 0.0], [3.0, 0.0], [4.0, 0.0]]
    clear = motionBridge(points, [0.0, 1.0], [], 0.5)
    rock = { cx: clear[1][0], cy: clear[1][1], rx: 0.05, ry: 0.05 }
    blocked = motionBridge(points, [0.0, 1.0], [rock], 0.5)
    assertNear(t, blocked[0][1], 0, 0.00001, "collision later in corrected path rejects whole correction")
    assertNear(t, clear[4][1], 0, 0.00001, "clear correction returns to path")
end sub

sub motionTest_handoffDart(t as object)
    points = [[0.0, 0.0], [25.0, 0.0], [50.0, 0.0], [75.0, 0.0], [100.0, 0.0]]
    corrected = motionBridge(points, [0.0, 1.0], [], 0.5, true)
    elapsed = 0.5 * (1.0 - 0.75 ^ (1.0 / 3.0))
    u = elapsed / 0.35
    assertNear(t, corrected[1][1], 1.0 - u * u * (3.0 - 2.0 * u), 0.00001, "dart correction follows elapsed time, not eased path fraction")
    assertNear(t, corrected[4][1], 0, 0.00001, "dart final waypoint preserved")
    short = motionBridge(points, [0.0, 1.0], [], 0.1)
    assertNear(t, short[4][1], 0, 0.00001, "short segment finishes correction at endpoint")
    unchanged = motionBridge(points, [0.0, 0.0], [], 0.5)
    for i = 0 to 4
        assertNear(t, unchanged[i][0], points[i][0], 0.00001, "zero correction preserves x")
        assertNear(t, unchanged[i][1], points[i][1], 0.00001, "zero correction preserves y")
    end for
end sub
