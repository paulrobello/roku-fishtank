' Pure helpers for config/scene.json (the ReefTank layer stack, lanes and decor).
' No SceneGraph: ReefTank reads and parses the file, these functions validate and
' query the parsed object so they run under brs-cli unit tests.

' Parses an "0xRRGGBBAA" or "#RRGGBBAA" string into a 32-bit RGBA integer (high bit
' set comes back negative, as SceneGraph color fields expect). Integers pass through.
' Anything else returns fallback.
function sceneCfgParseColor(value as dynamic, fallback = &hFFFFFFFF as integer) as integer
    c = sceneCfgColorOrInvalid(value)
    if c = invalid then return fallback
    return c
end function

function sceneCfgIsColor(value as dynamic) as boolean
    return sceneCfgColorOrInvalid(value) <> invalid
end function

function sceneCfgColorOrInvalid(value as dynamic) as dynamic
    if sceneCfgIsNumber(value) then return Int(value)
    if not sceneCfgIsString(value) then return invalid
    s = LCase(value)
    if Left(s, 2) = "0x" then
        s = Mid(s, 3)
    else if Left(s, 1) = "#" then
        s = Mid(s, 2)
    end if
    if Len(s) <> 8 then return invalid
    digits = "0123456789abcdef"
    c = 0
    for i = 1 to 8
        d = Instr(1, digits, Mid(s, i, 1)) - 1
        if d < 0 then return invalid
        c = (c << 4) or d
    end for
    return c
end function

function sceneCfgIsNumber(v as dynamic) as boolean
    t = LCase(type(v))
    return t = "integer" or t = "rointeger" or t = "float" or t = "rofloat" or t = "double" or t = "rodouble" or t = "longinteger" or t = "rolonginteger"
end function

function sceneCfgIsString(v as dynamic) as boolean
    t = LCase(type(v))
    return t = "string" or t = "rostring"
end function

function sceneCfgIsArray(v as dynamic) as boolean
    return LCase(type(v)) = "roarray"
end function

function sceneCfgIsObject(v as dynamic) as boolean
    return LCase(type(v)) = "roassociativearray"
end function

' Returns a list of problem strings; an empty list means the config is usable.
function sceneCfgValidate(cfg as dynamic) as object
    errors = []
    if not sceneCfgIsObject(cfg) then
        errors.push("scene config is not a JSON object")
        return errors
    end if

    design = cfg.design
    if not sceneCfgIsObject(design) or not sceneCfgIsNumber(design.width) or not sceneCfgIsNumber(design.height) then
        errors.push("design needs numeric width and height")
    else if design.width <= 0 or design.height <= 0 then
        errors.push("design width and height must be positive")
    end if

    ids = {}
    laneIds = {}
    if not sceneCfgIsArray(cfg.layers) or cfg.layers.count() = 0 then
        errors.push("layers must be a non-empty array")
    else
        for i = 0 to cfg.layers.count() - 1
            layer = cfg.layers[i]
            where = "layers[" + i.toStr() + "]"
            if not sceneCfgIsObject(layer) or not sceneCfgIsString(layer.id) or layer.id = "" then
                errors.push(where + " needs a string id")
            else
                if ids.doesExist(layer.id) then errors.push(where + " duplicates id " + layer.id)
                ids[layer.id] = true
                if not sceneCfgIsNumber(layer.parallax) then errors.push(layer.id + " needs a numeric parallax")
                if layer.lane <> invalid then
                    sceneCfgValidateLane(layer.id, layer.lane, errors)
                    laneIds[layer.id] = true
                end if
            end if
        end for
    end if

    if cfg.decor <> invalid then
        if not sceneCfgIsArray(cfg.decor) then
            errors.push("decor must be an array")
        else
            for i = 0 to cfg.decor.count() - 1
                sceneCfgValidateDecor("decor[" + i.toStr() + "]", cfg.decor[i], ids, errors)
            end for
        end if
    end if
    sceneCfgValidateDrift(cfg, errors)
    if cfg.population <> invalid then sceneCfgValidatePopulation(cfg.population, ids, laneIds, errors)
    return errors
end function

sub sceneCfgValidateLane(id as string, lane as dynamic, errors as object)
    if not sceneCfgIsObject(lane) then
        errors.push(id + " lane must be an object")
        return
    end if
    r = lane.rect
    if not sceneCfgIsObject(r) or not sceneCfgIsNumber(r.left) or not sceneCfgIsNumber(r.top) or not sceneCfgIsNumber(r.right) or not sceneCfgIsNumber(r.bottom) then
        errors.push(id + " lane needs a numeric rect {left, top, right, bottom}")
    else if r.right <= r.left or r.bottom <= r.top then
        errors.push(id + " lane rect is empty")
    end if
    if not sceneCfgIsNumber(lane.scale) or lane.scale <= 0 then errors.push(id + " lane needs a positive scale")
    if not sceneCfgIsColor(lane.tint) then errors.push(id + " lane tint must be 0xRRGGBBAA")
end sub

sub sceneCfgValidateDecor(where as string, d as dynamic, ids as object, errors as object)
    if not sceneCfgIsObject(d) or not sceneCfgIsString(d.id) or d.id = "" then
        errors.push(where + " needs a string id")
        return
    end if
    if not sceneCfgIsString(d.layer) or not ids.doesExist(d.layer) then errors.push(d.id + " names an unknown layer")
    if not sceneCfgIsString(d.uri) or d.uri = "" then errors.push(d.id + " needs a uri")
    if not sceneCfgIsNumber(d.x) or not sceneCfgIsNumber(d.y) then errors.push(d.id + " needs numeric x and y")
    if not sceneCfgIsNumber(d.width) or not sceneCfgIsNumber(d.height) or d.width <= 0 or d.height <= 0 then
        errors.push(d.id + " needs a positive width and height")
    end if
end sub

' Layer ids back to front.
function sceneCfgLayerIds(cfg as object) as object
    ids = []
    for each layer in cfg.layers
        ids.push(layer.id)
    end for
    return ids
end function

' Index of the layer with this id in the back-to-front stack, or -1.
function sceneCfgLayerIndex(cfg as object, id as string) as integer
    for i = 0 to cfg.layers.count() - 1
        if cfg.layers[i].id = id then return i
    end for
    return -1
end function

' Lanes back to front as { id, left, top, right, bottom, scale, tint } with tint parsed.
function sceneCfgLanes(cfg as object) as object
    lanes = []
    for each layer in cfg.layers
        if layer.lane <> invalid then
            r = layer.lane.rect
            lanes.push({
                id: layer.id
                left: r.left
                top: r.top
                right: r.right
                bottom: r.bottom
                scale: layer.lane.scale
                tint: sceneCfgParseColor(layer.lane.tint)
            })
        end if
    end for
    return lanes
end function

' Uniform camera scale that maps the design width onto the screen width.
function sceneCfgDesignScale(cfg as object, screenWidth as float) as float
    return screenWidth / cfg.design.width
end function

' ---- Camera drift (P1.2) ----
' scene.json "drift": { enabled, periodSeconds, amplitude: { x, y }, keyCount }. The camera
' follows a closed ellipse (x = ax*sin(2*pi*p), y = ay*cos(2*pi*p), p = 0..1 over the period)
' and each layer moves by parallax * camera offset. Every layer shares the same keys, so the
' layers stay in phase and the last key equals the first, which makes the loop seamless.

function sceneCfgDriftEnabled(cfg as object) as boolean
    d = cfg.drift
    if not sceneCfgIsObject(d) then return false
    return d.enabled <> false
end function

' Largest camera amplitude { x, y } that no layer's full-view decor can outrun: a decor that
' spans the design rect on an axis has margin left/right (top/bottom) of art, and a layer
' with parallax p shifts by p * amplitude, so amplitude <= margin / p. Axes with no spanning
' decor are unbounded (reported as 1.0e9).
function sceneCfgDriftMaxAmplitude(cfg as object) as object
    limit = { x: 1.0e9, y: 1.0e9 }
    if not sceneCfgIsArray(cfg.decor) then return limit
    parallax = {}
    for each layer in cfg.layers
        parallax[layer.id] = layer.parallax
    end for
    w = cfg.design.width
    h = cfg.design.height
    for each d in cfg.decor
        p = parallax[d.layer]
        if p <> invalid and p > 0 then
            if d.x <= 0 and d.x + d.width >= w then
                limit.x = sceneCfgMin(limit.x, sceneCfgMin(-d.x, d.x + d.width - w) / p)
            end if
            if d.y <= 0 and d.y + d.height >= h then
                limit.y = sceneCfgMin(limit.y, sceneCfgMin(-d.y, d.y + d.height - h) / p)
            end if
        end if
    end for
    return limit
end function

function sceneCfgMin(a as float, b as float) as float
    if a < b then return a
    return b
end function

' Appends problems with cfg.drift to errors. Skipped when drift is absent.
sub sceneCfgValidateDrift(cfg as object, errors as object)
    d = cfg.drift
    if d = invalid then return
    if not sceneCfgIsObject(d) then
        errors.push("drift must be an object")
        return
    end if
    if d.enabled <> invalid and LCase(type(d.enabled)) <> "boolean" and LCase(type(d.enabled)) <> "roboolean" then errors.push("drift enabled must be a boolean")
    if not sceneCfgIsNumber(d.periodSeconds) or d.periodSeconds <= 0 then errors.push("drift needs a positive periodSeconds")
    if d.keyCount <> invalid and (not sceneCfgIsNumber(d.keyCount) or d.keyCount < 8) then errors.push("drift keyCount must be at least 8")
    a = d.amplitude
    if not sceneCfgIsObject(a) or not sceneCfgIsNumber(a.x) or not sceneCfgIsNumber(a.y) or a.x < 0 or a.y < 0 then
        errors.push("drift needs amplitude {x, y} of non-negative numbers")
        return
    end if
    if not sceneCfgIsObject(cfg.design) or not sceneCfgIsNumber(cfg.design.width) or not sceneCfgIsNumber(cfg.design.height) then return
    if not sceneCfgIsArray(cfg.layers) then return
    max = sceneCfgDriftMaxAmplitude(cfg)
    if a.x > max.x + 0.0001 then errors.push("drift amplitude x " + a.x.toStr() + " would reveal a decor edge (max " + Str(max.x).trim() + ")")
    if a.y > max.y + 0.0001 then errors.push("drift amplitude y " + a.y.toStr() + " would reveal a decor edge (max " + Str(max.y).trim() + ")")
end sub

function sceneCfgDriftKeyCount(drift as object) as integer
    if sceneCfgIsNumber(drift.keyCount) then return Int(drift.keyCount)
    return 48
end function

' Keys 0..1 for a drift loop: keyCount + 1 evenly spaced keys, so the last value repeats the first.
function sceneCfgDriftKeys(drift as object) as object
    n = sceneCfgDriftKeyCount(drift)
    keys = []
    for i = 0 to n
        keys.push(i / n)
    end for
    return keys
end function

' Camera offset [x, y] at loop phase (0..1), scaled by a layer's parallax factor.
function sceneCfgDriftOffset(drift as object, phase as float, parallax as float) as object
    a = 2 * 3.14159265 * phase
    return [drift.amplitude.x * Sin(a) * parallax, drift.amplitude.y * Cos(a) * parallax]
end function

' One [x, y] value per key for a layer with this parallax; pairs with sceneCfgDriftKeys.
function sceneCfgDriftValues(drift as object, parallax as float) as object
    n = sceneCfgDriftKeyCount(drift)
    values = []
    for i = 0 to n - 1
        values.push(sceneCfgDriftOffset(drift, i / n, parallax))
    end for
    values.push(values[0])
    return values
end function

' ---------------------------------------------------------------------------
' Tank population (P2.7): scene.json "population" holds the FishBrain/School
' config URIs, the shared world (ellipses, caves, rocks, band) and, per density,
' the fish per lane plus the chromis school.

function sceneCfgDensityNames() as object
    return ["calm", "normal", "busy"]
end function

sub sceneCfgValidatePopulation(pop as dynamic, layerIds as object, laneIds as object, errors as object)
    if not sceneCfgIsObject(pop) then
        errors.push("population must be an object")
        return
    end if
    for each key in ["brainUri", "behaviorUri", "schoolUri"]
        if not sceneCfgIsString(pop[key]) or pop[key] = "" then errors.push("population needs a " + key)
    end for

    ellipses = []
    if not sceneCfgIsArray(pop.ellipses) or pop.ellipses.count() = 0 then
        errors.push("population.ellipses must be a non-empty array")
    else
        for i = 0 to pop.ellipses.count() - 1
            e = pop.ellipses[i]
            if not sceneCfgIsObject(e) or not sceneCfgIsNumber(e.cx) or not sceneCfgIsNumber(e.cy) or not sceneCfgIsNumber(e.rx) or not sceneCfgIsNumber(e.ry) or e.rx <= 0 or e.ry <= 0 then
                errors.push("population.ellipses[" + i.toStr() + "] needs numeric cx, cy and positive rx, ry")
            else
                ellipses.push(e)
            end if
        end for
    end if

    ' FishBrain gives cave fish caves[nth mod count], so an empty list would divide by zero.
    if not sceneCfgIsArray(pop.caves) or pop.caves.count() = 0 then
        errors.push("population.caves must be a non-empty array")
    else
        for i = 0 to pop.caves.count() - 1
            c = pop.caves[i]
            where = "population.caves[" + i.toStr() + "]"
            if not sceneCfgIsObject(c) or not sceneCfgIsPoint(c.mouth) or not sceneCfgIsPoint(c.den) then
                errors.push(where + " needs mouth and den [x, y]")
            else
                if not sceneCfgIsNumber(c.out) or (c.out <> 1 and c.out <> -1) then errors.push(where + " out must be 1 or -1")
                if not sceneCfgOutsideAll(ellipses, c.mouth) then errors.push(where + " mouth is inside an ellipse")
                if not sceneCfgOutsideAll(ellipses, c.den) then errors.push(where + " den is inside an ellipse")
            end if
        end for
    end if

    if not sceneCfgIsArray(pop.rocks) or pop.rocks.count() = 0 then
        errors.push("population.rocks must be a non-empty array")
    else
        for i = 0 to pop.rocks.count() - 1
            r = pop.rocks[i]
            if not sceneCfgIsPoint(r) then
                errors.push("population.rocks[" + i.toStr() + "] must be [x, y]")
            else if not sceneCfgOutsideAll(ellipses, r) then
                errors.push("population.rocks[" + i.toStr() + "] is inside an ellipse")
            end if
        end for
    end if

    b = pop.band
    if not sceneCfgIsObject(b) or not sceneCfgIsNumber(b.left) or not sceneCfgIsNumber(b.top) or not sceneCfgIsNumber(b.right) or not sceneCfgIsNumber(b.bottom) then
        errors.push("population.band needs a numeric rect {left, top, right, bottom}")
    else if b.right <= b.left or b.bottom <= b.top then
        errors.push("population.band is empty")
    else
        for each p in [[b.left, b.top], [b.right, b.top], [b.left, b.bottom], [b.right, b.bottom]]
            if not sceneCfgOutsideAll(ellipses, p) then errors.push("population.band corner [" + Str(p[0]).trim() + ", " + Str(p[1]).trim() + "] is inside an ellipse")
        end for
    end if

    sceneCfgValidateOccluders(pop.occluders, layerIds, laneIds, errors)
    sceneCfgValidateWeave(pop.weave, errors)

    if not sceneCfgIsObject(pop.densities) then
        errors.push("population.densities must be an object")
        return
    end if
    for each name in sceneCfgDensityNames()
        if not pop.densities.doesExist(name) then errors.push("population.densities needs " + name)
    end for
    for each name in pop.densities
        sceneCfgValidateDensity("density " + name, pop.densities[name], laneIds, errors)
        d = pop.densities[name]
        if sceneCfgIsObject(d) and d.nightSchool <> invalid then
            if not sceneCfgIsString(pop.nightSchoolUri) or pop.nightSchoolUri = "" then errors.push("density " + name + " has a nightSchool but population has no nightSchoolUri")
        end if
    end for
end sub

sub sceneCfgValidateDensity(where as string, d as dynamic, laneIds as object, errors as object)
    if not sceneCfgIsObject(d) or not sceneCfgIsObject(d.lanes) then
        errors.push(where + " needs a lanes object")
        return
    end if
    for each laneId in d.lanes
        if not laneIds.doesExist(laneId) then errors.push(where + " names " + laneId + ", which is not a lane")
        groups = d.lanes[laneId]
        if not sceneCfgIsArray(groups) then
            errors.push(where + " " + laneId + " must be an array")
        else
            for each g in groups
                if not sceneCfgIsObject(g) or not sceneCfgIsString(g.species) or g.species = "" then
                    errors.push(where + " " + laneId + " entry needs a species")
                else if not sceneCfgIsNumber(g.count) or g.count < 0 or g.count <> Int(g.count) then
                    errors.push(where + " " + laneId + " " + g.species + " count must be a whole number >= 0")
                end if
            end for
        end if
    end for
    for each entry in [{ key: "school", s: d.school }, { key: "nightSchool", s: d.nightSchool }]
        key = entry.key
        s = entry.s
        if s <> invalid then
            if not sceneCfgIsObject(s) or not sceneCfgIsString(s.lane) or not laneIds.doesExist(s.lane) then
                errors.push(where + " " + key + " needs a lane id")
            else if not sceneCfgIsNumber(s.count) or s.count < 0 or s.count <> Int(s.count) then
                errors.push(where + " " + key + " count must be a whole number >= 0")
            end if
        end if
    end for
end sub

function sceneCfgIsPoint(p as dynamic) as boolean
    return sceneCfgIsArray(p) and p.count() = 2 and sceneCfgIsNumber(p[0]) and sceneCfgIsNumber(p[1])
end function

' True when p is on or outside every ellipse (the FishBrain steering guard).
function sceneCfgOutsideAll(ellipses as object, p as object) as boolean
    for each e in ellipses
        dx = (p[0] - e.cx) / e.rx
        dy = (p[1] - e.cy) / e.ry
        if dx * dx + dy * dy < 1 then return false
    end for
    return true
end function

' The density to build: name when the config defines it, otherwise "normal".
function sceneCfgDensityName(cfg as object, name as string) as string
    if cfg.population.densities.doesExist(name) then return name
    return "normal"
end function

' What ReefTank builds for a density: { lanes: [{ lane, groups }], school }. lanes
' run back to front and skip lanes with no fish; lane is a sceneCfgLanes entry and
' groups the [{ species, count }] list. school is { lane, count } or invalid, and so
' is nightSchool (the night-only flashlight fish group, built from nightSchoolUri).
function sceneCfgDensityPlan(cfg as object, name as string) as object
    d = cfg.population.densities[sceneCfgDensityName(cfg, name)]
    plan = { lanes: [], school: invalid, nightSchool: invalid }
    for each lane in sceneCfgLanes(cfg)
        groups = d.lanes[lane.id]
        if groups <> invalid then
            n = 0
            for each g in groups
                n = n + g.count
            end for
            if n > 0 then plan.lanes.push({ lane: lane, groups: groups })
        end if
        if d.school <> invalid and d.school.count > 0 and d.school.lane = lane.id then plan.school = { lane: lane, count: d.school.count }
        if d.nightSchool <> invalid and d.nightSchool.count > 0 and d.nightSchool.lane = lane.id then plan.nightSchool = { lane: lane, count: d.nightSchool.count }
    end for
    return plan
end function

' Totals for a density: { fish, school, species: { name: count } } (fish excludes the school).
function sceneCfgDensityCounts(cfg as object, name as string) as object
    plan = sceneCfgDensityPlan(cfg, name)
    out = { fish: 0, school: 0, species: {} }
    for each entry in plan.lanes
        for each g in entry.groups
            out.fish = out.fish + g.count
            n = 0
            if out.species.doesExist(g.species) then n = out.species[g.species]
            out.species[g.species] = n + g.count
        end for
    end for
    if plan.school <> invalid then out.school = plan.school.count
    return out
end function

' Lane rect as the { left, top, right, bottom } FishBrain and School expect.
function sceneCfgLaneRect(lane as object) as object
    return { left: lane.left, top: lane.top, right: lane.right, bottom: lane.bottom }
end function

' ---------------------------------------------------------------------------
' Occlusion and weaving data (P1.8, P2.4). population.occluders maps a decor
' layer id to rects ({ left, top, right, bottom }, layer coordinates) where that
' layer's art is solid enough to hide a fish. population.weave sets which species
' change lanes and how (see components/lib/weave.brs).

function sceneCfgIsRect(r as dynamic) as boolean
    if not sceneCfgIsObject(r) then return false
    if not sceneCfgIsNumber(r.left) or not sceneCfgIsNumber(r.top) or not sceneCfgIsNumber(r.right) or not sceneCfgIsNumber(r.bottom) then return false
    return r.right > r.left and r.bottom > r.top
end function

sub sceneCfgValidateOccluders(occ as dynamic, layerIds as object, laneIds as object, errors as object)
    if occ = invalid then return
    if not sceneCfgIsObject(occ) then
        errors.push("population.occluders must be an object keyed by layer id")
        return
    end if
    for each id in occ
        if not layerIds.doesExist(id) or laneIds.doesExist(id) then errors.push("population.occluders names " + id + ", which is not a decor layer")
        rects = occ[id]
        if not sceneCfgIsArray(rects) then
            errors.push("population.occluders." + id + " must be an array")
        else
            for i = 0 to rects.count() - 1
                if not sceneCfgIsRect(rects[i]) then errors.push("population.occluders." + id + "[" + i.toStr() + "] needs a non-empty rect {left, top, right, bottom}")
            end for
        end if
    end for
end sub

sub sceneCfgValidateWeave(w as dynamic, errors as object)
    if w = invalid then return
    if not sceneCfgIsObject(w) then
        errors.push("population.weave must be an object")
        return
    end if
    if not sceneCfgIsArray(w.species) then errors.push("population.weave.species must be an array of species names")
    if not sceneCfgIsNumber(w.chance) or w.chance < 0 or w.chance > 1 then errors.push("population.weave.chance must be 0..1")
    for each key in ["seekSec", "seekSpeed", "holdSec", "cooldownSec"]
        if not sceneCfgIsNumber(w[key]) or w[key] <= 0 then errors.push("population.weave." + key + " must be positive")
    end for
    if not sceneCfgIsNumber(w.slack) or w.slack < 0 then errors.push("population.weave.slack must be >= 0")
end sub

' What one lane's FishBrain needs for weaving, or invalid when population.weave is
' absent: { home, lanes: [{ id, rect, scale, tint }] back to front, gaps, species
' (name -> true), chance, seekSec, seekSpeed, holdSec, cooldownSec }. gaps[i] lists
' the hide rects for a switch between lanes i and i + 1: the occluders of every decor
' layer in front of lane i + 1, because only those hide the fish in both lanes (a
' rect of the layer between the lanes stops hiding it the moment it joins the
' nearer lane). Each rect is shrunk by the camera drift between its layer and either
' lane (amplitude x |parallax difference|) plus weave.slack, so the fish stays
' hidden at every drift phase and across the reparent.
function sceneCfgWeavePlan(cfg as object, laneId as string) as dynamic
    pop = cfg.population
    if pop = invalid or not sceneCfgIsObject(pop.weave) then return invalid
    w = pop.weave
    lanes = sceneCfgLanes(cfg)
    plan = { home: -1, lanes: [], gaps: [], species: {}, chance: w.chance, seekSec: w.seekSec, seekSpeed: w.seekSpeed, holdSec: w.holdSec, cooldownSec: w.cooldownSec }
    for i = 0 to lanes.count() - 1
        ln = lanes[i]
        if ln.id = laneId then plan.home = i
        plan.lanes.push({ id: ln.id, rect: sceneCfgLaneRect(ln), scale: ln.scale, tint: ln.tint })
    end for
    for each name in w.species
        plan.species[name] = true
    end for
    ax = 0.0
    ay = 0.0
    if sceneCfgDriftEnabled(cfg) then
        ax = cfg.drift.amplitude.x
        ay = cfg.drift.amplitude.y
    end if
    occ = pop.occluders
    for i = 0 to lanes.count() - 2
        gap = []
        pa = sceneCfgLayerParallax(cfg, lanes[i].id)
        pb = sceneCfgLayerParallax(cfg, lanes[i + 1].id)
        front = sceneCfgLayerIndex(cfg, lanes[i + 1].id)
        if sceneCfgIsObject(occ) then
            ' Layer order, not key order, so the list is the same on every platform.
            for k = front + 1 to cfg.layers.count() - 1
                layer = cfg.layers[k]
                rects = occ[layer.id]
                if rects <> invalid then
                    dp = Abs(layer.parallax - pa)
                    if Abs(layer.parallax - pb) > dp then dp = Abs(layer.parallax - pb)
                    mx = ax * dp + w.slack
                    my = ay * dp + w.slack
                    for each r in rects
                        gap.push({ left: r.left + mx, top: r.top + my, right: r.right - mx, bottom: r.bottom - my, layer: layer.id })
                    end for
                end if
            end for
        end if
        plan.gaps.push(gap)
    end for
    return plan
end function

function sceneCfgLayerParallax(cfg as object, id as string) as float
    i = sceneCfgLayerIndex(cfg, id)
    if i < 0 then return 0.0
    return cfg.layers[i].parallax
end function
