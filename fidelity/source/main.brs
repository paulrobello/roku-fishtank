' Fidelity device package (P0.5): bsconfig.fidelity.json stages this file as
' source/main.brs, so the sideloaded screensaver shows FidelityScene instead of
' the channel's scene. Built by `make fidelity-build` to dist/fidelity.zip.
sub RunScreenSaver()
    screen = createObject("roSGScreen")
    port = createObject("roMessagePort")
    screen.setMessagePort(port)
    screen.createScene("FidelityScene")
    screen.show()
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then exit while
    end while
end sub
