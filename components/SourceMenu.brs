sub init()
    m.top.focusable = true
    m.host = m.top.findNode("cards")
    m.titleFont = m.top.findNode("titleTemplate").font
    m.detailFont = m.top.findNode("detailTemplate").font
    m.cards = []
    m.top.observeField("choices", "onChoicesChanged")
end sub

function sourceLogo(id as String) as String
    if id = "plutovod" then id = "plutotv"
    extension = ".png"
    if id = "freetv" then extension = ".jpg"
    return "pkg:/images/providers/" + id + extension
end function

function sourceGridMove(index as Integer, count as Integer, key as String) as Integer
    if count < 1 then return 0
    target = index
    if key = "up" and index >= 2 then target = index - 2
    if key = "down" and Int(index / 2) < Int((count - 1) / 2) then target = index + 2
    if key = "left" and index mod 2 = 1 then target = index - 1
    if key = "right" and index mod 2 = 0 and index + 1 < count then target = index + 1
    if target >= count then target = count - 1
    return target
end function

sub onChoicesChanged()
    choices = m.top.choices
    if type(choices) <> "roArray" then return
    compact = choices.Count() > 6
    cardHeight = 144
    rowPitch = 160
    if compact
        cardHeight = 117
        rowPitch = 129
    end if
    helpTitle = m.top.findNode("sourceHelpTitle")
    helpText = m.top.findNode("sourceHelpText")
    if helpTitle <> invalid and helpText <> invalid
        helpTitle.visible = choices.Count() mod 2 = 1
        helpText.visible = choices.Count() mod 2 = 1
        helpY = 452
        if compact then helpY = 510
        helpTitle.translation = [652, helpY]
        helpText.translation = [652, helpY + 50]
    end if
    if m.cards.Count() <> choices.Count()
        m.host.removeChildrenIndex(m.host.getChildCount(), 0)
        m.cards = []
        for i = 0 to choices.Count() - 1
            group = m.host.createChild("Group")
            group.translation = [40 + (i mod 2) * 612, 110 + Int(i / 2) * rowPitch]
            border = group.createChild("Rectangle")
            border.width = 588
            border.height = cardHeight
            background = group.createChild("Rectangle")
            background.translation = [2, 2]
            background.width = 584
            background.height = cardHeight - 4
            logoTile = group.createChild("Rectangle")
            logoTile.translation = [14, 16]
            logoTile.width = 120
            logoTile.height = cardHeight - 24
            logoTile.color = "0x0A1015FF"
            logo = group.createChild("Poster")
            logo.translation = [24, 21]
            logo.width = 100
            logo.height = 80
            logo.loadWidth = 192
            logo.loadHeight = 160
            logo.loadDisplayMode = "scaleToFit"
            title = group.createChild("Label")
            title.translation = [150, 13]
            title.width = 418
            title.height = 48
            title.font = m.titleFont
            detail = group.createChild("Label")
            detail.translation = [150, 63]
            detail.width = 414
            detail.height = 44
            detail.wrap = true
            detail.maxLines = 2
            detail.font = m.detailFont
            m.cards.Push({border: border, background: background, logo: logo, title: title, detail: detail})
        end for
    end if
    for i = 0 to choices.Count() - 1
        choice = choices[i]
        card = m.cards[i]
        card.title.text = choice.title
        uri = sourceLogo(choice.id)
        if card.logo.uri <> uri then card.logo.uri = uri
        if choice.id = "iptvorg"
            card.detail.text = "WORLDWIDE" + Chr(10) + "Country playlists"
        else if choice.id = "freetv"
            card.detail.text = "WORLDWIDE" + Chr(10) + "Curated free channels"
        else if choice.id = "archive"
            card.detail.text = "RARE CINEMA" + Chr(10) + "Cuts, workprints and discoveries"
        else if choice.id = "plutovod"
            card.detail.text = "ON DEMAND" + Chr(10) + "Movies, posters and title details"
        else
            card.detail.text = "US LIVE CHANNELS" + Chr(10) + "Live channels + programme guide"
        end if
    end for
    if m.top.focusedIndex >= choices.Count() then m.top.focusedIndex = 0
    drawSourceFocus()
end sub

sub drawSourceFocus()
    for i = 0 to m.cards.Count() - 1
        card = m.cards[i]
        card.border.color = "0x2A3A41FF"
        card.background.color = "0x18242AFF"
        card.title.color = "0xEAF2F0FF"
        card.detail.color = "0x8CA9AEFF"
        if i = m.top.focusedIndex
            card.border.color = "0x39FF14FF"
            card.background.color = "0x223C31FF"
            card.title.color = "0x39FF14FF"
            card.detail.color = "0x00C8FFFF"
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
