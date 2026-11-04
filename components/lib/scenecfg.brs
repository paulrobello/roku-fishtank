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
                if layer.lane <> invalid then sceneCfgValidateLane(layer.id, layer.lane, errors)
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
