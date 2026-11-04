sub init()
    dr = m.top.currentDesignResolution
    w = dr.width
    h = dr.height
    print "FishtankTest screensaver running: "; w; "x"; h

    water = m.top.findNode("water")
    water.size = [w, h]

    pebbles = m.top.findNode("pebbles")
    pebbles.loadWidth = w
    pebbles.loadHeight = int(w * 160.0 / 1280.0)
    pebbles.translation = [0, h - pebbles.loadHeight]

    ' Fish authored against hd (1280x720) coordinates, scaled to the design resolution.
    sx = w / 1280.0
    sy = h / 720.0
    fish = [
        { uri: "pkg:/images/fish_orange.png", y: 190, bob: 40, size: 1.0, dur: 22 },
        { uri: "pkg:/images/fish_blue.png", y: 380, bob: 60, size: 0.8, dur: 30 },
        { uri: "pkg:/images/fish_orange.png", y: 540, bob: 30, size: 1.2, dur: 17 }
    ]
    for each f in fish
        spawnFish(f, sx, sy, w)
    end for
end sub

sub spawnFish(f as object, sx as float, sy as float, w as float)
    poster = createObject("roSGNode", "Poster")
    poster.uri = f.uri
    lw = int(240 * f.size * sx)
    lh = int(140 * f.size * sy)
    poster.loadWidth = lw
    poster.loadHeight = lh

    y0 = f.y * sy
    yMid = (f.y + f.bob) * sy
    poster.translation = [-lw, y0]

    anim = createObject("roSGNode", "Animation")
    anim.duration = f.dur
    anim.repeat = true
    anim.easeFunction = "linear"

    interp = createObject("roSGNode", "Vector2DFieldInterpolator")
    interp.fieldToInterp = poster.translation
    interp.key = [0.0, 0.5, 1.0]
    interp.keyValue = [[-lw, y0], [w * 0.55, yMid], [w + lw, y0]]
    anim.appendChild(interp)

    m.top.appendChild(poster)
    m.top.appendChild(anim)
    anim.control = "start"
end sub
