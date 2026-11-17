' ZP01: indexed blocks of <=128 delta-coded records, preserving hundredths.
function locationZipRead(value as string) as dynamic
    data = CreateObject("roByteArray")
    if not data.ReadFile("pkg:/config/location/us-zips.bin") then return invalid
    return locationZipLookup(value, data)
end function

function locationZipLookup(value as string, data as dynamic) as dynamic
    if not CreateObject("roRegex", "^[0-9]{5}$", "").isMatch(value) then return invalid
    if type(data) <> "roByteArray" then return invalid
    if data.count() < 17 then return invalid
    if data[0] <> 90 or data[1] <> 80 or data[2] <> 48 or data[3] <> 49 then return invalid
    count = locationZipUInt(data, 4, 4)
    if count < 1 or count > 100000 then return invalid
    if locationZipUInt(data, 8, 2) <> 128 then return invalid
    blocks = Int((count + 127) / 128)
    base = 10 + blocks * 7
    if base >= data.count() then return invalid
    target = value.toInt()
    low = 0
    high = blocks - 1
    block = -1
    while low <= high
        middle = Int((low + high) / 2)
        code = locationZipUInt(data, 10 + middle * 7, 3)
        if code < 0 or code > 99999 then return invalid
        if code <= target then
            block = middle
            low = middle + 1
        else
            high = middle - 1
        end if
    end while
    if block < 0 then return invalid
    offset = locationZipUInt(data, 13 + block * 7, 4)
    if offset < 0 then return invalid
    finish = data.count()
    if block + 1 < blocks then
        nextOffset = locationZipUInt(data, 13 + (block + 1) * 7, 4)
        if nextOffset <= offset then return invalid
        finish = base + nextOffset
    end if
    if finish > data.count() or base + offset >= finish then return invalid
    state = { pos: base + offset, finish: finish }
    code = 0
    lat = 0
    lon = 0
    remaining = count - block * 128
    if remaining > 128 then remaining = 128
    for i = 0 to remaining - 1
        dz = locationZipVar(data, state)
        da = locationZipVar(data, state)
        db = locationZipVar(data, state)
        if dz < 0 or da < 0 or db < 0 then return invalid
        if i > 0 and dz = 0 then return invalid
        code += dz
        lat += locationZipSigned(da)
        lon += locationZipSigned(db)
        if code > 99999 or lat < 0 or lat > 18000 or lon < 0 or lon > 36000 then return invalid
        if i = 0 and code <> locationZipUInt(data, 10 + block * 7, 3) then return invalid
        if code = target then return settingsLocationParse((lat / 100.0 - 90).toStr() + "," + (lon / 100.0 - 180).toStr())
        if code > target then return invalid
    end for
    return invalid
end function

' Bounded integer reads avoid overflow and malformed offsets.
function locationZipUInt(data as object, start as integer, width as integer) as integer
    if start < 0 or start + width > data.count() then return -1
    value = 0
    for i = start to start + width - 1
        value = value * 256 + data[i]
        if value > 1000000 then return -1
    end for
    return value
end function

function locationZipVar(data as object, state as object) as integer
    value = 0
    factor = 1
    for i = 0 to 2
        if state.pos >= state.finish then return -1
        b = data[state.pos]
        state.pos++
        value += (b mod 128) * factor
        if b < 128 then return value
        factor *= 128
    end for
    return -1
end function

function locationZipSigned(value as integer) as integer
    if value mod 2 = 1 then return -Int(value / 2) - 1
    return Int(value / 2)
end function

function locationCityCoordinates(row as dynamic) as dynamic
    if type(row) <> "roArray" then return invalid
    if row.count() <> 3 then return invalid
    if row[1] = invalid or row[2] = invalid then return invalid
    return settingsLocationParse((row[1] / 100.0).toStr() + "," + (row[2] / 100.0).toStr())
end function

' Build a five-character ZIP without dropping leading zeros.
function locationZipDigits(digits as object) as string
    value = ""
    for each digit in digits
        value += digit.toStr()
    end for
    return value
end function
