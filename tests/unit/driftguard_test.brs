function driftguardTestSuite() as object
    return { name: "driftguard", tests: [
        { name: "safeStates", fn: driftguardTest_safe }
        { name: "motionAndWrap", fn: driftguardTest_motion }
        { name: "recoveryThreshold", fn: driftguardTest_recovery }
    ] }
end function
sub driftguardTest_safe(t as object)
    assertEqual(t, driftGuardStep(0.5, 0.5, 9, false, "stopped").restart, false, "off stays off")
    assertEqual(t, driftGuardStep(0.5, 0.5, 9, true, "paused").restart, false, "pause respected")
    assertEqual(t, driftGuardStep(invalid, 0.5, 0, true, "running").restart, false, "first sample")
end sub
sub driftguardTest_motion(t as object)
    assertEqual(t, driftGuardStep(0.25, 0.2501, 2, true, "running").unchanged, 0, "slow movement")
    assertEqual(t, driftGuardStep(0.99, 0.01, 2, true, "running").restart, false, "loop wrap")
    assertEqual(t, driftGuardStep(0.24, 0.26, 2, true, "running").restart, false, "turnaround")
end sub
sub driftguardTest_recovery(t as object)
    assertEqual(t, driftGuardStep(0.5, 0.5, 0, true, "running").restart, false, "one sample")
    assertEqual(t, driftGuardStep(0.5, 0.5, 1, true, "running").restart, false, "two samples")
    assertEqual(t, driftGuardStep(0.5, 0.5, 2, true, "running").restart, true, "three samples recover")
    assertEqual(t, driftGuardStep(0.5, 0.5, 0, true, "stopped").restart, true, "stopped recovers")
end sub
