' Glow Grid look shared by zer0TV's 1080p screens: colours, fonts, clock and
' the purple key-pill hints along the bottom of a screen.

function glowColors() as Object
    return {
        ground: "0x070B12FF"
        green: "0x39FF14FF"
        cyan: "0x00C8FFFF"
        text: "0xDCE4F2FF"
        white: "0xFFFFFFFF"
        soft: "0xAEB9CCFF"
        muted: "0x8391AAFF"
        hint: "0xC3CDDEFF"
        purple: "0x6B2FD6FF"
        cell: "0x121A26FF"
        card: "0x111927FF"
        airing: "0x1A2738FF"
        cardFocus: "0x1A2738FF"
    }
end function

' A system font at a given size; weight "bold" or "regular". Cached per component.
function glowFont(weight as String, size as Integer) as Object
    if m.glowFonts = invalid then m.glowFonts = {}
    name = weight + Str(size).Trim()
    if m.glowFonts.DoesExist(name) then return m.glowFonts[name]
    f = CreateObject("roSGNode", "Font")
    if weight = "bold" then f.uri = "font:BoldSystemFontFile" else f.uri = "font:SystemFontFile"
    f.size = size
    m.glowFonts[name] = f
    return f
end function

' "7:42 PM"
function glowClock() as String
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    hour = now.GetHours()
    suffix = "AM"
    if hour >= 12 then suffix = "PM"
    hour = hour mod 12
    if hour = 0 then hour = 12
    minute = now.GetMinutes()
    pad = ""
    if minute < 10 then pad = "0"
    return Str(hour).Trim() + ":" + pad + Str(minute).Trim() + " " + suffix
end function

' The real remote buttons, drawn as in Box://Stream and Spelunkr (purple pad
' and OK, dark round buttons). Pictures: pkg:/images/hints, shipped with
' Box://Stream inside zer0TV.
function glowHintWidths() as Object
    return {"dpad-updown": 52, "dpad-leftright": 52, "dpad-all": 36, "dpad-up": 36, "dpad-down": 36, "dpad-left": 36, "dpad-right": 36, "ok": 44, "rewind": 36, "forward": 36, "playpause": 36, "back": 36, "star": 36, "replay": 36}
end function

' Fills host with button pictures and a word each:
' hints = [{icons: ["dpad-all"], text: "CHOOSE"}, {icons: ["ok"], text: "OPEN"}, ...].
sub glowHints(host as Object, hints as Object)
    host.removeChildrenIndex(host.getChildCount(), 0)
    widths = glowHintWidths()
    font = glowFont("bold", 20)
    x = 0
    for each item in hints
        for each icon in item.icons
            poster = host.createChild("Poster")
            poster.uri = "pkg:/images/hints/" + icon + ".png"
            poster.width = widths[icon]
            poster.height = 34
            poster.translation = [x, 0]
            x = x + poster.width + 4
        end for
        label = host.createChild("Label")
        label.font = font
        label.color = glowColors().hint
        label.height = 34
        label.vertAlign = "center"
        label.text = item.text
        label.translation = [x + 6, 0]
        ' The measured width can be missing before the font is ready.
        width = label.boundingRect().width
        if width < Len(item.text) * 8 then width = Len(item.text) * 12
        x = x + 6 + width + 34
    end for
end sub

' ---- QWERTY keyboard (channel and Archive search) ------------------------------
' Rows of keys; each key {value, label, start, units} on a 10-unit row.
function qwertyLayout(withSearch as Boolean) as Object
    rows = [["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"], ["A", "S", "D", "F", "G", "H", "J", "K", "L", "'"], ["Z", "X", "C", "V", "B", "N", "M", "-", "."]]
    layout = []
    for each row in rows
        keys = []
        start = (10 - row.Count()) / 2
        for each value in row
            keys.Push({value: value, label: value, start: start, units: 1})
            start = start + 1
        end for
        layout.Push(keys)
    end for
    if withSearch
        layout.Push([{value: "SPC", label: "SPACE", start: 0, units: 3}, {value: "DEL", label: "DELETE", start: 3, units: 2}, {value: "CLR", label: "CLEAR", start: 5, units: 2}, {value: "SEARCH", label: "SEARCH", start: 7, units: 3}])
    else
        layout.Push([{value: "SPC", label: "SPACE", start: 0, units: 4}, {value: "DEL", label: "DELETE", start: 4, units: 3}, {value: "CLR", label: "CLEAR", start: 7, units: 3}])
    end if
    return layout
end function

' Up/Down: the key in the new row under the middle of the current key.
function qwertyColumn(layout as Object, fromRow as Integer, fromCol as Integer, toRow as Integer) as Integer
    key = layout[fromRow][fromCol]
    middle = key.start + key.units / 2
    best = 0
    for i = 0 to layout[toRow].Count() - 1
        k = layout[toRow][i]
        if middle >= k.start and middle < k.start + k.units then return i
        if Abs(k.start + k.units / 2 - middle) < Abs(layout[toRow][best].start + layout[toRow][best].units / 2 - middle) then best = i
    end for
    return best
end function

' Builds the key nodes in host: pitch px per unit, keyHeight px tall.
function qwertyNodes(host as Object, layout as Object, pitch as Integer, keyHeight as Integer) as Object
    nodes = []
    for r = 0 to layout.Count() - 1
        for c = 0 to layout[r].Count() - 1
            k = layout[r][c]
            back = host.createChild("Poster")
            back.uri = "pkg:/images/glow/card.9.png"
            back.translation = [k.start * pitch, r * (keyHeight + 8)]
            back.width = k.units * pitch - 8
            back.height = keyHeight
            label = host.createChild("Label")
            label.translation = back.translation
            label.width = back.width
            label.height = keyHeight
            label.horizAlign = "center"
            label.vertAlign = "center"
            label.font = glowFont("bold", 26)
            if k.units > 1 then label.font = glowFont("bold", 20)
            label.text = k.label
            nodes.Push({back: back, label: label, row: r, col: c})
        end for
    end for
    return nodes
end function

sub qwertyDraw(nodes as Object, row as Integer, col as Integer, active as Boolean)
    for each key in nodes
        if active and key.row = row and key.col = col
            key.back.blendColor = "0x39FF14FF"
            key.label.color = "0x06110AFF"
        else
            key.back.blendColor = "0x1A2738FF"
            key.label.color = "0xDCE4F2FF"
        end if
    end for
end sub

