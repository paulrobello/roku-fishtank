' Anemone hosting (P4.1): a clownfish attached to a host point nestles among the
' tentacles, leaves to roam close by, and comes back. Pure functions over the
' brain.brs fish state; brainTickBehavior hands a fish with a host to hostTick.
'
' host (config/extras.json anemone.host): x, y (nestle point), radius (nestle
' spread), leash (roam limit), nestleSec, roamSec, segSec ([min, max] s),
' approachSec, nestleSpeed, roamSpeed (px/s).
'
' Modes: nestle (slow arrive moves to points within radius of the host point)
' -> roam (arrive moves to points between 2 x radius and leash) -> approach
' (arrive to the host point) -> nestle. Every move goes through
' brainPlanArrive, so steerMove keeps the ellipse guard.

' Hosts fish at the anemone: places it inside the nestle radius and starts it
' nestling. Uses only the fish's own PRNG, so other fish are unaffected.
sub hostAttach(fish as object, host as object, world as object, cfg as object)
    fish.host = host
    if fish.kind = invalid then fish.kind = "cruise"
    p = hostPick(fish, world, 0, host.radius)
    a = fish.agent
    a.x = p[0]
    a.y = p[1]
    a.vx = 0
    a.vy = 0
    fish.points = [[a.x, a.y]]
    fish.startTick = 0
    fish.steps = 0
    fish.dart = false
    fish.hostMode = "nestle"
    fish.hostEnd = brainSecTicks(fish.rng, host.nestleSec, cfg.tick)
    fish.hostVisits = 1
end sub

' One brain tick for a hosted fish; plans the next segment when the current
' one has ended. Returns "segment" or "".
function hostTick(fish as object, cfg as object, world as object, now as integer) as string
    if now < fish.startTick + fish.steps then return ""
    h = fish.host
    a = fish.agent
    tick = cfg.tick
    if fish.hostMode = "nestle" then
        if now >= fish.hostEnd then hostSetMode(fish, "roam", now + brainSecTicks(fish.rng, h.roamSec, tick))
    else if fish.hostMode = "roam" then
        if now >= fish.hostEnd then hostSetMode(fish, "approach", now + Int(h.approachSec / tick))
    else if fish.hostMode = "approach" then
        if brainDist(a, [h.x, h.y]) <= h.radius or now >= fish.hostEnd then
            hostSetMode(fish, "nestle", now + brainSecTicks(fish.rng, h.nestleSec, tick))
            fish.hostVisits = fish.hostVisits + 1
        end if
    end if

    steps = 4
    if fish.hostMode = "approach" then
        fish.points = brainPlanArrive(fish, world, h.x, h.y, h.roamSpeed, steps, tick)
    else
        steps = brainSecTicks(fish.rng, h.segSec, tick)
        rMin = 0.0
        rMax = h.radius
        speed = h.nestleSpeed
        if fish.hostMode = "roam" then
            rMin = 2 * h.radius
            rMax = h.leash
            speed = h.roamSpeed
        end if
        p = hostPick(fish, world, rMin, rMax)
        fish.points = brainPlanArrive(fish, world, p[0], p[1], speed, steps, tick)
    end if
    brainStartSegment(fish, cfg, now, steps, false)
    return "segment"
end function

sub hostSetMode(fish as object, mode as string, modeEnd as integer)
    fish.hostMode = mode
    fish.hostEnd = modeEnd
end sub

' A random point at distance [rMin, rMax] from the host point, inside the
' lane and outside every ellipse; the host point itself after 16 misses.
function hostPick(fish as object, world as object, rMin as float, rMax as float) as object
    h = fish.host
    lane = world.lane
    for tries = 1 to 16
        ang = prngRange(fish.rng, 0, 6.2831853)
        r = prngRange(fish.rng, rMin, rMax)
        x = h.x + Cos(ang) * r
        y = h.y + Sin(ang) * r
        if x >= lane.left and x <= lane.right and y >= lane.top and y <= lane.bottom then
            if brainClearOf(world.ellipses, x, y, 1.0) then return [x, y]
        end if
    end for
    return [h.x, h.y]
end function

' The host for a brain in lane laneId hosting species, or invalid: hosts is
' config/extras.json anemone.host, which names its lane and species.
function hostFor(host as dynamic, laneId as string, species as string) as dynamic
    if host = invalid then return invalid
    if host.lane <> laneId then return invalid
    for each s in host.species
        if s = species then return host
    end for
    return invalid
end function
