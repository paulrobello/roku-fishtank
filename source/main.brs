sub RunScreenSaver()
    screen = createObject("roSGScreen")
    port = createObject("roMessagePort")
    screen.setMessagePort(port)
    screen.createScene("FishtankTest")
    screen.show()

    ' Any remote keypress terminates a screensaver (platform behavior);
    ' loop until the screen closes.
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then exit while
    end while
end sub
