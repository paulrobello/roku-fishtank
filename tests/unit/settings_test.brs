' Unit tests for components/lib/settings.brs (P5.1).
' The registry tests use the real roRegistrySection("ReefTank") that brs-cli provides
' and restore the section's keys when done.

function settingsTestSuite() as object
    return {
        name: "settings"
        tests: [
            { name: "defaultsOnEmptyStore", fn: settingsTest_defaultsOnEmptyStore }
            { name: "roundTrip", fn: settingsTest_roundTrip }
            { name: "invalidStoredFallsBack", fn: settingsTest_invalidStoredFallsBack }
            { name: "partialStoreKeepsOtherDefaults", fn: settingsTest_partialStore }
            { name: "saveSanitisesInvalid", fn: settingsTest_saveSanitisesInvalid }
            { name: "stepWraps", fn: settingsTest_stepWraps }
            { name: "registryRoundTrip", fn: settingsTest_registryRoundTrip }
            { name: "applyPlanDefaults", fn: settingsTest_applyPlanDefaults }
            { name: "applyPlanMapsValues", fn: settingsTest_applyPlanMapsValues }
            { name: "applyPlanRejectsInvalid", fn: settingsTest_applyPlanRejectsInvalid }
            { name: "applyToScene", fn: settingsTest_applyToScene }
        ]
    }
end function

sub settingsTest_defaultsOnEmptyStore(t as object)
    v = settingsLoad(settingsMemoryStore())
    assertEqual(t, v.nightMode, "auto", "nightMode")
    assertEqual(t, v.density, "normal", "density")
    assertEqual(t, v.drift, "on", "drift")
end sub

sub settingsTest_roundTrip(t as object)
    store = settingsMemoryStore()
    settingsSave(store, { nightMode: "night", density: "busy", drift: "off" })
    v = settingsLoad(store)
    assertEqual(t, v.nightMode, "night", "nightMode")
    assertEqual(t, v.density, "busy", "density")
    assertEqual(t, v.drift, "off", "drift")
end sub

sub settingsTest_invalidStoredFallsBack(t as object)
    store = settingsMemoryStore()
    store.write("nightMode", "midnight")
    store.write("density", "BUSY")
    store.write("drift", "")
    v = settingsLoad(store)
    assertEqual(t, v.nightMode, "auto", "nightMode")
    assertEqual(t, v.density, "normal", "density")
    assertEqual(t, v.drift, "on", "drift")
end sub

sub settingsTest_partialStore(t as object)
    store = settingsMemoryStore()
    store.write("density", "calm")
    v = settingsLoad(store)
    assertEqual(t, v.density, "calm", "density")
    assertEqual(t, v.nightMode, "auto", "nightMode")
    assertEqual(t, v.drift, "on", "drift")
end sub

sub settingsTest_saveSanitisesInvalid(t as object)
    store = settingsMemoryStore()
    saved = settingsSave(store, { nightMode: "dusk", density: 5, drift: "off" })
    assertEqual(t, saved.nightMode, "auto", "saved nightMode")
    assertEqual(t, saved.density, "normal", "saved density")
    assertEqual(t, store.read("nightMode"), "auto", "stored nightMode")
    assertEqual(t, store.read("drift"), "off", "stored drift")
end sub

sub settingsTest_stepWraps(t as object)
    assertEqual(t, settingsStep("nightMode", "auto", 1), "day", "auto +1")
    assertEqual(t, settingsStep("nightMode", "night", 1), "auto", "night +1 wraps")
    assertEqual(t, settingsStep("density", "calm", -1), "busy", "calm -1 wraps")
    assertEqual(t, settingsStep("drift", "on", 1), "off", "on +1")
    assertEqual(t, settingsStep("drift", "off", 1), "on", "off +1 wraps")
    assertEqual(t, settingsStep("drift", "bogus", 1), "off", "invalid current counts as first")
end sub

sub settingsTest_applyPlanDefaults(t as object)
    plan = settingsApplyPlan(settingsLoad(settingsMemoryStore()))
    assertEqual(t, plan.density, "normal", "density")
    assertEqual(t, plan.drift, true, "drift")
    assertEqual(t, plan.nightMode, "auto", "nightMode")
end sub

sub settingsTest_applyPlanMapsValues(t as object)
    store = settingsMemoryStore()
    settingsSave(store, { nightMode: "night", density: "calm", drift: "off" })
    plan = settingsApplyPlan(settingsLoad(store))
    assertEqual(t, plan.density, "calm", "density")
    assertEqual(t, plan.drift, false, "drift")
    assertEqual(t, plan.nightMode, "night", "nightMode")
    assertEqual(t, settingsApplyPlan({ nightMode: "day", density: "busy", drift: "on" }).nightMode, "day", "day")
end sub

sub settingsTest_applyPlanRejectsInvalid(t as object)
    plan = settingsApplyPlan({ nightMode: "dusk", density: 5, drift: "maybe" })
    assertEqual(t, plan.density, "normal", "density")
    assertEqual(t, plan.drift, true, "drift")
    assertEqual(t, plan.nightMode, "auto", "nightMode")
    empty = settingsApplyPlan(invalid)
    assertEqual(t, empty.density, "normal", "invalid input density")
end sub

sub settingsTest_applyToScene(t as object)
    ' A stand-in for the ReefTank node: with and without the nightMode field.
    scene = { density: "normal", drift: true, hasField: function(name as string) as boolean
            return m[name] <> invalid
        end function }
    store = settingsMemoryStore()
    settingsSave(store, { nightMode: "night", density: "calm", drift: "off" })
    settingsApplyToScene(scene, store)
    assertEqual(t, scene.density, "calm", "density applied")
    assertEqual(t, scene.drift, false, "drift applied")
    assertEqual(t, scene.nightMode, invalid, "no nightMode field, none written")

    scene.nightMode = "auto"
    settingsApplyToScene(scene, store)
    assertEqual(t, scene.nightMode, "night", "nightMode applied when the field exists")
end sub

sub settingsTest_registryRoundTrip(t as object)
    section = settingsRegistryStore()
    saved = settingsLoad(section)
    ' Start from an empty section so the defaults check is meaningful.
    for each key in settingsKeys()
        section.delete(key)
    end for
    section.flush()
    assertEqual(t, settingsLoad(settingsRegistryStore()).density, "normal", "empty registry density")

    settingsSave(settingsRegistryStore(), { nightMode: "day", density: "calm", drift: "off" })
    v = settingsLoad(settingsRegistryStore())
    assertEqual(t, v.nightMode, "day", "nightMode")
    assertEqual(t, v.density, "calm", "density")
    assertEqual(t, v.drift, "off", "drift")

    for each key in settingsKeys()
        section.delete(key)
    end for
    section.flush()
    settingsSave(settingsRegistryStore(), saved)
end sub
