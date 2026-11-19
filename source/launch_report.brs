' Local-only, coarse technical data. No serial, IP, account, locale or location.
sub launchRecord(status as string, elapsedMs as integer)
    print "LAUNCH app-entry-elapsed-ms="; elapsedMs; " status="; status; " (not total Roku launch time or first-frame proof)"
    if status <> "render-ready" then return
    try
        device = createObject("roDeviceInfo")
        app = createObject("roAppInfo")
        osVersion = invalid
        try
            rawOsVersion = device.getOSVersion()
            if launchOsVersionText(rawOsVersion) <> "" then
                osVersion = { major: rawOsVersion.major, minor: rawOsVersion.minor, revision: rawOsVersion.revision, build: rawOsVersion.build }
            end if
        catch osError
            print "LAUNCH OS version unavailable"
        end try
        report = { model: device.getModel(), os: launchOsVersionText(osVersion), osVersion: osVersion, build: app.getVersion() + " / diag3", elapsedMs: elapsedMs, status: status }
        store = createObject("roRegistrySection", "ReefTankDiagnostics")
        if not store.write("lastLaunch", formatJson(report)) then
            print "LAUNCH local report write failed"
            return
        end if
        if not store.flush() then
            print "LAUNCH local report flush failed"
            return
        end if
        if store.read("lastLaunch") = formatJson(report) then
            print "LAUNCH local report saved and read back"
        else
            print "LAUNCH local report readback mismatch"
        end if
    catch e
        print "LAUNCH local report unavailable"
    end try
end sub

' Strict documented GetOSVersion fields. Never reinterpret legacy GetVersion text.
' Empty means unavailable; UI translates that label. Missing revision is not zero.
function launchOsVersionText(version as dynamic) as string
    if type(version) <> "roAssociativeArray" and type(version) <> "AssociativeArray" then return ""
    nonDigits = createObject("roRegex", "[^0-9]", "")
    for each key in ["major", "minor", "revision", "build"]
        part = version[key]
        if type(part) <> "String" and type(part) <> "roString" then return ""
        if len(part) = 0 or len(part) > 10 then return ""
        if nonDigits.isMatch(part) then return ""
    end for
    return version.major + "." + version.minor + "." + version.revision + " / " + version.build
end function
