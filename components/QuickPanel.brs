' Quick channel switch (Replay in full screen), as in Spelunkr: a list on the
' left while the video keeps playing the same channel. Up/Down choose,
' Left/Right switch between every channel and favorites, OK switches,
' Back or Replay closes with nothing changed. Closes itself after 10 s idle.

sub initQuickPanel()
    m.quickPanel = m.top.findNode("quickPanel")
    m.quickTitle = m.top.findNode("quickTitle")
    m.quickTitle.font = glowFont("bold", 24)
    m.quickHighlight = m.top.findNode("quickHighlight")
    host = m.top.findNode("quickRows")
    m.quickViews = []
    for slot = 0 to 8
        group = host.createChild("Group")
        group.translation = [0, slot * 92]
        logo = group.createChild("Poster")
        logo.translation = [20, 8]
        logo.width = 132
        logo.height = 76
        logo.loadWidth = 264
        logo.loadHeight = 152
        logo.loadDisplayMode = "scaleToFit"
        number = group.createChild("Label")
        number.translation = [166, 10]
        number.width = 70
        number.height = 32
        number.font = glowFont("bold", 22)
        number.color = "0x8391AAFF"
        name = group.createChild("Label")
        name.translation = [236, 10]
        name.width = 420
        name.height = 32
        name.font = glowFont("bold", 24)
        name.ellipsisText = " "
        playing = group.createChild("Label")
        playing.translation = [166, 48]
        playing.width = 490
        playing.height = 28
        playing.font = glowFont("regular", 19)
        playing.color = "0x8391AAFF"
        playing.ellipsisText = " "
        star = group.createChild("Poster")
        star.uri = "pkg:/images/glow/pin.png"
        star.translation = [128, 4]
        star.width = 26
        star.height = 26
        m.quickViews.Push({group: group, logo: logo, number: number, name: name, playing: playing, star: star})
    end for
    glowHints(m.top.findNode("quickHints"), [{icons: ["dpad-updown"], text: "CHOOSE"}, {icons: ["dpad-leftright"], text: "FAVORITES"}, {icons: ["ok"], text: "WATCH"}, {icons: ["back"], text: "CLOSE"}])
    m.quickTimer = CreateObject("roSGNode", "Timer")
    m.quickTimer.duration = 10
    m.quickTimer.observeField("fire", "closeQuick")
    m.quickOpen = false
end sub

' The channel index (in displayList) that is playing full screen.
function playingIndex() as Integer
    if m.playingChannel <> invalid
        for i = 0 to m.displayList.Count() - 1
            if m.displayList[i].url = m.playingChannel.url then return i
        end for
    end if
    return m.guideIndex
end function

sub openQuick()
    if m.displayList.Count() = 0 then return
    hidePlayerBanner()
    m.quickOpen = true
    m.quickFavOnly = false
    buildQuickList()
    m.quickPanel.visible = true
    renderQuick()
    m.quickTimer.control = "stop"
    m.quickTimer.control = "start"
end sub

sub closeQuick()
    m.quickOpen = false
    m.quickPanel.visible = false
    m.quickTimer.control = "stop"
end sub

sub buildQuickList()
    m.quickList = []
    for i = 0 to m.displayList.Count() - 1
        if not m.quickFavOnly or isFavorite(m.displayList[i].url) then m.quickList.Push(i)
    end for
    current = playingIndex()
    m.quickPos = 0
    for i = 0 to m.quickList.Count() - 1
        if m.quickList[i] = current then m.quickPos = i
    end for
end sub

sub renderQuick()
    count = m.quickList.Count()
    if m.quickFavOnly then m.quickTitle.text = "FAVORITES" else m.quickTitle.text = "CHANNELS"
    if m.quickFavOnly and count = 0 then m.quickTitle.text = "NO FAVORITES YET"
    ' A long list keeps the highlight in the middle row and wraps; a short one
    ' lists from the top.
    wrap = count >= 9
    current = playingIndex()
    now = CreateObject("roDateTime").AsSeconds()
    for slot = 0 to 8
        view = m.quickViews[slot]
        position = slot
        if wrap then position = ((m.quickPos - 4 + slot) mod count + count) mod count
        if position >= count or count = 0
            view.group.visible = false
        else
            view.group.visible = true
            index = m.quickList[position]
            ch = m.displayList[index]
            view.number.text = (index + 1).ToStr()
            uri = "pkg:/images/no_logo.png"
            if ch.logo <> invalid and ch.logo <> "" then uri = ch.logo
            if view.logo.uri <> uri then view.logo.uri = uri
            view.star.visible = isFavorite(ch.url)
            view.name.text = ch.name
            playing = ""
            for each p in guidePrograms(ch)
                if p.start <= now and p.stop > now
                    playing = p.title
                    exit for
                end if
            end for
            if index = current
                if playing <> "" then playing = "WATCHING  ·  " + playing else playing = "WATCHING"
            end if
            view.playing.text = playing
            view.name.color = "0xDCE4F2FF"
            if index = current then view.name.color = "0x39FF14FF"
        end if
    end for
    highlight = 4
    if not wrap then highlight = m.quickPos
    m.quickHighlight.visible = count > 0
    m.quickHighlight.translation = [0, highlight * 92]
end sub

function quickKey(key as String) as Boolean
    m.quickTimer.control = "stop"
    m.quickTimer.control = "start"
    count = m.quickList.Count()
    if key = "up" and count > 0
        m.quickPos = (m.quickPos - 1 + count) mod count
        renderQuick()
    else if key = "down" and count > 0
        m.quickPos = (m.quickPos + 1) mod count
        renderQuick()
    else if key = "left" or key = "right"
        m.quickFavOnly = not m.quickFavOnly
        buildQuickList()
        renderQuick()
    else if key = "OK" and count > 0
        index = m.quickList[m.quickPos]
        closeQuick()
        if index <> playingIndex() then fullscreenTune(index) else showNowPlayingBanner()
    else if key = "back" or key = "replay"
        closeQuick()
    else if key = "options"
        closeQuick()
        return false
    end if
    return true
end function

' Up/Down in full screen flip channels (Up = next), as in Spelunkr.
sub fullscreenChannelStep(delta as Integer)
    count = m.displayList.Count()
    if count < 2 then return
    fullscreenTune(((playingIndex() + delta) mod count + count) mod count)
end sub

sub fullscreenTune(index as Integer)
    if index < 0 or index >= m.displayList.Count() then return
    ch = m.displayList[index]
    m.guideIndex = index
    pushRecent(ch)
    showNowPlayingBanner(ch)
    requestPlayback(ch, true)
end sub
