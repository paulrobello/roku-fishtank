' Unit tests for the arch swimmer loop: components/lib/arch.brs. The config mirrors
' config/arch.json so a config edit cannot silently weaken the tests.

function archTestSuite() as object
    return {
        name: "arch"
        tests: [
            { name: "seedRules", fn: archTest_seedRules }
            { name: "clipIsInsetOverlay", fn: archTest_clipIsInsetOverlay }
            { name: "planIsDeterministic", fn: archTest_planIsDeterministic }
            { name: "passagesKeepTheirGapsAllSeeds", fn: archTest_passagesKeepTheirGapsAllSeeds }
            { name: "passagesStayInTheBandAllSeeds", fn: archTest_passagesStayInTheBandAllSeeds }
            { name: "tracksLoopSeamlesslyAllSeeds", fn: archTest_tracksLoopSeamlesslyAllSeeds }
            { name: "fishHiddenOffPassageAllSeeds", fn: archTest_fishHiddenOffPassageAllSeeds }
            { name: "bothDirectionsSwim", fn: archTest_bothDirectionsSwim }
            { name: "pitchFollowsTheClimb", fn: archTest_pitchFollowsTheClimb }
        ]
    }
end function

function archTest_cfg() as object
    return {
        layer: "waterGradient"
        overlay: { uri: "pkg:/images/decor/arch_overlay.png", x: 240, y: 480, width: 416, height: 192 }
        clipInset: 2
        species: "royal_gramma"
        scale: 0.45
        tint: "0x7890B8FF"
        swimSpeed: 70
        passages: 6
        firstGapSec: [10, 30]
        gapSec: [20, 60]
        speedPx: [26, 40]
        yBand: [548, 584]
        waveAmp: [2, 6]
        waveCycles: [0.5, 1.5]
        keysPerPassage: 12
        pitchMaxDeg: 8
        parkGap: 40
        parkBelow: 60
        hopSec: 0.5
    }
end function

' royal_gramma.rig.json: bounds x -22..88, y 0..50 around mirror_center (33, 25).
function archTest_halfExtent() as object
    s = archTest_cfg().scale
    return { x: 55 * s, y: 25 * s }
end function

sub archTest_seedRules(t as object)
    assertEqual(t, archSeed(7, 3.0, 99), 7, "preview seed wins")
    assertEqual(t, archSeed(0, 3.0, 99), 1, "freeze without seed is 1")
    assertEqual(t, archSeed(0, 0.0, 99), 99, "otherwise the clock")
end sub

sub archTest_clipIsInsetOverlay(t as object)
    c = archClip(archTest_cfg())
    assertEqual(t, c.x, 242, "x")
    assertEqual(t, c.y, 482, "y")
    assertEqual(t, c.width, 412, "width")
    assertEqual(t, c.height, 188, "height")
end sub

sub archTest_planIsDeterministic(t as object)
    a = archPlan(archTest_cfg(), prngNew(7))
    b = archPlan(archTest_cfg(), prngNew(7))
    c = archPlan(archTest_cfg(), prngNew(8))
    assertEqual(t, FormatJson(a.tracks), FormatJson(b.tracks), "same seed, same loop")
    assertTrue(t, FormatJson(a.tracks) <> FormatJson(c.tracks), "another seed, another loop")
end sub

sub archTest_passagesKeepTheirGapsAllSeeds(t as object)
    cfg = archTest_cfg()
    for seed = 1 to 40
        plan = archPlan(cfg, prngNew(seed))
        ps = plan.passages
        assertEqual(t, ps.count(), cfg.passages, "passage count")
        assertTrue(t, ps[0].start >= cfg.firstGapSec[0] and ps[0].start <= cfg.firstGapSec[1], "first gap, seed " + seed.toStr())
        for k = 1 to ps.count() - 1
            gap = ps[k].start - ps[k - 1].finish
            assertTrue(t, gap >= cfg.gapSec[0] - 0.001 and gap <= cfg.gapSec[1] + 0.001, "gap " + k.toStr() + ", seed " + seed.toStr())
        end for
        for each p in ps
            sec = p.finish - p.start
            assertTrue(t, sec >= 492 / cfg.speedPx[1] - 0.01 and sec <= 492 / cfg.speedPx[0] + 0.01, "passage speed, seed " + seed.toStr())
        end for
        assertTrue(t, plan.duration - ps[ps.count() - 1].finish >= cfg.gapSec[0] - 0.001, "loop tail gap")
    end for
end sub

sub archTest_passagesStayInTheBandAllSeeds(t as object)
    cfg = archTest_cfg()
    limit = cfg.pitchMaxDeg * 3.14159265 / 180.0 + 0.0001
    for seed = 1 to 40
        for each p in archPlan(cfg, prngNew(seed)).passages
            for i = 0 to p.points.count() - 1
                y = p.points[i][1]
                assertTrue(t, y >= cfg.yBand[0] - 0.01 and y <= cfg.yBand[1] + 0.01, "y in band, seed " + seed.toStr())
                assertTrue(t, Abs(p.rots[i]) <= limit, "pitch clamped, seed " + seed.toStr())
            end for
        end for
    end for
end sub

sub archTest_tracksLoopSeamlesslyAllSeeds(t as object)
    for seed = 1 to 40
        for each track in archPlan(archTest_cfg(), prngNew(seed)).tracks
            n = track.keys.count()
            assertEqual(t, track.points.count(), n, "one point per key")
            assertEqual(t, track.rots.count(), n, "one rotation per key")
            assertEqual(t, track.keys[0], 0.0, "starts at 0")
            assertTrue(t, Abs(track.keys[n - 1] - 1.0) < 0.000001, "ends at 1")
            for i = 1 to n - 1
                assertTrue(t, track.keys[i] > track.keys[i - 1], "keys increase, seed " + seed.toStr())
            end for
            assertEqual(t, FormatJson(track.points[0]), FormatJson(track.points[n - 1]), "loop closes")
        end for
    end for
end sub

' Off a passage every keyframe segment lies wholly outside the clip, with the scaled rig
' bounds clear of it: both ends below it, or both beyond the same side.
sub archTest_fishHiddenOffPassageAllSeeds(t as object)
    cfg = archTest_cfg()
    c = archClip(cfg)
    h = archTest_halfExtent()
    for seed = 1 to 40
        plan = archPlan(cfg, prngNew(seed))
        for f = 0 to 1
            track = plan.tracks[f]
            for i = 1 to track.keys.count() - 1
                tm = (track.keys[i - 1] + track.keys[i]) / 2 * plan.duration
                inside = false
                for each p in plan.passages
                    if tm > p.start and tm < p.finish then inside = true
                end for
                if not inside then
                    a = track.points[i - 1]
                    b = track.points[i]
                    below = a[1] - h.y > c.y + c.height and b[1] - h.y > c.y + c.height
                    left = a[0] + h.x < c.x and b[0] + h.x < c.x
                    right = a[0] - h.x > c.x + c.width and b[0] - h.x > c.x + c.width
                    assertTrue(t, below or left or right, "segment " + i.toStr() + " of fish " + f.toStr() + " hidden, seed " + seed.toStr())
                end if
            end for
        end for
    end for
end sub

sub archTest_bothDirectionsSwim(t as object)
    rights = 0
    lefts = 0
    for seed = 1 to 10
        for each p in archPlan(archTest_cfg(), prngNew(seed)).passages
            if p.dir > 0 then rights = rights + 1 else lefts = lefts + 1
            if p.dir > 0 then
                assertTrue(t, p.points[0][0] < p.points[p.points.count() - 1][0], "right-swimmer moves right")
            else
                assertTrue(t, p.points[0][0] > p.points[p.points.count() - 1][0], "left-swimmer moves left")
            end if
        end for
    end for
    assertTrue(t, rights > 10 and lefts > 10, "both directions occur")
end sub

sub archTest_pitchFollowsTheClimb(t as object)
    assertTrue(t, archPitch(100, -10, 8, 1) > 0, "rising to the right is counter-clockwise")
    assertTrue(t, archPitch(-100, -10, 8, -1) < 0, "rising to the left is clockwise")
    assertTrue(t, archPitch(100, 10, 8, 1) < 0, "sinking to the right is clockwise")
    assertTrue(t, Abs(archPitch(100, -1000, 8, 1) - 8 * 3.14159265 / 180.0) < 0.0001, "clamped to maxDeg")
    assertEqual(t, archPitch(0, 5, 8, 1), 0.0, "no heading, no pitch")
end sub
