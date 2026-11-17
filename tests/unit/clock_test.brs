function clockTestSuite() as object
    return {
        name: "clock", tests: [
            { name: "localTimeFormatting", fn: clockTest_format }
            { name: "defaultOffAndPersistence", fn: clockTest_settings }
            { name: "subtleAndMoving", fn: clockTest_style }
            { name: "previewClockParsing", fn: clockTest_preview }
        ]
    }
end function

sub clockTest_format(t as object)
    assertEqual(t, clockDisplay(0, "12h"), "12:00 AM", "midnight")
    assertEqual(t, clockDisplay(720, "12h"), "12:00 PM", "noon")
    assertEqual(t, clockDisplay(785, "12h"), "1:05 PM", "minute padding")
    assertEqual(t, clockDisplay(1439, "24h"), "23:59", "24 hour")
    assertEqual(t, clockDisplay(1440, "24h"), "00:00", "midnight rollover")
    assertEqual(t, clockDisplay(-1, "24h"), "23:59", "negative wrap")
    assertEqual(t, clockDisplay(65, ""), "1:05 AM", "unknown clock format fallback")
end sub

sub clockTest_settings(t as object)
    store = settingsMemoryStore()
    assertEqual(t, settingsLoad(store).digitalClock, "off", "opt in default")
    assertEqual(t, settingsApplyPlan(invalid).digitalClockEnabled, false, "invalid settings stay off")
    values = settingsLoad(store)
    values.digitalClock = settingsStep("digitalClock", values.digitalClock, 1)
    settingsSave(store, values)
    assertEqual(t, settingsLoad(store).digitalClock, "on", "toggle persists")
    assertEqual(t, settingsApplyPlan(settingsLoad(store)).digitalClockEnabled, true, "scene receives enabled")
    settingsLocationSave(store, "35.2,-80.8")
    assertEqual(t, settingsLoad(store).digitalClock, "on", "location does not clear clock")
    store.write("digitalClock", "yes")
    assertEqual(t, settingsLoad(store).digitalClock, "off", "invalid stored value defaults off")
end sub

sub clockTest_style(t as object)
    assertEqual(t, clockParts(65, "12h").time, "1:05", "separate time")
    assertEqual(t, clockParts(65, "12h").period, "AM", "small period")
    assertEqual(t, clockParts(665, "12h").time, "11:05", "two digit hours")
    assertEqual(t, clockParts(785, "12h").period, "PM", "afternoon period")
    assertEqual(t, clockParts(785, "24h").period, "", "24 hour has no period")
    assertEqual(t, clockParts(785, "24h").time, "13:05", "24 hour time")
    assertEqual(t, clockColor(0), &h70B7D0FF, "day water blue")
    assertEqual(t, clockColor(1), &h6A91B7FF, "night water blue")
    assertEqual(t, clockColor(-1), clockColor(0), "day color clamp")
    assertEqual(t, clockColor(2), clockColor(1), "night color clamp")
    assertNear(t, clockOpacity(0), 0.16, 0.00001, "subtle day text")
    assertNear(t, clockOpacity(1), 0.10, 0.00001, "dim at night")
    assertNear(t, clockOpacity(3), 0.10, 0.00001, "night clamp")
    plan = clockDriftPlan()
    assertEqual(t, plan.keys.count(), 49, "smooth native drift knots")
    assertEqual(t, plan.values.count(), plan.keys.count(), "matched key arrays")
    for each p in plan.values
        assertTrue(t, p[0] >= 597 and p[0] <= 681, "x stays in safe water region")
        assertTrue(t, p[1] >= 222 and p[1] <= 258, "y stays in safe water region")
    end for
    assertTrue(t, Abs(clockDriftAt(210)[0] - clockDriftAt(0)[0]) > 40, "independent drift changes pixels")
    assertNear(t, plan.values[0][0], plan.values[48][0], 0.001, "x loop closes")
    assertNear(t, plan.values[0][1], plan.values[48][1], 0.001, "y loop closes")
end sub

sub clockTest_preview(t as object)
    assertEqual(t, clockPreviewMinutes("2026-11-17T23:59"), 1439, "dated preview")
    assertEqual(t, clockPreviewMinutes("1:05"), 65, "short preview")
    assertEqual(t, clockPreviewMinutes("24:00"), invalid, "bad hour")
    assertEqual(t, clockPreviewMinutes("7:99"), invalid, "bad minute")
    assertEqual(t, clockPreviewMinutes(""), invalid, "absent means real local clock")
end sub
