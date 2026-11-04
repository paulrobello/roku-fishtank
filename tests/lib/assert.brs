' Minimal assert library for brs-cli unit tests.
' Every assert takes the test context `t` created by the runner:
'   { name: "<suite>.<test>", failures: 0 }
' A failure prints "FAIL <test name>: <message> (<file>:<line>)", increments
' t.failures and lets the test continue so later asserts still report.

function assertEqual(t as object, actual as dynamic, expected as dynamic, msg = "" as string) as boolean
    if assertValuesEqual_(actual, expected) then return true
    assertFail_(t, msg, "expected " + assertToStr_(expected) + ", got " + assertToStr_(actual))
    return false
end function

function assertTrue(t as object, cond as dynamic, msg = "" as string) as boolean
    if assertKind_(cond) = "boolean" and cond then return true
    assertFail_(t, msg, "expected true, got " + assertToStr_(cond))
    return false
end function

function assertNear(t as object, actual as dynamic, expected as dynamic, tolerance as dynamic, msg = "" as string) as boolean
    if assertKind_(actual) = "number" and assertKind_(expected) = "number" then
        if Abs(actual - expected) <= tolerance then return true
    end if
    detail = "expected " + assertToStr_(expected) + " +/- " + assertToStr_(tolerance) + ", got " + assertToStr_(actual)
    assertFail_(t, msg, detail)
    return false
end function

sub assertFail_(t as object, msg as string, detail as string)
    t.failures = t.failures + 1
    text = detail
    if msg <> "" then text = msg + ": " + detail
    print "FAIL " + t.name + ": " + text + assertCallerLocation_()
end sub

' Returns " (<file>:<line>)" for the innermost stack frame outside this
' library, read from the backtrace of a thrown-and-caught exception.
function assertCallerLocation_() as string
    try
        throw "assert location probe"
    catch e
        bt = e.backtrace
        if bt = invalid then return ""
        for i = bt.count() - 1 to 0 step -1
            frame = bt[i]
            if not LCase(frame.function).startsWith("assert") then
                return " (" + frame.filename + ":" + frame.line_number.toStr() + ")"
            end if
        end for
    end try
    return ""
end function

function assertKind_(v as dynamic) as string
    tp = LCase(type(v))
    if tp = "integer" or tp = "rointeger" or tp = "longinteger" or tp = "rolonginteger" or tp = "float" or tp = "rofloat" or tp = "double" or tp = "rodouble" or tp = "rointrinsicdouble" then return "number"
    if tp = "boolean" or tp = "roboolean" then return "boolean"
    if tp = "string" or tp = "rostring" then return "string"
    if tp = "invalid" or tp = "roinvalid" then return "invalid"
    return tp
end function

function assertValuesEqual_(a as dynamic, b as dynamic) as boolean
    ka = assertKind_(a)
    if ka <> assertKind_(b) then return false
    if ka = "invalid" then return true
    if ka = "number" or ka = "boolean" or ka = "string" then return a = b
    return false
end function

function assertToStr_(v as dynamic) as string
    k = assertKind_(v)
    if k = "invalid" then return "invalid"
    if k = "string" then return Chr(34) + v + Chr(34)
    if k = "number" or k = "boolean" then return v.toStr()
    return "<" + type(v) + ">"
end function
