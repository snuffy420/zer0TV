function xmltvTime(value as Dynamic) as Integer
    if value = invalid then return 0
    value = value.Trim()
    if Len(value) < 14 then return 0
    iso = Left(value, 4) + "-" + Mid(value, 5, 2) + "-" + Mid(value, 7, 2) + "T" + Mid(value, 9, 2) + ":" + Mid(value, 11, 2) + ":" + Mid(value, 13, 2) + "Z"
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(iso)
    offset = 0
    if Len(value) >= 20
        offset = (Val(Mid(value, 17, 2)) * 60 + Val(Mid(value, 19, 2))) * 60
        if Mid(value, 16, 1) = "-" then offset = -offset
    end if
    return dt.AsSeconds() - offset
end function

function epgName(value as String) as String
    value = CreateObject("roRegex", "^[A-Z]{2}\s*-\s*", "").Replace(value, "")
    value = CreateObject("roRegex", "\s*\([0-9]+p\).*$", "i").Replace(value, "")
    return CreateObject("roRegex", "[^a-z0-9]", "i").ReplaceAll(LCase(value), "")
end function

function epgId(value as String) as String
    ' Playlist rendition suffixes (for example @SD / @HD) share one station guide.
    return CreateObject("roRegex", "@(SD|HD|FHD|UHD|4K|8K|[0-9]+p)$", "i").Replace(LCase(value), "")
end function

function epgNumber(value as Dynamic) as Boolean
    kind = type(value)
    return kind = "Integer" or kind = "roInt" or kind = "LongInteger" or kind = "roLongInteger" or kind = "Float" or kind = "roFloat" or kind = "Double" or kind = "roDouble"
end function

' Keep a small live window and a strict object budget, regardless of input feed size.
function guideProgramAllowed(startTime as Integer, stopTime as Integer, now as Integer) as Boolean
    return stopTime > now - 900 and startTime < now + 21600 and stopTime > startTime
end function

function compactProgram(p as Object) as Object
    description = ""
    if type(p.description) = "roString" or type(p.description) = "String" then description = Left(p.description, 240)
    return {start: p.start, stop: p.stop, title: Left(p.title, 160), description: description}
end function

function epgString(value as Dynamic) as Boolean
    return type(value) = "String" or type(value) = "roString"
end function
