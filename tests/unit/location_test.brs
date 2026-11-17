function locationTestSuite() as object
    return {
        name: "location"
        tests: [
            { name: "offlineLookup", fn: locationTest_lookup }
            { name: "bundledDatabase", fn: locationTest_database }
            { name: "parseAndValidate", fn: locationTest_parse }
            { name: "persistAndPreserve", fn: locationTest_persist }
            { name: "charlotteMorning", fn: locationTest_charlotte }
            { name: "refreshDateAndDst", fn: locationTest_refresh }
            { name: "hemisphereAndPolar", fn: locationTest_hemisphere }
        ]
    }
end function

sub locationTest_parse(t as object)
    loc = settingsLocationParse(" 35.2271, -80.8431 ")
    assertNear(t, loc.latitude, 35.2271, 0.0001, "latitude")
    assertNear(t, loc.longitude, -80.8431, 0.0001, "longitude")
    assertEqual(t, settingsLocationLabel(loc), "Charlotte, NC", "city name")
    for each value in [invalid, 4, "", "35", "1,2,3", "NaN,0", "91,0", "0,-181", "35x,-80", "1e2,0", "1.,2", ".,2"]
        assertEqual(t, settingsLocationParse(value), invalid, "reject malformed/out-of-range coordinates")
    end for
    for each value in ["-90,-180", "90,180", "+0,0", "-33.8688,151.2093"]
        assertTrue(t, settingsLocationParse(value) <> invalid, "accept boundary and southern coordinates")
    end for
end sub

sub locationTest_persist(t as object)
    store = settingsMemoryStore()
    assertEqual(t, settingsLocationLabel(settingsLocationLoad(store)), "Woodland, CA", "upgrade default")
    assertTrue(t, settingsLocationSave(store, "35.2271,-80.8431"), "save Charlotte")
    settingsSave(store, { nightMode: "night", density: "calm", drift: "off" })
    assertEqual(t, settingsLocationLabel(settingsLocationLoad(store)), "Charlotte, NC", "other preferences preserve location")
    assertEqual(t, settingsLocationSave(store, "invalid"), false, "reject bad save")
    assertEqual(t, settingsLocationLabel(settingsLocationLoad(store)), "Charlotte, NC", "failed save preserves location")
    assertEqual(t, settingsLoad(store).nightMode, "night", "location preserves forced mode")
    store.write("solarLocation", "garbage")
    assertEqual(t, settingsLocationLabel(settingsLocationLoad(store)), "Woodland, CA", "corrupt storage fallback")
end sub

sub locationTest_charlotte(t as object)
    charlotte = solarTimes(35.2271, -80.8431, 2026, 11, 16, -300)
    woodland = solarTimes(38.68, -121.77, 2026, 11, 16, -300)
    assertEqual(t, daynightPhase(510, charlotte, "auto").phase, "day", "Charlotte 08:30 is day")
    assertEqual(t, daynightPhase(510, woodland, "auto").phase, "night", "regression: Woodland solar time was still night")
    assertTrue(t, charlotte.sunrise > 410 and charlotte.sunrise < 430, "Charlotte sunrise near 07:00 EST")
    assertEqual(t, daynightPhase(charlotte.civilDawn, charlotte, "auto").phase, "dawn", "dawn boundary")
    assertEqual(t, daynightPhase(charlotte.sunrise, charlotte, "auto").phase, "day", "sunrise boundary")
    assertEqual(t, daynightPhase(charlotte.sunset, charlotte, "auto").phase, "dusk", "sunset boundary")
    assertEqual(t, daynightPhase(charlotte.civilDusk, charlotte, "auto").phase, "night", "dusk boundary")
    assertEqual(t, daynightPhase(510, charlotte, "night").phase, "night", "night override")
end sub

sub locationTest_refresh(t as object)
    state = { solarKey: "", location: settingsLocationParse("35.2271,-80.8431") }
    clock = { year: 2026, month: 11, day: 1, offset: -240 }
    nightRefreshSolar(state, clock)
    before = state.solar.sunrise
    clock.offset = -300
    nightRefreshSolar(state, clock)
    assertNear(t, state.solar.sunrise, before - 60, 0.001, "DST offset refreshed")
    clock.day = 2
    nightRefreshSolar(state, clock)
    expected = solarTimes(35.2271, -80.8431, 2026, 11, 2, -300)
    assertNear(t, state.solar.sunrise, expected.sunrise, 0.001, "midnight date refreshed")
    assertEqual(t, state.solarKey, "2026-11-2/-300", "date/offset key")
    state.solar.sunrise = 123
    nightRefreshSolar(state, clock)
    assertEqual(t, state.solar.sunrise, 123, "unchanged date reuses cache")
end sub

sub locationTest_hemisphere(t as object)
    sydney = solarTimes(-33.8688, 151.2093, 2026, 11, 16, 660)
    assertEqual(t, daynightPhase(720, sydney, "auto").phase, "day", "southern hemisphere local noon")
    polar = solarTimes(80, 0, 2026, 12, 21, 0)
    assertEqual(t, daynightPhase(720, polar, "auto").phase, "day", "documented polar fallback")
    assertEqual(t, daynightPhase(720, polar, "night").phase, "night", "polar night override available")
end sub

sub locationTest_lookup(t as object)
    assertEqual(t, locationZipDigits([0, 0, 6, 0, 1]), "00601", "remote digit picker preserves zeros")
    data = CreateObject("roByteArray")
    data.fromHexString("5a50303100000002008000025900000000d904f6a80190b101c7e70592209156")
    first = locationZipLookup("00601", data)
    assertNear(t, first.latitude, 18.11, 0.001, "leading zero ZIP")
    assertNear(t, first.longitude, -66.64, 0.001, "ZIP longitude")
    last = locationZipLookup("95776", data)
    assertNear(t, last.latitude, 38.68, 0.001, "last ZIP")
    for each value in ["601", "00000", "99999", "95776-1234", " 95776", "abcde", ""]
        assertEqual(t, locationZipLookup(value, data), invalid, "reject unknown or malformed ZIP")
    end for
    assertEqual(t, locationZipLookup("00601", ""), invalid, "empty database")
    assertEqual(t, locationZipLookup("00601", "00601"), invalid, "truncated database")
    broken = CreateObject("roByteArray")
    broken.fromHexString("5a50303100000002008000025900000000d904f6a801")
    assertEqual(t, locationZipLookup("00601", broken), invalid, "truncated varint record")
    broken.fromHexString("5a503031000000020080000259ffffffffd904f6a80190b101")
    assertEqual(t, locationZipLookup("00601", broken), invalid, "out of range index")
    broken.fromHexString("5a50303100000002008000025900000000808080")
    assertEqual(t, locationZipLookup("00601", broken), invalid, "overlong varint")
    city = locationCityCoordinates(["Sydney", -3387, 15121])
    assertNear(t, city.latitude, -33.87, 0.001, "southern city")
    assertEqual(t, locationCityCoordinates(invalid), invalid, "invalid city")
    assertEqual(t, locationCityCoordinates(["bad", 9100, 0]), invalid, "invalid latitude")
end sub

sub locationTest_database(t as object)
    data = CreateObject("roByteArray")
    assertTrue(t, data.ReadFile("pkg:/config/location/us-zips.bin"), "load bundled binary database")
    samples = ParseJson(ReadAsciiFile("pkg:/tests/fixtures/location-samples.json"))
    assertEqual(t, samples.count(), 528, "first and last record of every block")
    for each row in samples
        loc = locationZipLookup(row[0], data)
        assertTrue(t, loc <> invalid, "find block boundary ZIP " + row[0])
        if loc <> invalid then
            assertNear(t, loc.latitude, row[1] / 100.0 - 90, 0.001, "exact latitude " + row[0])
            assertNear(t, loc.longitude, row[2] / 100.0 - 180, 0.001, "exact longitude " + row[0])
        end if
    end for
    assertEqual(t, locationZipLookup("00000", data), invalid, "missing ZIP stays missing")
    assertEqual(t, locationZipLookup("99999", data), invalid, "upper missing ZIP")
    assertTrue(t, locationZipRead("00601") <> invalid, "production binary reader preserves leading zero")
end sub
