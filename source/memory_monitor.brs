' Memory notifications live on the same port as the owning screen. Keep this
' context alive for the entire entry point; never mutate persisted preferences.
function memoryMonitorCreate(port as object) as object
    app = invalid
    device = invalid
    try
        app = createObject("roAppMemoryMonitor")
    catch e
        print "MEMORY app monitor unavailable"
    end try
    try
        device = createObject("roDeviceInfo")
    catch e
        print "MEMORY legacy monitor unavailable"
    end try
    return memoryMonitorStart(port, app, device, memoryHasInterface)
end function

function memoryHasInterface(value as dynamic, name as string) as boolean
    if value = invalid then return false
    try
        return getInterface(value, name) <> invalid
    catch e
        return false
    end try
end function

' Dependency injection keeps unsupported interfaces and old implementations testable.
function memoryMonitorStart(port as object, app as dynamic, device as dynamic, supports as object) as object
    state = { app: app, device: device, source: "none", snapshot: { percent: invalid, availableKb: invalid, limits: invalid, generalLevel: invalid } }
    if supports(app, "ifAppMemoryMonitor") then
        state.snapshot = memoryMonitorSnapshot(app)
        if supports(app, "ifSetMessagePort") then
            try
                app.setMessagePort(port)
                if app.EnableMemoryWarningEvent(true) = true then state.source = "app"
            catch e
                print "MEMORY app subscription unavailable"
            end try
        end if
    end if
    ' roDeviceInfo on OS 16 can expose SetMessagePort without advertising
    ' ifSetMessagePort. Guard the documented method by try/catch instead.
    if state.source = "none" and supports(device, "ifDeviceInfo") then
        try
            device.setMessagePort(port)
            if device.EnableLowGeneralMemoryEvent(true) = true then state.source = "legacy"
        catch e
            print "MEMORY legacy subscription unavailable"
        end try
    end if
    if state.source = "legacy" then
        try
            level = device.GetGeneralMemoryLevel()
            if type(level) = "String" or type(level) = "roString" then state.snapshot.generalLevel = lCase(level)
        catch e
            print "MEMORY initial general level unavailable"
        end try
    end if
    print "MEMORY source="; state.source; " snapshot="; formatJson(state.snapshot)
    return state
end function

function memoryMonitorSnapshot(app as object) as object
    sample = { percent: invalid, availableKb: invalid, limits: invalid, generalLevel: invalid }
    ' Independent guards: a missing getter must not hide the other metrics or
    ' stop subscription (older devices and simulators have partial interfaces).
    try
        value = app.GetMemoryLimitPercent()
        if memoryValidPercent(value) then sample.percent = value
    catch e
        print "MEMORY percent unavailable"
    end try
    try
        value = app.GetChannelAvailableMemory()
        if memoryIsNumber(value) then
            if value >= 0 then sample.availableKb = value
        end if
    catch e
        print "MEMORY available memory unavailable"
    end try
    try
        value = app.GetChannelMemoryLimit()
        if type(value) = "roAssociativeArray" then sample.limits = value
    catch e
        print "MEMORY limits unavailable"
    end try
    return sample
end function

function memoryIsNumber(value as dynamic) as boolean
    kind = lCase(type(value))
    return kind = "integer" or kind = "rointeger" or kind = "longinteger" or kind = "rolonginteger" or kind = "float" or kind = "rofloat" or kind = "double" or kind = "rodouble" or kind = "rointrinsicdouble"
end function

function memoryValidPercent(value as dynamic) as boolean
    if not memoryIsNumber(value) then return false
    return value >= 0
end function

' Only the selected notification source is trusted. Missing, malformed, normal,
' decreasing and unrelated device events are harmless. 90% leaves headroom
' before the platform's 95% threshold; critical legacy pressure has no percentage.
function memoryPressureAction(source as string, eventType as string, info as dynamic) as string
    if type(info) <> "roAssociativeArray" then return "ignore"
    if source = "app" and eventType = "roAppMemoryNotificationEvent" then
        percent = info.memoryUsagePercent
        if not memoryValidPercent(percent) then return "ignore"
        if percent >= 90 then return "close"
        if percent >= 80 then return "warn"
        return "normal"
    end if
    if source = "legacy" and eventType = "roDeviceInfoEvent" then
        level = info.generalMemoryLevel
        if type(level) <> "String" and type(level) <> "roString" then return "ignore"
        level = lCase(level)
        if level = "critical" then return "close"
        if level = "low" then return "warn"
        if level = "normal" then return "normal"
    end if
    return "ignore"
end function

function memoryMonitorHandle(state as object, msg as dynamic, screen as object) as boolean
    eventType = type(msg)
    if eventType <> "roAppMemoryNotificationEvent" and eventType <> "roDeviceInfoEvent" then return false
    info = invalid
    try
        info = msg.getInfo()
    catch e
        return false
    end try
    return memoryMonitorApply(state.source, eventType, info, screen)
end function

function memoryMonitorApply(source as string, eventType as string, info as dynamic, screen as object) as boolean
    action = memoryPressureAction(source, eventType, info)
    if action = "warn" or action = "close" then print "MEMORY pressure="; action; " info="; formatJson(info)
    if action <> "close" then return false
    ' Terminate this nonessential scene instead of changing the user's settings.
    screen.close()
    return true
end function

sub memoryMonitorStop(state as object)
    ' Disable only the source actually enabled. Failure during shutdown must not
    ' prevent the entry point returning and releasing screen/monitor references.
    try
        if state.source = "app" then state.app.EnableMemoryWarningEvent(false)
        if state.source = "legacy" then state.device.EnableLowGeneralMemoryEvent(false)
    catch e
        print "MEMORY unsubscribe unavailable"
    end try
    state.app = invalid
    state.device = invalid
    state.source = "none"
end sub

' Initial pressure check runs before scene allocation in both entry points.
function memoryMonitorStartup(state as object, screen as object) as boolean
    if memoryMonitorApply("app", "roAppMemoryNotificationEvent", { memoryUsagePercent: state.snapshot.percent }, screen) then return true
    return memoryMonitorApply(state.source, "roDeviceInfoEvent", { generalMemoryLevel: state.snapshot.generalLevel }, screen)
end function
