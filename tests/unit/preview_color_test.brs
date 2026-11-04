' Unit tests for source/preview_color.brs (the ?freeze shim's colour interpolation).
' Expected values are the preview's patched brs-scenegraph 0.6.2
' ColorFieldInterpolator.interpolateColor (hue lerped with no wrap, the device rule F5),
' run in bun on the method source extracted from the served /brs/brs-sg.js (2026-11-04).

function previewColorTestSuite() as object
    return {
        name: "previewColor"
        tests: [
            { name: "matchesDeviceSamples", fn: previewColorTest_matchesDeviceSamples }
            { name: "matchesPatchedBrsSceneGraph", fn: previewColorTest_matchesPatchedBrsSceneGraph }
            { name: "notRgbLerp", fn: previewColorTest_notRgbLerp }
        ]
    }
end function

' Measured on the Primary 4850X (OS 15.3.4), docs/fidelity cell 7: 0xFEFF01 / 0x00FF01 /
' 0x00FEFF at fractions 0.251 / 0.501 / 0.752 of red -> blue. At the exact fractions the
' rule gives pure yellow, green and cyan (every channel within 1 of the device).
sub previewColorTest_matchesDeviceSamples(t as object)
    assertEqual(t, previewColorHex_(previewLerpColorHsv(&hFF0000FF, &h0000FFFF, 0.25)), "0xFFFF00FF", "red -> blue at 0.25 is yellow")
    assertEqual(t, previewColorHex_(previewLerpColorHsv(&hFF0000FF, &h0000FFFF, 0.5)), "0x00FF00FF", "red -> blue at 0.5 is green")
    assertEqual(t, previewColorHex_(previewLerpColorHsv(&hFF0000FF, &h0000FFFF, 0.75)), "0x00FFFFFF", "red -> blue at 0.75 is cyan")
end sub

sub previewColorTest_matchesPatchedBrsSceneGraph(t as object)
    ' [from, to, fraction, patched brs-sg result]
    cases = [
        [&hFF0000FF, &h0000FFFF, 0, &hFF0000FF]
        [&hFF0000FF, &h0000FFFF, 0.125, &hFF8000FF]
        [&hFF0000FF, &h0000FFFF, 0.375, &h80FF00FF]
        [&hFF0000FF, &h0000FFFF, 1, &h0000FFFF]
        [&h0000FFFF, &hFF0000FF, 0.25, &h00FFFFFF]
        [&h0000FFFF, &hFF0000FF, 0.5, &h00FF00FF]
        [&h00FF00FF, &h0000FFFF, 0.25, &h00FF80FF]
        [&h00FF00FF, &h0000FFFF, 0.5, &h00FFFFFF]
        [&h808080FF, &h00FF00FF, 0.5, &hC0C060FF]
        [&hFF000000, &h0000FF80, 0.3, &hCCFF0026]
        [&h123456FF, &hFEDCBA40, 0.7, &hA9CC7579]
        ' Assumption (unmeasured): magenta (300) -> yellow (60) goes down through cyan (180)
        ' rather than wrapping through red.
        [&hFF00FFFF, &hFFFF00FF, 0.25, &h0000FFFF]
        [&hFF00FFFF, &hFFFF00FF, 0.5, &h00FFFFFF]
        [&hFF00FFFF, &hFFFF00FF, 0.75, &h00FF00FF]
    ]
    for each c in cases
        got = previewLerpColorHsv(c[0], c[1], c[2])
        assertEqual(t, previewColorHex_(got), previewColorHex_(c[3]), previewColorHex_(c[0]) + " -> " + previewColorHex_(c[1]) + " at " + c[2].toStr())
    end for
end sub

' The RGB lerp the shim used before gives 0x800080FF here; HSV keeps full saturation.
sub previewColorTest_notRgbLerp(t as object)
    assertTrue(t, previewLerpColorHsv(&hFF0000FF, &h0000FFFF, 0.5) <> &h800080FF)
end sub

function previewColorHex_(c as integer) as string
    digits = "0123456789ABCDEF"
    s = "0x"
    for shift = 24 to 0 step -8
        v = (c >> shift) and 255
        s = s + mid(digits, (v >> 4) + 1, 1) + mid(digits, (v and 15) + 1, 1)
    end for
    return s
end function
