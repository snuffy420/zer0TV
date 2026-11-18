sub init()
    m.back = m.top.findNode("back")
    m.flag = m.top.findNode("flag")
    m.pin = m.top.findNode("pin")
    m.name = m.top.findNode("name")
    m.ring = m.top.findNode("ring")
    m.name.font = glowFont("bold", 24)
    onFocus()
end sub

sub onContent()
    item = m.top.itemContent
    if item = invalid then return
    m.name.text = item.title
    size = 24
    if Len(item.title) > 16 then size = 21
    if Len(item.title) > 28 then size = 18
    m.name.font = glowFont("bold", size)
    if m.flag.uri <> item.HDPosterUrl then m.flag.uri = item.HDPosterUrl
    m.pin.visible = item.ShortDescriptionLine1 = "pinned"
end sub

sub onFocus()
    colors = glowColors()
    focused = m.top.focusPercent
    if not m.top.gridHasFocus then focused = 0
    m.ring.opacity = focused
    if focused > 0.5
        m.back.blendColor = colors.cardFocus
        m.name.color = colors.white
    else
        m.back.blendColor = colors.card
        m.name.color = colors.text
    end if
end sub
