' Source cards: sourceColumns() cards a row; each is the logo on a dark tile
' and the name under it.

function sourceColumns() as Integer
    return 4
end function

sub init()
    m.top.focusable = true
    m.host = m.top.findNode("cards")
    m.focusRing = m.top.findNode("focusRing")
    m.cards = []
    m.top.observeField("choices", "onChoicesChanged")
    m.top.observeField("visible", "onVisibleChanged")
    glowHints(m.top.findNode("hints"), [{icons: ["dpad-all"], text: "CHOOSE"}, {icons: ["ok"], text: "OPEN"}, {icons: ["star"], text: "ABOUT"}, {icons: ["back"], text: "EXIT"}])
    onVisibleChanged()
end sub

sub onVisibleChanged()
    pulse = m.top.findNode("pulse")
    if pulse = invalid then return
    if m.top.visible then pulse.control = "start" else pulse.control = "stop"
end sub

function sourceLogo(id as String) as String
    ' Box://Stream's own mark, packaged with it.
    if id = "boxstream" then return "pkg:/images/mark.png"
    return "pkg:/images/providers/" + id + ".png"
end function

function sourceGridMove(index as Integer, count as Integer, key as String) as Integer
    if count < 1 then return 0
    cols = sourceColumns()
    target = index
    if key = "up" and index >= cols then target = index - cols
    if key = "down" and Int(index / cols) < Int((count - 1) / cols) then target = index + cols
    if key = "left" and index mod cols > 0 then target = index - 1
    if key = "right" and index mod cols < cols - 1 and index + 1 < count then target = index + 1
    if target >= count then target = count - 1
    return target
end function

' Card size and place for a card count (two rows fit; more rows get shorter).
function sourceCardBox(i as Integer, count as Integer) as Object
    cols = sourceColumns()
    rows = Int((count + cols - 1) / cols)
    height = 320
    pitch = 352
    if rows > 2
        height = 210
        pitch = 236
    end if
    return {x: 96 + (i mod cols) * 440, y: 214 + Int(i / cols) * pitch, w: 412, h: height}
end function

sub onChoicesChanged()
    choices = m.top.choices
    if type(choices) <> "roArray" then return
    if m.cards.Count() <> choices.Count()
        m.host.removeChildrenIndex(m.host.getChildCount(), 0)
        m.cards = []
        for i = 0 to choices.Count() - 1
            place = sourceCardBox(i, choices.Count())
            group = m.host.createChild("Group")
            group.translation = [place.x, place.y]
            back = group.createChild("Poster")
            back.uri = "pkg:/images/glow/card.9.png"
            back.width = place.w
            back.height = place.h
            tileHeight = place.h - 96
            tile = group.createChild("Poster")
            tile.uri = "pkg:/images/glow/card.9.png"
            tile.blendColor = "0x0A0F18FF"
            tile.translation = [14, 14]
            tile.width = place.w - 28
            tile.height = tileHeight
            logo = group.createChild("Poster")
            logo.translation = [Int(place.w / 2) - 140, 34]
            logo.width = 280
            logo.height = tileHeight - 40
            logo.loadWidth = 280
            logo.loadHeight = 180
            logo.loadDisplayMode = "scaleToFit"
            textTop = tileHeight + 32
            title = group.createChild("Label")
            title.translation = [26, textTop]
            title.width = place.w - 52
            title.height = 46
            title.font = glowFont("bold", 34)
            title.horizAlign = "center"
            m.cards.Push({group: group, back: back, logo: logo, title: title, place: place})
        end for
    end if
    for i = 0 to choices.Count() - 1
        choice = choices[i]
        card = m.cards[i]
        card.title.text = choice.title
        uri = sourceLogo(choice.id)
        if card.logo.uri <> uri then card.logo.uri = uri
    end for
    if m.top.focusedIndex >= choices.Count() then m.top.focusedIndex = 0
    drawSourceFocus()
end sub

sub drawSourceFocus()
    colors = glowColors()
    for i = 0 to m.cards.Count() - 1
        card = m.cards[i]
        if i = m.top.focusedIndex
            card.back.blendColor = colors.cardFocus
            card.title.color = colors.white
            if m.focusRing <> invalid
                m.focusRing.translation = [card.place.x - 36, card.place.y - 36]
                m.focusRing.width = card.place.w + 72
                m.focusRing.height = card.place.h + 72
                m.focusRing.visible = true
            end if
        else
            card.back.blendColor = colors.card
            card.title.color = colors.text
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.top.visible then return false
    count = m.cards.Count()
    if key = "up" or key = "down" or key = "left" or key = "right"
        m.top.focusedIndex = sourceGridMove(m.top.focusedIndex, count, key)
        drawSourceFocus()
        return true
    else if key = "OK" or key = "play"
        if count > 0 then m.top.selectedIndex = m.top.focusedIndex
        return true
    end if
    return false
end function
