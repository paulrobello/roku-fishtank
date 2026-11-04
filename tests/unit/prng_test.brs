' Unit tests for components/lib/prng.brs.
' Reference values were computed independently in Python with 32-bit masking:
'   x ^= (x << 13) & 0xFFFFFFFF; x ^= x >> 17; x ^= (x << 5) & 0xFFFFFFFF
' raw state shown as signed int32, NextU32 = x >> 1, NextFloat = (x >> 8) / 2^24.
' The seed-1 sequence (270369, 67634689, 2647435461, ...) also matches
' Marsaglia's published xorshift32 output.

function prngTestSuite() as object
    return {
        name: "prng"
        tests: [
            { name: "sameSeedSameSequence", fn: prngTest_sameSeedSameSequence }
            { name: "differentSeedsDiffer", fn: prngTest_differentSeedsDiffer }
            { name: "rawStateMatchesReference", fn: prngTest_rawStateMatchesReference }
            { name: "nextU32MatchesReference", fn: prngTest_nextU32MatchesReference }
            { name: "nextFloatMatchesReference", fn: prngTest_nextFloatMatchesReference }
            { name: "nextU32InRange", fn: prngTest_nextU32InRange }
            { name: "floatsInRange", fn: prngTest_floatsInRange }
            { name: "zeroSeedFallback", fn: prngTest_zeroSeedFallback }
        ]
    }
end function

sub prngTest_sameSeedSameSequence(t as object)
    a = prngNew(42)
    b = prngNew(42)
    for i = 1 to 200
        if not assertEqual(t, prngNextU32(a), prngNextU32(b), "draw " + i.toStr()) then return
    end for
end sub

sub prngTest_differentSeedsDiffer(t as object)
    a = prngNew(1)
    b = prngNew(2)
    same = 0
    for i = 1 to 50
        if prngNextU32(a) = prngNextU32(b) then same = same + 1
    end for
    assertEqual(t, same, 0, "matching draws between seed 1 and seed 2")
end sub

sub prngTest_rawStateMatchesReference(t as object)
    expected = [270369, 67634689, -1647531835, 307599695, -1896278063, 745495504, 632435482, 435756210]
    rng = prngNew(1)
    for i = 0 to expected.count() - 1
        prngNextRaw(rng)
        assertEqual(t, rng.state, expected[i], "seed 1 state " + i.toStr())
    end for
end sub

sub prngTest_nextU32MatchesReference(t as object)
    expected = [1668463165, 848626903, 1408255952, 977740021, 359421161, 1641810225, 2142843084, 1840455580]
    rng = prngNew(12345)
    for i = 0 to expected.count() - 1
        v = prngNextU32(rng)
        assertEqual(t, LCase(type(v)), "integer", "type of draw " + i.toStr())
        assertEqual(t, v, expected[i], "seed 12345 draw " + i.toStr())
    end for
end sub

sub prngTest_nextFloatMatchesReference(t as object)
    expected = [0.7769386768341064, 0.395172655582428, 0.6557702422142029, 0.4552956223487854, 0.16736847162246704, 0.764527440071106, 0.9978390336036682, 0.8570289015769958]
    rng = prngNew(12345)
    for i = 0 to expected.count() - 1
        assertNear(t, prngNextFloat(rng), expected[i], 0.000001, "seed 12345 float " + i.toStr())
    end for
end sub

sub prngTest_nextU32InRange(t as object)
    rng = prngNew(7)
    for i = 1 to 5000
        v = prngNextU32(rng)
        if not assertTrue(t, v >= 0, "draw " + i.toStr() + " = " + v.toStr() + " is negative") then return
    end for
end sub

sub prngTest_floatsInRange(t as object)
    rng = prngNew(99)
    for i = 1 to 5000
        f = prngNextFloat(rng)
        if not assertTrue(t, f >= 0 and f < 1, "float " + f.toStr() + " outside [0,1)") then return
    end for
    assertEqual(t, LCase(type(prngNextFloat(rng))), "float", "prngNextFloat type")
    for i = 1 to 5000
        r = prngRange(rng, -5, 5)
        if not assertTrue(t, r >= -5 and r < 5, "range " + r.toStr() + " outside [-5,5)") then return
    end for
    ' Large offset, narrow span: single-precision rounding can hit hi.
    for i = 1 to 5000
        r = prngRange(rng, 1000, 1001)
        if not assertTrue(t, r >= 1000 and r < 1001, "range " + r.toStr() + " outside [1000,1001)") then return
    end for
end sub

sub prngTest_zeroSeedFallback(t as object)
    z = prngNew(0)
    assertTrue(t, z.state <> 0, "seed 0 must map to a non-zero state")
    assertEqual(t, z.state, prngZeroSeed(), "seed 0 maps to prngZeroSeed()")
    g = prngNew(&h9E3779B9)
    expected = [1359758873, -533834434, 2075758394, 25405621]
    for i = 0 to expected.count() - 1
        v = prngNextRaw(z)
        assertEqual(t, v, expected[i], "zero-seed state " + i.toStr())
        assertEqual(t, v, prngNextRaw(g), "zero seed tracks &h9E3779B9 at " + i.toStr())
    end for
    for i = 1 to 1000
        if not assertTrue(t, prngNextRaw(z) <> 0, "state stuck at 0 on draw " + i.toStr()) then return
    end for
end sub
