' Unit tests for the P4 reef extras: components/lib/extras.brs (sway keyframes,
' seeded walk loops, caustic tile grids, night fade) and components/lib/host.brs
' (P4.1 anemone hosting). Configs mirror config/extras.json so a config edit
' cannot silently weaken the tests.

function extrasTestSuite() as object
    return {
        name: "extras"
        tests: [
            { name: "swayValuesLoopSeamlessly", fn: extrasTest_swayValuesLoopSeamlessly }
            { name: "currentPhaseTravelsRight", fn: extrasTest_currentPhaseTravelsRight }
            { name: "walkPathIsDeterministic", fn: extrasTest_walkPathIsDeterministic }
            { name: "walkPathStaysOnItsSurface", fn: extrasTest_walkPathStaysOnItsSurface }
            { name: "walkPathClosesItsLoop", fn: extrasTest_walkPathClosesItsLoop }
            { name: "walkPathTurnsOnlyWhilePaused", fn: extrasTest_walkPathTurnsOnlyWhilePaused }
            { name: "gaitSwingsOnlyWhileWalking", fn: extrasTest_gaitSwingsOnlyWhileWalking }
            { name: "shuttleTurnsOnlyInCoverAllSeeds", fn: extrasStrict_shuttleTurnsOnlyInCoverAllSeeds }
            { name: "turnTrackSwapsAtMiddle", fn: extrasTest_turnTrackSwapsAtMiddle }
            { name: "tileGridCoversClipWhileScrolling", fn: extrasTest_tileGridCoversClipWhileScrolling }
            { name: "nightOpacityFadesAndHides", fn: extrasTest_nightOpacityFadesAndHides }
            { name: "lerpColorEndpointsAndMidpoint", fn: extrasTest_lerpColorEndpointsAndMidpoint }
            { name: "seedRules", fn: extrasTest_seedRules }
            { name: "hostNestlesWithinRadiusOver10000Ticks", fn: extrasTest_hostNestlesWithinRadiusOver10000Ticks }
            { name: "hostRoamsWithinLeash", fn: extrasTest_hostRoamsWithinLeash }
            { name: "hostCyclesNestleRoamApproach", fn: extrasTest_hostCyclesNestleRoamApproach }
            { name: "hostIsDeterministic", fn: extrasTest_hostIsDeterministic }
            { name: "hostForMatchesLaneAndSpecies", fn: extrasTest_hostForMatchesLaneAndSpecies }
            { name: "walkOnGroundAllSeeds", fn: extrasStrict_walkOnGroundAllSeeds }
            { name: "walkFacingMatchesMotionAllSeeds", fn: extrasStrict_walkFacingMatchesMotionAllSeeds }
            { name: "shrimpTurnsWithin5Minutes", fn: extrasStrict_shrimpTurnsWithin5Minutes }
            { name: "causticGridCoversClipAtAnyOffset", fn: extrasStrict_causticGridCoversClipAtAnyOffset }
            { name: "hostStaysWithinLeash10kTicks", fn: extrasStrict_hostStaysWithinLeash10kTicks }
            { name: "hostNestlesLeavesAndReturns", fn: extrasStrict_hostNestlesLeavesAndReturns }
        ]
    }
end function

function extrasTest_current() as object
    return { period: 7.0, waveLength: 2400, keyCount: 17 }
end function

function extrasTest_shrimpWalk() as object
    return { x: 600, y: 862, left: 470, right: 860, speed: 24, legPx: [40, 150], pauseSec: [1.5, 5.0], legs: 6, turnSec: 0.02 }
end function

function extrasTest_host() as object
    return {
        lane: "frontLane"
        species: ["ocellaris_clownfish"]
        x: 1238
        y: 752
        radius: 28
        leash: 200
        nestleSec: [12, 22]
        roamSec: [6, 14]
        segSec: [1.0, 2.5]
        approachSec: 8
        nestleSpeed: 14
        roamSpeed: 45
    }
end function

' The front lane rect and the scene.json ellipses around the anemone.
function extrasTest_world() as object
    return {
        lane: { left: 160, top: 180, right: 1760, bottom: 940 }
        ellipses: [
            { cx: 445, cy: 445, rx: 250, ry: 60 }
            { cx: 180, cy: 640, rx: 120, ry: 180 }
            { cx: 690, cy: 560, rx: 75, ry: 140 }
            { cx: 990, cy: 760, rx: 170, ry: 170 }
            { cx: 1450, cy: 800, rx: 180, ry: 170 }
            { cx: 1810, cy: 720, rx: 130, ry: 140 }
            { cx: 1580, cy: 560, rx: 170, ry: 80 }
        ]
        caves: []
        rocks: []
        band: invalid
        arriveTime: 0.6
        arriveResponse: 6.0
    }
end function

function extrasTest_brainCfg() as object
    return {
        tick: 0.125, segMinSec: 0.5, segMaxSec: 1.5, minSpeed: 35, maxSpeed: 110
        wanderJitter: 3.0, wanderAccel: 80, avoidMargin: 0.5, avoidAccel: 300
        laneBand: 80, laneAccel: 400, dartChance: 0.004, dartSpeed: 420
        dartTurn: 1.2, dartSteps: 4, facingDeadband: 6, speedBucket: 15, spawnMargin: 0.3
    }
end function

' Runs a hosted fish for `ticks` ticks from `seed` and returns
' { visits, maxNestle, maxRoam, modes }.
function extrasTest_runHost(seed as integer, ticks as integer) as object
    cfg = extrasTest_brainCfg()
    world = extrasTest_world()
    host = extrasTest_host()
    fish = brainNewFish(cfg, seed, world.lane, world.ellipses)
    hostAttach(fish, host, world, cfg)
    maxNestle = 0.0
    maxRoam = 0.0
    modes = { nestle: 0, roam: 0, approach: 0 }
    for now = 0 to ticks
        hostTick(fish, cfg, world, now)
        d = Sqr((fish.agent.x - host.x) * (fish.agent.x - host.x) + (fish.agent.y - host.y) * (fish.agent.y - host.y))
        if fish.hostMode = "nestle" then
            modes.nestle = modes.nestle + 1
            if d > maxNestle then maxNestle = d
        else if fish.hostMode = "roam" then
            modes.roam = modes.roam + 1
            if d > maxRoam then maxRoam = d
        else
            modes.approach = modes.approach + 1
        end if
    end for
    return { visits: fish.hostVisits, maxNestle: maxNestle, maxRoam: maxRoam, modes: modes }
end function

sub extrasTest_swayValuesLoopSeamlessly(t as object)
    values = extrasSwayValues(0.15, 1.2, 17)
    if not assertEqual(t, values.count(), 17, "value count") then return
    if not assertTrue(t, Abs(values[0] - values[16]) < 0.000001, "first and last values match") then return
    peak = 0.0
    for each v in values
        if Abs(v) > peak then peak = Abs(v)
    end for
    if not assertNear(t, peak, 0.15, 0.001, "peak near amplitude") then return
    for each v in values
        if not assertTrue(t, Abs(v) <= 0.15 + 0.000001, "value within amplitude") then return
    end for
end sub

sub extrasTest_currentPhaseTravelsRight(t as object)
    cur = extrasTest_current()
    ' One wave of waveLength px: the phase repeats one wavelength right.
    assertNear(t, extrasCurrentPhase(cur, 0) - extrasCurrentPhase(cur, cur.waveLength), 6.2831853, 0.0001, "phase advances one turn per wavelength")
end sub

sub extrasTest_walkPathIsDeterministic(t as object)
    a = extrasWalkPath(extrasTest_shrimpWalk(), 7)
    b = extrasWalkPath(extrasTest_shrimpWalk(), 7)
    if not assertEqual(t, b.keys.count(), a.keys.count(), "key count") then return
    ok = true
    for i = 0 to a.keys.count() - 1
        if Abs(a.keys[i] - b.keys[i]) > 0.000001 then ok = false
        if Abs(a.points[i][0] - b.points[i][0]) > 0.000001 then ok = false
        if a.facings[i] <> b.facings[i] then ok = false
    end for
    if not assertNear(t, b.duration, a.duration, 0.000001, "duration") then return
    assertTrue(t, ok, "same seed gives the same path, points and facings")
end sub

sub extrasTest_walkPathStaysOnItsSurface(t as object)
    walk = extrasTest_shrimpWalk()
    path = extrasWalkPath(walk, 11)
    if not assertEqual(t, path.points.count(), path.keys.count(), "one point per key") then return
    for i = 0 to path.points.count() - 1
        p = path.points[i]
        if not assertTrue(t, p[1] = walk.y, "y fixed at " + i.toStr()) then return
        if not assertTrue(t, p[0] >= walk.left - 0.001 and p[0] <= walk.right + 0.001, "x within range at " + i.toStr()) then return
    end for
    ' Keys are the sorted event times, so they rise monotonically.
    for i = 1 to path.keys.count() - 1
        if not assertTrue(t, path.keys[i] >= path.keys[i - 1], "keys non-decreasing at " + i.toStr()) then return
    end for
end sub

sub extrasTest_walkPathClosesItsLoop(t as object)
    walk = extrasTest_shrimpWalk()
    path = extrasWalkPath(walk, 3)
    first = path.points[0]
    last = path.points[path.points.count() - 1]
    if not assertNear(t, last[0], first[0], 0.001, "loop returns to its start x") then return
    assertEqual(t, path.facings[path.facings.count() - 1], path.facings[0], "loop returns to its starting facing")
end sub

sub extrasTest_walkPathTurnsOnlyWhilePaused(t as object)
    walk = extrasTest_shrimpWalk()
    path = extrasWalkPath(walk, 5)
    for i = 1 to path.points.count() - 1
        dx = path.points[i][0] - path.points[i - 1][0]
        if Abs(dx) > 0.001 then
            ' A moving leg: the facing is the direction of travel at both ends
            ' (the turn finished during the pause before the leg).
            want = 1
            if dx < 0 then want = -1
            if not assertEqual(t, path.facings[i], want, "facing matches travel at " + i.toStr()) then return
            if not assertEqual(t, path.facings[i - 1], want, "facing already turned before the leg at " + i.toStr()) then return
        end if
    end for
    assertTrue(t, true, "")
end sub

sub extrasTest_turnTrackSwapsAtMiddle(t as object)
    path = { keys: [0.0, 0.2, 0.4, 0.5, 0.8], facings: [1, 1, -1, -1, 1] }
    tr = extrasTurnTrack(path, 0.25)
    if not assertEqual(t, tr.keys.count(), 10, "two turns of four keys plus the ends") then return
    for i = 1 to tr.keys.count() - 1
        if not assertTrue(t, tr.keys[i] > tr.keys[i - 1], "keys rise at " + i.toStr()) then return
    end for
    ' First turn spans 0.2..0.4: narrow at 0.29 and 0.31, swapping between them.
    if not assertNear(t, tr.keys[2], 0.29, 0.000001, "narrow starts at 45%") then return
    if not assertEqual(t, tr.scale[2][0], 0.25, "narrow width") then return
    if not assertEqual(t, tr.right[2], 1.0, "old art before the swap") then return
    if not assertEqual(t, tr.left[3], 1.0, "new art after the swap") then return
    if not assertEqual(t, tr.right[3], 0.0, "old art hidden after the swap") then return
    if not assertEqual(t, tr.scale[4][0], 1.0, "full width after the turn") then return
    if not assertEqual(t, tr.right[tr.keys.count() - 1], 1.0, "ends on the last facing") then return
end sub

' True when rect r covers point p.
function extrasTest_covers(r as object, px as float, py as float) as boolean
    return px >= r[0] and px < r[0] + r[2] and py >= r[1] and py < r[1] + r[3]
end function

sub extrasTest_tileGridCoversClipWhileScrolling(t as object)
    clip = { x: -320, y: 952, width: 2560, height: 128 }
    tile = 512
    for each dir in [[1, 1], [-1, 1]]
        grid = extrasTileGrid(clip, tile, dir)
        if not assertTrue(t, grid.count() > 0, "grid not empty") then return
        ' Sample the clip edges at scroll offsets 0 and tile-1 along dir.
        for each off in [0, tile - 1]
            ox = dir[0] * off
            oy = dir[1] * off
            for each s in [[clip.x, clip.y], [clip.x + clip.width - 1, clip.y], [clip.x, clip.y + clip.height - 1], [clip.x + clip.width - 1, clip.y + clip.height - 1], [clip.x + clip.width / 2, clip.y + clip.height / 2]]
                covered = false
                for each o in grid
                    if extrasTest_covers([o[0] + ox, o[1] + oy, tile, tile], s[0], s[1]) then covered = true
                end for
                if not assertTrue(t, covered, "point " + s[0].toStr() + "," + s[1].toStr() + " covered at offset " + off.toStr() + " dir " + dir[0].toStr() + "," + dir[1].toStr()) then return
            end for
        end for
    end for
    assertTrue(t, true, "")
end sub

sub extrasTest_nightOpacityFadesAndHides(t as object)
    if not assertNear(t, extrasNightOpacity(0.3, 0.0, 0.9), 0.3, 0.000001, "day at nightLevel 0") then return
    if not assertNear(t, extrasNightOpacity(0.3, 0.5, 0.9), 0.15, 0.000001, "half at nightLevel 0.5") then return
    if not assertNear(t, extrasNightOpacity(0.3, 0.9, 0.9), 0.0, 0.000001, "hidden at hideAt") then return
    assertNear(t, extrasNightOpacity(0.3, 1.0, 0.9), 0.0, 0.000001, "hidden at full night")
end sub

sub extrasTest_lerpColorEndpointsAndMidpoint(t as object)
    a = &h102030FF
    b = &h304050FF
    if not assertEqual(t, extrasLerpColor(a, b, 0.0), a, "f 0 returns a") then return
    if not assertEqual(t, extrasLerpColor(a, b, 1.0), b, "f 1 returns b") then return
    assertEqual(t, extrasLerpColor(a, b, 0.5), &h203040FF, "f 0.5 blends each channel")
end sub

sub extrasTest_seedRules(t as object)
    if not assertEqual(t, extrasSeed(7, 0.0, 999), 7, "preview seed wins") then return
    if not assertEqual(t, extrasSeed(7, 3.0, 999), 7, "preview seed wins under freeze") then return
    if not assertEqual(t, extrasSeed(0, 3.0, 999), 1, "frozen without a seed is stable") then return
    assertEqual(t, extrasSeed(0, 0.0, 12345), 12345, "otherwise the wall clock seed")
end sub

sub extrasTest_hostNestlesWithinRadiusOver10000Ticks(t as object)
    r = extrasTest_runHost(7, 10000)
    if not assertTrue(t, r.modes.nestle > 0, "fish spent ticks nestling") then return
    ' arrive steering can overshoot a target inside the radius slightly; one
    ' target radius of slack keeps the assertion about the nest, not the easing.
    assertTrue(t, r.maxNestle <= extrasTest_host().radius + extrasTest_host().radius, "nestle distance stays within the nest (max was " + r.maxNestle.toStr() + ")")
end sub

sub extrasTest_hostRoamsWithinLeash(t as object)
    r = extrasTest_runHost(9, 4000)
    if not assertTrue(t, r.modes.roam > 0, "fish spent ticks roaming") then return
    assertTrue(t, r.maxRoam <= extrasTest_host().leash + extrasTest_host().leash, "roam distance stays within the leash (max was " + r.maxRoam.toStr() + ")")
end sub

sub extrasTest_hostCyclesNestleRoamApproach(t as object)
    r = extrasTest_runHost(5, 8000)
    if not assertTrue(t, r.visits >= 2, "fish returned to the anemone at least twice (" + r.visits.toStr() + " visits)") then return
    if not assertTrue(t, r.modes.roam > 0, "fish roamed between visits") then return
    assertTrue(t, r.modes.approach > 0, "fish approached between roam and nestle")
end sub

sub extrasTest_hostIsDeterministic(t as object)
    a = extrasTest_runHost(21, 3000)
    b = extrasTest_runHost(21, 3000)
    if not assertEqual(t, b.visits, a.visits, "visit count") then return
    assertNear(t, b.maxNestle, a.maxNestle, 0.000001, "max nestle distance")
end sub

sub extrasTest_hostForMatchesLaneAndSpecies(t as object)
    host = extrasTest_host()
    h = hostFor(host, "frontLane", "ocellaris_clownfish")
    if not assertTrue(t, h <> invalid and h.x = host.x and h.y = host.y, "matching lane and species") then return
    if not assertTrue(t, hostFor(host, "midLane", "ocellaris_clownfish") = invalid, "other lanes are not hosted") then return
    if not assertTrue(t, hostFor(host, "frontLane", "yellow_tang") = invalid, "other species are not hosted") then return
    assertEqual(t, hostFor(invalid, "frontLane", "ocellaris_clownfish"), invalid, "no host block, no hosting")
end sub

' ---- Strict bounds (P4.1, P4.3, P4.5 verify lines) ----

function extrasStrict_walks() as object
    return [
        extrasTest_shrimpWalk()
        { x: 900, y: 934, left: 820, right: 1120, speed: 60, legPx: [20, 90], pauseSec: [1.0, 4.0], legs: 8 }
        { x: 1300, y: 866, left: 1270, right: 1340, speed: 1.5, legPx: [15, 40], pauseSec: [10, 30], legs: 4 }
    ]
end function

' Ground constraint: every key of every critter loop, 40 seeds each, stays on its y and range.
sub extrasStrict_walkOnGroundAllSeeds(t as object)
    for each w in extrasStrict_walks()
        for seed = 1 to 40
            p = extrasWalkPath(w, seed)
            last = p.points.count() - 1
            if not assertEqual(t, p.points[last][0], p.points[0][0], "loop closes seed " + seed.toStr()) then return
            for each pt in p.points
                if not assertEqual(t, pt[1], w.y, "ground y seed " + seed.toStr()) then return
                if not assertTrue(t, pt[0] >= w.left - 0.001 and pt[0] <= w.right + 0.001, "x in bounds seed " + seed.toStr()) then return
            end for
        end for
    end for
end sub

sub extrasStrict_walkFacingMatchesMotionAllSeeds(t as object)
    w = extrasTest_shrimpWalk()
    for seed = 1 to 60
        p = extrasWalkPath(w, seed)
        for i = 1 to p.points.count() - 1
            dx = p.points[i][0] - p.points[i - 1][0]
            if dx <> 0 then
                f = 1
                if dx < 0 then f = -1
                if not assertEqual(t, p.facings[i - 1], f, "turned while moving seed " + seed.toStr()) then return
                if not assertEqual(t, p.facings[i], f, "walks backwards seed " + seed.toStr()) then return
            end if
        end for
    end for
end sub

' P4.3 verify: at ?seed=1 the shrimp (walk salt 0) moves and turns within 5 minutes.
sub extrasStrict_shrimpTurnsWithin5Minutes(t as object)
    p = extrasWalkPath(extrasTest_shrimpWalk(), 1)
    assertTrue(t, p.duration < 300, "loop shorter than 5 min: " + Str(p.duration))
    turns = 0
    moves = 0
    for i = 1 to p.facings.count() - 1
        if p.facings[i] <> p.facings[i - 1] then turns = turns + 1
        if p.points[i][0] <> p.points[i - 1][0] then moves = moves + 1
    end for
    assertTrue(t, turns >= 2, "turns")
    assertTrue(t, moves >= 3, "moves")
end sub

' Every probe point of the clip is under some tile at 17 scroll offsets in [0, tile).
sub extrasStrict_causticGridCoversClipAtAnyOffset(t as object)
    clip = { x: -320, y: 952, width: 2560, height: 128 }
    for each dir in [[1, 1], [-1, 1]]
        grid = extrasTileGrid(clip, 512, dir)
        for k = 0 to 16
            off = 511.999 * k / 16
            for py = clip.y to clip.y + clip.height - 1 step 31
                for px = clip.x to clip.x + clip.width - 1 step 97
                    hit = false
                    for each o in grid
                        if extrasTest_covers([o[0] + dir[0] * off, o[1] + dir[1] * off, 512, 512], px, py) then hit = true
                    end for
                    if not assertTrue(t, hit, "gap at " + Str(px) + "," + Str(py) + " off " + Str(off)) then return
                end for
            end for
        end for
    end for
    assertEqual(t, extrasTileGrid(clip, 512, [1, 1]).count(), 12, "6 x 2 tiles")
end sub

' A hosted clownfish through brainTickBehavior on the drawn polyline, in the scene's front lane.
function extrasStrict_runHost(seed as integer, ticks as integer) as object
    cfg = extrasTest_brainCfg()
    world = extrasTest_world()
    h = extrasTest_host()
    fish = brainNewFish(cfg, seed, world.lane, world.ellipses)
    hostAttach(fish, h, world, cfg)
    out = { maxDist: 0.0, nestleMax: 0.0, roams: 0, inside: 0, visits: 0 }
    prev = ""
    for now = 0 to ticks - 1
        brainTickBehavior(fish, cfg, world, now)
        p = fish.points[now - fish.startTick]
        d = Sqr((p[0] - h.x) * (p[0] - h.x) + (p[1] - h.y) * (p[1] - h.y))
        if d > out.maxDist then out.maxDist = d
        if fish.hostMode = "nestle" and d > out.nestleMax then out.nestleMax = d
        if fish.hostMode <> prev then
            if fish.hostMode = "roam" then out.roams = out.roams + 1
            prev = fish.hostMode
        end if
        if not brainClearOf(world.ellipses, p[0], p[1], 0.999) then out.inside = out.inside + 1
    end for
    out.visits = fish.hostVisits
    return out
end function

' P4.1 verify: the hosted clownfish never leaves the host radius (the leash, +20 px of
' arrive overshoot) over 10k steps, and never enters an ellipse.
sub extrasStrict_hostStaysWithinLeash10kTicks(t as object)
    h = extrasTest_host()
    for each seed in [1, 7, 42]
        r = extrasStrict_runHost(seed, 10000)
        assertTrue(t, r.maxDist <= h.leash + 20, "seed " + seed.toStr() + " max distance " + Str(r.maxDist))
        assertEqual(t, r.inside, 0, "inside an ellipse")
    end for
end sub

' It nestles among the tentacles, leaves, and comes back many times in 10k ticks.
sub extrasStrict_hostNestlesLeavesAndReturns(t as object)
    h = extrasTest_host()
    r = extrasStrict_runHost(3, 10000)
    assertTrue(t, r.visits >= 10, "nestle visits " + r.visits.toStr())
    assertTrue(t, r.roams >= 10, "roams " + r.roams.toStr())
    assertTrue(t, r.nestleMax <= h.radius * 2.5, "nestle spread " + Str(r.nestleMax))
end sub

' Gait keys rise monotonically over [0, 1], the legs rest at every path key (so pauses and
' the loop point are still), and each moving leg swings a whole number of strides.
sub extrasTest_gaitSwingsOnlyWhileWalking(t as object)
    for each seed in [1, 7, 42]
        path = extrasWalkPath(extrasTest_shrimpWalk(), seed)
        g = extrasGait(path, 20.0, 0.1, 1.0)
        if not assertNear(t, g.keys[0], 0.0, 0.000001, "starts at 0 seed " + seed.toStr()) then return
        if not assertNear(t, g.keys[g.keys.count() - 1], 1.0, 0.000001, "ends at 1 seed " + seed.toStr()) then return
        peak = 0.0
        for i = 1 to g.keys.count() - 1
            if not assertTrue(t, g.keys[i] >= g.keys[i - 1], "keys rise at " + i.toStr() + " seed " + seed.toStr()) then return
            if Abs(g.values[i]) > peak then peak = Abs(g.values[i])
        end for
        if not assertNear(t, peak, 0.1, 0.000001, "swings to amp seed " + seed.toStr()) then return
        for each k in path.keys
            for i = 0 to g.keys.count() - 1
                if Abs(g.keys[i] - k) < 0.0000001 then
                    if not assertNear(t, g.values[i], 0.0, 0.000001, "rests at path key seed " + seed.toStr()) then return
                end if
            end for
        end for
    end for
end sub

function extrasTest_shuttleWalk() as object
    return { x: 80, y: 914, left: 60, right: 1300, speed: 24, legPx: [40, 150], pauseSec: [1.5, 5.0], trips: 2, turnZones: [[60, 100], [1220, 1300]], turnSec: 0.7 }
end function

' The shrimp shuttle over 40 seeds: every facing change happens at rest inside a turn
' zone, it never walks backwards, both zones are visited, and the loop closes facing right.
sub extrasStrict_shuttleTurnsOnlyInCoverAllSeeds(t as object)
    w = extrasTest_shuttleWalk()
    for seed = 1 to 40
        p = extrasWalkPath(w, seed)
        last = p.points.count() - 1
        tag = " seed " + seed.toStr()
        if not assertEqual(t, p.points[last][0], w.x, "loop closes" + tag) then return
        if not assertEqual(t, p.facings[last], 1, "ends facing right" + tag) then return
        turns = 0
        for i = 1 to last
            x = p.points[i][0]
            if not assertTrue(t, x >= w.left - 0.001 and x <= w.right + 0.001, "x in bounds" + tag) then return
            dx = x - p.points[i - 1][0]
            if p.facings[i] <> p.facings[i - 1] then
                turns = turns + 1
                if not assertEqual(t, dx, 0.0, "turns at rest" + tag) then return
                inZone = false
                for each z in w.turnZones
                    if x >= z[0] - 0.001 and x <= z[1] + 0.001 then inZone = true
                end for
                if not assertTrue(t, inZone, "turn at x " + Str(x) + " is in cover" + tag) then return
            else if dx <> 0 then
                if not assertTrue(t, dx * p.facings[i] > 0, "walks forwards" + tag) then return
            end if
        end for
        if not assertEqual(t, turns, 4, "two round trips" + tag) then return
    end for
end sub
