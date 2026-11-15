function fishbeatTestSuite() as object
    return {
        name: "fishbeat"
        tests: [
            { name: "frequencyIsExactlyThreeQuarters", fn: fishbeatTest_frequency }
            { name: "originalFinClampsUnchanged", fn: fishbeatTest_clamps }
        ]
    }
end function

sub fishbeatTest_frequency(t as object)
    for each speed in [-10, 0, 1, 20, 35, 60, 100, 200, 420, 1000]
        p = fishBeatPeriods(speed)
        if not assertNear(t, p.fin / p.tail, 0.75, 0.00001, "tail frequency ratio") then return
    end for
end sub

sub fishbeatTest_clamps(t as object)
    assertNear(t, fishBeatPeriods(60).fin, 1.0, 0.00001, "normal fin period")
    assertNear(t, fishBeatPeriods(60).tail, 1.3333333, 0.00001, "normal tail period")
    assertNear(t, fishBeatPeriods(0).fin, 3.0, 0.00001, "slow fin clamp")
    assertNear(t, fishBeatPeriods(1000).fin, 0.35, 0.00001, "fast fin clamp")
end sub
