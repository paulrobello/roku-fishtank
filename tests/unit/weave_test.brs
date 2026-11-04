' Unit tests for lane weaving (components/lib/weave.brs, P2.4) and the
' occlusion data it reads from scene.json (components/lib/scenecfg.brs, P1.8).

function weaveTestSuite() as object
    return {
        name: "weave"
        tests: [
            { name: "planUsesLayersInFrontOfBothLanes", fn: weaveTest_planUsesLayersInFrontOfBothLanes }
            { name: "planShrinksByDrift", fn: weaveTest_planShrinksByDrift }
            { name: "occluderValidation", fn: weaveTest_occluderValidation }
            { name: "attachOnlyListedSpecies", fn: weaveTest_attachOnlyListedSpecies }
            { name: "switchOnlyWhenHidden", fn: weaveTest_switchOnlyWhenHidden }
            { name: "sameSeedSameSwitches", fn: weaveTest_sameSeedSameSwitches }
            { name: "noRegionNoSwitch", fn: weaveTest_noRegionNoSwitch }
        ]
    }
end function

' Three lanes with a decor layer between each pair and one in front of all of them.
function weaveTest_cfg() as object
    return {
        design: { width: 1920, height: 1080 }
        drift: { enabled: true, periodSeconds: 90, amplitude: { x: 80, y: 0 }, keyCount: 48 }
        layers: [
            { id: "water", parallax: 0.2 }
            { id: "back", parallax: 0.5, lane: { rect: { left: 160, top: 260, right: 1760, bottom: 820 }, scale: 0.6, tint: "0x9FB8D2FF" } }
            { id: "midDecor", parallax: 0.6 }
            { id: "mid", parallax: 0.7, lane: { rect: { left: 160, top: 220, right: 1760, bottom: 840 }, scale: 0.8, tint: "0xD2E0EEFF" } }
            { id: "frontDecor", parallax: 0.8 }
            { id: "front", parallax: 0.9, lane: { rect: { left: 160, top: 180, right: 1760, bottom: 940 }, scale: 1.0, tint: "0xFFFFFFFF" } }
            { id: "fg", parallax: 1.0 }
        ]
        population: {
            occluders: {
                midDecor: [{ left: 0, top: 800, right: 700, bottom: 990 }]
                frontDecor: [{ left: 1000, top: 500, right: 1600, bottom: 990 }]
            }
            weave: { species: ["royal_blue_tang", "yellow_tang"], chance: 1.0, seekSec: 12, seekSpeed: 70, holdSec: 1.5, cooldownSec: 2, slack: 4 }
        }
    }
end function

sub weaveTest_planUsesLayersInFrontOfBothLanes(t as object)
    plan = sceneCfgWeavePlan(weaveTest_cfg(), "back")
    assertEqual(t, plan.home, 0, "back is lane 0")
    assertEqual(t, plan.lanes.count(), 3)
    assertEqual(t, plan.gaps[0].count(), 1, "back-mid: only frontDecor hides a fish in both lanes")
    assertEqual(t, plan.gaps[0][0].layer, "frontDecor")
    assertEqual(t, plan.gaps[1].count(), 0, "mid-front: nothing in fg, so no hide rect")
    assertEqual(t, sceneCfgWeavePlan({ layers: [], population: {} }, "back"), invalid, "no weave block, no plan")
end sub

sub weaveTest_planShrinksByDrift(t as object)
    r = sceneCfgWeavePlan(weaveTest_cfg(), "mid").gaps[0][0]
    ' frontDecor 0.8 vs back 0.5 and mid 0.7: 80 * 0.3 + 4 slack on x, 0 * 0.3 + 4 on y.
    assertNear(t, r.left, 1028.0, 0.001)
    assertNear(t, r.right, 1572.0, 0.001)
    assertNear(t, r.top, 504.0, 0.001)
    assertNear(t, r.bottom, 986.0, 0.001)
end sub

sub weaveTest_occluderValidation(t as object)
    layerIds = { water: true, back: true, midDecor: true }
    laneIds = { back: true }
    errors = []
    sceneCfgValidateOccluders({ midDecor: [{ left: 0, top: 0, right: 10, bottom: 10 }] }, layerIds, laneIds, errors)
    assertEqual(t, errors.count(), 0, "a valid occluder")
    errors = []
    sceneCfgValidateOccluders({ back: [], nope: [], midDecor: [{ left: 5, top: 0, right: 5, bottom: 10 }] }, layerIds, laneIds, errors)
    assertEqual(t, errors.count(), 3, "lane id, unknown id and an empty rect")
    errors = []
    sceneCfgValidateWeave({ species: [], chance: 2, seekSec: 0, seekSpeed: 1, holdSec: 1, cooldownSec: 1, slack: -1 }, errors)
    assertEqual(t, errors.count(), 3, "chance, seekSec and slack")
end sub

function weaveTest_world(planLane as string) as object
    cfg = behaviorTest_cfg()
    beh = behaviorTest_beh()
    plan = sceneCfgWeavePlan(weaveTest_cfg(), planLane)
    beh.weave = plan
    cfg.lane = plan.lanes[plan.home].rect
    cfg.ellipses = [{ cx: 300, cy: 300, rx: 60, ry: 40 }]
    return { cfg: cfg, beh: beh, world: brainNewWorld(cfg, beh), plan: plan }
end function

function weaveTest_spawn(env as object, species as string, seed as integer) as object
    fish = brainNewBehaviorFish(env.cfg, env.beh, env.world, species, seed, 0)
    weaveAttach(fish, env.world, species, { x: -45, y: 0, width: 240, height: 113 }, [75.0, 56.5], seed + 1)
    return fish
end function

sub weaveTest_attachOnlyListedSpecies(t as object)
    env = weaveTest_world("back")
    assertTrue(t, weaveTest_spawn(env, "royal_blue_tang", 11).wv <> invalid, "listed species weaves")
    assertEqual(t, weaveTest_spawn(env, "moorish_idol", 11).wv, invalid, "unlisted species does not")
    f = weaveTest_spawn(env, "royal_blue_tang", 11)
    assertNear(t, f.box.hw, 120.0, 0.001, "half width about the mirror centre, symmetric")
    assertNear(t, f.box.hh, 56.5, 0.001)
end sub

' Drives fish and returns [{ fish, tick, from, to, hidden }] for every lane switch,
' checking hiddenness at the switch tick with the strict body-in-rect test.
function weaveTest_switches(env as object, seeds as object, ticks as integer) as object
    fishes = []
    for each s in seeds
        fishes.push(weaveTest_spawn(env, "royal_blue_tang", s))
    end for
    out = []
    lanes = []
    for each f in fishes
        lanes.push(f.laneIdx)
    end for
    for now = 0 to ticks - 1
        for i = 0 to fishes.count() - 1
            f = fishes[i]
            brainTickBehavior(f, env.cfg, env.world, now)
            if f.laneSwitch then
                f.laneSwitch = false
                src = lanes[i]
                gap = src
                if f.laneIdx < gap then gap = f.laneIdx
                s = env.plan.lanes[src].scale
                if env.plan.lanes[f.laneIdx].scale > s then s = env.plan.lanes[f.laneIdx].scale
                out.push({ fish: i, tick: now, src: src, dst: f.laneIdx, hidden: weaveHidden(f, env.plan, gap, s) })
                lanes[i] = f.laneIdx
            end if
        end for
    end for
    return out
end function

sub weaveTest_switchOnlyWhenHidden(t as object)
    env = weaveTest_world("back")
    sw = weaveTest_switches(env, [3, 5, 8, 13], 2400)
    assertTrue(t, sw.count() >= 2, "fish switched lanes " + sw.count().toStr() + " times in 300 s")
    for each s in sw
        assertTrue(t, s.hidden, "fish " + s.fish.toStr() + " switched at tick " + s.tick.toStr() + " outside an occluder")
        assertTrue(t, Abs(s.dst - s.src) = 1, "switches go to an adjacent lane")
        assertTrue(t, s.dst <= 1, "no hide rect between mid and front, so never the front lane")
    end for
end sub

sub weaveTest_sameSeedSameSwitches(t as object)
    a = weaveTest_switches(weaveTest_world("back"), [3, 5], 1600)
    b = weaveTest_switches(weaveTest_world("back"), [3, 5], 1600)
    assertEqual(t, a.count(), b.count())
    for i = 0 to a.count() - 1
        assertEqual(t, a[i].tick, b[i].tick, "switch " + i.toStr() + " tick")
        assertEqual(t, a[i].dst, b[i].dst, "switch " + i.toStr() + " lane")
    end for
end sub

sub weaveTest_noRegionNoSwitch(t as object)
    env = weaveTest_world("mid")
    ' A hide rect smaller than the fish body leaves no anchor region.
    env.plan.gaps[0] = [{ left: 1000, top: 500, right: 1100, bottom: 560 }]
    sw = weaveTest_switches(env, [3, 5, 8], 1600)
    assertEqual(t, sw.count(), 0, "no lane switch without a hide region")
end sub
