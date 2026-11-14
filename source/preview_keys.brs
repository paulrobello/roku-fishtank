' Preview only: a click on the page sends OK, which flips between day and night. On a
' device any key exits the screensaver before the scene sees it.
function onKeyEvent(key as string, press as boolean) as boolean
    if not press or key <> "OK" or not m.global.hasField("previewNight") then return false
    if m.top.isNight then
        m.top.nightMode = "day"
    else
        m.top.nightMode = "night"
    end if
    return true
end function
