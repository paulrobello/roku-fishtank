' Arch swimmer logic (config/arch.json, components/Arch). Pure functions over plain
' AAs so brs-cli unit tests can run them. Points are design pixels of the fish anchor
' (rig mirror_center); times are seconds of the loop at speed 1.

' Seed: ?seed in the preview, 1 under ?freeze without one, otherwise the clock.
function archSeed(previewSeed as integer, freeze as float, clockSeed as integer) as integer
    if previewSeed > 0 then return previewSeed
    if freeze > 0 then return 1
    return clockSeed
end function

' The swim clip: the overlay rect inset by clipInset on every side.
function archClip(cfg as object) as object
    o = cfg.overlay
    inset = cfg.clipInset
    return { x: o.x + inset, y: o.y + inset, width: o.width - 2 * inset, height: o.height - 2 * inset }
end function

' The seeded loop: { duration, passages, tracks }. passages[k] = { start, finish, dir }
' (dir 1 swims right, -1 left). tracks[0] drives the right-facing fish and tracks[1]
' the left-facing one, each { keys (fractions of duration), points, rots }; both start
' and end the loop at the same parked point, so the repeat is seamless.
function archPlan(cfg as object, rng as object) as object
    clip = archClip(cfg)
    xLeft = clip.x - cfg.parkGap
    xRight = clip.x + clip.width + cfg.parkGap
    parkY = clip.y + clip.height + cfg.parkBelow
    n = cfg.keysPerPassage
    passages = []
    t = prngRange(rng, cfg.firstGapSec[0], cfg.firstGapSec[1])
    for k = 0 to cfg.passages - 1
        if k > 0 then t = t + prngRange(rng, cfg.gapSec[0], cfg.gapSec[1])
        dir = 1
        if prngNextFloat(rng) < 0.5 then dir = -1
        speed = prngRange(rng, cfg.speedPx[0], cfg.speedPx[1])
        amp = prngRange(rng, cfg.waveAmp[0], cfg.waveAmp[1])
        cycles = prngRange(rng, cfg.waveCycles[0], cfg.waveCycles[1])
        phase = prngRange(rng, 0, 6.2831853)
        y0 = prngRange(rng, cfg.yBand[0] + amp, cfg.yBand[1] - amp)
        y1 = prngRange(rng, cfg.yBand[0] + amp, cfg.yBand[1] - amp)
        xA = xLeft
        xB = xRight
        if dir < 0 then
            xA = xRight
            xB = xLeft
        end if
        finish = t + (xRight - xLeft) / speed
        p = { start: t, finish: finish, dir: dir, xA: xA, xB: xB, times: [], points: [], rots: [] }
        for i = 0 to n
            u = i / n
            w = 6.2831853 * cycles
            p.times.push(t + u * (finish - t))
            p.points.push([xA + (xB - xA) * u, y0 + (y1 - y0) * u + amp * Sin(w * u + phase)])
            p.rots.push(archPitch(xB - xA, (y1 - y0) + amp * w * Cos(w * u + phase), cfg.pitchMaxDeg, dir))
        end for
        passages.push(p)
        t = finish
    end for
    duration = t + cfg.gapSec[0]
    tracks = []
    for each dir in [1, -1]
        tracks.push(archTrack(passages, dir, xLeft, parkY, duration, cfg.hopSec))
    end for
    return { duration: duration, passages: passages, tracks: tracks }
end function

' Rotation (radians, counter-clockwise positive) for a path heading (dx, dy) per unit
' by a fish facing dir: nose-up is counter-clockwise facing right, clockwise facing
' left (as brainPitchTarget), clamped to maxDeg.
function archPitch(dx as float, dy as float, maxDeg as float, dir as integer) as float
    adx = dx
    if adx < 0 then adx = -adx
    if adx = 0 then return 0.0
    climb = Atn(-dy / adx)
    limit = maxDeg * 3.14159265 / 180.0
    if climb > limit then climb = limit
    if climb < -limit then climb = -limit
    if dir < 0 then return -climb
    return climb
end function

' One fish's keyframes over the loop: parked under the clip, it hops up outside the
' clip's side to each of its passages, swims it, hops back down and slides along the
' park row to its next entry side. Every point off a passage is outside the clip.
function archTrack(passages as object, dir as integer, xPark as float, parkY as float, duration as float, hop as float) as object
    mine = []
    for each p in passages
        if p.dir = dir then mine.push(p)
    end for
    x0 = xPark
    if mine.count() > 0 then x0 = mine[0].xA
    times = [0.0]
    points = [[x0, parkY]]
    rots = [0.0]
    for each p in mine
        times.push(p.start - hop)
        points.push([p.xA, parkY])
        rots.push(0.0)
        for i = 0 to p.times.count() - 1
            times.push(p.times[i])
            points.push(p.points[i])
            rots.push(p.rots[i])
        end for
        times.push(p.finish + hop)
        points.push([p.xB, parkY])
        rots.push(0.0)
    end for
    times.push(duration)
    points.push([x0, parkY])
    rots.push(0.0)
    keys = []
    for each t in times
        keys.push(t / duration)
    end for
    return { keys: keys, points: points, rots: rots }
end function

' Anchor points to Fish translations (the Fish origin is its body top-left).
function archTranslations(points as object, anchor as object) as object
    out = []
    for each p in points
        out.push([p[0] - anchor[0], p[1] - anchor[1]])
    end for
    return out
end function
