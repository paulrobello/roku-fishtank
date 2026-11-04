' Unit tests for components/lib/scenecfg.brs.

function scenecfgTestSuite() as object
    return {
        name: "scenecfg"
        tests: [
            { name: "parseColorHex", fn: scenecfgTest_parseColorHex }
            { name: "parseColorHighBit", fn: scenecfgTest_parseColorHighBit }
            { name: "parseColorFallback", fn: scenecfgTest_parseColorFallback }
            { name: "validConfigHasNoErrors", fn: scenecfgTest_validConfigHasNoErrors }
            { name: "reportsBadConfig", fn: scenecfgTest_reportsBadConfig }
            { name: "notAnObject", fn: scenecfgTest_notAnObject }
            { name: "layerQueries", fn: scenecfgTest_layerQueries }
            { name: "lanesBackToFront", fn: scenecfgTest_lanesBackToFront }
            { name: "designScale", fn: scenecfgTest_designScale }
            { name: "driftMaxAmplitude", fn: scenecfgTest_driftMaxAmplitude }
            { name: "driftValidates", fn: scenecfgTest_driftValidates }
            { name: "driftRejectsEdgeReveal", fn: scenecfgTest_driftRejectsEdgeReveal }
            { name: "driftRejectsBadFields", fn: scenecfgTest_driftRejectsBadFields }
            { name: "driftLoopIsClosedAndInPhase", fn: scenecfgTest_driftLoopIsClosedAndInPhase }
            { name: "populationValid", fn: scenecfgTest_populationValid }
            { name: "populationReportsProblems", fn: scenecfgTest_populationReportsProblems }
            { name: "populationNeedsDensitiesAndCaves", fn: scenecfgTest_populationNeedsDensitiesAndCaves }
            { name: "densityPlanBackToFront", fn: scenecfgTest_densityPlanBackToFront }
            { name: "densityFallsBackToNormal", fn: scenecfgTest_densityFallsBackToNormal }
        ]
    }
end function

function scenecfgTest_sample() as object
    text = "{""design"": {""width"": 1920, ""height"": 1080}, ""layers"": ["
    text = text + "{""id"": ""water"", ""parallax"": 0.2},"
    text = text + "{""id"": ""backLane"", ""parallax"": 0.5, ""lane"": {""rect"": {""left"": 10, ""top"": 20, ""right"": 110, ""bottom"": 220}, ""scale"": 0.6, ""tint"": ""0x9FB8D2FF""}},"
    text = text + "{""id"": ""coral"", ""parallax"": 0.6},"
    text = text + "{""id"": ""frontLane"", ""parallax"": 0.9, ""lane"": {""rect"": {""left"": 0, ""top"": 0, ""right"": 1920, ""bottom"": 1080}, ""scale"": 1, ""tint"": ""#FFFFFFFF""}}"
    text = text + "], ""decor"": [{""id"": ""rock"", ""layer"": ""coral"", ""uri"": ""pkg:/images/x.png"", ""x"": -5, ""y"": 0, ""width"": 10, ""height"": 20}]}"
    return ParseJson(text)
end function

sub scenecfgTest_parseColorHex(t as object)
    assertEqual(t, sceneCfgParseColor("0x062B45FF"), &h062B45FF)
    assertEqual(t, sceneCfgParseColor("#0a0b0c0d"), &h0A0B0C0D, "lower-case with #")
    assertEqual(t, sceneCfgParseColor(&h11223344), &h11223344, "integer passes through")
end sub

sub scenecfgTest_parseColorHighBit(t as object)
    assertEqual(t, sceneCfgParseColor("0xFFAA80FF"), &hFFAA80FF)
    assertEqual(t, sceneCfgParseColor("0xFFFFFFFF"), -1, "opaque white is -1 as int32")
    assertTrue(t, sceneCfgParseColor("0x80000000") < 0, "high bit set is negative")
end sub

sub scenecfgTest_parseColorFallback(t as object)
    assertEqual(t, sceneCfgParseColor("0x123"), &hFFFFFFFF, "too short")
    assertEqual(t, sceneCfgParseColor("0xGG0000FF", 7), 7, "bad digit")
    assertEqual(t, sceneCfgParseColor(invalid, 5), 5, "invalid")
    assertTrue(t, not sceneCfgIsColor("red"))
    assertTrue(t, sceneCfgIsColor("0x00000000"), "transparent black is a color")
end sub

sub scenecfgTest_validConfigHasNoErrors(t as object)
    errors = sceneCfgValidate(scenecfgTest_sample())
    assertEqual(t, errors.count(), 0, errors.join("; "))
end sub

sub scenecfgTest_reportsBadConfig(t as object)
    cfg = scenecfgTest_sample()
    cfg.layers[2].id = "water"
    cfg.layers[1].lane.rect.right = 5
    cfg.layers[3].lane.tint = "white"
    cfg.decor[0].layer = "nowhere"
    cfg.decor[0].width = 0
    errors = sceneCfgValidate(cfg)
    text = errors.join("|")
    assertTrue(t, Instr(1, text, "duplicates id water") > 0, text)
    assertTrue(t, Instr(1, text, "backLane lane rect is empty") > 0, text)
    assertTrue(t, Instr(1, text, "frontLane lane tint") > 0, text)
    assertTrue(t, Instr(1, text, "rock names an unknown layer") > 0, text)
    assertTrue(t, Instr(1, text, "rock needs a positive width") > 0, text)
    assertEqual(t, errors.count(), 5, text)
end sub

sub scenecfgTest_notAnObject(t as object)
    assertEqual(t, sceneCfgValidate(invalid).count(), 1)
    assertEqual(t, sceneCfgValidate(ParseJson("{""design"": {""width"": 1920, ""height"": 1080}, ""layers"": []}")).count(), 1, "empty layers")
end sub

sub scenecfgTest_layerQueries(t as object)
    cfg = scenecfgTest_sample()
    assertEqual(t, sceneCfgLayerIds(cfg).join(","), "water,backLane,coral,frontLane")
    assertEqual(t, sceneCfgLayerIndex(cfg, "coral"), 2)
    assertEqual(t, sceneCfgLayerIndex(cfg, "missing"), -1)
end sub

sub scenecfgTest_lanesBackToFront(t as object)
    lanes = sceneCfgLanes(scenecfgTest_sample())
    assertEqual(t, lanes.count(), 2)
    assertEqual(t, lanes[0].id, "backLane")
    assertEqual(t, lanes[0].right, 110)
    assertNear(t, lanes[0].scale, 0.6, 0.0001)
    assertEqual(t, lanes[0].tint, &h9FB8D2FF)
    assertEqual(t, lanes[1].id, "frontLane")
    assertEqual(t, lanes[1].tint, -1)
end sub

sub scenecfgTest_designScale(t as object)
    cfg = scenecfgTest_sample()
    assertNear(t, sceneCfgDesignScale(cfg, 1920), 1.0, 0.0001)
    assertNear(t, sceneCfgDesignScale(cfg, 1280), 0.6667, 0.0001, "hd")
end sub

function scenecfgTest_driftSample() as object
    cfg = scenecfgTest_sample()
    cfg.decor.push({ id: "bd", layer: "water", uri: "pkg:/images/b.png", x: -300, y: 0, width: 2520, height: 1080 })
    cfg.decor.push({ id: "fg", layer: "coral", uri: "pkg:/images/f.png", x: -30, y: -6, width: 1980, height: 1100 })
    cfg.drift = { enabled: true, periodSeconds: 90, amplitude: { x: 40, y: 0 }, keyCount: 16 }
    return cfg
end function

sub scenecfgTest_driftMaxAmplitude(t as object)
    max = sceneCfgDriftMaxAmplitude(scenecfgTest_driftSample())
    assertNear(t, max.x, 50.0, 0.001, "coral 30 px margin / parallax 0.6 beats water 300 / 0.2")
    assertNear(t, max.y, 0.0, 0.001, "backdrop has no vertical margin")
    assertTrue(t, sceneCfgDriftMaxAmplitude(scenecfgTest_sample()).x > 1.0e8, "no spanning decor means unbounded")
end sub

sub scenecfgTest_driftValidates(t as object)
    cfg = scenecfgTest_driftSample()
    assertEqual(t, sceneCfgValidate(cfg).count(), 0, sceneCfgValidate(cfg).join("; "))
    cfg.drift.amplitude.x = 50
    assertEqual(t, sceneCfgValidate(cfg).count(), 0, "exactly at the limit is allowed")
    assertTrue(t, sceneCfgDriftEnabled(cfg))
    cfg.drift.enabled = false
    assertTrue(t, not sceneCfgDriftEnabled(cfg))
end sub

sub scenecfgTest_driftRejectsEdgeReveal(t as object)
    cfg = scenecfgTest_driftSample()
    cfg.drift.amplitude.x = 51
    errors = sceneCfgValidate(cfg)
    assertEqual(t, errors.count(), 1, errors.join("|"))
    assertTrue(t, Instr(1, errors[0], "amplitude x") > 0, errors[0])
    cfg.drift.amplitude.x = 10
    cfg.drift.amplitude.y = 1
    errors = sceneCfgValidate(cfg)
    assertEqual(t, errors.count(), 1, errors.join("|"))
    assertTrue(t, Instr(1, errors[0], "amplitude y") > 0, errors[0])
end sub

sub scenecfgTest_driftRejectsBadFields(t as object)
    cfg = scenecfgTest_driftSample()
    cfg.drift.periodSeconds = 0
    cfg.drift.keyCount = 3
    cfg.drift.enabled = "yes"
    assertEqual(t, sceneCfgValidate(cfg).count(), 3, sceneCfgValidate(cfg).join("|"))
    cfg.drift = { periodSeconds: 90 }
    assertEqual(t, sceneCfgValidate(cfg).count(), 1, "missing amplitude")
    cfg.drift = "slow"
    assertEqual(t, sceneCfgValidate(cfg).count(), 1, "not an object")
    cfg.drift = invalid
    assertEqual(t, sceneCfgValidate(cfg).count(), 0, "drift is optional")
end sub

sub scenecfgTest_driftLoopIsClosedAndInPhase(t as object)
    drift = scenecfgTest_driftSample().drift
    keys = sceneCfgDriftKeys(drift)
    values = sceneCfgDriftValues(drift, 0.5)
    assertEqual(t, keys.count(), 17)
    assertEqual(t, values.count(), 17)
    assertNear(t, keys[0], 0.0, 0.0001)
    assertNear(t, keys[16], 1.0, 0.0001)
    assertNear(t, values[0][0], values[16][0], 0.0001, "loop closes in x")
    assertNear(t, values[0][1], values[16][1], 0.0001, "loop closes in y")
    assertNear(t, values[4][0], 20.0, 0.001, "quarter phase is the extreme, parallax 0.5 x amplitude 40")
    assertNear(t, values[12][0], -20.0, 0.001, "three quarters is the opposite extreme")
    full = sceneCfgDriftValues(drift, 1.0)
    assertNear(t, full[4][0], 40.0, 0.001, "a layer at parallax 1 moves the full amplitude")

' scenecfgTest_sample() plus a population: one ellipse at (500, 500), a cave and a
' rock outside it, and three densities over backLane and frontLane.
function scenecfgTest_popSample() as object
    cfg = scenecfgTest_sample()
    text = "{""brainUri"": ""pkg:/config/brain.json"", ""behaviorUri"": ""pkg:/config/behavior.json"", ""schoolUri"": ""pkg:/config/school.json"","
    text = text + """ellipses"": [{""cx"": 500, ""cy"": 500, ""rx"": 100, ""ry"": 50}],"
    text = text + """caves"": [{""mouth"": [620, 500], ""den"": [700, 500], ""out"": -1}],"
    text = text + """rocks"": [[500, 440]],"
    text = text + """band"": {""left"": 0, ""top"": 900, ""right"": 1000, ""bottom"": 950},"
    text = text + """densities"": {"
    text = text + """calm"": {""lanes"": {""frontLane"": [{""species"": ""lionfish"", ""count"": 1}]}},"
    text = text + """normal"": {""lanes"": {""frontLane"": [{""species"": ""yellow_tang"", ""count"": 2}, {""species"": ""lionfish"", ""count"": 1}], ""backLane"": [{""species"": ""royal_gramma"", ""count"": 2}, {""species"": ""yellow_tang"", ""count"": 1}]}, ""school"": {""lane"": ""backLane"", ""count"": 10}},"
    text = text + """busy"": {""lanes"": {""backLane"": [{""species"": ""royal_gramma"", ""count"": 0}], ""frontLane"": [{""species"": ""yellow_tang"", ""count"": 30}]}, ""school"": {""lane"": ""frontLane"", ""count"": 14}}"
    text = text + "}}"
    cfg.population = ParseJson(text)
    return cfg
end function

sub scenecfgTest_populationValid(t as object)
    errors = sceneCfgValidate(scenecfgTest_popSample())
    assertEqual(t, errors.count(), 0, errors.join("; "))
end sub

sub scenecfgTest_populationReportsProblems(t as object)
    cfg = scenecfgTest_popSample()
    pop = cfg.population
    pop.caves[0].mouth = [560, 500]
    pop.caves[0].out = 0
    pop.rocks.push([510, 505])
    pop.rocks.push([1])
    pop.band.bottom = 800
    pop["schoolUri"] = ""
    pop.densities.normal.lanes.coral = [{ species: "lionfish", count: 1 }]
    pop.densities.normal.lanes.frontLane[0].count = 1.5
    pop.densities.calm.school = { lane: "water", count: 3 }
    errors = sceneCfgValidate(cfg)
    text = errors.join("|")
    assertTrue(t, Instr(1, text, "population needs a schoolUri") > 0, text)
    assertTrue(t, Instr(1, text, "caves[0] mouth is inside an ellipse") > 0, text)
    assertTrue(t, Instr(1, text, "caves[0] out must be 1 or -1") > 0, text)
    assertTrue(t, Instr(1, text, "rocks[1] is inside an ellipse") > 0, text)
    assertTrue(t, Instr(1, text, "rocks[2] must be [x, y]") > 0, text)
    assertTrue(t, Instr(1, text, "population.band is empty") > 0, text)
    assertTrue(t, Instr(1, text, "density normal names coral, which is not a lane") > 0, text)
    assertTrue(t, Instr(1, text, "yellow_tang count must be a whole number") > 0, text)
    assertTrue(t, Instr(1, text, "density calm school needs a lane id") > 0, text)
    assertEqual(t, errors.count(), 9, text)
end sub

sub scenecfgTest_populationNeedsDensitiesAndCaves(t as object)
    cfg = scenecfgTest_popSample()
    cfg.population.densities.delete("busy")
    cfg.population.caves = []
    cfg.population.ellipses[0].rx = 0
    text = sceneCfgValidate(cfg).join("|")
    assertTrue(t, Instr(1, text, "population.densities needs busy") > 0, text)
    assertTrue(t, Instr(1, text, "population.caves must be a non-empty array") > 0, text)
    assertTrue(t, Instr(1, text, "ellipses[0] needs numeric cx, cy and positive rx, ry") > 0, text)
end sub

sub scenecfgTest_densityPlanBackToFront(t as object)
    cfg = scenecfgTest_popSample()
    plan = sceneCfgDensityPlan(cfg, "normal")
    assertEqual(t, plan.lanes.count(), 2)
    assertEqual(t, plan.lanes[0].lane.id, "backLane", "back lane first")
    assertEqual(t, plan.lanes[0].groups[0].species, "royal_gramma")
    assertNear(t, plan.lanes[0].lane.scale, 0.6, 0.0001)
    assertEqual(t, plan.lanes[1].lane.id, "frontLane")
    assertEqual(t, plan.school.lane.id, "backLane")
    assertEqual(t, plan.school.count, 10)
    r = sceneCfgLaneRect(plan.lanes[0].lane)
    assertEqual(t, r.left, 10)
    assertEqual(t, r.top, 20)
    assertEqual(t, r.right, 110)
    assertEqual(t, r.bottom, 220)

    counts = sceneCfgDensityCounts(cfg, "normal")
    assertEqual(t, counts.fish, 6)
    assertEqual(t, counts.school, 10)
    assertEqual(t, counts.species.yellow_tang, 3, "summed across lanes")

    busy = sceneCfgDensityPlan(cfg, "busy")
    assertEqual(t, busy.lanes.count(), 1, "a lane whose groups total 0 fish is skipped")
    assertEqual(t, busy.lanes[0].lane.id, "frontLane")
    assertEqual(t, sceneCfgDensityPlan(cfg, "calm").school, invalid, "no school entry")
end sub

sub scenecfgTest_densityFallsBackToNormal(t as object)
    cfg = scenecfgTest_popSample()
    assertEqual(t, sceneCfgDensityName(cfg, "busy"), "busy")
    assertEqual(t, sceneCfgDensityName(cfg, "frantic"), "normal")
    assertEqual(t, sceneCfgDensityName(cfg, ""), "normal")
    assertEqual(t, sceneCfgDensityCounts(cfg, "frantic").fish, 6)
end sub
