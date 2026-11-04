' Reef extras logic (P4.1-P4.5): sway keyframes, seeded walk loops, caustic tile
' grids and the night fade. Pure functions over plain values with no SceneGraph
' dependency, so components/Extras and brs-cli unit tests share them.

' keyCount evenly spaced keys over [0, 1].
function extrasLoopKeys(keyCount as integer) as object
    keys = []
    for j = 0 to keyCount - 1
        keys.push(j / (keyCount - 1))
    end for
    return keys
end function

' One full sine period of amplitude amp (radians) starting at phase (radians),
' sampled at extrasLoopKeys(keyCount). First and last values are equal, so a
' repeating Animation loops without a jump.
function extrasSwayValues(amp as float, phase as float, keyCount as integer) as object
    values = []
    for j = 0 to keyCount - 1
        values.push(amp * Sin(6.2831853 * j / (keyCount - 1) + phase))
    end for
    values[keyCount - 1] = values[0]
    return values
end function

' Phase (radians) of the shared current at design x: one wave of waveLength px
' travels across the tank, so neighbouring chains bend in sequence.
function extrasCurrentPhase(current as object, x as float) as float
    return -6.2831853 * x / current.waveLength
end function

' A seeded walk that loops: pauses and straight legs along y = cfg.y between
' cfg.left and cfg.right, ending where it started with the starting facing.
' cfg: x (start), y, left, right, speed (px/s), legPx [min, max], pauseSec
' [min, max], legs (count, the last leg returns to x). Facing turns only during
' a pause (a step of turnSec), never while moving. Returns { duration, keys,
' points ([x, y] per key), facings (1 right, -1 left, per key) }.
function extrasWalkPath(cfg as object, seed as integer) as object
    if cfg.turnZones <> invalid then return extrasShuttlePath(cfg, seed)
    rng = prngNew(seed)
    turn = 0.02
    if cfg.turnSec <> invalid then turn = cfg.turnSec
    x = cfg.x
    dir = 1
    if prngNextFloat(rng) < 0.5 then dir = -1
    times = [0.0]
    xs = [x]
    faces = [dir]
    path = { times: times, xs: xs, faces: faces, t: 0.0, facing: dir, turn: turn }
    for leg = 0 to cfg.legs - 1
        if leg = cfg.legs - 1 then
            target = cfg.x
        else
            length = prngRange(rng, cfg.legPx[0], cfg.legPx[1])
            if prngNextFloat(rng) < 0.3 then dir = -dir
            target = x + dir * length
            if target > cfg.right or target < cfg.left then target = x - dir * length
            if target > cfg.right then target = cfg.right
            if target < cfg.left then target = cfg.left
        end if
        pause = prngRange(rng, cfg.pauseSec[0], cfg.pauseSec[1])
        dx = target - x
        legFacing = path.facing
        if dx > 0 then legFacing = 1
        if dx < 0 then legFacing = -1
        extrasWalkPause(path, x, pause, legFacing)
        if Abs(dx) > 0.5 then
            path.t = path.t + Abs(dx) / cfg.speed
            times.push(path.t)
            xs.push(target)
            faces.push(legFacing)
            x = target
            dir = legFacing
        end if
    end for
    ' Close the loop: a last pause that turns back to the starting facing.
    extrasWalkPause(path, x, prngRange(rng, cfg.pauseSec[0], cfg.pauseSec[1]), faces[0])
    keys = []
    points = []
    for i = 0 to times.count() - 1
        keys.push(times[i] / path.t)
        points.push([xs[i], cfg.y])
    end for
    return { duration: path.t, keys: keys, points: points, facings: faces }
end function

' Leg swing keyed on a walk path: while the walker moves, side x amp x sin(stride phase)
' with one full swing per stridePx of travel (a whole number per leg, at least one),
' sampled at its quarter points; while it pauses, 0. side is 1 or -1 (the opposite
' legs). Returns { keys, values } for an interpolator on the walk's own Animation, so
' the legs stay in step with the translation and still under ?freeze.
function extrasGait(path as object, stridePx as float, amp as float, side as float) as object
    quarter = [0.0, 1.0, 0.0, -1.0]
    keys = [path.keys[0]]
    values = [0.0]
    for i = 1 to path.keys.count() - 1
        k0 = path.keys[i - 1]
        k1 = path.keys[i]
        dx = Abs(path.points[i][0] - path.points[i - 1][0])
        if dx > 0.5 and k1 > k0 then
            n = Int(dx / stridePx + 0.5)
            if n < 1 then n = 1
            steps = n * 4
            for j = 1 to steps
                keys.push(k0 + (k1 - k0) * j / steps)
                values.push(side * amp * quarter[j mod 4])
            end for
        else
            keys.push(k1)
            values.push(0.0)
        end if
    end for
    return { keys: keys, values: values }
end function

' A walk that turns only inside cfg.turnZones ([[x0, x1], [x0, x1]], left zone first),
' where cover hides the turn: from cfg.x (in the left zone, facing right) it crosses to a
' seeded point in the other zone in legs of cfg.legPx with pauses, turns there, and
' repeats for cfg.trips round trips, ending back at cfg.x facing right. Returns the
' extrasWalkPath shape.
function extrasShuttlePath(cfg as object, seed as integer) as object
    rng = prngNew(seed)
    x = cfg.x
    times = [0.0]
    xs = [x]
    faces = [1]
    path = { times: times, xs: xs, faces: faces, t: 0.0, facing: 1, turn: cfg.turnSec }
    halves = cfg.trips * 2
    for h = 0 to halves - 1
        dir = 1
        z = cfg.turnZones[1]
        if h mod 2 = 1 then
            dir = -1
            z = cfg.turnZones[0]
        end if
        goal = cfg.x
        if h < halves - 1 then goal = prngRange(rng, z[0], z[1])
        while Abs(goal - x) > 0.5
            target = x + dir * prngRange(rng, cfg.legPx[0], cfg.legPx[1])
            if dir * (goal - target) < cfg.legPx[0] then target = goal
            extrasWalkPause(path, x, prngRange(rng, cfg.pauseSec[0], cfg.pauseSec[1]), dir)
            path.t = path.t + Abs(target - x) / cfg.speed
            times.push(path.t)
            xs.push(target)
            faces.push(dir)
            x = target
        end while
        extrasWalkPause(path, x, prngRange(rng, cfg.pauseSec[0], cfg.pauseSec[1]), -dir)
    end for
    keys = []
    points = []
    for i = 0 to times.count() - 1
        keys.push(times[i] / path.t)
        points.push([xs[i], cfg.y])
    end for
    return { duration: path.t, keys: keys, points: points, facings: faces }
end function

' A fish-like turn for a walker with right and left art: over each facing step of the
' path the turn Group narrows to narrow, the art swaps across the middle tenth, and it
' widens again. Returns { keys, scale ([x, y] per key), right, left (opacity per key) }
' for interpolators on the walk's own Animation.
function extrasTurnTrack(path as object, narrow as float) as object
    f0 = path.facings[0]
    keys = [0.0]
    scale = [[1.0, 1.0]]
    right = [extrasBool(f0 = 1)]
    left = [extrasBool(f0 = -1)]
    last = f0
    for i = 1 to path.keys.count() - 1
        a = path.facings[i - 1]
        b = path.facings[i]
        if a <> b then
            k0 = path.keys[i - 1]
            d = path.keys[i] - k0
            for each phase in [[0.0, 1.0, a], [0.45, narrow, a], [0.55, narrow, b], [1.0, 1.0, b]]
                keys.push(k0 + d * phase[0])
                scale.push([phase[1], 1.0])
                right.push(extrasBool(phase[2] = 1))
                left.push(extrasBool(phase[2] = -1))
            end for
            last = b
        end if
    end for
    keys.push(1.0)
    scale.push([1.0, 1.0])
    right.push(extrasBool(last = 1))
    left.push(extrasBool(last = -1))
    return { keys: keys, scale: scale, right: right, left: left }
end function

function extrasBool(v as boolean) as float
    if v then return 1.0
    return 0.0
end function

' Holds at x for pause seconds; when newFacing differs, the facing steps over
' path.turn seconds at the middle of the pause.
sub extrasWalkPause(path as object, x as float, pause as float, newFacing as integer)
    if newFacing <> path.facing then
        mid = path.t + pause / 2
        path.times.push(mid)
        path.xs.push(x)
        path.faces.push(path.facing)
        path.times.push(mid + path.turn)
        path.xs.push(x)
        path.faces.push(newFacing)
        path.facing = newFacing
    end if
    path.t = path.t + pause
    path.times.push(path.t)
    path.xs.push(x)
    path.faces.push(path.facing)
end sub

' Tile origins covering clip ({ x, y, width, height }) while the grid scrolls
' by up to one tile along dir ([dx, dy], each -1, 0 or 1). A positive axis
' starts one tile before the clip, so the grid still covers it at any offset
' in [0, tile).
function extrasTileGrid(clip as object, tile as integer, dir as object) as object
    x0 = clip.x
    if dir[0] > 0 then x0 = clip.x - tile
    y0 = clip.y
    if dir[1] > 0 then y0 = clip.y - tile
    cols = Int((clip.width + tile - 1) / tile)
    if dir[0] <> 0 then cols = cols + 1
    rows = Int((clip.height + tile - 1) / tile)
    if dir[1] <> 0 then rows = rows + 1
    out = []
    for r = 0 to rows - 1
        for c = 0 to cols - 1
            out.push([x0 + c * tile, y0 + r * tile])
        end for
    end for
    return out
end function

' Day opacity faded by nightLevel (0 day, 1 night); 0 from hideAt up, where
' the caller hides the layer to save its fill rate.
function extrasNightOpacity(dayOpacity as float, nightLevel as float, hideAt as float) as float
    if nightLevel >= hideAt then return 0.0
    if nightLevel <= 0 then return dayOpacity
    return dayOpacity * (1 - nightLevel)
end function

' Per-channel linear blend of two 0xRRGGBBAA colours, f in [0, 1].
function extrasLerpColor(a as integer, b as integer, f as float) as integer
    if f <= 0 then return a
    if f >= 1 then return b
    out = 0
    for shift = 24 to 0 step -8
        ca = (a >> shift) and &hFF
        cb = (b >> shift) and &hFF
        c = Int(ca + (cb - ca) * f + 0.5)
        out = out or (c << shift)
    end for
    return out
end function

' Seed for the extras: ?seed in the preview, 1 under ?freeze without one,
' otherwise from the wall clock. Pass the preview globals in.
function extrasSeed(previewSeed as integer, freeze as float, clockSeed as integer) as integer
    if previewSeed > 0 then return previewSeed
    if freeze > 0 then return 1
    return clockSeed
end function
