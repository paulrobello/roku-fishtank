' Day/night phase machine. Pure functions: the caller injects the clock as
' local minutes after midnight (Float, so the preview's ?time/?speed clock can
' feed fractional minutes) plus the day's solar times from solarTimes().
'
' Phases use half-open intervals so the blend is continuous everywhere:
'   day   [sunrise, sunset)       blend 0
'   dusk  [sunset, civilDusk)     blend 0 -> 1
'   night [civilDusk, civilDawn)  blend 1, wrapping through midnight
'   dawn  [civilDawn, sunrise)    blend 1 -> 0
' Override modes: "day" (always day), "night" (always night); "auto" and any
' unknown value follow the sun.

function daynightMinutesPerDay() as integer
    return 1440
end function

' Minutes wrapped to [0, 1440), so 1440 is midnight and negatives wrap back.
function daynightWrapMinutes(minutes as dynamic) as dynamic
    perDay = daynightMinutesPerDay()
    return minutes - perDay * Int(minutes / perDay)
end function

' True for invalid, also when boxed (roInvalid). Checked by type so a number
' is never compared with invalid.
function daynightIsInvalid(v as dynamic) as boolean
    tp = LCase(type(v))
    return tp = "invalid" or tp = "roinvalid"
end function

function daynightState(phase as string, blend as dynamic) as object
    return { phase: phase, blend: blend }
end function

' Returns { phase: "day" | "dusk" | "night" | "dawn", blend: 0..1 } where
' blend is 0 for full day and 1 for full night. solar is the AA from
' solarTimes(); if any of its events is invalid (polar day or night) the
' result is day.
function daynightPhase(nowMinutes as dynamic, solar as object, mode as string) as object
    m = LCase(mode)
    if m = "day" then return daynightState("day", 0.0)
    if m = "night" then return daynightState("night", 1.0)
    if daynightIsInvalid(solar.civilDawn) or daynightIsInvalid(solar.sunrise) or daynightIsInvalid(solar.sunset) or daynightIsInvalid(solar.civilDusk) then
        return daynightState("day", 0.0)
    end if

    now = daynightWrapMinutes(nowMinutes)
    if now >= solar.sunrise and now < solar.sunset then return daynightState("day", 0.0)
    if now >= solar.sunset and now < solar.civilDusk then
        return daynightState("dusk", (now - solar.sunset) / (solar.civilDusk - solar.sunset))
    end if
    if now >= solar.civilDawn and now < solar.sunrise then
        return daynightState("dawn", (solar.sunrise - now) / (solar.sunrise - solar.civilDawn))
    end if
    return daynightState("night", 1.0)
end function
