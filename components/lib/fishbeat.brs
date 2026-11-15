' Keep original fin timing and speed clamps. A 25% frequency reduction requires
' dividing the tail period by 0.75, not multiplying the period by 1.25.
function fishBeatPeriods(speed as float) as object
    if speed < 1 then speed = 1
    period = 60.0 / speed
    if period < 0.35 then period = 0.35
    if period > 3.0 then period = 3.0
    return { fin: period, tail: period / 0.75 }
end function
