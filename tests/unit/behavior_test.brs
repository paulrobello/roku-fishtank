' Unit tests for the per-species behaviours in components/lib/brain.brs
' (P2.6). The behaviour config mirrors config/behavior.json and the brain
' config is brain_test.brs's copy of config/brain.json, so a config edit
' cannot silently weaken the tests.

function behaviorTestSuite() as object
    return {
        name: "behavior"
        tests: [
            { name: "cavesAndRocksOutsideEllipses", fn: behaviorTest_cavesAndRocksOutsideEllipses }
            { name: "kindsBySpecies", fn: behaviorTest_kindsBySpecies }
            { name: "legacySpawnUnchanged", fn: behaviorTest_legacySpawnUnchanged }
            { name: "grammaCycle", fn: behaviorTest_grammaCycle }
            { name: "grammaHoverStaysAtCave", fn: behaviorTest_grammaHoverStaysAtCave }
            { name: "grammaBacksInFacingOut", fn: behaviorTest_grammaBacksInFacingOut }
            { name: "mandarinStaysInBand", fn: behaviorTest_mandarinStaysInBand }
            { name: "lionfishSlowNoDarts", fn: behaviorTest_lionfishSlowNoDarts }
            { name: "grazerCycleAndSlowPecks", fn: behaviorTest_grazerCycleAndSlowPecks }
            { name: "grazerApproachReachesBlockedRock", fn: behaviorTest_grazerApproachReachesBlockedRock }
            { name: "seed1EveryBehaviorWithin300s", fn: behaviorTest_seed1EveryBehaviorWithin300s }
            { name: "guardHoldsLongRuns", fn: behaviorTest_guardHoldsLongRuns }
            { name: "sameSeedSameTransitions", fn: behaviorTest_sameSeedSameTransitions }
        ]
    }
end function

function behaviorTest_cfg() as object
    cfg = brainTest_cfg()
    cfg.lane = brainTest_lane()
    cfg.ellipses = brainTest_ellipses()
    cfg.species = "royal_blue_tang"
    cfg.count = 25
    return cfg
end function

function behaviorTest_beh() as object
    return {
        population: [
            { species: "royal_blue_tang", count: 2 }
            { species: "yellow_tang", count: 2 }
            { species: "emperor_angelfish", count: 1 }
            { species: "moorish_idol", count: 1 }
            { species: "ocellaris_clownfish", count: 2 }
            { species: "royal_gramma", count: 2 }
            { species: "lionfish", count: 1 }
            { species: "mandarin_dragonet", count: 1 }
        ]
        species: {
            royal_blue_tang: "grazer", yellow_tang: "grazer", emperor_angelfish: "grazer", moorish_idol: "grazer"
            ocellaris_clownfish: "cruise", royal_gramma: "cave", lionfish: "hover", mandarin_dragonet: "bottom"
        }
        kinds: {
            grazer: { cruiseSec: [20, 50], approachSpeed: 70, approachSec: 15, arriveRadius: 10, grazeSec: [6, 12], peckSpeed: 18, peckRadius: 8, peckSec: [0.25, 0.5], pauseSec: [0.25, 1.0] }
            cave: { hoverSec: [5, 12], hoverSegSec: [1, 2.5], hoverRadius: 16, hoverSpeed: 14, backSpeed: 22, retreatSec: 8, hideSec: [4, 9], emergeSpeed: 30, emergeSec: 8, arriveRadius: 3 }
            bottom: { pauseSec: [1, 4], hopPx: [30, 90], hopSpeed: 70, hopSec: 3, arriveRadius: 3 }
            hover: {
                driftSec: [25, 50], hangSec: [6, 12]
                drift: { minSpeed: 8, maxSpeed: 20, wanderJitter: 0.6, wanderAccel: 12, segMinSec: 3, segMaxSec: 6, dartChance: 0 }
                hang: { minSpeed: 0, maxSpeed: 4, wanderJitter: 0.4, wanderAccel: 4, segMinSec: 3, segMaxSec: 6, dartChance: 0 }
            }
        }
        arriveTime: 0.6
        arriveResponse: 6
        caves: [
            { mouth: [695, 640], den: [638, 640], out: 1 }
            { mouth: [1030, 700], den: [1098, 700], out: -1 }
            { mouth: [1425, 380], den: [1459, 380], out: -1 }
        ]
        rocks: [[400, 515], [900, 320], [950, 520], [1250, 590], [1665, 380]]
        band: { left: 200, top: 850, right: 1720, bottom: 890 }
    }
end function

' One fish of `species` (the nth of its kind) for `ticks` ticks. Returns
' { segs: [{ tick, mode, kind, points, facing }], trans: [{ tick, src, dst }] }.
function behaviorTest_runOne(species as string, nth as integer, seed as integer, ticks as integer) as object
    cfg = behaviorTest_cfg()
    beh = behaviorTest_beh()
    world = brainNewWorld(cfg, beh)
    fish = brainNewBehaviorFish(cfg, beh, world, species, seed, nth)
    return behaviorTest_drive([fish], cfg, world, ticks)[0]
end function

' Ticks every fish for `ticks` ticks and records each one's segments and
' mode changes.
function behaviorTest_drive(fishes as object, cfg as object, world as object, ticks as integer) as object
    out = []
    for each f in fishes
        out.push({ fish: f, segs: [], trans: [] })
    end for
    for now = 0 to ticks - 1
        for each r in out
            f = r.fish
            kind = brainTickBehavior(f, cfg, world, now)
            if f.beh <> invalid then
                if f.trTo <> "" then
                    r.trans.push({ tick: now, src: f.trFrom, dst: f.trTo })
                    f.trFrom = ""
                    f.trTo = ""
                end if
            end if
            if kind <> "" then
                mode = "cruise"
                if f.beh <> invalid then mode = f.mode
                r.segs.push({ tick: now, mode: mode, kind: kind, points: f.points, facing: f.facing })
            end if
        end for
    end for
    return out
end function

function behaviorTest_hasTrans(trans as object, src as string, dst as string) as boolean
    for each tr in trans
        if tr.src = src and tr.dst = dst then return true
    end for
    return false
end function

' Max speed in px/s over every piece of a polyline drawn one piece per tick.
function behaviorTest_maxPieceSpeed(points as object, tick as float) as float
    best = 0.0
    for i = 1 to points.count() - 1
        dx = points[i][0] - points[i - 1][0]
        dy = points[i][1] - points[i - 1][1]
        v = Sqr(dx * dx + dy * dy) / tick
        if v > best then best = v
    end for
    return best
end function

' Points inside an ellipse plus pieces passing through one.
function behaviorTest_guardViolations(segs as object, ellipses as object) as integer
    bad = 0
    for each seg in segs
        p = seg.points
        for i = 0 to p.count() - 1
            if brainTest_inside(ellipses, p[i][0], p[i][1]) then bad = bad + 1
            if i > 0 then
                if steerFirstHit(ellipses, p[i - 1][0], p[i - 1][1], p[i][0], p[i][1]) >= 0 then bad = bad + 1
            end if
        end for
    end for
    return bad
end function

sub behaviorTest_cavesAndRocksOutsideEllipses(t as object)
    beh = behaviorTest_beh()
    ellipses = brainTest_ellipses()
    lane = brainTest_lane()
    bad = 0
    for each c in beh.caves
        ' The mouth is a spawn point, so it clears the spawn margin (norm >= 1.3).
        if not brainClearOf(ellipses, c.mouth[0], c.mouth[1], 1.69) then bad = bad + 1
        if brainTest_inside(ellipses, c.den[0], c.den[1]) then bad = bad + 1
        if steerFirstHit(ellipses, c.mouth[0], c.mouth[1], c.den[0], c.den[1]) >= 0 then bad = bad + 1
        ' The den lies on the side opposite the opening.
        if (c.den[0] - c.mouth[0]) * c.out >= 0 then bad = bad + 1
    end for
    for each r in beh.rocks
        if brainTest_inside(ellipses, r[0], r[1]) then bad = bad + 1
        if r[0] < lane.left or r[0] > lane.right or r[1] < lane.top or r[1] > lane.bottom then bad = bad + 1
    end for
    b = beh.band
    if not brainClearOf(ellipses, b.left, b.top, 1.69) or not brainClearOf(ellipses, b.right, b.top, 1.69) then bad = bad + 1
    for x = b.left to b.right step 10
        if not brainClearOf(ellipses, x, b.top, 1.69) then bad = bad + 1
    end for
    if b.bottom > lane.bottom or b.top < lane.top then bad = bad + 1
    assertEqual(t, bad, 0, "cave, rock or band placement")
end sub

sub behaviorTest_kindsBySpecies(t as object)
    cfg = behaviorTest_cfg()
    beh = behaviorTest_beh()
    world = brainNewWorld(cfg, beh)
    spawned = brainSpawnAll(cfg, beh, world, 1)
    assertEqual(t, spawned.count(), 12, "population size")
    kinds = {}
    for each s in spawned
        assertTrue(t, s.state <> invalid, "spawned " + s.species)
        if s.state <> invalid then kinds[s.species] = s.state.kind
    end for
    assertEqual(t, kinds.royal_blue_tang, "grazer", "tang")
    assertEqual(t, kinds.moorish_idol, "grazer", "idol")
    assertEqual(t, kinds.ocellaris_clownfish, "cruise", "clownfish keeps cruising")
    assertEqual(t, kinds.royal_gramma, "cave", "gramma")
    assertEqual(t, kinds.lionfish, "hover", "lionfish")
    assertEqual(t, kinds.mandarin_dragonet, "bottom", "mandarin")
end sub

' Without a behaviour config, brainSpawnAll gives the P2.3 tank exactly.
sub behaviorTest_legacySpawnUnchanged(t as object)
    cfg = behaviorTest_cfg()
    world = brainNewWorld(cfg, invalid)
    spawned = brainSpawnAll(cfg, invalid, world, 7)
    assertEqual(t, spawned.count(), 25, "count from brain config")
    master = prngNew(7)
    diffs = 0
    for each s in spawned
        old = brainNewFish(cfg, brainFishSeed(master), cfg.lane, cfg.ellipses)
        if old.agent.x <> s.state.agent.x or old.agent.y <> s.state.agent.y or old.rng.state <> s.state.rng.state then diffs = diffs + 1
        if s.state.beh <> invalid then diffs = diffs + 1
    end for
    assertEqual(t, diffs, 0, "legacy spawns differ")
end sub

sub behaviorTest_grammaCycle(t as object)
    for nth = 0 to 2
        r = behaviorTest_runOne("royal_gramma", nth, 100 + nth, 2400)
        tr = r.trans
        assertTrue(t, behaviorTest_hasTrans(tr, "spawn", "hover"), "spawn->hover")
        assertTrue(t, behaviorTest_hasTrans(tr, "hover", "retreat"), "hover->retreat cave " + nth.toStr())
        assertTrue(t, behaviorTest_hasTrans(tr, "retreat", "hide"), "retreat->hide")
        assertTrue(t, behaviorTest_hasTrans(tr, "hide", "emerge"), "hide->emerge")
        assertTrue(t, behaviorTest_hasTrans(tr, "emerge", "hover"), "emerge->hover")
        ' The only legal successions.
        legal = { spawn: "hover", hover: "retreat", retreat: "hide", hide: "emerge", emerge: "hover" }
        bad = 0
        for each x in tr
            if legal[x.src] <> x.dst then bad = bad + 1
        end for
        assertEqual(t, bad, 0, "illegal cave transitions")
    end for
end sub

' While hovering, a gramma stays within hoverRadius * sqrt(2) plus a small
' overshoot of its cave mouth, and every gramma point stays near its cave.
sub behaviorTest_grammaHoverStaysAtCave(t as object)
    beh = behaviorTest_beh()
    b = beh.kinds.cave
    bound = b.hoverRadius * 1.415 + 6
    for nth = 0 to 2
        cave = beh.caves[nth]
        r = behaviorTest_runOne("royal_gramma", nth, 200 + nth, 2400)
        worst = 0.0
        far = 0.0
        hoverSegs = 0
        for each seg in r.segs
            for each p in seg.points
                dx = p[0] - cave.mouth[0]
                dy = p[1] - cave.mouth[1]
                d = Sqr(dx * dx + dy * dy)
                if d > far then far = d
                if seg.mode = "hover" and d > worst then worst = d
            end for
            if seg.mode = "hover" then hoverSegs = hoverSegs + 1
        end for
        assertTrue(t, hoverSegs > 20, "hover segments seen")
        assertTrue(t, worst <= bound, "hover strays " + Str(worst).trim() + " px from mouth " + nth.toStr())
        ' Never further than the den plus the hover zone.
        dx = cave.den[0] - cave.mouth[0]
        dy = cave.den[1] - cave.mouth[1]
        assertTrue(t, far <= Sqr(dx * dx + dy * dy) + bound, "cave fish strays " + Str(far).trim() + " px")
    end for
end sub

' Retreat moves tail first: net motion is toward the den, against facing,
' and facing stays on the cave's opening side in every segment.
sub behaviorTest_grammaBacksInFacingOut(t as object)
    beh = behaviorTest_beh()
    for nth = 0 to 2
        cave = beh.caves[nth]
        r = behaviorTest_runOne("royal_gramma", nth, 300 + nth, 2400)
        retreats = 0
        backward = 0
        wrongFacing = 0
        for each seg in r.segs
            if seg.facing <> cave.out then wrongFacing = wrongFacing + 1
            if seg.mode = "retreat" then
                p = seg.points
                dx = p[p.count() - 1][0] - p[0][0]
                if Abs(dx) > 0.5 then
                    retreats = retreats + 1
                    if dx * cave.out < 0 then backward = backward + 1
                end if
            end if
        end for
        assertEqual(t, wrongFacing, 0, "segments facing away from the opening")
        assertTrue(t, retreats >= 3, "retreat segments that move")
        assertEqual(t, backward, retreats, "retreat segments moving tail first")
    end for
end sub

sub behaviorTest_mandarinStaysInBand(t as object)
    band = behaviorTest_beh().band
    for seed = 1 to 2
        r = behaviorTest_runOne("mandarin_dragonet", 0, seed, 2400)
        out = 0
        hops = 0
        for each seg in r.segs
            if seg.mode = "hop" then hops = hops + 1
            for each p in seg.points
                if p[0] < band.left - 0.01 or p[0] > band.right + 0.01 or p[1] < band.top - 0.01 or p[1] > band.bottom + 0.01 then out = out + 1
            end for
        end for
        assertEqual(t, out, 0, "points outside the band, seed " + seed.toStr())
        assertTrue(t, hops > 20, "hop segments")
        assertTrue(t, behaviorTest_hasTrans(r.trans, "graze", "hop"), "graze->hop")
        assertTrue(t, behaviorTest_hasTrans(r.trans, "hop", "graze"), "hop->graze")
    end for
end sub

sub behaviorTest_lionfishSlowNoDarts(t as object)
    b = behaviorTest_beh().kinds.hover
    cfg = behaviorTest_cfg()
    for seed = 1 to 2
        r = behaviorTest_runOne("lionfish", 0, seed, 2400)
        darts = 0
        worst = 0.0
        hangWorst = 0.0
        for each seg in r.segs
            if seg.kind = "dart" then darts = darts + 1
            v = behaviorTest_maxPieceSpeed(seg.points, cfg.tick)
            if v > worst then worst = v
            if seg.mode = "hang" and v > hangWorst then hangWorst = v
        end for
        assertEqual(t, darts, 0, "lionfish darts")
        assertTrue(t, worst <= b.drift.maxSpeed + 0.01, "lionfish speed " + Str(worst).trim())
        assertTrue(t, hangWorst <= b.hang.maxSpeed + 0.01, "hang speed " + Str(hangWorst).trim())
        assertTrue(t, behaviorTest_hasTrans(r.trans, "drift", "hang"), "drift->hang")
        assertTrue(t, behaviorTest_hasTrans(r.trans, "hang", "drift"), "hang->drift")
    end for
end sub

' A grazer with the ellipse between it and the rock used to hover at the
' outline until approachSec expired and gave up (approach->cruise). The
' approach now detours around the ellipse and reaches the graze point.
sub behaviorTest_grazerApproachReachesBlockedRock(t as object)
    cfg = behaviorTest_cfg()
    beh = behaviorTest_beh()
    beh.rocks = [[560, 365]]
    world = brainNewWorld(cfg, beh)
    world.ellipses = [{ cx: 440, cy: 440, rx: 260, ry: 60 }]
    fish = brainNewBehaviorFish(cfg, beh, world, "royal_blue_tang", 1, 0)
    ' Spawn across the ellipse from the rock, so the direct line crosses it.
    fish.agent.x = 560.0
    fish.agent.y = 520.0
    fish.agent.vx = 0.0
    fish.agent.vy = 0.0
    fish.mode = "approach"
    fish.target = beh.rocks[0]
    fish.modeEnd = 240
    sawGraze = false
    reached = false
    for now = 0 to 119
        brainTickBehavior(fish, cfg, world, now)
        if fish.trTo = "graze" then sawGraze = true
        if brainDist(fish.agent, fish.target) <= beh.kinds.grazer.arriveRadius then reached = true
    end for
    assertTrue(t, sawGraze, "approach -> graze within approachSec")
    assertTrue(t, reached, "reached the graze point")
end sub

sub behaviorTest_grazerCycleAndSlowPecks(t as object)
    cfg = behaviorTest_cfg()
    b = behaviorTest_beh().kinds.grazer
    species = ["royal_blue_tang", "yellow_tang", "emperor_angelfish", "moorish_idol"]
    for i = 0 to species.count() - 1
        r = behaviorTest_runOne(species[i], i, 400 + i, 2400)
        assertTrue(t, behaviorTest_hasTrans(r.trans, "cruise", "approach"), species[i] + " cruise->approach")
        assertTrue(t, behaviorTest_hasTrans(r.trans, "approach", "graze"), species[i] + " approach->graze")
        assertTrue(t, behaviorTest_hasTrans(r.trans, "graze", "cruise"), species[i] + " graze->cruise")
        worst = 0.0
        badDarts = 0
        for each seg in r.segs
            if seg.mode = "graze" then
                v = behaviorTest_maxPieceSpeed(seg.points, cfg.tick)
                if v > worst then worst = v
            end if
            if seg.kind = "dart" and seg.mode <> "cruise" then badDarts = badDarts + 1
        end for
        assertTrue(t, worst <= b.peckSpeed + 0.01, "graze pecks stay slow (" + Str(worst).trim() + ")")
        assertEqual(t, badDarts, 0, "darts outside cruise")
    end for
end sub

' The acceptance check, replayed: the ?seed=1 BehaviorDemoScene population
' shows every species' behaviour transitions within 300 s of scene time.
sub behaviorTest_seed1EveryBehaviorWithin300s(t as object)
    cfg = behaviorTest_cfg()
    beh = behaviorTest_beh()
    world = brainNewWorld(cfg, beh)
    fishes = []
    species = []
    for each s in brainSpawnAll(cfg, beh, world, 1)
        fishes.push(s.state)
        species.push(s.species)
    end for
    runs = behaviorTest_drive(fishes, cfg, world, Int(300 / cfg.tick))
    need = {
        grazer: [["cruise", "approach"], ["approach", "graze"], ["graze", "cruise"]]
        cave: [["hover", "retreat"], ["retreat", "hide"], ["hide", "emerge"], ["emerge", "hover"]]
        bottom: [["graze", "hop"], ["hop", "graze"]]
        hover: [["drift", "hang"], ["hang", "drift"]]
    }
    for i = 0 to runs.count() - 1
        f = fishes[i]
        if need.doesExist(f.kind) then
            for each pair in need[f.kind]
                assertTrue(t, behaviorTest_hasTrans(runs[i].trans, pair[0], pair[1]), "fish " + i.toStr() + " " + species[i] + " " + pair[0] + "->" + pair[1] + " by 300 s")
            end for
        end if
        assertEqual(t, behaviorTest_guardViolations(runs[i].segs, world.ellipses), 0, "guard, fish " + i.toStr())
    end for
end sub

' Every species together, long seeded runs: no point inside and no piece
' through an ellipse, in any state.
sub behaviorTest_guardHoldsLongRuns(t as object)
    cfg = behaviorTest_cfg()
    beh = behaviorTest_beh()
    world = brainNewWorld(cfg, beh)
    bad = 0
    pieces = 0
    for seed = 2 to 2
        fishes = []
        for each s in brainSpawnAll(cfg, beh, world, seed)
            fishes.push(s.state)
        end for
        for each r in behaviorTest_drive(fishes, cfg, world, 4800)
            bad = bad + behaviorTest_guardViolations(r.segs, world.ellipses)
            for each seg in r.segs
                pieces = pieces + seg.points.count() - 1
            end for
        end for
    end for
    assertEqual(t, bad, 0, "guard violations")
    assertTrue(t, pieces > 50000, "enough pieces checked (" + pieces.toStr() + ")")
end sub

sub behaviorTest_sameSeedSameTransitions(t as object)
    a = behaviorTest_runOne("royal_gramma", 1, 77, 1600)
    b = behaviorTest_runOne("royal_gramma", 1, 77, 1600)
    assertEqual(t, a.trans.count(), b.trans.count(), "transition count")
    diffs = 0
    for i = 0 to a.trans.count() - 1
        if a.trans[i].tick <> b.trans[i].tick or a.trans[i].dst <> b.trans[i].dst then diffs = diffs + 1
    end for
    assertEqual(t, diffs, 0, "same seed differs")
end sub
