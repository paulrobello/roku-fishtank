' Unit tests for source/preview_color.brs (the ?freeze shim's colour interpolation).
' Expected values are brs-scenegraph 0.6.2's own ColorFieldInterpolator.interpolateColor,
' run in bun on the method source extracted verbatim from
' node_modules/brs-scenegraph/lib/brs-sg.node.js (2026-11-04).

function previewColorTestSuite() as object
    return {
        name: "previewColor"
        tests: [
            { name: "matchesBrsSceneGraph", fn: previewColorTest_matchesBrsSceneGraph }
            { name: "notRgbLerp", fn: previewColorTest_notRgbLerp }
        ]
    }
end function

sub previewColorTest_matchesBrsSceneGraph(t as object)
    ' [from, to, fraction, brs-sg result]
    cases = [
        [&hFF0000FF, &h0000FFFF, 0, &hFF0000FF]
        [&hFF0000FF, &h0000FFFF, 0.125, &hFF0040FF]
        [&hFF0000FF, &h0000FFFF, 0.25, &hFF0080FF]
        [&hFF0000FF, &h0000FFFF, 0.375, &hFF00BFFF]
        [&hFF0000FF, &h0000FFFF, 0.5, &hFF00FFFF]
        [&hFF0000FF, &h0000FFFF, 0.75, &h8000FFFF]
        [&hFF0000FF, &h0000FFFF, 1, &h0000FFFF]
        [&h0000FFFF, &hFF0000FF, 0.25, &h8000FFFF]
        [&h0000FFFF, &hFF0000FF, 0.5, &hFF00FFFF]
        [&h00FF00FF, &h0000FFFF, 0.25, &h00FF80FF]
        [&h00FF00FF, &h0000FFFF, 0.5, &h00FFFFFF]
        [&h808080FF, &h00FF00FF, 0.5, &hC0C060FF]
        [&hFF000000, &h0000FF80, 0.3, &hFF009926]
        [&h123456FF, &hFEDCBA40, 0.7, &hA9CC7579]
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
