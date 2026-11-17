' Pure display/layout helpers: device local time is supplied by the component.
function clockDisplay(minutes as integer, format as string) as string
    minutes = ((minutes mod 1440) + 1440) mod 1440
    hour = Int(minutes / 60)
    minute = minutes mod 60
    minuteText = minute.toStr()
    if minute < 10 then minuteText = "0" + minuteText
    if format = "24h" then
        hourText = hour.toStr()
        if hour < 10 then hourText = "0" + hourText
        return hourText + ":" + minuteText
    end if
    suffix = " AM"
    if hour >= 12 then suffix = " PM"
    hour = hour mod 12
    if hour = 0 then hour = 12
    return hour.toStr() + ":" + minuteText + suffix
end function

function clockOpacity(nightBlend as float) as float
    if nightBlend < 0 then nightBlend = 0
    if nightBlend > 1 then nightBlend = 1
    return 0.16 - 0.06 * nightBlend
end function

' Slow independent pixel movement, including when camera drift is switched off.
' This reduces static placement; it is not a guarantee against display burn-in.
function clockDriftAt(seconds as float) as object
    angle = seconds * 6.2831853 / 840.0
    return [639.0 + 42.0 * Sin(angle), 240.0 + 18.0 * Sin(angle * 2.0)]
end function

function clockDriftPlan() as object
    keys = []
    values = []
    for i = 0 to 48
        keys.push(i / 48.0)
        values.push(clockDriftAt(i * 840.0 / 48.0))
    end for
    return { keys: keys, values: values, duration: 840.0 }
end function

' Deliberately limited to the existing preview HH:MM / ISO-date-time forms.
function clockPreviewMinutes(text as string) as dynamic
    if Len(text) >= 16 then text = Mid(text, 12, 5)
    parts = text.split(":")
    if parts.count() <> 2 then return invalid
    digits = CreateObject("roRegex", "^[0-9]{1,2}:[0-9]{2}$", "")
    if not digits.isMatch(text) then return invalid
    hour = parts[0].toInt()
    minute = parts[1].toInt()
    if hour > 23 or minute > 59 then return invalid
    return hour * 60 + minute
end function

' Separate period label de-emphasises AM/PM without a width-dependent gap.
function clockParts(minutes as integer, format as string) as object
    parts = clockDisplay(minutes, format).split(" ")
    period = ""
    if parts.count() > 1 then period = parts[1]
    return { time: parts[0], period: period }
end function

' Muted water-blue rather than neutral gray; independently follows night lighting.
function clockColor(nightBlend as float) as integer
    if nightBlend < 0 then nightBlend = 0
    if nightBlend > 1 then nightBlend = 1
    r = Int(112 - 6 * nightBlend)
    g = Int(183 - 38 * nightBlend)
    b = Int(208 - 25 * nightBlend)
    return r * 16777216 + g * 65536 + b * 256 + 255
end function
