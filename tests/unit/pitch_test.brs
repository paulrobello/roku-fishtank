' Unit tests for the fish pitch in components/lib/brain.brs. SceneGraph
' rotation is counter-clockwise positive and screen y grows down, so nose-up
' is positive facing right and negative facing left. The pitch block mirrors
' config/brain.json, copied so a config edit cannot weaken the tests.

function pitchTestSuite() as object
    return {
        name: "pitch"
        tests: [
            { name: "slowDriftStaysNearLevel", fn: pitchTest_slowDriftStaysNearLevel }
            { name: "dartUpFacingRightIsNoseUp", fn: pitchTest_dartUpFacingRightIsNoseUp }
            { name: "dartUpFacingLeftIsNoseUp", fn: pitchTest_dartUpFacingLeftIsNoseUp }
            { name: "dartDownIsNoseDown", fn: pitchTest_dartDownIsNoseDown }
            { name: "clampedAtMax", fn: pitchTest_clampedAtMax }
            { name: "levelAndStillAreZero", fn: pitchTest_levelAndStillAreZero }
            { name: "seriesEasesFromCarriedPitch", fn: pitchTest_seriesEasesFromCarriedPitch }
            { name: "segmentCarriesPitch", fn: pitchTest_segmentCarriesPitch }
        ]
    }
end function

function pitchTest_p() as object
    return { maxDeg: 28, cruiseDeg: 4, speedLo: 120, speedHi: 300, follow: 0.55 }
end function

function pitchTest_deg(rad as float) as float
    return rad * 180.0 / 3.14159265
end function

' A drift straight up at 20 px/s (one 0.125 s tick = 2.5 px) tilts no more
' than cruiseDeg, and a gentle cruise climb tilts by its own small slope.
sub pitchTest_slowDriftStaysNearLevel(t as object)
    p = pitchTest_p()
    up = pitchTest_deg(brainPitchTarget(p, 0, -2.5, 0.125, 1))
    assertNear(t, up, 4.0, 0.01, "vertical drift is capped at cruiseDeg")
    ' 100 px/s cruise rising at about 2.9 deg.
    gentle = pitchTest_deg(brainPitchTarget(p, 12.49, -0.625, 0.125, 1))
    assertTrue(t, gentle > 2.5 and gentle < 3.1, "gentle climb keeps its slope, got " + Str(gentle))
end sub

' A 420 px/s dart rising at 20 deg, facing right: counter-clockwise, 20 deg.
sub pitchTest_dartUpFacingRightIsNoseUp(t as object)
    a = 20 * 3.14159265 / 180.0
    dx = 52.5 * Cos(a)
    dy = -52.5 * Sin(a)
    assertNear(t, pitchTest_deg(brainPitchTarget(pitchTest_p(), dx, dy, 0.125, 1)), 20.0, 0.01)
end sub

' The same rising dart travelling left, facing left: clockwise, -20 deg, so
' the head on the left rises.
sub pitchTest_dartUpFacingLeftIsNoseUp(t as object)
    a = 20 * 3.14159265 / 180.0
    dx = -52.5 * Cos(a)
    dy = -52.5 * Sin(a)
    assertNear(t, pitchTest_deg(brainPitchTarget(pitchTest_p(), dx, dy, 0.125, -1)), -20.0, 0.01)
end sub

sub pitchTest_dartDownIsNoseDown(t as object)
    a = 15 * 3.14159265 / 180.0
    right = brainPitchTarget(pitchTest_p(), 52.5 * Cos(a), 52.5 * Sin(a), 0.125, 1)
    left = brainPitchTarget(pitchTest_p(), -52.5 * Cos(a), 52.5 * Sin(a), 0.125, -1)
    assertNear(t, pitchTest_deg(right), -15.0, 0.01, "facing right, diving")
    assertNear(t, pitchTest_deg(left), 15.0, 0.01, "facing left, diving")
end sub

' A near-vertical dart tips by maxDeg and no further, both facings and both
' ways; halfway up the speed ramp the limit is halfway between the caps.
sub pitchTest_clampedAtMax(t as object)
    p = pitchTest_p()
    assertNear(t, pitchTest_deg(brainPitchTarget(p, 5, -52, 0.125, 1)), 28.0, 0.01, "up, right")
    assertNear(t, pitchTest_deg(brainPitchTarget(p, -5, -52, 0.125, -1)), -28.0, 0.01, "up, left")
    assertNear(t, pitchTest_deg(brainPitchTarget(p, 5, 52, 0.125, 1)), -28.0, 0.01, "down, right")
    ' 210 px/s straight up: limit 4 + 24 * 0.5 = 16 deg.
    assertNear(t, pitchTest_deg(brainPitchTarget(p, 0, -26.25, 0.125, 1)), 16.0, 0.01, "mid ramp")
end sub

sub pitchTest_levelAndStillAreZero(t as object)
    p = pitchTest_p()
    assertNear(t, brainPitchTarget(p, 52.5, 0, 0.125, 1), 0.0, 0.0001, "level dart")
    assertNear(t, brainPitchTarget(p, -52.5, 0, 0.125, -1), 0.0, 0.0001, "level dart left")
    assertNear(t, brainPitchTarget(p, 0, 0, 0.125, 1), 0.0, 0.0001, "still")
end sub

' A dart straight up from a carried pitch: the series starts at the carried
' value and closes on the target monotonically without overshoot; a level
' segment afterwards eases back toward zero.
sub pitchTest_seriesEasesFromCarriedPitch(t as object)
    p = pitchTest_p()
    target = 28 * 3.14159265 / 180.0
    pts = [[0, 0], [2, -52], [4, -104], [6, -156], [8, -208]]
    s = brainPitchSeries(p, pts, 0.05, 1, 0.125)
    assertEqual(t, s.count(), 5)
    assertNear(t, s[0], 0.05, 0.0001, "starts at the carried pitch")
    assertNear(t, s[1], 0.05 + (target - 0.05) * 0.55, 0.0001, "first tick closes follow of the gap")
    for i = 1 to 4
        assertTrue(t, s[i] > s[i - 1] and s[i] <= target + 0.0001, "monotone, no overshoot at " + i.toStr())
    end for
    level = brainPitchSeries(p, [[8, -208], [20, -208], [32, -208], [44, -208]], s[4], 1, 0.125)
    for i = 1 to 3
        assertTrue(t, level[i] < level[i - 1] and level[i] > 0, "eases out toward level at " + i.toStr())
    end for
end sub

' brainStartSegment reads the old segment's pitch at the cut tick before it
' replaces the segment, so a dart cut mid-cruise starts from the cruise tilt.
sub pitchTest_segmentCarriesPitch(t as object)
    cfg = brainTest_cfg()
    cfg.pitch = pitchTest_p()
    fish = { points: [[0, 0], [10, -1], [20, -2], [30, -3]], startTick: 10, steps: 3, facing: 1, lockFacing: 0, pitches: [0.0, 0.01, 0.02, 0.03] }
    fish.points = [[20, -2], [70, -50], [120, -100]]
    brainStartSegment(fish, cfg, 12, 2, true)
    assertNear(t, fish.pitches[0], 0.02, 0.0001, "carried from tick 12 of the old segment")
    assertEqual(t, fish.pitches.count(), 3)
    assertTrue(t, fish.pitches[2] > fish.pitches[1] and fish.pitches[1] > 0.02, "tips nose-up into the dart")
    assertNear(t, brainPitchAtTick(fish, 14), fish.pitches[2], 0.0001)
    assertNear(t, brainPitchAtTick(fish, 99), fish.pitches[2], 0.0001, "clamped past the end")
    cfg.Delete("pitch")
    brainStartSegment(fish, cfg, 14, 2, false)
    assertTrue(t, fish.pitches = invalid, "no pitch block, no pitches")
    assertNear(t, brainPitchAtTick(fish, 15), 0.0, 0.0001)
end sub
