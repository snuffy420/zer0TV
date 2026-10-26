' Reuse a fixed six-row grid, one background worker and one video decoder.
sub initGuide()
    m.guide = m.top.findNode("guide")
    m.guideRows = m.top.findNode("guideRows")
    m.guideTimes = m.top.findNode("guideTimes")
    m.guideTrap = m.top.findNode("guideTrap")
    m.guideTitle = m.top.findNode("guideTitle")
    m.guideDetail = m.top.findNode("guideDetail")
    m.guideDescription = m.top.findNode("guideDescription")
    m.guideLogo = m.top.findNode("guideLogo")
    m.guideClock = m.top.findNode("guideClock")
    m.guideInfo = m.top.findNode("guideInfo")
    m.guidePreview = m.top.findNode("guidePreview")
    m.guideChannelHeading = m.top.findNode("guideChannelHeading")
    m.guideWanted = true
    preferences = CreateObject("roRegistrySection", "zer0_preferences")
    if preferences.Read("channelView") = "list" then m.guideWanted = false
    m.guideIndex = 0
    m.guideActive = false
    m.guideData = {}
    m.guideCountry = ""
    m.guideDataIdentity = ""
    m.guideMessage = ""
    m.guideCoverage = ""
    m.guideFetched = 0
    m.previewUrl = ""
    m.playerReturn = "channels"
    m.guideEpoch = CreateObject("roDateTime").AsSeconds()
    m.guideCursor = m.guideEpoch
    m.previewTimer = CreateObject("roSGNode", "Timer")
    m.previewTimer.duration = 1.2
    m.previewTimer.observeField("fire", "previewGuideChannel")
    m.guideTimer = CreateObject("roSGNode", "Timer")
    m.guideTimer.duration = 60
    m.guideTimer.repeat = true
    m.guideTimer.observeField("fire", "onGuideTick")
    m.video.observeField("state", "onVideoState")
    m.video.observeField("errorCode", "onVideoError")
    m.playRequest = invalid
    m.releaseVideo = false
    m.switchTimer = CreateObject("roSGNode", "Timer")
    m.switchTimer.duration = 0.15
    m.switchTimer.observeField("fire", "startPendingPlayback")
    m.previewWatchdog = CreateObject("roSGNode", "Timer")
    m.previewWatchdog.duration = 25
    m.previewWatchdog.observeField("fire", "onPreviewTimeout")
    m.guideTaskBusy = false
    m.guidePending = invalid
    m.guideRequestCount = 0
    m.epgTask = CreateObject("roSGNode", "EpgTask")
    m.epgTask.observeField("state", "onGuideTaskState")
    m.guideRenderedPage = -1
    m.guideRenderedTime = -1
    m.guideDataRevision = 0
    m.guideRenderedRevision = -1
    initGuidePool()
end sub

function countryForGuide() as String
    if m.selectedCountry = invalid then return ""
    code = LCase(m.selectedCountry.code)
    if code = "uk" then return "gb"
    if Len(code) = 2 then return code
    for each c in getBuiltInCountries()
        if LCase(c.countryName) = LCase(m.selectedCountry.name)
            if c.code = "UK" then return "gb"
            return LCase(c.code)
        end if
    end for
    if code = "usa" or code = "united states of america" then return "us"
    if code = "uk" then return "gb"
    if code = "south korea" then return "kr"
    if code = "czech republic" then return "cz"
    return ""
end function

sub loadCountryGuide()
    code = countryForGuide()
    identity = m.source + ":" + code
    if code = "" then identity = m.source + ":special"
    if m.guideCountry = identity then return
    m.guideCountry = identity
    if m.guideDataIdentity <> identity
        m.guideData = {}
        m.guideDataRevision = m.guideDataRevision + 1
        m.guideCoverage = ""
    end if
    m.guideMessage = "No country guide available · channels remain watchable"
    if code = "" then return
    m.guideMessage = "Loading country guide… · browse and watch while it loads"
    config = ParseJson(ReadAsciiFile("pkg:/config/epg.json"))
    base = ""
    if config <> invalid and config.jsonBase <> invalid then base = config.jsonBase
    if isLiveProvider(m.source) then base = ""
    m.epgTask.cancelled = true
    m.guidePending = {code: code, provider: m.source, base: base}
    startGuideRequest()
end sub

sub startGuideRequest()
    if m.guideTaskBusy or m.guidePending = invalid then return
    request = m.guidePending
    m.guidePending = invalid
    channels = []
    for each ch in m.channels
        channels.Push({name: ch.name, tvgId: ch.tvgId})
    end for
    m.guideRequestCount = m.guideRequestCount + 1
    m.epgTask.country = request.code
    m.epgTask.provider = request.provider
    m.epgTask.channels = channels
    m.epgTask.jsonBase = request.base
    m.epgTask.xmlUrl = ""
    if isLiveProvider(request.provider) then m.epgTask.xmlUrl = m.providers[request.provider].liveEpgUrl
    m.epgTask.requestId = m.guideRequestCount.ToStr()
    m.epgTask.cancelled = false
    m.epgTask.done = false
    m.epgTask.result = {}
    m.guideTaskBusy = true
    m.epgTask.control = "RUN"
end sub

sub onGuideTaskState()
    state = m.epgTask.state
    if state <> "done" and state <> "stop" then return
    m.guideTaskBusy = false
    if not m.epgTask.cancelled and m.epgTask.done then onGuideLoaded()
    m.epgTask.result = {}
    m.epgTask.channels = []
    startGuideRequest()
end sub

sub onGuideLoaded()
    if m.epgTask = invalid then return
    if not m.epgTask.done then return
    m.guideData = m.epgTask.result
    m.guideDataIdentity = m.guideCountry
    m.guideDataRevision = m.guideDataRevision + 1
    m.guideMessage = m.epgTask.message
    m.guideFetched = CreateObject("roDateTime").AsSeconds()
    matched = 0
    for each ch in m.channels
        if guidePrograms(ch).Count() > 0 then matched = matched + 1
    end for
    m.guideCoverage = " · " + matched.ToStr() + " / " + m.channels.Count().ToStr() + " channels matched"
    if m.guideActive and m.view = "channels" then drawGuide()
end sub

sub showGuide()
    m.guideActive = true
    m.guide.visible = true
    m.list.visible = false
    m.guideTrap.setFocus(true)
    m.guideIndex = 0
    m.guideLetters = buildGuideLetterIndex(m.displayList)
    m.guideChannelHeading.text = "CHANNEL | REW/FF A-Z"
    m.guideRenderedPage = -1
    m.logo.uri = ""
    m.lastLogoUrl = ""
    m.guideEpoch = CreateObject("roDateTime").AsSeconds()
    m.guideCursor = m.guideEpoch
    loadCountryGuide()
    drawGuide()
    m.guideTimer.control = "start"
    if m.displayList.Count() > 0
        m.previewTimer.control = "start"
    else
        stopGuidePlayback()
        m.guidePreview.text = "No channels match this filter"
    end if
end sub

sub hideGuide()
    m.guideActive = false
    m.guide.visible = false
    m.previewTimer.control = "stop"
    m.guideTimer.control = "stop"
    m.guideRenderedPage = -1
    for each row in m.guidePool
        row.logo.uri = ""
        row.programs = []
        for each cell in row.cells
            cell.program = invalid
            cell.label.text = ""
        end for
    end for
    m.guideLogo.uri = ""
    cancelCountryGuide()
    if m.view <> "video" and m.view <> "playeropts"
        stopGuidePlayback()
    end if
end sub

function guidePrograms(ch as Object) as Object
    if m.guideData = invalid then return []
    if m.guideData.schedules = invalid then return []
    if ch.guideId = invalid
        ch.guideId = ""
        if ch.tvgId <> invalid and ch.tvgId <> "" then ch.guideId = epgId(ch.tvgId)
        ch.guideName = epgName(ch.name)
    end if
    schedules = m.guideData.schedules
    if schedules.DoesExist(ch.guideId) then return schedules[ch.guideId]
    if m.guideData.aliases <> invalid
        if m.guideData.aliases.DoesExist(ch.guideName)
            id = m.guideData.aliases[ch.guideName]
            if schedules.DoesExist(id) then return schedules[id]
        end if
    end if
    return []
end function

function guideTime(epoch as Integer) as String
    dt = CreateObject("roDateTime")
    dt.FromSeconds(epoch)
    dt.ToLocalTime()
    hours = dt.GetHours()
    suffix = " AM"
    if hours >= 12 then suffix = " PM"
    hours = hours mod 12
    if hours = 0 then hours = 12
    minutes = dt.GetMinutes().ToStr()
    if Len(minutes) = 1 then minutes = "0" + minutes
    return hours.ToStr() + ":" + minutes + suffix
end function

function guideLabel(parent as Object, text as String, x as Float, y as Float, width as Float, color as String, bold = false as Boolean) as Object
    node = parent.createChild("Label")
    node.text = text
    node.translation = [x, y]
    node.width = width
    node.height = 30
    node.color = color
    node.font = m.guideDescription.font
    if bold then node.font = m.guideDetail.font
    return node
end function

function guideRect(parent as Object, x as Float, y as Float, width as Float, height as Float, color as String) as Object
    node = parent.createChild("Rectangle")
    node.translation = [x, y]
    node.width = width
    node.height = height
    node.color = color
    return node
end function

sub initGuidePool()
    m.guidePool = []
    m.guideTimeLabels = []
    for slot = 0 to 5
        m.guideTimeLabels.Push(guideLabel(m.guideTimes, "", 302 + slot * 150, 0, 145, "0x8AA898FF"))
    end for
    for index = 0 to 5
        group = m.guideRows.createChild("Group")
        group.translation = [0, index * 49]
        row = {group: group, cells: [], channelIndex: -1, programs: []}
        row.background = guideRect(group, 0, 0, 298, 46, "0x192126FF")
        row.edge = guideRect(group, 0, 0, 3, 46, "0x39FF14FF")
        row.logo = group.createChild("Poster")
        row.logo.translation = [10, 5]
        row.logo.width = 50
        row.logo.height = 36
        row.logo.loadWidth = 100
        row.logo.loadHeight = 72
        row.logo.loadDisplayMode = "scaleToFit"
        row.name = guideLabel(group, "", 70, 9, 218, "0xEAF2F0FF")
        guideRect(group, 302, 0, 898, 46, "0x131B20FF")
        row.empty = guideLabel(group, "No listings available   ·   OK to watch live", 316, 9, 866, "0x6F898AFF")
        for cell = 0 to 15
            tile = guideRect(group, 0, 0, 1, 46, "0x202B31FF")
            label = guideLabel(group, "", 0, 9, 1, "0xD8E5E2FF")
            tile.visible = false
            label.visible = false
            row.cells.Push({box: tile, label: label, program: invalid})
        end for
        m.guidePool.Push(row)
    end for
    m.guideNowLine = guideRect(m.guideRows, 0, 0, 2, 291, "0x00C8FFBB")
end sub

sub drawGuide()
    if not m.guideActive then return
    count = m.displayList.Count()
    if m.guideIndex >= count then m.guideIndex = count - 1
    if m.guideIndex < 0 then m.guideIndex = 0
    startTime = Int(m.guideCursor / 1800#) * 1800
    page = Int(m.guideIndex / 6) * 6
    rebuild = page <> m.guideRenderedPage or startTime <> m.guideRenderedTime or m.guideDataRevision <> m.guideRenderedRevision
    pageChanged = page <> m.guideRenderedPage
    if rebuild
        for slot = 0 to 5
            m.guideTimeLabels[slot].text = guideTime(startTime + slot * 1800)
        end for
    end if
    for rowIndex = 0 to 5
        row = m.guidePool[rowIndex]
        index = page + rowIndex
        row.group.visible = index < count
        if index < count
            ch = m.displayList[index]
            selected = index = m.guideIndex
            row.background.color = "0x192126FF"
            if selected then row.background.color = "0x244034FF"
            row.edge.visible = selected
            name = ch.name
            if isFavorite(ch.url) then name = "★ " + name
            row.name.text = name
            row.name.font = m.guideDescription.font
            if selected then row.name.font = m.guideDetail.font
            if pageChanged
                uri = "pkg:/images/no_logo.png"
                if ch.logo <> invalid and ch.logo <> "" then uri = ch.logo
                if row.logo.uri <> uri then row.logo.uri = uri
            end if
            if rebuild
                row.programs = guidePrograms(ch)
                for each cell in row.cells
                    cell.box.visible = false
                    cell.label.visible = false
                    cell.program = invalid
                end for
                cellIndex = 0
                for each p in row.programs
                    if p.stop > startTime and p.start < startTime + 10800
                        leftTime = p.start
                        rightTime = p.stop
                        if leftTime < startTime then leftTime = startTime
                        if rightTime > startTime + 10800 then rightTime = startTime + 10800
                        x = 302 + (leftTime - startTime) / 12#
                        width = (rightTime - leftTime) / 12# - 3
                        if width > 3 and cellIndex < 16
                            cell = row.cells[cellIndex]
                            cell.program = p
                            cell.box.translation = [x, 0]
                            cell.box.width = width
                            cell.box.visible = true
                            cell.label.translation = [x + 9, 9]
                            cell.label.width = 1
                            if width > 24 then cell.label.width = width - 18
                            cell.label.text = p.title
                            cell.label.visible = width > 24
                            cellIndex = cellIndex + 1
                        end if
                    end if
                end for
                row.empty.visible = cellIndex = 0
            end if
            for each cell in row.cells
                if cell.program <> invalid
                    focused = selected and cell.program.start <= m.guideCursor and cell.program.stop > m.guideCursor
                    cell.box.color = "0x202B31FF"
                    cell.label.color = "0xD8E5E2FF"
                    cell.label.font = m.guideDescription.font
                    if focused
                        cell.box.color = "0x39FF14FF"
                        cell.label.color = "0x0A1711FF"
                        cell.label.font = m.guideDetail.font
                    end if
                end if
            end for
        else if pageChanged
            row.logo.uri = ""
            row.programs = []
        end if
    end for
    m.guideRenderedPage = page
    m.guideRenderedTime = startTime
    m.guideRenderedRevision = m.guideDataRevision
    dt = CreateObject("roDateTime")
    now = dt.AsSeconds()
    dt.ToLocalTime()
    m.guideClock.text = dt.AsDateString("short-month-no-weekday") + "   " + guideTime(now)
    m.guideInfo.text = m.guideMessage + m.guideCoverage
    m.status.text = "Up/Down Channel | REW/FF A-Z | Left/Right Time | Replay Search | OK Watch | * Menu"
    m.guideNowLine.visible = now >= startTime and now < startTime + 10800
    if m.guideNowLine.visible then m.guideNowLine.translation = [302 + (now - startTime) / 12#, 0]
    if count = 0
        m.guideTitle.text = "No channels in this view"
        m.guideDetail.text = "Press Back to clear filters or return to countries."
        m.guideDescription.text = ""
        m.guideLogo.uri = ""
        return
    end if
    ch = m.displayList[m.guideIndex]
    uri = "pkg:/images/no_logo.png"
    if ch.logo <> invalid and ch.logo <> "" then uri = ch.logo
    if m.guideLogo.uri <> uri then m.guideLogo.uri = uri
    m.guideTitle.text = ch.name
    m.guideDetail.text = "Live channel · no programme information"
    m.guideDescription.text = "Listings are optional. This channel is still available to watch."
    for each p in guidePrograms(ch)
        if p.start <= m.guideCursor and p.stop > m.guideCursor
            m.guideTitle.text = p.title
            m.guideDetail.text = ch.name + "   ·   " + guideTime(p.start) + " – " + guideTime(p.stop)
            m.guideDescription.text = p.description
            exit for
        end if
    end for
    m.subtitle.text = count.ToStr() + " channels · " + (m.guideIndex + 1).ToStr() + " / " + count.ToStr() + " · LIVE GUIDE"
end sub

sub previewGuideChannel()
    if not m.guideActive or m.view <> "channels" then return
    if m.displayList.Count() = 0 then return
    requestPlayback(m.displayList[m.guideIndex], false)
end sub

function playerIdle(state as String) as Boolean
    return state = "none" or state = "stopped" or state = "finished" or state = "error" or state = ""
end function

sub requestPlayback(ch as Object, fullScreen as Boolean)
    if ch = invalid or ch.url = invalid or ch.url = "" then return
    m.previewTimer.control = "stop"
    if m.previewUrl = ch.url and m.video.visible and (m.video.state = "playing" or m.video.state = "buffering")
        return
    end if
    m.playRequest = {channel: ch, fullScreen: fullScreen}
    m.switchClock = CreateObject("roTimespan")
    m.previewWatchdog.control = "stop"
    if not playerIdle(m.video.state)
        m.releaseVideo = true
        m.video.visible = false
        m.video.control = "stop"
    end if
    m.switchTimer.control = "stop"
    m.switchTimer.control = "start"
end sub

sub startPendingPlayback()
    if m.playRequest = invalid then return
    if not playerIdle(m.video.state)
        if m.switchClock.TotalMilliseconds() < 5000
            m.switchTimer.control = "start"
        else
            m.playRequest = invalid
            m.guidePreview.text = "Player is still stopping · OK to retry"
            print "[zer0 player] stop timeout; refused overlapping tune"
        end if
        return
    end if
    request = m.playRequest
    m.playRequest = invalid
    if request.fullScreen
        if m.view <> "video" and m.view <> "playeropts" then return
    else
        if not m.guideActive or m.view <> "channels" then return
        if m.displayList.Count() = 0 then return
        if m.displayList[m.guideIndex].url <> request.channel.url then return
    end if
    m.video.content = invalid
    m.releaseVideo = false
    ch = request.channel
    m.playingChannel = ch
    content = CreateObject("roSGNode", "ContentNode")
    content.url = ch.url
    content.title = ch.name
    content.streamFormat = "hls"
    if epgString(ch.streamFormat) then content.streamFormat = ch.streamFormat
    content.live = ch.isMovie <> true
    m.video.content = content
    m.previewUrl = ch.url
    m.video.enableUI = false
    if request.fullScreen
        m.video.translation = [0, 0]
        m.video.width = 1280
        m.video.height = 720
    else
        m.video.translation = [900, 106]
        m.video.width = 336
        m.video.height = 189
        m.guidePreview.text = "Connecting · " + ch.name
        m.previewWatchdog.control = "start"
    end if
    m.video.visible = true
    m.video.control = "play"
end sub

sub stopGuidePlayback()
    m.playRequest = invalid
    m.switchTimer.control = "stop"
    m.previewWatchdog.control = "stop"
    m.releaseVideo = true
    m.video.visible = false
    m.previewUrl = ""
    m.video.control = "stop"
    if playerIdle(m.video.state)
        m.video.content = invalid
        m.releaseVideo = false
    end if
end sub

sub onVideoState()
    state = m.video.state
    if state = "stopped" or state = "none"
        if m.releaseVideo
            m.releaseVideo = false
            m.video.content = invalid
            m.previewUrl = ""
        end if
        if m.playRequest <> invalid then m.switchTimer.control = "start"
        return
    end if
    if state = "playing"
        m.previewWatchdog.control = "stop"
        if m.view = "video" then showNowPlayingBanner()
    end if
    if m.playRequest <> invalid then return
    if m.guideActive and m.view = "channels"
        if state = "playing"
            m.guidePreview.text = "LIVE   ·   OK / Play to expand"
        else if state = "buffering"
            m.guidePreview.text = "Buffering live preview…"
        else if state = "error" or state = "finished"
            stopGuidePlayback()
            m.guidePreview.text = "Preview unavailable · OK to retry"
            print "[zer0 player] preview ended/error · code="; m.video.errorCode
        end if
    else if m.view = "video" and (state = "error" or state = "finished")
        movieReturn = m.playerReturn = "movies"
        stopGuidePlayback()
        returnFromPlayer()
        if movieReturn
            message = "Playback ended. Choose another title or press OK to replay."
            if state = "error" then message = "Playback unavailable. Try another title or refresh the catalog."
            m.movieUI.callFunc("resumeBrowsing", message)
            return
        end if
        m.guidePreview.text = "Stream unavailable · OK to retry"
        m.status.text = "Stream unavailable or ended · choose another channel"
        print "[zer0 player] full-screen ended/error · code="; m.video.errorCode
    end if
end sub

sub onVideoError()
    if m.video.state = "error" then onVideoState()
end sub

sub onPreviewTimeout()
    if m.view <> "channels" or not m.guideActive then return
    if m.video.state = "playing" then return
    stopGuidePlayback()
    m.guidePreview.text = "Preview timed out · OK to retry"
    print "[zer0 player] preview timed out"
end sub

sub expandGuideVideo()
    if m.displayList.Count() = 0 then return
    ch = m.displayList[m.guideIndex]
    pushRecent(ch)
    m.playerReturn = "guide"
    m.previewTimer.control = "stop"
    m.previewWatchdog.control = "stop"
    m.view = "video"
    m.guide.visible = false
    m.video.translation = [0, 0]
    m.video.width = 1280
    m.video.height = 720
    m.video.enableUI = false
    focusPlayer()
    showNowPlayingBanner(ch)
    requestPlayback(ch, true)
end sub

sub returnFromPlayer()
    hidePlayerBanner()
    m.playerTrap.visible = false
    m.npTimer.control = "stop"
    m.npBar.visible = false
    m.npText.visible = false
    m.view = "channels"
    if m.playerReturn = "movies"
        stopGuidePlayback()
        m.view = "movies"
        m.movieUI.callFunc("resumeBrowsing")
    else if m.playerReturn = "guide" and m.guideActive
        if m.playRequest <> invalid then m.playRequest.fullScreen = false
        m.guide.visible = true
        m.video.translation = [900, 106]
        m.video.width = 336
        m.video.height = 189
        m.video.enableUI = false
        if m.video.state = "buffering" then m.previewWatchdog.control = "start"
        m.guideTrap.setFocus(true)
        onGuideTick()
    else
        stopGuidePlayback()
        m.list.visible = true
        m.list.setFocus(true)
        if m.selectedCountry <> invalid then m.title.text = m.selectedCountry.name
        m.subtitle.text = m.displayList.Count().ToStr() + " channels"
    end if
end sub

sub focusChannels()
    if m.view = "sources" and m.sourceMenu <> invalid
        m.sourceMenu.setFocus(true)
    else if m.guideActive
        m.guideTrap.setFocus(true)
        if not m.video.visible
            m.previewTimer.control = "stop"
            m.previewTimer.control = "start"
        end if
    else
        m.list.setFocus(true)
    end if
end sub

sub onGuideTick()
    if m.guideActive and m.view = "channels"
        now = CreateObject("roDateTime").AsSeconds()
        if Abs(m.guideCursor - m.guideEpoch) < 120 then m.guideCursor = now
        m.guideEpoch = now
        if m.guideFetched > 0 and now - m.guideFetched >= 1800
            m.guideCountry = ""
            m.guideFetched = now
            loadCountryGuide()
        end if
        drawGuide()
    end if
end sub

function guideKey(key as String) as Boolean
    if key = "up" or key = "down"
        delta = 1
        if key = "up" then delta = -1
        m.guideIndex = m.guideIndex + delta
        if m.guideIndex < 0 then m.guideIndex = 0
        if m.guideIndex >= m.displayList.Count() then m.guideIndex = m.displayList.Count() - 1
        drawGuide()
        m.previewTimer.control = "stop"
        m.previewTimer.control = "start"
        return true
    else if key = "fastforward" or key = "rewind"
        direction = 1
        if key = "rewind" then direction = -1
        target = nextGuideLetterIndex(m.displayList, m.guideLetters, m.guideIndex, direction)
        if target >= 0
            m.guideIndex = target
            drawGuide()
            m.guideChannelHeading.text = "CHANNEL " + channelLetter(m.displayList[target].name) + " | REW/FF"
            m.previewTimer.control = "stop"
            m.previewTimer.control = "start"
        end if
        return true
    else if key = "left" or key = "right"
        delta = 1800
        if key = "left" then delta = -delta
        m.guideCursor = m.guideCursor + delta
        if m.guideCursor < m.guideEpoch - 900 then m.guideCursor = m.guideEpoch - 900
        if m.guideCursor > m.guideEpoch + 10800 then m.guideCursor = m.guideEpoch + 10800
        drawGuide()
        return true
    else if key = "OK" or key = "play"
        if m.displayList.Count() > 0
            if key = "play" or (m.previewUrl = m.displayList[m.guideIndex].url and m.video.state = "playing")
                expandGuideVideo()
            else
                previewGuideChannel()
            end if
        end if
        return true
    else if key = "replay"
        openSearch()
        return true
    end if
    return false
end function


sub cancelCountryGuide()
    if m.epgTask <> invalid
        m.epgTask.cancelled = true
    end if
    m.guidePending = invalid
    m.guideCountry = ""
    m.guideDataIdentity = ""
    m.guideData = {}
    m.guideDataRevision = m.guideDataRevision + 1
end sub
