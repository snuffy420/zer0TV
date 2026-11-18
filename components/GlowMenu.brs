sub init()
    m.top.focusable = true
    m.rowHost = m.top.findNode("rows")
    m.position = m.top.findNode("position")
    m.position.font = glowFont("bold", 18)
    m.rows = []
    m.offset = 0
end sub

function itemCount() as Integer
    if m.top.content = invalid then return 0
    return m.top.content.getChildCount()
end function

sub onJump()
    m.top.itemFocused = m.top.jumpToItem
    m.offset = 0
    render()
end sub

sub render()
    size = m.top.itemSize
    width = 780
    height = 64
    if type(size) = "roArray" and size.Count() = 2
        width = size[0]
        height = size[1]
    end if
    count = m.top.numRows
    if m.rows.Count() <> count
        m.rowHost.removeChildrenIndex(m.rowHost.getChildCount(), 0)
        m.rows = []
        for i = 0 to count - 1
            back = m.rowHost.createChild("Poster")
            back.uri = "pkg:/images/glow/card.9.png"
            label = m.rowHost.createChild("Label")
            label.font = glowFont("bold", 24)
            label.vertAlign = "center"
            label.ellipsisText = " "
            m.rows.Push({back: back, label: label})
        end for
    end if
    total = itemCount()
    focus = m.top.itemFocused
    if focus >= total then focus = total - 1
    if focus < 0 then focus = 0
    if focus < m.offset then m.offset = focus
    if focus > m.offset + count - 1 then m.offset = focus - count + 1
    for i = 0 to count - 1
        row = m.rows[i]
        index = m.offset + i
        row.back.translation = [0, i * height]
        row.back.width = width
        row.back.height = height - 10
        row.label.translation = [24, i * height]
        row.label.width = width - 48
        row.label.height = height - 10
        visible = index < total
        row.back.visible = visible
        row.label.visible = visible
        if visible
            row.label.text = m.top.content.getChild(index).title
            if index = focus
                row.back.blendColor = "0x39FF14FF"
                row.label.color = "0x06110AFF"
            else
                row.back.blendColor = "0x1A2738FF"
                row.label.color = "0xDCE4F2FF"
            end if
        end if
    end for
    ' "3 of 14" when the list is longer than the rows shown.
    m.position.visible = total > count
    m.position.translation = [0, count * height]
    m.position.width = width
    m.position.height = 30
    m.position.text = (focus + 1).ToStr() + " of " + total.ToStr()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press or not m.top.visible then return false
    total = itemCount()
    if total = 0 then return false
    if key = "up" or key = "down"
        focus = m.top.itemFocused
        if key = "up" then focus = focus - 1 else focus = focus + 1
        if focus < 0 then focus = total - 1
        if focus >= total then focus = 0
        m.top.itemFocused = focus
        render()
        return true
    else if key = "rewind" or key = "fastforward"
        focus = m.top.itemFocused
        if key = "rewind" then focus = focus - m.top.numRows else focus = focus + m.top.numRows
        if focus < 0 then focus = 0
        if focus >= total then focus = total - 1
        m.top.itemFocused = focus
        render()
        return true
    else if key = "OK"
        m.top.itemSelected = m.top.itemFocused
        return true
    end if
    return false
end function
