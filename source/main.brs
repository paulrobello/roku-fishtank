sub RunScreenSaver()
    reefRunScreen("ReefTank")
end sub

' Settings saves changes immediately; memory-pressure exit never rewrites them.
sub RunScreenSaverSettings()
    reefRunScreen("ReefTankSettings")
end sub

sub reefRunScreen(sceneName as string)
    screen = createObject("roSGScreen")
    port = createObject("roMessagePort")
    screen.setMessagePort(port)
    memory = memoryMonitorCreate(port)
    ' Avoid allocating a scene if the app is already under critical pressure.
    if memoryMonitorStartup(memory, screen) then
        memoryMonitorStop(memory)
        return
    end if
    screen.createScene(sceneName)
    screen.show()
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" then
            if msg.isScreenClosed() then exit while
        else if memoryMonitorHandle(memory, msg, screen) then
            exit while
        end if
    end while
    memoryMonitorStop(memory)
end sub
