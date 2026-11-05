' Unit tests for components/lib/glow.brs (night light organs) and the scene.json
' nightSchool density plan.

function glowTestSuite() as object
    return {
        name: "glow"
        tests: [
            { name: "blinkLoopCloses", fn: glowTest_blinkLoopCloses }
            { name: "blinkSpansInRange", fn: glowTest_blinkSpansInRange }
            { name: "blinkDeterministicPerSeed", fn: glowTest_blinkDeterministicPerSeed }
            { name: "blinkAtPose", fn: glowTest_blinkAtPose }
            { name: "rotatePlan", fn: glowTest_rotatePlan }
            { name: "nightShow", fn: glowTest_nightShow }
            { name: "nightSchoolPlan", fn: glowTest_nightSchoolPlan }
        ]
    }
end function

function glowTest_cfg() as object
    return { blinkLoopSec: [9, 14], blinkOnSec: [1.6, 5.0], blinkOffSec: [0.12, 0.35], blinkFadeSec: 0.06 }
end function

sub glowTest_blinkLoopCloses(t as object)
    for seed = 1 to 40
        p = glowBlinkPlan(glowTest_cfg(), prngNew(seed))
        last = p.keys.count() - 1
        assertEqual(t, p.keys.count(), p.values.count(), "keys and values pair up")
        assertNear(t, p.keys[0], 0.0, 0.000001, "starts at 0")
        assertNear(t, p.keys[last], 1.0, 0.000001, "ends at 1")
        assertEqual(t, p.values[0], p.values[last], "loop closes lit")
        assertTrue(t, p.duration >= 9 and p.duration <= 14, "duration in range")
        assertTrue(t, last >= 5, "at least one blink per loop (seed " + seed.toStr() + ")")
        for i = 1 to last
            assertTrue(t, p.keys[i] > p.keys[i - 1], "keys strictly increase")
        end for
    end for
end sub

' Each blink is lit -> fade -> shut span -> fade -> lit; shut spans and lit spans stay
' inside their configured ranges, and the tail of the loop is lit at least blinkOnSec[0].
sub glowTest_blinkSpansInRange(t as object)
    for seed = 1 to 40
        p = glowBlinkPlan(glowTest_cfg(), prngNew(seed * 13))
        d = p.duration
        n = p.keys.count()
        lastLit = 0.0
        i = 1
        while i + 3 < n
            assertEqual(t, p.values[i], 1.0, "lit before the blink")
            assertEqual(t, p.values[i + 1], 0.0, "shut")
            assertEqual(t, p.values[i + 2], 0.0, "still shut")
            assertEqual(t, p.values[i + 3], 1.0, "lit again")
            lit = (p.keys[i] - lastLit) * d
            assertTrue(t, lit >= 1.6 - 0.001 and lit <= 5.0 + 0.001, "lit span " + Str(lit))
            assertNear(t, (p.keys[i + 1] - p.keys[i]) * d, 0.06, 0.001, "fade out")
            shut = (p.keys[i + 2] - p.keys[i + 1]) * d
            assertTrue(t, shut >= 0.12 - 0.001 and shut <= 0.35 + 0.001, "shut span " + Str(shut))
            assertNear(t, (p.keys[i + 3] - p.keys[i + 2]) * d, 0.06, 0.001, "fade in")
            lastLit = p.keys[i + 3]
            i = i + 4
        end while
        assertEqual(t, i, n - 1, "only the closing key is left")
        assertTrue(t, (1.0 - lastLit) * d >= 1.6 - 0.001, "tail lit span")
    end for
end sub

sub glowTest_blinkDeterministicPerSeed(t as object)
    a = glowBlinkPlan(glowTest_cfg(), prngNew(77))
    b = glowBlinkPlan(glowTest_cfg(), prngNew(77))
    c = glowBlinkPlan(glowTest_cfg(), prngNew(78))
    assertEqual(t, a.duration, b.duration, "same seed, same loop")
    assertEqual(t, a.keys.count(), b.keys.count(), "same seed, same blinks")
    assertTrue(t, a.duration <> c.duration, "another seed, another loop")
end sub

sub glowTest_blinkAtPose(t as object)
    p = { duration: 10.0, keys: [0.0, 0.3, 0.31, 0.33, 0.34, 1.0], values: [1.0, 1.0, 0.0, 0.0, 1.0, 1.0] }
    assertNear(t, glowBlinkAt(p, 0.0), 1.0, 0.0001, "lit at 0")
    assertNear(t, glowBlinkAt(p, 3.05), 0.5, 0.0001, "half way through the fade")
    assertNear(t, glowBlinkAt(p, 3.2), 0.0, 0.0001, "shut")
    assertNear(t, glowBlinkAt(p, 13.2), 0.0, 0.0001, "wraps every duration")
    assertNear(t, glowBlinkAt(p, 9.9), 1.0, 0.0001, "lit near the end")
end sub

sub glowTest_rotatePlan(t as object)
    for seed = 1 to 30
        p = glowBlinkPlan(glowTest_cfg(), prngNew(seed * 31))
        assertTrue(t, p.phase >= 0 and p.phase < 1, "phase in [0, 1)")
        r = glowRotatePlan(p, p.phase)
        last = r.keys.count() - 1
        assertEqual(t, r.keys.count(), r.values.count(), "keys and values pair up")
        assertNear(t, r.keys[0], 0.0, 0.000001, "starts at 0")
        assertNear(t, r.keys[last], 1.0, 0.000001, "ends at 1")
        assertEqual(t, r.values[0], r.values[last], "rotated loop closes")
        for i = 1 to last
            assertTrue(t, r.keys[i] > r.keys[i - 1], "keys strictly increase (seed " + seed.toStr() + ")")
        end for
        for k = 0 to 40
            s = k * p.duration / 40.0
            assertNear(t, glowBlinkAt(r, s), glowBlinkAt(p, s + p.phase * p.duration), 0.002, "same curve, shifted (float keys)")
        end for
    end for
end sub

sub glowTest_nightShow(t as object)
    s = glowNightShow(0.0)
    assertEqual(t, s.visible, false, "hidden by day")
    assertNear(t, s.opacity, 0.0, 0.0001)
    s = glowNightShow(-0.5)
    assertEqual(t, s.visible, false, "hidden below 0")
    s = glowNightShow(0.25)
    assertEqual(t, s.visible, true, "shown as night falls")
    assertNear(t, s.opacity, 0.25, 0.0001)
    s = glowNightShow(1.0)
    assertNear(t, s.opacity, 1.0, 0.0001, "full at night")
    s = glowNightShow(1.5)
    assertNear(t, s.opacity, 1.0, 0.0001, "clamped")
end sub

sub glowTest_nightSchoolPlan(t as object)
    cfg = scenecfgTest_popSample()
    pop = cfg.population
    pop.densities.normal.nightSchool = { lane: "backLane", count: 6 }
    errors = sceneCfgValidate(cfg)
    assertEqual(t, errors.count(), 1, "nightSchool needs nightSchoolUri: " + errors.join("|"))
    assertTrue(t, Instr(1, errors.join("|"), "density normal has a nightSchool but population has no nightSchoolUri") > 0, errors.join("|"))
    pop.nightSchoolUri = "pkg:/config/night_school.json"
    errors = sceneCfgValidate(cfg)
    assertEqual(t, errors.count(), 0, errors.join("|"))

    plan = sceneCfgDensityPlan(cfg, "normal")
    assertTrue(t, plan.nightSchool <> invalid, "normal has a night school")
    assertEqual(t, plan.nightSchool.lane.id, "backLane")
    assertEqual(t, plan.nightSchool.count, 6)
    assertEqual(t, plan.school.count, 10, "chromis school unchanged")
    assertTrue(t, sceneCfgDensityPlan(cfg, "calm").nightSchool = invalid, "calm has none")

    pop.densities.calm.nightSchool = { lane: "reef", count: 2 }
    pop.densities.busy.nightSchool = { lane: "backLane", count: 0.5 }
    text = sceneCfgValidate(cfg).join("|")
    assertTrue(t, Instr(1, text, "density calm nightSchool needs a lane id") > 0, text)
    assertTrue(t, Instr(1, text, "density busy nightSchool count must be a whole number") > 0, text)
end sub
