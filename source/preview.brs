' Browser-preview entry point. brs-engine has no screensaver entry point, so this
' Main builds the same scene as RunScreenSaver and runs the same message loop.
' Preview-only: bsconfig.json excludes this file and it must never ship to a device.
'
' URL params arrive as deep-link strings in args (seed, time, speed, freeze, scene, species,
<<<<<<< HEAD
' density, night) and are exposed to the scene as m.global.previewSeed/previewTime/
' previewSpeed/previewFreeze/previewSpecies/previewDensity/previewNight.
=======
' density, debug) and are exposed to the scene as m.global.previewSeed/previewTime/previewSpeed/
' previewFreeze/previewSpecies/previewDensity/previewDebug.
>>>>>>> 3a31cba (P1.8 avoidance and occlusion data: re-measured ellipses, caves, rocks and band for the composed tank, per-layer occluder rects, ?debug=1 overlay)
' ?scene=<ComponentName> picks the scene to create (default ReefTank).
' ?night=1 / ?night=0 force the ReefTank night mode (P3); ?time=HH:MM (or
' YYYY-MM-DDTHH:MM) sets its clock, so dusk can be frozen deterministically.
sub Main(args as object)
    params = previewParseArgs(args)
    print "PREVIEW_PARAMS scene="; params.scene; " seed="; params.seed; " time="; params.time; " speed="; params.speed; " freeze="; params.freeze; " species="; params.species; " density="; params.density; " night="; params.night

    screen = createObject("roSGScreen")
    port = createObject("roMessagePort")
    screen.setMessagePort(port)
    screen.getGlobalNode().addFields({
        previewSeed: params.seed,
        previewTime: params.time,
        previewSpeed: params.speed,
        previewFreeze: params.freeze,
        previewSpecies: params.species,
        previewDensity: params.density,
<<<<<<< HEAD
        previewNight: params.night
=======
        previewDebug: params.debug
>>>>>>> 3a31cba (P1.8 avoidance and occlusion data: re-measured ellipses, caves, rocks and band for the composed tank, per-layer occluder rects, ?debug=1 overlay)
    })
    scene = screen.createScene(params.scene)
    screen.show()

    timeout = 0
    if params.freeze > 0 then timeout = 50
    clock = createObject("roTimespan")
    frozen = false
    while true
        msg = wait(timeout, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then exit while
        if params.freeze > 0 then
            if frozen
                ' Animations started after the freeze are paused too, so the frame stays stable.
                previewFreezeTree(scene, scene, -1)
            else if clock.totalMilliseconds() >= params.freeze * 1000
                previewFreezeTree(scene, scene, params.freeze)
                frozen = true
                timeout = 250
                print "PREVIEW_FROZEN t="; params.freeze
            end if
        end if
    end while
end sub

function previewParseArgs(args as object) as object
<<<<<<< HEAD
    params = { scene: "ReefTank", seed: 0, time: "", speed: 1.0, freeze: 0.0, species: "", density: "", night: "" }
=======
    params = { scene: "ReefTank", seed: 0, time: "", speed: 1.0, freeze: 0.0, species: "", density: "", debug: 0 }
>>>>>>> 3a31cba (P1.8 avoidance and occlusion data: re-measured ellipses, caves, rocks and band for the composed tank, per-layer occluder rects, ?debug=1 overlay)
    if args = invalid then return params
    if args.scene <> invalid and args.scene <> "" then params.scene = args.scene
    if args.seed <> invalid then params.seed = args.seed.toInt()
    if args.time <> invalid then params.time = args.time
    if args.speed <> invalid then params.speed = val(lCase(args.speed).replace("x", ""))
    if args.freeze <> invalid then params.freeze = val(args.freeze)
    if args.species <> invalid then params.species = args.species
    if args.density <> invalid then params.density = args.density
<<<<<<< HEAD
    if args.night <> invalid then params.night = args.night
=======
    if args.debug <> invalid then params.debug = args.debug.toInt()
>>>>>>> 3a31cba (P1.8 avoidance and occlusion data: re-measured ellipses, caves, rocks and band for the composed tank, per-layer occluder rects, ?debug=1 overlay)
    return params
end function

' Pauses every running Animation under node. When t >= 0 it also snaps each paused
' Animation's targets to their value at t seconds after scene start, so reloads freeze
' on an identical frame regardless of when the pause lands. Assumes the animation
' started with the scene (true for animations started in init()).
sub previewFreezeTree(node as object, scene as object, t as float)
    if node.subtype() = "Animation" and node.state = "running" then
        node.control = "pause"
        if t >= 0 then previewSeekAnimation(node, scene, t)
    end if
    for i = 0 to node.getChildCount() - 1
        previewFreezeTree(node.getChild(i), scene, t)
    end for
end sub

sub previewSeekAnimation(anim as object, scene as object, t as float)
    duration = anim.duration
    if duration <= 0 then return
    delay = anim.delay
    if anim.repeat then
        period = duration + delay
        elapsed = t - int(t / period) * period - delay
    else
        elapsed = t - delay
    end if
    f = elapsed / duration
    if f < 0 then f = 0
    if f > 1 then f = 1
    f = previewEase(f, anim.easeFunction)
    for i = 0 to anim.getChildCount() - 1
        previewApplyInterpolator(anim.getChild(i), f, scene)
    end for
end sub

' Mirrors the brs-scenegraph ease curves (default outCubic).
function previewEase(f as float, name as string) as float
    n = lCase(name)
    if n = "" then n = "outcubic"
    if n = "linear" then return f
    if n = "inquad" then return f * f
    if n = "outquad" then return f * (2 - f)
    if n = "inoutquad" then
        if f < 0.5 then return 2 * f * f
        return (4 - 2 * f) * f - 1
    end if
    if n = "incubic" then return f * f * f
    if n = "outcubic" then return (f - 1) * (f - 1) * (f - 1) + 1
    if n = "inoutcubic" then
        if f < 0.5 then return 4 * f * f * f
        return 4 * (f - 1) * (f - 1) * (f - 1) + 1
    end if
    print "PREVIEW_WARN freeze: ease "; name; " not mirrored, using linear"
    return f
end function

sub previewApplyInterpolator(interp as object, f as float, scene as object)
    target = interp.fieldToInterp
    if type(target) = "roArray" then target = target[0]
    if target = invalid or target = "" then return
    parts = target.split(".")
    if parts.count() <> 2 then return
    node = scene.findNode(parts[0])
    keys = interp.key
    values = interp.keyValue
    if node = invalid or keys = invalid or values = invalid or keys.count() = 0 then return
    if interp.reverse then f = 1 - f

    last = keys.count() - 1
    if last > values.count() - 1 then last = values.count() - 1
    if last = 0 or f <= keys[0] then
        node.setField(parts[1], values[0])
        return
    end if
    if f >= keys[last] then
        node.setField(parts[1], values[last])
        return
    end if
    i = 0
    while i < last - 1 and f > keys[i + 1]
        i = i + 1
    end while
    span = keys[i + 1] - keys[i]
    u = 0.0
    if span > 0 then u = (f - keys[i]) / span
    a = values[i]
    b = values[i + 1]

    kind = interp.subtype()
    if kind = "Vector2DFieldInterpolator" then
        node.setField(parts[1], [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u])
    else if kind = "ColorFieldInterpolator" then
        node.setField(parts[1], previewLerpColorHsv(a, b, u))
    else
        node.setField(parts[1], a + (b - a) * u)
    end if
end sub
