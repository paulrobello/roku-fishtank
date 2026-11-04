' Unit tests for components/lib/daynight.brs.
' Most tests use fixed synthetic solar times so boundaries are exact:
'   civilDawn 06:00 (360), sunrise 06:30 (390), sunset 17:00 (1020),
'   civilDusk 17:30 (1050).

function daynightTestSuite() as object
    return {
        name: "daynight"
        tests: [
            { name: "boundaries", fn: daynightTest_boundaries }
            { name: "midPhases", fn: daynightTest_midPhases }
            { name: "duskBlendMonotonic", fn: daynightTest_duskBlendMonotonic }
            { name: "dawnBlendMonotonic", fn: daynightTest_dawnBlendMonotonic }
            { name: "overrideModes", fn: daynightTest_overrideModes }
            { name: "midnightWrap", fn: daynightTest_midnightWrap }
            { name: "blendContinuousAllDay", fn: daynightTest_blendContinuousAllDay }
            { name: "woodlandSolarTimes", fn: daynightTest_woodlandSolarTimes }
            { name: "missingEventsFallBackToDay", fn: daynightTest_missingEventsFallBackToDay }
        ]
    }
end function

function daynightTestSolar() as object
    return { civilDawn: 360.0, sunrise: 390.0, sunset: 1020.0, civilDusk: 1050.0 }
end function

sub daynightTestExpect(t as object, minutes as dynamic, mode as string, phase as string, blend as float, label as string)
    got = daynightPhase(minutes, daynightTestSolar(), mode)
    assertEqual(t, got.phase, phase, label + " phase")
    assertNear(t, got.blend, blend, 0.000001, label + " blend")
end sub

sub daynightTest_boundaries(t as object)
    daynightTestExpect(t, 1020.0, "auto", "dusk", 0.0, "exactly sunset")
    daynightTestExpect(t, 1050.0, "auto", "night", 1.0, "exactly end of civil dusk")
    daynightTestExpect(t, 360.0, "auto", "dawn", 1.0, "exactly start of civil dawn")
    daynightTestExpect(t, 390.0, "auto", "day", 0.0, "exactly sunrise")
    daynightTestExpect(t, 1019.99, "auto", "day", 0.0, "just before sunset")
    daynightTestExpect(t, 359.99, "auto", "night", 1.0, "just before civil dawn")
end sub

sub daynightTest_midPhases(t as object)
    daynightTestExpect(t, 720.0, "auto", "day", 0.0, "noon")
    daynightTestExpect(t, 1035.0, "auto", "dusk", 0.5, "mid dusk")
    daynightTestExpect(t, 375.0, "auto", "dawn", 0.5, "mid dawn")
    daynightTestExpect(t, 1380.0, "auto", "night", 1.0, "23:00")
    daynightTestExpect(t, 180.0, "auto", "night", 1.0, "03:00")
end sub

sub daynightTest_duskBlendMonotonic(t as object)
    solar = daynightTestSolar()
    prev = -1.0
    for minute = 1015 to 1055
        for frac = 0 to 3
            got = daynightPhase(minute + frac * 0.25, solar, "auto")
            label = "dusk at " + (minute + frac * 0.25).toStr()
            if not assertTrue(t, got.blend >= prev, label + " blend " + got.blend.toStr() + " < " + prev.toStr()) then return
            if not assertTrue(t, got.blend >= 0 and got.blend <= 1, label + " blend out of [0,1]") then return
            prev = got.blend
        end for
    end for
    assertNear(t, prev, 1.0, 0.000001, "blend reaches night")
end sub

sub daynightTest_dawnBlendMonotonic(t as object)
    solar = daynightTestSolar()
    prev = 2.0
    for minute = 355 to 395
        for frac = 0 to 3
            got = daynightPhase(minute + frac * 0.25, solar, "auto")
            label = "dawn at " + (minute + frac * 0.25).toStr()
            if not assertTrue(t, got.blend <= prev, label + " blend " + got.blend.toStr() + " > " + prev.toStr()) then return
            if not assertTrue(t, got.blend >= 0 and got.blend <= 1, label + " blend out of [0,1]") then return
            prev = got.blend
        end for
    end for
    assertNear(t, prev, 0.0, 0.000001, "blend reaches day")
end sub

sub daynightTest_overrideModes(t as object)
    samples = [0.0, 180.0, 360.0, 375.0, 390.0, 720.0, 1020.0, 1035.0, 1050.0, 1380.0, 1439.5]
    for each minutes in samples
        label = " at " + minutes.toStr()
        daynightTestExpect(t, minutes, "day", "day", 0.0, "day override" + label)
        daynightTestExpect(t, minutes, "night", "night", 1.0, "night override" + label)
        daynightTestExpect(t, minutes, "Night", "night", 1.0, "mixed-case night override" + label)
    end for
    daynightTestExpect(t, 720.0, "auto", "day", 0.0, "auto at noon")
    daynightTestExpect(t, 1380.0, "auto", "night", 1.0, "auto at 23:00")
    daynightTestExpect(t, 1380.0, "bogus", "night", 1.0, "unknown mode follows the sun")
    daynightTestExpect(t, 720.0, "", "day", 0.0, "empty mode follows the sun")
end sub

sub daynightTest_midnightWrap(t as object)
    daynightTestExpect(t, 1439.0, "auto", "night", 1.0, "23:59")
    daynightTestExpect(t, 1439.99, "auto", "night", 1.0, "23:59.99")
    daynightTestExpect(t, 0.0, "auto", "night", 1.0, "00:00")
    daynightTestExpect(t, 1440.0, "auto", "night", 1.0, "1440 wraps to 00:00")
    daynightTestExpect(t, 1440.0 + 1035.0, "auto", "dusk", 0.5, "next-day mid dusk wraps")
    daynightTestExpect(t, -60.0, "auto", "night", 1.0, "-60 wraps to 23:00")
    daynightTestExpect(t, -1440.0 + 375.0, "auto", "dawn", 0.5, "previous-day mid dawn wraps")
end sub

' Walks the whole day in quarter-minute steps (crossing midnight) and checks
' that the blend never jumps by more than one step's worth of dusk or dawn.
sub daynightTest_blendContinuousAllDay(t as object)
    solar = daynightTestSolar()
    stepMin = 0.25
    maxJump = stepMin / 30.0 + 0.000001
    prev = daynightPhase(1200.0, solar, "auto").blend
    for i = 1 to 1440 * 4
        minutes = 1200.0 + i * stepMin
        got = daynightPhase(minutes, solar, "auto")
        if not assertTrue(t, Abs(got.blend - prev) <= maxJump, "blend jump at " + minutes.toStr()) then return
        prev = got.blend
    end for
end sub

sub daynightTest_woodlandSolarTimes(t as object)
    solar = solarTimes(38.68, -121.77, 2026, 11, 1, -480)
    assertEqual(t, daynightPhase(solar.sunset, solar, "auto").phase, "dusk", "at sunset")
    assertEqual(t, daynightPhase(solar.civilDusk, solar, "auto").phase, "night", "at civil dusk")
    assertEqual(t, daynightPhase(solar.civilDawn, solar, "auto").phase, "dawn", "at civil dawn")
    assertEqual(t, daynightPhase(solar.sunrise, solar, "auto").phase, "day", "at sunrise")
    mid = daynightPhase((solar.sunset + solar.civilDusk) / 2, solar, "auto")
    assertEqual(t, mid.phase, "dusk", "mid dusk phase")
    assertNear(t, mid.blend, 0.5, 0.001, "mid dusk blend")
end sub

sub daynightTest_missingEventsFallBackToDay(t as object)
    polar = { civilDawn: invalid, sunrise: invalid, sunset: invalid, civilDusk: invalid }
    got = daynightPhase(720.0, polar, "auto")
    assertEqual(t, got.phase, "day", "polar auto phase")
    assertEqual(t, daynightPhase(720.0, polar, "night").phase, "night", "polar night override")
end sub
