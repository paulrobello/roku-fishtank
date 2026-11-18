sub init()
    m.ready = false
    m.label = m.top.findNode("backgroundClockText")
    m.label.font.size = 156
    m.period = m.top.findNode("backgroundClockPeriod")
    m.period.font.size = 54
    m.face = m.top.findNode("clockFace")
    m.tick = m.top.findNode("clockTick")
    m.tick.observeField("fire", "clockRefresh")
    m.drift = m.top.findNode("clockDrift")
    interp = m.top.findNode("clockDriftInterp")
    plan = clockDriftPlan()
    interp.key = plan.keys
    interp.keyValue = plan.values
    m.drift.duration = plan.duration
    m.device = CreateObject("roDeviceInfo")
    m.freeze = 0.0
    if m.global.hasField("previewFreeze") then m.freeze = m.global.previewFreeze
    m.fixedMinutes = invalid
    if m.global.hasField("previewTime") then m.fixedMinutes = clockPreviewMinutes(m.global.previewTime)
    if m.freeze > 0 and m.fixedMinutes = invalid then m.fixedMinutes = 720
    m.scene = invalid
    m.ready = true
    onClockEnabled()
end sub

' Called after attachment; do not depend on getScene() being ready during init.
sub clockStart(scene as object)
    m.scene = scene
    m.scene.observeField("nightBlend", "onClockLight")
    m.scene.observeField("clockFormat", "onClockFormat")
    clockRefreshLight()
end sub

sub onClockEnabled()
    if m.ready <> true then return
    m.top.visible = m.top.enabled
    m.tick.control = "stop"
    m.drift.control = "stop"
    if not m.top.enabled then return
    clockRefresh()
    if m.freeze > 0 then
        m.face.translation = clockDriftAt(m.freeze)
    else
        m.drift.control = "start"
        m.tick.control = "start"
    end if
end sub

sub onClockFormat()
    if m.ready = true then clockRefresh()
end sub

sub onClockLight()
    if m.ready = true then clockRefreshLight()
end sub

sub clockRefreshLight()
    blend = 0.0
    if m.scene <> invalid and m.scene.hasField("nightBlend") then blend = m.scene.nightBlend
    m.top.opacity = clockOpacity(blend)
    color = clockColor(blend)
    m.label.color = color
    m.period.color = color
end sub

sub clockRefresh()
    if not m.top.enabled then return
    format = m.device.GetClockFormat()
    minutes = m.fixedMinutes
    if minutes = invalid then
        now = CreateObject("roDateTime")
        now.ToLocalTime()
        minutes = now.GetHours() * 60 + now.GetMinutes()
    end if
    if m.freeze > 0 then format = "12h"
    preference = "device"
    if m.scene <> invalid then preference = m.scene.clockFormat
    format = clockResolveFormat(preference, format)
    parts = clockParts(minutes, format)
    if m.label.text <> parts.time then m.label.text = parts.time
    periodText = ""
    if parts.period = "AM" then periodText = tr("AM")
    if parts.period = "PM" then periodText = tr("PM")
    if m.period.text <> periodText then m.period.text = periodText
    m.period.visible = parts.period <> ""
    ' Right alignment keeps a consistent 12px gap for both 1:05 and 11:05.
    if parts.period = "" then
        m.label.width = 642
        m.label.horizAlign = "center"
    else
        m.label.width = 500
        m.label.horizAlign = "right"
    end if
    clockRefreshLight()
end sub
