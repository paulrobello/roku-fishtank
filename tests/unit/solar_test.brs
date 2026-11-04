' Unit tests for components/lib/solar.brs.
'
' Location: Woodland, CA, 38.68 N, 121.77 W. All times are local minutes after
' local midnight. Offsets: PDT -420 on 2026-03-08 (DST starts that morning) and
' 2026-06-21, PST -480 on 2026-11-01 (DST ends that morning) and 2026-12-21.
'
' Reference sources (fetched 2026-11-04):
'   noaa: NOAA Solar Calculator, https://gml.noaa.gov/grad/solcalc/ , algorithm
'         in https://gml.noaa.gov/grad/solcalc/main.js (calcSunriseSet, two
'         passes, zenith 90.833). The rendered calculator page is
'         JavaScript-only and does not show civil twilight, so these values
'         come from an independent Python double-precision port of main.js;
'         civilDawn/civilDusk are that port at zenith 96.
'   usno: US Naval Observatory one-day API (independent algorithm):
'     2026-03-08 https://aa.usno.navy.mil/api/rstt/oneday?date=2026-03-08&coords=38.68,-121.77&tz=-7&dst=false
'     2026-06-21 https://aa.usno.navy.mil/api/rstt/oneday?date=2026-06-21&coords=38.68,-121.77&tz=-7&dst=false
'     2026-11-01 https://aa.usno.navy.mil/api/rstt/oneday?date=2026-11-01&coords=38.68,-121.77&tz=-8&dst=false
'     2026-12-21 https://aa.usno.navy.mil/api/rstt/oneday?date=2026-12-21&coords=38.68,-121.77&tz=-8&dst=false
'   sso:  sunrise-sunset.org API:
'     2026-03-08 https://api.sunrise-sunset.org/json?lat=38.68&lng=-121.77&date=2026-03-08&formatted=0&tzid=America/Los_Angeles
'     2026-06-21 https://api.sunrise-sunset.org/json?lat=38.68&lng=-121.77&date=2026-06-21&formatted=0&tzid=America/Los_Angeles
'     2026-11-01 https://api.sunrise-sunset.org/json?lat=38.68&lng=-121.77&date=2026-11-01&formatted=0&tzid=America/Los_Angeles
'     2026-12-21 https://api.sunrise-sunset.org/json?lat=38.68&lng=-121.77&date=2026-12-21&formatted=0&tzid=America/Los_Angeles
'
' date        event      noaa     usno         sso
' 2026-03-08  civilDawn  422.21   07:02 422    07:01:50 421.83
'             sunrise    448.71   07:29 449    07:28:15 448.25
'             sunset     1147.38  19:07 1147   19:07:14 1147.23
'             civilDusk  1173.92  19:34 1174   19:33:39 1173.65
' 2026-06-21  civilDawn  310.75   05:11 311    05:10:50 310.83
'             sunrise    342.70   05:43 343    05:42:42 342.70
'             sunset     1235.25  20:35 1235   20:35:15 1235.25
'             civilDusk  1267.19  21:07 1267   21:07:07 1267.12
' 2026-11-01  civilDawn  366.54   06:07 367    06:06:50 366.83
'             sunrise    394.10   06:34 394    06:34:17 394.28
'             sunset     1026.62  17:07 1027   17:07:00 1027.00
'             civilDusk  1054.17  17:34 1054   17:34:27 1054.45
' 2026-12-21  civilDawn  411.63   06:52 412    06:51:43 411.72
'             sunrise    441.52   07:21 441    07:21:28 441.47
'             sunset     1009.13  16:49 1009   16:49:09 1009.15
'             civilDusk  1039.02  17:19 1039   17:18:54 1038.90
'
' Every event must land within 2 minutes of each source. The NOAA port is
' also checked within 0.1 minute: a Float absolute Julian day (jd + utc/1440
' in single precision) was measured to drift up to 1.4 minutes, which passes
' the 2-minute checks but fails this one.

function solarTestSuite() as object
    return {
        name: "solar"
        tests: [
            { name: "julianDayNumber", fn: solarTest_julianDayNumber }
            { name: "matchesNoaaWithin2Min", fn: solarTest_matchesNoaaWithin2Min }
            { name: "matchesUsnoWithin2Min", fn: solarTest_matchesUsnoWithin2Min }
            { name: "matchesSunriseSunsetOrgWithin2Min", fn: solarTest_matchesSsoWithin2Min }
            { name: "tracksNoaaPortTightly", fn: solarTest_tracksNoaaPortTightly }
            { name: "eventOrder", fn: solarTest_eventOrder }
            { name: "utcOffsetShiftsLocalTimes", fn: solarTest_utcOffsetShiftsLocalTimes }
            { name: "polarDayIsInvalid", fn: solarTest_polarDayIsInvalid }
        ]
    }
end function

function solarTestWoodlandLat() as float
    return 38.68
end function

function solarTestWoodlandLon() as float
    return -121.77
end function

' Reference rows: [civilDawn, sunrise, sunset, civilDusk] per source.
function solarTestReferences() as object
    return [
        {
            label: "2026-03-08", year: 2026, month: 3, day: 8, offset: -420
            noaa: [422.21, 448.71, 1147.38, 1173.92]
            usno: [422, 449, 1147, 1174]
            sso: [421.83, 448.25, 1147.23, 1173.65]
        }
        {
            label: "2026-06-21", year: 2026, month: 6, day: 21, offset: -420
            noaa: [310.75, 342.70, 1235.25, 1267.19]
            usno: [311, 343, 1235, 1267]
            sso: [310.83, 342.70, 1235.25, 1267.12]
        }
        {
            label: "2026-11-01", year: 2026, month: 11, day: 1, offset: -480
            noaa: [366.54, 394.10, 1026.62, 1054.17]
            usno: [367, 394, 1027, 1054]
            sso: [366.83, 394.28, 1027.00, 1054.45]
        }
        {
            label: "2026-12-21", year: 2026, month: 12, day: 21, offset: -480
            noaa: [411.63, 441.52, 1009.13, 1039.02]
            usno: [412, 441, 1009, 1039]
            sso: [411.72, 441.47, 1009.15, 1038.90]
        }
    ]
end function

function solarTestEventNames() as object
    return ["civilDawn", "sunrise", "sunset", "civilDusk"]
end function

sub solarTestCheckSource(t as object, source as string, tolerance as float)
    names = solarTestEventNames()
    for each ref in solarTestReferences()
        got = solarTimes(solarTestWoodlandLat(), solarTestWoodlandLon(), ref.year, ref.month, ref.day, ref.offset)
        expected = ref[source]
        for i = 0 to names.count() - 1
            assertNear(t, got[names[i]], expected[i], tolerance, ref.label + " " + names[i] + " vs " + source)
        end for
    end for
end sub

sub solarTest_julianDayNumber(t as object)
    assertEqual(t, solarJulianDayNumber(2000, 1, 1), 2451545, "J2000.0 day")
    assertEqual(t, solarJulianDayNumber(1970, 1, 1), 2440588, "Unix epoch day")
    assertEqual(t, solarJulianDayNumber(2026, 3, 8), 2461108, "2026-03-08")
    assertEqual(t, solarJulianDayNumber(2024, 2, 29), 2460370, "leap day 2024-02-29")
    assertEqual(t, solarJulianDayNumber(2024, 3, 1), 2460371, "day after leap day")
end sub

sub solarTest_matchesNoaaWithin2Min(t as object)
    solarTestCheckSource(t, "noaa", 2.0)
end sub

sub solarTest_matchesUsnoWithin2Min(t as object)
    solarTestCheckSource(t, "usno", 2.0)
end sub

sub solarTest_matchesSsoWithin2Min(t as object)
    solarTestCheckSource(t, "sso", 2.0)
end sub

sub solarTest_tracksNoaaPortTightly(t as object)
    solarTestCheckSource(t, "noaa", 0.1)
end sub

sub solarTest_eventOrder(t as object)
    for each ref in solarTestReferences()
        got = solarTimes(solarTestWoodlandLat(), solarTestWoodlandLon(), ref.year, ref.month, ref.day, ref.offset)
        assertTrue(t, got.civilDawn > 0, ref.label + " civilDawn after midnight")
        assertTrue(t, got.civilDawn < got.sunrise, ref.label + " civilDawn before sunrise")
        assertTrue(t, got.sunrise < got.sunset, ref.label + " sunrise before sunset")
        assertTrue(t, got.sunset < got.civilDusk, ref.label + " sunset before civilDusk")
        assertTrue(t, got.civilDusk < 1440, ref.label + " civilDusk before midnight")
    end for
end sub

' The lib takes the offset from the caller, so the same date under PST is
' exactly one hour earlier on the local clock than under PDT.
sub solarTest_utcOffsetShiftsLocalTimes(t as object)
    pdt = solarTimes(solarTestWoodlandLat(), solarTestWoodlandLon(), 2026, 3, 8, -420)
    pst = solarTimes(solarTestWoodlandLat(), solarTestWoodlandLon(), 2026, 3, 8, -480)
    for each name in solarTestEventNames()
        assertNear(t, pdt[name] - pst[name], 60, 0.0001, name + " PDT minus PST")
    end for
end sub

sub solarTest_polarDayIsInvalid(t as object)
    got = solarTimes(80.0, 0.0, 2026, 6, 21, 0)
    assertEqual(t, got.sunrise, invalid, "80 N midsummer sunrise")
    assertEqual(t, got.sunset, invalid, "80 N midsummer sunset")
    assertEqual(t, got.civilDawn, invalid, "80 N midsummer civilDawn")
    assertEqual(t, got.civilDusk, invalid, "80 N midsummer civilDusk")
end sub
