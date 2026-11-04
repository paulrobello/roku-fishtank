sub RunScreenSaver()
    screen = createObject("roSGScreen")
    port = createObject("roMessagePort")
    screen.setMessagePort(port)
    screen.createScene("ReefTank")
    screen.show()

    ' Any remote keypress terminates a screensaver (platform behavior);
    ' loop until the screen closes.
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then exit while
    end while
end sub

' Settings entry point (Settings > Theme > Screensavers > Reef Tank). Back closes the
' scene, which ends the screen and this loop.
sub RunScreenSaverSettings()
    screen = createObject("roSGScreen")
    port = createObject("roMessagePort")
    screen.setMessagePort(port)
    screen.createScene("ReefTankSettings")
    screen.show()

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then exit while
    end while
end sub
