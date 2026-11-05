' Unit-test runner for brs-cli. `make test` runs:
'   brs-cli tests/run_tests.brs tests/lib/*.brs tests/unit/*.brs components/lib/*.brs source/preview_color.brs
' brs-cli has no exit API: an uncaught `throw` ends the run with
' EXIT_BRIGHTSCRIPT_CRASH and process exit code 1, so the runner throws after
' the summary when any test failed (or when no tests ran).
'
' To add a suite: create tests/unit/<name>_test.brs with a
' <name>TestSuite() function returning { name, tests: [{ name, fn }] } and
' list it in testSuites() below. BrightScript has no reflection, so the
' registry is explicit.

function testSuites() as object
    return [
        prngTestSuite()
        steerTestSuite()
        solarTestSuite()
        daynightTestSuite()
        brainTestSuite()
        scenecfgTestSuite()
        previewColorTestSuite()
        schoolTestSuite()
        behaviorTestSuite()
        settingsTestSuite()
        bubblesTestSuite()
        nightTestSuite()
        weaveTestSuite()
        extrasTestSuite()
        pitchTestSuite()
        glowTestSuite()
        archTestSuite()
    ]
end function

sub Main()
    total = 0
    failed = 0
    for each suite in testSuites()
        for each test in suite.tests
            total = total + 1
            t = { name: suite.name + "." + test.name, failures: 0 }
            fn = test.fn
            try
                fn(t)
            catch e
                t.failures = t.failures + 1
                print "FAIL " + t.name + ": crashed: " + e.message + runnerCrashLocation(e)
            end try
            if t.failures = 0 then
                print "PASS " + t.name
            else
                failed = failed + 1
            end if
        end for
    end for

    print "----"
    print (total - failed).toStr() + " passed, " + failed.toStr() + " failed, " + total.toStr() + " total"
    if total = 0 then throw "no tests ran"
    if failed > 0 then throw failed.toStr() + " test(s) failed"
end sub

function runnerCrashLocation(e as object) as string
    bt = e.backtrace
    if bt = invalid or bt.count() = 0 then return ""
    frame = bt[bt.count() - 1]
    return " (" + frame.filename + ":" + frame.line_number.toStr() + ")"
end function
