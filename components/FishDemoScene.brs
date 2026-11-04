sub init()
    dr = m.top.currentDesignResolution
    water = m.top.findNode("water")
    water.width = dr.width
    water.height = dr.height

    ' The first turn starts with the scene, so ?freeze can seek it (preview.brs assumes
    ' running Animations started at scene start).
    m.fish = [m.top.findNode("tang1x"), m.top.findNode("tang2x")]
    for each fish in m.fish
        fish.species = "royal_blue_tang"
        fish.swimSpeed = 60.0
        fish.facing = -1
    end for

    ' Under ?freeze no turn may start after the frame is frozen: the timer stays off
    ' before the 3 s turn has settled and fires only once after it.
    freeze = 0.0
    if m.global.hasField("previewFreeze") then freeze = m.global.previewFreeze
    m.timer = m.top.findNode("turnTimer")
    m.timer.repeat = (freeze = 0)
    m.timer.observeField("fire", "onTurnTimer")
    if freeze = 0 or freeze > 3.5 then m.timer.control = "start"
end sub

sub onTurnTimer()
    for each fish in m.fish
        fish.facing = -fish.facing
    end for
end sub
