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
