function fishbeatTestSuite() as object
    return {
        name: "fishbeat"
        tests: [
            { name: "speedMatchedTail", fn: fishbeatTest_frequency }
            { name: "originalFinClampsUnchanged", fn: fishbeatTest_clamps }
            { name: "elapsedPhaseAndPause", fn: fishbeatTest_phase }
            { name: "retimePreservesCurve", fn: fishbeatTest_curve }
            { name: "retimeThreshold", fn: fishbeatTest_threshold }
            { name: "pauseTransitionsOnly", fn: fishbeatTest_pauseTransitions }
        ]
    }
end function

sub fishbeatTest_frequency(t as object)
    previous = 100.0
    for each speed in [-10, 0, 1, 20, 35, 60, 100, 200, 420, 1000]
        p = fishBeatPeriods(speed)
        assertTrue(t, p.tail <= previous, "tail frequency rises with speed")
        assertTrue(t, p.tail >= 1.0 / 2.1 - 0.00001, "dart frequency capped")
        previous = p.tail
    end for
    assertNear(t, fishBeatTailPeriod(0), 1.0 / 0.12, 0.00001, "hover tail is slow")
    assertTrue(t, fishBeatTailPeriod(35) > 2.2857, "slow cruise beats slower than old mapping")
    assertTrue(t, fishBeatTailPeriod(269) < fishBeatTailPeriod(60), "dart faster than cruise")
end sub

sub fishbeatTest_clamps(t as object)
    assertNear(t, fishBeatPeriods(60).fin, 1.0, 0.00001, "normal fin period")
    assertNear(t, fishBeatPeriods(0).fin, 3.0, 0.00001, "slow fin clamp")
    assertNear(t, fishBeatPeriods(1000).fin, 0.35, 0.00001, "fast fin clamp")
end sub

sub fishbeatTest_phase(t as object)
    assertNear(t, fishBeatPhase(0.8, 0.6, 2), 0.1, 0.00001, "phase wraps")
    assertNear(t, fishBeatPhase(0.37, 0, 2), 0.37, 0.00001, "paused phase holds")
    assertNear(t, fishBeatPhase(0.37, -3, 2), 0.37, 0.00001, "negative elapsed ignored")
    assertNear(t, fishBeatPhase(0.37, 8, 0), 0.37, 0.00001, "uninitialized period safe")
    phase = 0.17
    total = 0.0
    for each dt in [0.017, 0.033, 0.12, 0.005, 0.4, 0.07]
        phase = fishBeatPhase(phase, dt, 1.8)
        total = total + dt
    end for
    assertNear(t, phase, fishBeatPhase(0.17, total, 1.8), 0.00001, "callback frequency independent")
    atPause = fishBeatPhase(0.17, 0.4, 1.8)
    resumed = fishBeatPhase(atPause, 0.2, 1.8)
    assertNear(t, resumed, fishBeatPhase(0.17, 0.6, 1.8), 0.00001, "paused wall time excluded")
end sub

sub fishbeatTest_curve(t as object)
    for each phase in [0.0, 0.031, 0.25, 0.499, 0.71, 0.999]
        curve = fishBeatTailCurve(phase, 0.2, 0.5)
        expected = fishBeatTailSample(phase, 0.2, 0.5)
        last = curve.keys.count() - 1
        assertNear(t, curve.keys[0], 0, 0.00001, "starts at zero")
        assertNear(t, curve.keys[last], 1, 0.00001, "ends at one")
        assertNear(t, curve.rotations[0], expected.rotation, 0.00001, "retime keeps rotation")
        assertNear(t, curve.scales[0][0], expected.scale[0], 0.00001, "retime keeps foreshortening")
        assertNear(t, curve.rotations[last], curve.rotations[0], 0.00001, "rotation loop closes")
        assertNear(t, curve.scales[last][0], curve.scales[0][0], 0.00001, "sway loop closes")
        for i = 1 to last
            assertTrue(t, curve.keys[i] > curve.keys[i - 1], "strictly increasing keys")
        end for
        mirrored = fishBeatTailCurve(phase, -0.2, 0.5)
        assertNear(t, mirrored.rotations[0], -curve.rotations[0], 0.00001, "mirrored swing sign")
    end for
end sub

sub fishbeatTest_threshold(t as object)
    assertTrue(t, fishBeatShouldRetime(0, 2), "initialization always retimes")
    assertEqual(t, fishBeatShouldRetime(2, 2.1), false, "small velocity jitter ignored")
    assertTrue(t, fishBeatShouldRetime(2, 2.4), "slowdown retimes")
    assertTrue(t, fishBeatShouldRetime(2, 1.5), "acceleration retimes")
end sub

sub fishbeatTest_pauseTransitions(t as object)
    assertEqual(t, fishBeatPauseAction(false, false), "", "running speed update must not resume/restart tail")
    assertEqual(t, fishBeatPauseAction(false, true), "pause", "running to paused")
    assertEqual(t, fishBeatPauseAction(true, true), "", "retimed paused tail stays paused")
    assertEqual(t, fishBeatPauseAction(true, false), "resume", "paused to running")
    assertEqual(t, fishBeatPauseAction(false, false), "", "initial start is not followed by resume")
end sub
