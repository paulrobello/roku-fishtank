function launchdiagTestSuite() as object
    return { name: "launchdiag", tests: [{ name: "osVersion", fn: launchdiagTest_osVersion }, { name: "readiness", fn: launchdiagTest_readiness }, { name: "reportValidation", fn: launchdiagTest_report }] }
end function

sub launchdiagTest_readiness(t as object)
    assertEqual(t, launchGate([], 100, true), "asset-error", "empty required assets cannot pass")
    assertEqual(t, launchGate(["ready"], 100, false), "pending", "screen must be shown")
    assertEqual(t, launchGate(["ready", "loading"], 100, true), "pending", "all initial assets required")
    assertEqual(t, launchGate(["none"], 100, true), "pending", "unrequested image not ready")
    assertEqual(t, launchGate(["ready", "failed"], 100, true), "asset-error", "no success on asset failure")
    assertEqual(t, launchGate(["loading", "failed"], 100, true), "asset-error", "failure not hidden by pending asset")
    assertEqual(t, launchGate(["ready", "ready"], 100, true), "ready", "all assets loaded")
    assertEqual(t, launchGate(["loading"], 60000, true), "timeout", "bounded diagnostics")
end sub

sub launchdiagTest_report(t as object)
    assertEqual(t, launchReportValid(invalid), false, "missing report")
    assertEqual(t, launchReportValid("bad"), false, "malformed report")
    report = { model: "3810X", os: "16.0.4", build: "0.2.0002 / diag1", elapsedMs: 1234, status: "render-ready" }
    assertEqual(t, launchReportValid(report), true, "completed report")
    report.elapsedMs = "1234"
    assertEqual(t, launchReportValid(report), false, "reject numeric string")
    report.elapsedMs = -1
    assertEqual(t, launchReportValid(report), false, "reject negative time")
    report.elapsedMs = 1200
    report.status = "certified"
    assertEqual(t, launchReportValid(report), false, "reject false certification status")
    report.status = "render-ready"
    report.delete("model")
    assertEqual(t, launchReportValid(report), false, "require model")
end sub

sub launchdiagTest_osVersion(t as object)
    version = { major: "16", minor: "0", revision: "4", build: "853" }
    assertEqual(t, launchOsVersionText(version), "16.0.4 / 853", "documented fields")
    assertEqual(t, launchOsVersionText(invalid), "", "legacy missing structured value")
    assertEqual(t, launchOsVersionText("416.04E00853A"), "", "never parse legacy string")
    assertEqual(t, launchOsVersionText({ major: "16", minor: "0", build: "853" }), "", "missing revision not invented")
    for each bad in [invalid, "", "1x", "-1", "1.5", " 16", "16 ", "1" + chr(10), "12345678901", 16, true, {}]
        version.major = bad
        assertEqual(t, launchOsVersionText(version), "", "invalid field unavailable")
    end for
    version.major = "16"
    version.revision = "0"
    version.build = "000853"
    assertEqual(t, launchOsVersionText(version), "16.0.0 / 000853", "zero revision and string build retained")
end sub
