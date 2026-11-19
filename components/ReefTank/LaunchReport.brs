' Enabled only by the production RunScreenSaver entry, after screen.show().
' All diagnostics stop after readiness/failure. No animation state is changed.
sub launchReportStart()
    if not m.top.launchWatch or m.launchTimer <> invalid then return
    if m.launchSceneBuilt <> true then
        m.top.launchOutcome = "asset-error"
        return
    end if
    m.launchDone = false
    m.launchAssets = []
    launchReportCollect(m.top, true)
    if m.launchAssets.count() = 0 then
        m.top.launchOutcome = "asset-error"
        return
    end if
    m.launchClock = createObject("roTimespan")
    m.launchTimer = m.top.createChild("Timer")
    m.launchTimer.duration = 0.1
    m.launchTimer.repeat = true
    m.launchTimer.observeField("fire", "launchReportPoll")
    m.launchTimer.control = "start"
end sub

sub launchReportCollect(node as object, visible as boolean)
    if node.hasField("visible") then visible = visible and node.visible
    if node.hasField("opacity") then visible = visible and node.opacity > 0
    if not visible then return
    if node.isSubtype("Poster") then
        if node.uri <> "" then m.launchAssets.push(node)
    end if
    for i = 0 to node.getChildCount() - 1
        launchReportCollect(node.getChild(i), visible)
    end for
end sub

sub launchReportPoll()
    if m.launchDone then return
    statuses = []
    for each poster in m.launchAssets
        statuses.push(poster.loadStatus)
    end for
    status = launchGate(statuses, m.launchClock.totalMilliseconds(), m.top.launchWatch)
    if status = "pending" then return
    m.launchDone = true
    m.launchTimer.control = "stop"
    m.launchTimer.unobserveField("fire")
    m.launchAssets = []
    if status = "ready" then
        ' Roku records completion on the subsequent render pass. Asset readiness
        ' plus this timer callback is not independent first-frame proof.
        ' Publish the local readiness result independently of native beacon
        ' acceptance. Standalone screensaver firmware may reject this beacon.
        m.top.launchOutcome = "render-ready"
        print "LAUNCH scene initial-assets-ready; requesting native beacon"
        try
            beaconResult = m.top.signalBeacon("AppLaunchComplete")
            print "LAUNCH native-beacon-return="; beaconResult
        catch e
            print "LAUNCH native beacon unavailable; local readiness preserved"
        end try
    else
        m.top.launchOutcome = status
    end if
end sub
