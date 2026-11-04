sub init()
    m.frames = 0
    ticker = m.top.findNode("ticker")
    ticker.observeField("opacity", "onFrame")
    anim = createObject("roSGNode", "Animation")
    anim.duration = 1.0
    anim.repeat = true
    anim.easeFunction = "linear"
    interp = createObject("roSGNode", "FloatFieldInterpolator")
    interp.fieldToInterp = ["ticker.opacity"]
    interp.key = [0.0, 1.0]
    interp.keyValue = [0.02, 0.98]
    anim.appendChild(interp)
    m.top.appendChild(anim)
    anim.control = "start"
    m.clock = createObject("roSGNode", "Timer")
    m.clock.duration = 1.0
    m.clock.repeat = true
    m.clock.observeField("fire", "onSecond")
    m.top.appendChild(m.clock)
    m.clock.control = "start"
end sub

sub onFrame()
    m.frames = m.frames + 1
end sub

sub onSecond()
    print "FPS "; m.frames
    m.frames = 0
end sub
