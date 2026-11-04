' Seeded xorshift32 PRNG (Marsaglia 2003: shifts 13, 17, 5).
' Pure functions over a plain AA so SceneGraph components can include this
' file via <script uri> and brs-cli unit tests can run it directly.
'
' BrightScript has no unsigned type and no XOR operator. The 32-bit state is
' kept as a signed Integer holding the raw bit pattern; << wraps at 32 bits,
' every >> is masked so the result is a logical shift even if the runtime
' shifts arithmetically, and XOR is built from and/or/not.
' Constants are hex literals: decimal literals of 10+ digits parse as Double.

' Fallback for seed 0, which would otherwise stick at 0 forever.
function prngZeroSeed() as integer
    return &h9E3779B9
end function

function prngNew(seed as integer) as object
    if seed = 0 then seed = prngZeroSeed()
    return { state: seed }
end function

function prngXor32(a as integer, b as integer) as integer
    return (a or b) and not (a and b)
end function

' Advances the state and returns the raw 32-bit pattern as a signed Integer.
function prngNextRaw(rng as object) as integer
    x = rng.state
    x = prngXor32(x, x << 13)
    x = prngXor32(x, (x >> 17) and &h7FFF)
    x = prngXor32(x, x << 5)
    rng.state = x
    return x
end function

' Returns an Integer in [0, 2^31): the top 31 bits of the next raw value.
function prngNextU32(rng as object) as integer
    return (prngNextRaw(rng) >> 1) and &h7FFFFFFF
end function

' Returns a Float in [0, 1). Uses the top 24 bits so the quotient is exact in
' single precision and can never round up to 1.0.
function prngNextFloat(rng as object) as float
    return ((prngNextRaw(rng) >> 8) and &hFFFFFF) / 16777216.0
end function

' Returns a Float in [lo, hi). Float rounding of lo + span * f can land on hi
' when |lo| is large relative to the span; that case maps back to lo.
function prngRange(rng as object, lo as float, hi as float) as float
    v = lo + (hi - lo) * prngNextFloat(rng)
    if v >= hi then v = lo
    return v
end function
