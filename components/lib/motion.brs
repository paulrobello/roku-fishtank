' Render-only smoothing: steering decisions and original waypoint times stay intact.
' Monotone Hermite curves cannot overshoot either coordinate's span endpoints.
function motionTangent(a as float, b as float) as float
    if a * b <= 0 then return 0.0
    return 2.0 * a * b / (a + b)
end function

function motionHermite(a as float, b as float, ma as float, mb as float, u as float) as float
    u2 = u * u
    u3 = u2 * u
    return (2 * u3 - 3 * u2 + 1) * a + (u3 - 2 * u2 + u) * ma + (-2 * u3 + 3 * u2) * b + (u3 - u2) * mb
end function

' Four linear render samples per steering interval (31.25 ms at the usual 8 Hz).
' Test every rendered chord; unsafe rounded spans retain the approved straight path.
function motionSmoothPath(points as object, ellipses as object) as object
    out = [[points[0][0], points[0][1]]]
    last = points.count() - 1
    for i = 0 to last - 1
        a = points[i]
        b = points[i + 1]
        before = a
        after = b
        if i > 0 then before = points[i - 1]
        if i + 1 < last then after = points[i + 2]
        start = []
        finish = []
        for axis = 0 to 1
            d = b[axis] - a[axis]
            ma = d
            mb = d
            if i > 0 then ma = motionTangent(a[axis] - before[axis], d)
            if i + 1 < last then mb = motionTangent(d, after[axis] - b[axis])
            start.push(ma)
            finish.push(mb)
        end for
        samples = []
        previous = a
        safe = true
        for n = 1 to 4
            u = n / 4.0
            p = [motionHermite(a[0], b[0], start[0], finish[0], u), motionHermite(a[1], b[1], start[1], finish[1], u)]
            if steerFirstHit(ellipses, previous[0], previous[1], p[0], p[1]) >= 0 then safe = false
            samples.push(p)
            previous = p
        end for
        for n = 1 to 4
            if safe then
                out.push(samples[n - 1])
            else
                u = n / 4.0
                out.push([a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u])
            end if
        end for
    end for
    return out
end function

' Reconcile render/simulation clock disagreement gradually, not in one 31 ms chord.
' A smoothstep offset starts at the displayed position and vanishes over 350 ms.
' Check every changed chord; if the correction is unsafe keep the approved path.
function motionBridge(points as object, current as object, ellipses as object, duration as float, dart = false as boolean) as object
    if points.count() < 2 or duration <= 0 then return points
    dx = current[0] - points[0][0]
    dy = current[1] - points[0][1]
    if Abs(dx) + Abs(dy) < 0.001 then return points
    blend = 0.35
    if duration < blend then blend = duration
    corrected = []
    last = points.count() - 1
    for i = 0 to last
        fraction = i / last
        elapsed = duration * fraction
        if dart then elapsed = duration * (1.0 - (1.0 - fraction) ^ (1.0 / 3.0))
        u = elapsed / blend
        if u > 1 then u = 1
        weight = 1.0 - u * u * (3.0 - 2.0 * u)
        p = [points[i][0] + dx * weight, points[i][1] + dy * weight]
        if i > 0 then
            previous = corrected[i - 1]
            if steerFirstHit(ellipses, previous[0], previous[1], p[0], p[1]) >= 0 then return points
        end if
        corrected.push(p)
    end for
    return corrected
end function

' Instantaneous speed of the rendered polyline in local pixels per wall second.
' Includes outCubic's derivative, so the tail slows as a dart coasts to a stop.
function motionPathSpeed(points as object, elapsed as float, duration as float, dart as boolean) as float
    count = points.count() - 1
    if count < 1 or duration <= 0 or elapsed >= duration then return 0.0
    f = elapsed / duration
    if f < 0 then f = 0
    rate = 1.0
    if dart then
        rate = 3.0 * (1.0 - f) * (1.0 - f)
        f = 1.0 - (1.0 - f) ^ 3
    end if
    i = Int(f * count)
    if i >= count then i = count - 1
    dx = points[i + 1][0] - points[i][0]
    dy = points[i + 1][1] - points[i][1]
    return Sqr(dx * dx + dy * dy) * count / duration * rate
end function

' Exponential response uses elapsed time, not a fixed per-frame multiplier.
function motionFollowSpeed(previous as float, target as float, seconds as float) as float
    if seconds <= 0 then return previous
    tau = 0.45
    if target > previous then tau = 0.18
    return previous + (target - previous) * (1.0 - Exp(-seconds / tau))
end function

' Called by the existing shared brain/school timer: no per-fish timer is added.
' Derive velocity from the actual issued path, not camera/lane transforms or buckets.
sub motionDriveTail(item as object, seconds as float, dt as float)
    if item.motionPoints = invalid then return
    target = motionPathSpeed(item.motionPoints, seconds - item.motionStart, item.motionDuration, item.motionDart)
    previous = item.node.tailSpeed
    if previous < 0 then previous = target
    item.node.tailSpeed = motionFollowSpeed(previous, target, dt)
end sub

' Check school spacing over every rendered interval, including between sample times.
' Relative motion is linear on each chord; its closest approach has a closed form.
function motionSchoolClear(paths as object, minimum as float) as boolean
    for i = 0 to paths.count() - 2
        for j = i + 1 to paths.count() - 1
            for k = 1 to paths[i].count() - 1
                ax = paths[i][k - 1][0] - paths[j][k - 1][0]
                ay = paths[i][k - 1][1] - paths[j][k - 1][1]
                bx = paths[i][k][0] - paths[j][k][0]
                by = paths[i][k][1] - paths[j][k][1]
                dx = bx - ax
                dy = by - ay
                dd = dx * dx + dy * dy
                f = 0.0
                if dd > 0 then f = - (ax * dx + ay * dy) / dd
                if f < 0 then f = 0
                if f > 1 then f = 1
                x = ax + dx * f
                y = ay + dy * f
                if x * x + y * y < minimum * minimum then return false
            end for
        end for
    end for
    return true
end function
