' Reef Tank settings storage (P5.1).
'
' Three string settings persisted in the "ReefTank" registry section:
'   nightMode  auto | day | night   (default auto)
'   density    calm | normal | busy (default normal)
'   drift      on | off             (default on)
' A missing or unrecognised stored value reads as the default.
'
' A store is any object with read(key) as string, write(key, value) and flush().
' roRegistrySection satisfies it on the device and under brs-cli; settingsMemoryStore()
' is an assocarray-backed store for tests.

function settingsDefaults() as object
    return { nightMode: "auto", density: "normal", drift: "on" }
end function

' Allowed values per key, in the order the settings screen cycles through them.
function settingsOptions() as object
    return {
        nightMode: ["auto", "day", "night"]
        density: ["calm", "normal", "busy"]
        drift: ["on", "off"]
    }
end function

function settingsKeys() as object
    return ["nightMode", "density", "drift"]
end function

' The device store: the ReefTank registry section.
function settingsRegistryStore() as object
    return createObject("roRegistrySection", "ReefTank")
end function

function settingsMemoryStore() as object
    return {
        data: {}
        read: function(key as string) as string
            v = m.data[key]
            if v = invalid then return ""
            return v
        end function
        write: function(key as string, value as string) as boolean
            m.data[key] = value
            return true
        end function
        flush: function() as boolean
            return true
        end function
    }
end function

' Returns { nightMode, density, drift } with defaults for anything missing or invalid.
function settingsLoad(store as object) as object
    values = settingsDefaults()
    opts = settingsOptions()
    for each key in settingsKeys()
        stored = store.read(key)
        if settingsIndexOf(opts[key], stored) >= 0 then values[key] = stored
    end for
    return values
end function

' Writes every valid entry of values (invalid or missing ones are stored as defaults)
' and flushes. Returns the values as stored.
function settingsSave(store as object, values as object) as object
    clean = settingsDefaults()
    opts = settingsOptions()
    for each key in settingsKeys()
        v = values[key]
        if v <> invalid and settingsIndexOf(opts[key], v) >= 0 then clean[key] = v
        store.write(key, clean[key])
    end for
    store.flush()
    return clean
end function

' Index of value in the allowed list for key, or -1 when it is not allowed.
function settingsIndexOf(list as object, value as dynamic) as integer
    if type(value) <> "String" and type(value) <> "roString" then return -1
    for i = 0 to list.count() - 1
        if list[i] = value then return i
    end for
    return -1
end function

' The value one step (+1 or -1) from the current one for key, wrapping around.
function settingsStep(key as string, current as string, dir as integer) as string
    list = settingsOptions()[key]
    n = list.count()
    i = settingsIndexOf(list, current)
    if i < 0 then i = 0
    return list[(i + dir + n) mod n]
end function

' Maps stored settings to the ReefTank interface fields (P5.3):
' { density: "calm"|"normal"|"busy", drift: boolean, nightMode: "auto"|"day"|"night" }.
' Anything missing or unrecognised maps to the default, so the plan is always complete.
function settingsApplyPlan(values as dynamic) as object
    defaults = settingsDefaults()
    opts = settingsOptions()
    clean = {}
    for each key in settingsKeys()
        v = invalid
        if type(values) = "roAssociativeArray" then v = values[key]
        if settingsIndexOf(opts[key], v) >= 0 then clean[key] = v else clean[key] = defaults[key]
    end for
    return { density: clean.density, drift: clean.drift = "on", nightMode: clean.nightMode }
end function

' Applies the stored settings to a ReefTank scene node (call before the fish are built).
' The nightMode field belongs to the night-mode work and is only written when it exists.
sub settingsApplyToScene(scene as object, store as object)
    plan = settingsApplyPlan(settingsLoad(store))
    scene.density = plan.density
    scene.drift = plan.drift
    if scene.hasField("nightMode") then scene.nightMode = plan.nightMode
    print "SETTINGS applied density="; plan.density; " drift="; plan.drift; " nightMode="; plan.nightMode
end sub
