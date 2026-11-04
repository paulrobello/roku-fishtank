' Sunrise, sunset and civil twilight from the NOAA Solar Calculator equations
' (https://gml.noaa.gov/grad/solcalc/, main.js and the NOAA_Solar_Calculations
' spreadsheet, after Meeus "Astronomical Algorithms"). Pure functions: the
' caller passes the local calendar date and its UTC offset in minutes (on the
' device, from roDateTime local vs UTC, so the OS handles DST). Nothing here
' reads the clock.
'
' Precision: the day count is kept relative to J2000.0 (a small number) and in
' Double. Every Double expression uses # literals because brs-engine's CDbl
' returns a Float. Mean longitude and anomaly are reduced mod 360 in Double
' before the Float-only trig calls (Sin/Cos/Tan/Atn return Float).
' BrightScript has no Asin/Acos, so both are built from Atn and Sqr.

' Zenith angles in degrees: 90.833 is the standard rise/set (refraction plus
' the solar disk radius), 96 is the end of civil twilight.
function solarZenithRiseSet() as float
    return 90.833
end function

function solarZenithCivil() as float
    return 96.0
end function

' Julian Day Number of the Gregorian date (the JD at 12:00 UTC of that date),
' Fliegel and Van Flandern 1968. BrightScript's \ truncates toward zero, as
' the algorithm requires.
function solarJulianDayNumber(year as integer, month as integer, day as integer) as integer
    a = (month - 14) \ 12
    jdn = (1461 * (year + 4800 + a)) \ 4
    jdn = jdn + (367 * (month - 2 - 12 * a)) \ 12
    jdn = jdn - (3 * ((year + 4900 + a) \ 100)) \ 4
    return jdn + day - 32075
end function

function solarDegToRad(deg as dynamic) as dynamic
    return deg * 0.017453292519943295#
end function

function solarRadToDeg(r as dynamic) as dynamic
    return r * 57.29577951308232#
end function

' x reduced to [0, 360) in Double.
function solarWrap360(x as dynamic) as dynamic
    return x - 360# * Int(x / 360#)
end function

' Arcsine in radians for |x| < 1.
function solarAsin(x as dynamic) as dynamic
    return Atn(x / Sqr(1# - x * x))
end function

' Arccosine in radians for |x| < 1.
function solarAcos(x as dynamic) as dynamic
    return 2# * Atn(Sqr((1# - x) / (1# + x)))
end function

' Solar declination (degrees) and equation of time (minutes) at `days` days
' after J2000.0 (2000-01-01 12:00 TT, treated as UTC).
function solarSunAt(days as dynamic) as object
    jc = days / 36525#
    l0 = solarWrap360(280.46646# + jc * (36000.76983# + jc * 0.0003032#))
    m = solarWrap360(357.52911# + jc * (35999.05029# - 0.0001537# * jc))
    ecc = 0.016708634# - jc * (0.000042037# + 0.0000001267# * jc)
    mRad = solarDegToRad(m)
    center = Sin(mRad) * (1.914602# - jc * (0.004817# + 0.000014# * jc))
    center = center + Sin(2# * mRad) * (0.019993# - 0.000101# * jc) + Sin(3# * mRad) * 0.000289#
    omegaRad = solarDegToRad(solarWrap360(125.04# - 1934.136# * jc))
    lambdaRad = solarDegToRad(l0 + center - 0.00569# - 0.00478# * Sin(omegaRad))
    obliq0 = 23# + (26# + (21.448# - jc * (46.815# + jc * (0.00059# - jc * 0.001813#))) / 60#) / 60#
    obliqRad = solarDegToRad(obliq0 + 0.00256# * Cos(omegaRad))
    decl = solarRadToDeg(solarAsin(Sin(obliqRad) * Sin(lambdaRad)))
    y = Tan(obliqRad / 2#)
    y = y * y
    l0Rad = solarDegToRad(l0)
    eqt = y * Sin(2# * l0Rad) - 2# * ecc * Sin(mRad) + 4# * ecc * y * Sin(mRad) * Cos(2# * l0Rad)
    eqt = eqt - 0.5# * y * y * Sin(4# * l0Rad) - 1.25# * ecc * ecc * Sin(2# * mRad)
    return { decl: decl, eqTime: solarRadToDeg(eqt) * 4# }
end function

' UTC minutes after 00:00 UTC of the date (JD jdn - 0.5) at which the sun
' crosses `zenith`, rising or setting, evaluated with the sun's position at
' `days` after J2000.0. Returns invalid when the sun never reaches the zenith
' (polar day or night).
function solarEventUtcAt(rising as boolean, days as dynamic, lat as float, lon as float, zenith as float) as dynamic
    sun = solarSunAt(days)
    latRad = solarDegToRad(lat)
    declRad = solarDegToRad(sun.decl)
    haArg = Cos(solarDegToRad(zenith)) / (Cos(latRad) * Cos(declRad)) - Tan(latRad) * Tan(declRad)
    if haArg <= -1 or haArg >= 1 then return invalid
    ha = solarRadToDeg(solarAcos(haArg))
    if not rising then ha = -ha
    return 720# - 4# * (lon + ha) - sun.eqTime
end function

' Local minutes after local midnight of the event, two passes as in NOAA's
' calcSunriseSet: first with the sun at 00:00 UTC of the date, then again at
' the first-pass event time. invalid when the event does not occur.
function solarEventLocal(rising as boolean, jdn as integer, lat as float, lon as float, zenith as float, utcOffsetMin as integer) as dynamic
    day0 = (jdn - 2451545) * 1# - 0.5#
    utc = solarEventUtcAt(rising, day0, lat, lon, zenith)
    if solarIsInvalid(utc) then return invalid
    utc = solarEventUtcAt(rising, day0 + utc / 1440#, lat, lon, zenith)
    if solarIsInvalid(utc) then return invalid
    return utc + utcOffsetMin
end function

' True for invalid, also when boxed (roInvalid). Checked by type so a number
' is never compared with invalid, which brs-engine accepts but the device
' may raise as a type mismatch.
function solarIsInvalid(v as dynamic) as boolean
    tp = LCase(type(v))
    return tp = "invalid" or tp = "roinvalid"
end function

' Solar event times for a latitude (degrees north), longitude (degrees east,
' negative west), local calendar date and its UTC offset in minutes
' (PDT = -420, PST = -480). Returns local minutes after local midnight:
'   { sunrise, sunset, civilDawn, civilDusk }
' Each value is invalid when that event does not occur on the date.
function solarTimes(lat as float, lon as float, year as integer, month as integer, day as integer, utcOffsetMin as integer) as object
    jdn = solarJulianDayNumber(year, month, day)
    return {
        civilDawn: solarEventLocal(true, jdn, lat, lon, solarZenithCivil(), utcOffsetMin)
        sunrise: solarEventLocal(true, jdn, lat, lon, solarZenithRiseSet(), utcOffsetMin)
        sunset: solarEventLocal(false, jdn, lat, lon, solarZenithRiseSet(), utcOffsetMin)
        civilDusk: solarEventLocal(false, jdn, lat, lon, solarZenithCivil(), utcOffsetMin)
    }
end function
