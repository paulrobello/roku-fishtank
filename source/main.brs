sub RunScreenSaver()
    launchClock = createObject("roTimespan")
    reefRunScreen("ReefTank", launchClock)
end sub

' Settings saves changes immediately; memory-pressure exit never rewrites them.
sub RunScreenSaverSettings()
    reefRunScreen("ReefTankSettings")
end sub

sub reefRunScreen(sceneName as string, launchClock = invalid as dynamic)
    screen = createObject("roSGScreen")
    port = createObject("roMessagePort")
    screen.setMessagePort(port)
    memory = memoryMonitorCreate(port)
    ' Avoid allocating a scene if the app is already under critical pressure.
    if memoryMonitorStartup(memory, screen) then
        memoryMonitorStop(memory)
        return
    end if
    scene = screen.createScene(sceneName)
    screen.show()
    launchPending = launchClock <> invalid
    waitMs = 0
    if launchPending then
        observed = scene.observeField("launchOutcome", port)
        print "LAUNCH observer="; observed
        waitMs = 100
        scene.launchWatch = true
    end if
    while true
        msg = wait(waitMs, port)
        if type(msg) = "roSGScreenEvent" then
            if msg.isScreenClosed() then exit while
        else if type(msg) = "roSGNodeEvent" then
            if launchPending then print "LAUNCH field-event="; msg.getField()
        else if memoryMonitorHandle(memory, msg, screen) then
            exit while
        end if
        if launchPending then
            ' Readback also handles a missed observer notification. Stop polling
            ' permanently after this launch reaches a terminal outcome.
            outcome = scene.launchOutcome
            if outcome <> "" then
                launchRecord(outcome, launchClock.totalMilliseconds())
                launchPending = false
            else if launchClock.totalMilliseconds() >= 65000 then
                print "LAUNCH handoff timed out; no successful report written"
                launchPending = false
            end if
            if not launchPending then
                scene.unobserveField("launchOutcome")
                waitMs = 0
            end if
        end if
    end while
    memoryMonitorStop(memory)
end sub
