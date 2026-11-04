' Unit tests for components/lib/night.brs (P3.3-P3.6).

function nightTestSuite() as object
    return {
        name: "night"
        tests: [
            { name: "parseClock", fn: nightTest_parseClock }
            { name: "clockMinutes", fn: nightTest_clockMinutes }
            { name: "stepEases", fn: nightTest_stepEases }
            { name: "fxLevelsNeverStack", fn: nightTest_fxLevelsNeverStack }
            { name: "phaseToFxLevels", fn: nightTest_phaseToFxLevels }
            { name: "lerpColor", fn: nightTest_lerpColor }
            { name: "multiplyColor", fn: nightTest_multiplyColor }
            { name: "breathKeysLoop", fn: nightTest_breathKeysLoop }
            { name: "waveKeysLoop", fn: nightTest_waveKeysLoop }
            { name: "glowItemsFilter", fn: nightTest_glowItemsFilter }
            { name: "sparklePoolConstant", fn: nightTest_sparklePoolConstant }
        ]
    }
end function

sub nightTest_parseClock(t as object)
    c = nightParseClock("23:00")
    assertNear(t, c.minutes, 1380, 0.001, "23:00")
    assertEqual(t, c.year, 0, "no date")
    c = nightParseClock("7:05")
    assertNear(t, c.minutes, 425, 0.001, "7:05")
    c = nightParseClock("2026-11-04T17:14")
    assertNear(t, c.minutes, 1034, 0.001, "date and time")
    assertEqual(t, c.year, 2026, "year")
    assertEqual(t, c.month, 11, "month")
    assertEqual(t, c.day, 4, "day")
    c = nightParseClock("2026-06-21 05:30")
    assertNear(t, c.minutes, 330, 0.001, "space separator")
    assertTrue(t, nightParseClock("") = invalid, "empty")
    assertTrue(t, nightParseClock("24:00") = invalid, "hour 24")
    assertTrue(t, nightParseClock("12:60") = invalid, "minute 60")
    assertTrue(t, nightParseClock("noon") = invalid, "word")
    assertTrue(t, nightParseClock("12:3x") = invalid, "letter")
end sub

sub nightTest_clockMinutes(t as object)
    assertNear(t, nightClockMinutes(1380, 0, 1), 1380, 0.001, "start")
    assertNear(t, nightClockMinutes(1380, 120, 1), 1382, 0.001, "two minutes later")
    assertNear(t, nightClockMinutes(1000, 30, 60), 1030, 0.001, "speed 60")
end sub

sub nightTest_stepEases(t as object)
    assertNear(t, nightStep(0, 1, 1, 3), 0.33333, 0.0001, "one second of a 3 s ease")
    assertNear(t, nightStep(1, 0, 1, 4), 0.75, 0.0001, "back toward day")
    assertNear(t, nightStep(0.5, 0.51, 1, 3), 0.51, 0.0001, "small solar steps are followed exactly")
    assertNear(t, nightStep(0, 1, 0.25, 0), 1, 0.0001, "ease 0 snaps")
    ' A full ease reaches the target within easeSeconds and stays there.
    b = 0.0
    for i = 1 to 12
        b = nightStep(b, 1, 0.25, 3)
    end for
    assertNear(t, b, 1, 0.0001, "12 ticks of 0.25 s cover a 3 s ease")
end sub

sub nightTest_fxLevelsNeverStack(t as object)
    for i = 0 to 100
        blend = i / 100.0
        d = nightDayLevel(blend)
        n = nightNightLevel(blend)
        assertTrue(t, d = 0 or n = 0, "day and night shafts both visible at blend " + blend.toStr())
        assertTrue(t, d >= 0 and d <= 1 and n >= 0 and n <= 1, "levels in 0..1 at " + blend.toStr())
    end for
    assertNear(t, nightDayLevel(0), 1, 0.0001, "day at 0")
    assertNear(t, nightDayLevel(0.25), 0.5, 0.0001, "day at 0.25")
    assertNear(t, nightNightLevel(0.75), 0.5, 0.0001, "night at 0.75")
    assertNear(t, nightNightLevel(1), 1, 0.0001, "night at 1")
    assertTrue(t, not nightIsNight(0.49), "0.49 is not night")
    assertTrue(t, nightIsNight(0.5), "0.5 is night")
end sub

' Phase blend from daynight feeds the levels: noon is pure day, mid dusk shows
' neither shaft pair, 23:00 is pure night.
sub nightTest_phaseToFxLevels(t as object)
    solar = { civilDawn: 360.0, sunrise: 390.0, sunset: 1020.0, civilDusk: 1050.0 }
    noon = daynightPhase(720.0, solar, "auto")
    assertNear(t, nightDayLevel(noon.blend), 1, 0.0001, "noon day shafts")
    assertNear(t, nightNightLevel(noon.blend), 0, 0.0001, "noon night overlays")
    dusk = daynightPhase(1035.0, solar, "auto")
    assertNear(t, nightDayLevel(dusk.blend) + nightNightLevel(dusk.blend), 0, 0.0001, "mid dusk")
    late = daynightPhase(1380.0, solar, "auto")
    assertNear(t, nightNightLevel(late.blend), 1, 0.0001, "23:00 night overlays")
    forced = daynightPhase(720.0, solar, "night")
    assertTrue(t, nightIsNight(forced.blend), "nightMode night at noon")
end sub

sub nightTest_lerpColor(t as object)
    white = &hFFFFFFFF
    moon = &h40568CFF
    assertEqual(t, nightLerpColor(white, moon, 0), white, "blend 0")
    assertEqual(t, nightLerpColor(white, moon, 1), moon, "blend 1")
    ' (255 + 64) / 2 = 159.5 -> 160, (255 + 86) / 2 -> 171, (255 + 140) / 2 -> 198
    assertEqual(t, nightLerpColor(white, moon, 0.5), &hA0ABC6FF, "blend 0.5")
    assertEqual(t, nightLerpColor(&h00000000, &hFF00FF80, 0.5), &h80008040, "alpha too")
end sub

sub nightTest_multiplyColor(t as object)
    assertEqual(t, nightMultiplyColor(&hFFFFFFFF, &h40568CFF), &h40568CFF, "white x tint")
    assertEqual(t, nightMultiplyColor(&h9FB8D2FF, &hFFFFFFFF), &h9FB8D2FF, "base x white is exact")
    ' 0x9F x 0x40 / 255 = 39.9 -> 40 (0x28), 0xB8 x 0x56 / 255 -> 62 (0x3E), 0xD2 x 0x8C / 255 -> 115 (0x73)
    assertEqual(t, nightMultiplyColor(&h9FB8D2FF, &h40568CFF), &h283E73FF, "lane tint x moon")
end sub

sub nightTest_breathKeysLoop(t as object)
    k = nightBreathKeys(0.5, 0.8, 0, 9)
    assertEqual(t, k.keys.count(), 9, "key count")
    assertNear(t, k.keys[0], 0, 0.0001, "first key")
    assertNear(t, k.keys[8], 1, 0.0001, "last key")
    assertNear(t, k.values[0], k.values[8], 0.0001, "loops without a jump")
    assertNear(t, k.values[0], 0.65, 0.0001, "phase 0 starts mid")
    assertNear(t, k.values[2], 0.8, 0.0001, "peak at a quarter")
    assertNear(t, k.values[6], 0.5, 0.0001, "trough at three quarters")
    p = nightBreathKeys(0.5, 0.8, 90, 9)
    assertNear(t, p.values[0], 0.8, 0.0001, "phase 90 starts at the peak")
end sub

sub nightTest_waveKeysLoop(t as object)
    k = nightWaveKeys([9, 13, 17], 40, 8)
    assertEqual(t, k.keys.count(), 137, "17 cycles x 8 keys + 1")
    assertNear(t, k.keys[0], 0, 0.0001, "first key")
    assertNear(t, k.keys[136], 1, 0.0001, "last key")
    assertNear(t, k.values[0], k.values[136], 0.0001, "loops without a jump")
    lo = 1.0
    hi = -1.0
    for each v in k.values
        if v < lo then lo = v
        if v > hi then hi = v
    end for
    assertTrue(t, lo >= -1 and hi <= 1, "values in -1..1")
    assertTrue(t, hi - lo > 0.8, "wave has real swing")
    again = nightWaveKeys([9, 13, 17], 40, 8)
    assertNear(t, again.values[57], k.values[57], 0.000001, "deterministic")
    other = nightWaveKeys([9, 13, 17], 180, 8)
    assertTrue(t, Abs(other.values[57] - k.values[57]) > 0.0001, "phase shifts the wave")
    assertNear(t, nightWaveAt([], 0, 0.3), 0, 0.0001, "no components is flat")
end sub

sub nightTest_glowItemsFilter(t as object)
    glow = {
        groups: ["front_coral"]
        items: [
            { id: "g1", over: "front_coral_a0_0" }
            { id: "g2", over: "mid_coral_3" }
            { id: "g3", over: "front_coral_b1_2" }
            { id: "g4", over: "reefBackdrop" }
        ]
    }
    got = nightGlowItems(glow)
    assertEqual(t, got.count(), 2, "front only")
    assertEqual(t, got[0].id, "g1", "first")
    assertEqual(t, got[1].id, "g3", "second")
    glow.groups = ["front_coral", "mid_coral", "reefBackdrop"]
    assertEqual(t, nightGlowItems(glow).count(), 4, "all groups")
    glow.groups = []
    assertEqual(t, nightGlowItems(glow).count(), 0, "none")
end sub

sub nightTest_sparklePoolConstant(t as object)
    cfg = {
        pool: 30
        area: { left: 40, top: 120, right: 1880, bottom: 940 }
        sizeMin: 16
        sizeMax: 32
        driftMin: 20
        driftMax: 70
        periodMin: 7.0
        periodMax: 13.0
        delayMax: 4.0
        opacityMin: 0.4
        opacityMax: 1.0
    }
    a = nightSparkleSlots(cfg, prngNew(7))
    assertEqual(t, a.count(), 30, "pool size")
    for each s in a
        assertTrue(t, s.size >= 16 and s.size <= 32, "size in range")
        assertTrue(t, s.x >= 40 and s.x + s.size <= 1880, "x in area")
        assertTrue(t, s.y >= 120 and s.y + s.size <= 940, "y in area")
        assertTrue(t, s.period >= 7 and s.period <= 13, "period in range")
        assertTrue(t, s.peak >= 0.4 and s.peak <= 1, "peak in range")
    end for
    b = nightSparkleSlots(cfg, prngNew(7))
    assertEqual(t, b[17].x, a[17].x, "same seed, same layout")
    assertNear(t, b[17].period, a[17].period, 0.00001, "same seed, same period")
    tw = nightTwinkleKeys(0.8)
    assertEqual(t, tw.values[0], 0.0, "twinkle starts dark")
    assertEqual(t, tw.values[tw.values.count() - 1], 0.0, "twinkle ends dark")
    assertEqual(t, tw.keys.count(), tw.values.count(), "key and value counts")
end sub
