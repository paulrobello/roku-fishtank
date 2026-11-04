' Device check package: bsconfig.check.json stages this file as source/main.brs.
' It shows the scene named in config/devicecheck.json (written by make device-check)
' and adds an FpsMeter that prints "FPS n" to the 8087 console every second.
sub RunScreenSaver()
    sceneName = "ReefTank"
    cfg = parseJson(readAsciiFile("pkg:/config/devicecheck.json"))
    if cfg <> invalid and cfg.scene <> invalid then sceneName = cfg.scene
    screen = createObject("roSGScreen")
    port = createObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.createScene(sceneName)
    screen.show()
    print "DEVICECHECK scene="; sceneName
    scene.appendChild(createObject("roSGNode", "FpsMeter"))
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then exit while
    end while
end sub
