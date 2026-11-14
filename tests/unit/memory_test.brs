function memoryTestSuite() as object
    return {
        name: "memory"
        tests: [
            { name: "preferredSourceAndMetrics", fn: memoryTest_preferred }
            { name: "falseSubscriptionFallsBack", fn: memoryTest_fallback }
            { name: "missingComponentFallsBack", fn: memoryTest_missing }
            { name: "missingInterfaceNeverCalled", fn: memoryTest_interface }
            { name: "throwingSubscriptionFallsBack", fn: memoryTest_throwing }
            { name: "partialGettersDoNotBlockSubscription", fn: memoryTest_partial }
            { name: "noProvidersStillRuns", fn: memoryTest_none }
            { name: "missingPortInterfaceFallsBack", fn: memoryTest_port }
            { name: "legacyPortUnadvertisedButCallable", fn: memoryTest_legacyPort }
            { name: "missingMethodsAreSafe", fn: memoryTest_methods }
            { name: "percentBoundaries", fn: memoryTest_boundaries }
            { name: "invalidPercentIgnored", fn: memoryTest_invalid }
            { name: "legacyLevels", fn: memoryTest_legacy }
            { name: "unrelatedEventsIgnored", fn: memoryTest_unrelated }
            { name: "pressureClosesWithoutMutatingSettings", fn: memoryTest_close }
            { name: "normalAndModerateDoNotClose", fn: memoryTest_noClose }
            { name: "unsubscribeReleasesReferences", fn: memoryTest_stop }
            { name: "legacyUnsubscribe", fn: memoryTest_stopLegacy }
            { name: "failedUnsubscribeStillReleases", fn: memoryTest_stopFailure }
            { name: "invalidMetricValuesRejected", fn: memoryTest_badMetrics }
            { name: "initialPressureBeforeScene", fn: memoryTest_startup }
            { name: "legacyMetricFailureIsSafe", fn: memoryTest_legacyMetric }
            { name: "unsupportedRealInterfaceSafe", fn: memoryTest_realGuard }
        ]
    }
end function

function memoryMock() as object
    return {
        interfaces: { ifAppMemoryMonitor: true, ifDeviceInfo: true, ifSetMessagePort: true }
        calls: []
        enabled: false
        subscription: true
        general: "normal"
        GetGeneralMemoryLevel: function()
            m.calls.push("general")
            return m.general
        end function
        percent: 25
        available: 50000
        limits: { maxForegroundMemory: 100000 }
        setMessagePort: sub(port)
            m.calls.push("port")
            m.port = port
        end sub
        EnableMemoryWarningEvent: function(enabled)
            m.calls.push("app")
            m.enabled = enabled
            return m.subscription
        end function
        EnableLowGeneralMemoryEvent: function(enabled)
            m.calls.push("legacy")
            m.enabled = enabled
            return m.subscription
        end function
        GetMemoryLimitPercent: function()
            m.calls.push("percent")
            return m.percent
        end function
        GetChannelAvailableMemory: function()
            m.calls.push("available")
            return m.available
        end function
        GetChannelMemoryLimit: function()
            m.calls.push("limits")
            return m.limits
        end function
    }
end function

function memoryMockSupports(value as dynamic, name as string) as boolean
    if value = invalid then return false
    return value.interfaces[name] = true
end function

function memoryMockScreen() as object
    return {
        closes: 0
        settings: { density: "busy", drift: "off", nightMode: "night" }
        close: sub()
            m.closes++
        end sub
    }
end function

sub memoryTest_preferred(t)
    app = memoryMock()
    device = memoryMock()
    port = {}
    state = memoryMonitorStart(port, app, device, memoryMockSupports)
    assertEqual(t, state.source, "app")
    assertEqual(t, formatJson(app.calls), formatJson(["percent", "available", "limits", "port", "app"]))
    assertEqual(t, formatJson(device.calls), formatJson([]))
    assertEqual(t, state.snapshot.percent, 25)
    assertEqual(t, state.snapshot.availableKb, 50000)
    assertEqual(t, state.snapshot.limits.maxForegroundMemory, 100000)
    assertTrue(t, app.enabled)
end sub

sub memoryTest_fallback(t)
    app = memoryMock()
    app.subscription = false
    device = memoryMock()
    state = memoryMonitorStart({}, app, device, memoryMockSupports)
    assertEqual(t, state.source, "legacy")
    assertEqual(t, formatJson(device.calls), formatJson(["port", "legacy", "general"]))
end sub

sub memoryTest_missing(t)
    state = memoryMonitorStart({}, invalid, memoryMock(), memoryMockSupports)
    assertEqual(t, state.source, "legacy")
end sub

sub memoryTest_interface(t)
    app = memoryMock()
    app.interfaces.ifAppMemoryMonitor = false
    state = memoryMonitorStart({}, app, memoryMock(), memoryMockSupports)
    assertEqual(t, state.source, "legacy")
    assertEqual(t, formatJson(app.calls), formatJson([]))
end sub

sub memoryTest_throwing(t)
    app = memoryMock()
    app.EnableMemoryWarningEvent = function(enable)
        throw "unsupported"
    end function
    state = memoryMonitorStart({}, app, memoryMock(), memoryMockSupports)
    assertEqual(t, state.source, "legacy")
end sub

sub memoryTest_partial(t)
    app = memoryMock()
    app.GetChannelAvailableMemory = function()
        throw "unsupported"
    end function
    state = memoryMonitorStart({}, app, invalid, memoryMockSupports)
    assertEqual(t, state.source, "app")
    assertEqual(t, state.snapshot.availableKb, invalid)
    assertEqual(t, state.snapshot.percent, 25)
    assertEqual(t, state.snapshot.limits.maxForegroundMemory, 100000)
end sub

sub memoryTest_none(t)
    state = memoryMonitorStart({}, invalid, invalid, memoryMockSupports)
    assertEqual(t, state.source, "none")
    assertEqual(t, state.snapshot.percent, invalid)
end sub

sub memoryTest_port(t)
    app = memoryMock()
    app.interfaces.ifSetMessagePort = false
    state = memoryMonitorStart({}, app, memoryMock(), memoryMockSupports)
    assertEqual(t, state.source, "legacy")
    assertEqual(t, formatJson(app.calls), formatJson(["percent", "available", "limits"]))
end sub

sub memoryTest_methods(t)
    app = memoryMock()
    app.delete("EnableMemoryWarningEvent")
    device = memoryMock()
    device.delete("EnableLowGeneralMemoryEvent")
    state = memoryMonitorStart({}, app, device, memoryMockSupports)
    assertEqual(t, state.source, "none")
end sub

sub memoryTest_boundaries(t)
    for each value in [0, 79, 79.9]
        assertEqual(t, memoryPressureAction("app", "roAppMemoryNotificationEvent", { memoryUsagePercent: value }), "normal")
    end for
    for each value in [80, 85, 89.9]
        assertEqual(t, memoryPressureAction("app", "roAppMemoryNotificationEvent", { memoryUsagePercent: value }), "warn")
    end for
    for each value in [90, 95, 100, 101, 150]
        assertEqual(t, memoryPressureAction("app", "roAppMemoryNotificationEvent", { MemoryUsagePercent: value }), "close")
    end for
end sub

sub memoryTest_invalid(t)
    for each value in [invalid, "95", true, -1, {}, []]
        assertEqual(t, memoryPressureAction("app", "roAppMemoryNotificationEvent", { memoryUsagePercent: value }), "ignore")
    end for
    for each value in [invalid, "invalid", [], {}]
        assertEqual(t, memoryPressureAction("app", "roAppMemoryNotificationEvent", value), "ignore")
    end for
end sub

sub memoryTest_legacy(t)
    assertEqual(t, memoryPressureAction("legacy", "roDeviceInfoEvent", { generalMemoryLevel: "low" }), "warn")
    assertEqual(t, memoryPressureAction("legacy", "roDeviceInfoEvent", { generalMemoryLevel: "CRITICAL" }), "close")
    assertEqual(t, memoryPressureAction("legacy", "roDeviceInfoEvent", { generalMemoryLevel: "normal" }), "normal")
    assertEqual(t, memoryPressureAction("legacy", "roDeviceInfoEvent", { generalMemoryLevel: 90 }), "ignore")
end sub

sub memoryTest_unrelated(t)
    assertEqual(t, memoryPressureAction("app", "roDeviceInfoEvent", { generalMemoryLevel: "critical" }), "ignore")
    assertEqual(t, memoryPressureAction("none", "roAppMemoryNotificationEvent", { memoryUsagePercent: 95 }), "ignore")
    assertEqual(t, memoryPressureAction("legacy", "roDeviceInfoEvent", { linkStatus: true }), "ignore")
    assertEqual(t, memoryPressureAction("app", "roSGScreenEvent", { memoryUsagePercent: 95 }), "ignore")
    screen = memoryMockScreen()
    assertEqual(t, memoryMonitorHandle({ source: "app" }, invalid, screen), false)
    assertEqual(t, screen.closes, 0)
end sub

sub memoryTest_close(t)
    screen = memoryMockScreen()
    assertTrue(t, memoryMonitorApply("app", "roAppMemoryNotificationEvent", { memoryUsagePercent: 90 }, screen))
    assertEqual(t, screen.closes, 1)
    assertEqual(t, formatJson(screen.settings), formatJson({ density: "busy", drift: "off", nightMode: "night" }))
    assertTrue(t, memoryMonitorApply("legacy", "roDeviceInfoEvent", { generalMemoryLevel: "critical" }, screen))
end sub

sub memoryTest_noClose(t)
    screen = memoryMockScreen()
    for each value in [10, 85, 80, 20]
        assertEqual(t, memoryMonitorApply("app", "roAppMemoryNotificationEvent", { memoryUsagePercent: value }, screen), false)
    end for
    assertEqual(t, screen.closes, 0)
end sub

sub memoryTest_stop(t)
    app = memoryMock()
    state = memoryMonitorStart({}, app, invalid, memoryMockSupports)
    memoryMonitorStop(state)
    assertEqual(t, app.enabled, false)
    assertEqual(t, state.app, invalid)
    assertEqual(t, state.device, invalid)
    assertEqual(t, state.source, "none")
    memoryMonitorStop(state)
end sub

sub memoryTest_stopLegacy(t)
    device = memoryMock()
    state = memoryMonitorStart({}, invalid, device, memoryMockSupports)
    memoryMonitorStop(state)
    assertEqual(t, device.enabled, false)
end sub

sub memoryTest_stopFailure(t)
    app = memoryMock()
    state = memoryMonitorStart({}, app, invalid, memoryMockSupports)
    app.EnableMemoryWarningEvent = function(enable)
        throw "unsupported"
    end function
    memoryMonitorStop(state)
    assertEqual(t, state.app, invalid)
    assertEqual(t, state.source, "none")
end sub

sub memoryTest_badMetrics(t)
    app = memoryMock()
    app.percent = "95"
    app.available = -10
    app.limits = "invalid"
    state = memoryMonitorStart({}, app, invalid, memoryMockSupports)
    assertEqual(t, state.snapshot.percent, invalid)
    assertEqual(t, state.snapshot.availableKb, invalid)
    assertEqual(t, state.snapshot.limits, invalid)
end sub

sub memoryTest_realGuard(t)
    assertEqual(t, memoryHasInterface(invalid, "ifAppMemoryMonitor"), false)
    assertEqual(t, memoryHasInterface({}, "ifAppMemoryMonitor"), false)
end sub

sub memoryTest_startup(t)
    app = memoryMock()
    app.percent = 90
    state = memoryMonitorStart({}, app, invalid, memoryMockSupports)
    screen = memoryMockScreen()
    assertTrue(t, memoryMonitorStartup(state, screen))
    assertEqual(t, screen.closes, 1)
    device = memoryMock()
    device.general = "critical"
    state = memoryMonitorStart({}, invalid, device, memoryMockSupports)
    screen = memoryMockScreen()
    assertTrue(t, memoryMonitorStartup(state, screen))
    assertEqual(t, screen.closes, 1)
end sub

sub memoryTest_legacyMetric(t)
    device = memoryMock()
    device.delete("GetGeneralMemoryLevel")
    state = memoryMonitorStart({}, invalid, device, memoryMockSupports)
    assertEqual(t, state.source, "legacy")
    assertEqual(t, memoryMonitorStartup(state, memoryMockScreen()), false)
end sub

sub memoryTest_legacyPort(t)
    device = memoryMock()
    device.interfaces.ifSetMessagePort = false
    state = memoryMonitorStart({}, invalid, device, memoryMockSupports)
    assertEqual(t, state.source, "legacy")
    assertEqual(t, device.enabled, true)
end sub
