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
    m.guideGroup = m.top.findNode("guideGroup")
    m.guideTime = m.top.findNode("guideTime")
    m.guideProgress = m.top.findNode("guideProgress")
    m.guideNext = m.top.findNode("guideNext")
    m.guideNextText = m.top.findNode("guideNextText")
    m.guidePast = m.top.findNode("guidePast")
    m.guideNowLine = m.top.findNode("guideNowLine")
    m.guideRowsBg = m.top.findNode("guideRowsBg")
    m.guideRollBg = m.top.findNode("guideRollBg")
    m.guideRollText = m.top.findNode("guideRollText")
    m.guideRollAnim = m.top.findNode("guideRollAnim")
    m.guideRollAnim.observeField("state", "onGuideRollState")
    m.guideScanChip = m.top.findNode("guideScanChip")
    m.top.findNode("guideScanText").font = glowFont("bold", 17)
    m.guideScan = false
    m.guideRollTimer = CreateObject("roSGNode", "Timer")
    m.guideRollTimer.duration = 4
    m.guideRollTimer.repeat = true
    m.guideRollTimer.observeField("fire", "onGuideRollTick")
    m.guideFeatureTimer = CreateObject("roSGNode", "Timer")
    m.guideFeatureTimer.duration = 45
    m.guideFeatureTimer.repeat = true
    m.guideFeatureTimer.observeField("fire", "onGuideFeature")
    m.guideOver = m.top.findNode("guideOver")
    m.guideNumber = m.top.findNode("guideNumber")
    m.glowHeaderNode = m.top.findNode("glowHeader")
    m.guideDetail.font = glowFont("bold", 22)
    m.guideGroup.font = glowFont("regular", 20)
    m.top.findNode("guideNowTag").font = glowFont("bold", 19)
    m.guideTime.font = glowFont("regular", 22)
    m.guideDescription.font = glowFont("regular", 22)
    m.top.findNode("guideNextChip").font = glowFont("bold", 19)
    m.guideNextText.font = glowFont("regular", 20)
    m.guideChannelHeading.font = glowFont("bold", 19)
    m.guidePreview.font = glowFont("bold", 22)
    m.top.findNode("guideLiveText").font = glowFont("bold", 18)
    m.guideNumber.font = glowFont("bold", 40)
    ' Keys as in Spelunkr: up/down channel, left/right a letter, REW/FF the time.
    glowHints(m.top.findNode("guideHints"), [{icons: ["dpad-updown"], text: "CHANNEL"}, {icons: ["dpad-leftright"], text: "A-Z"}, {icons: ["rewind", "forward"], text: "TIME"}, {icons: ["ok"], text: "WATCH"}, {icons: ["playpause"], text: "SCAN"}, {icons: ["replay"], text: "SEARCH"}, {icons: ["star"], text: "MENU"}, {icons: ["back"], text: "COUNTRIES"}])
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
    m.guideTimer.duration = 15
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
    m.epgTask.observeField("early", "onGuideEarly")
    m.guideRenderedPage = -1
    m.guideRenderedTime = -1
    m.guideDataRevision = 0
    m.guideRenderedRevision = -1
    initGuidePool()
end sub

function countryForGuide() as String
    if m.selectedCountry = invalid then return ""
    code = LCase(m.selectedCountry.code)
    if m.source = "freetv"
        regions = ParseJson(ReadAsciiFile("pkg:/config/freetv-regions.json"))
        if type(regions) = "roAssociativeArray"
            if regions.DoesExist(m.selectedCountry.name) then return regions[m.selectedCountry.name]
        end if
    end if
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
    if isLiveProvider(m.source) and base <> "" then base = base + "/providers/" + m.source
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
    if isLiveProvider(request.provider)
        m.epgTask.xmlUrl = providerCountry(m.providers[request.provider], request.code).liveEpgUrl
    else
        feeds = ParseJson(ReadAsciiFile("pkg:/config/epg-sources.json"))
        if type(feeds) = "roAssociativeArray"
            if feeds.DoesExist(request.code) then m.epgTask.xmlUrl = feeds[request.code].Replace(".gz", "")
        end if
    end if
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

' The guide saved earlier on this Roku, while the fresh one loads.
sub onGuideEarly()
    if m.epgTask = invalid or m.epgTask.cancelled then return
    early = m.epgTask.early
    if type(early) <> "roAssociativeArray" or type(early.schedules) <> "roAssociativeArray" then return
    if m.guideDataIdentity = m.guideCountry and m.guideData <> invalid and m.guideData.schedules <> invalid and m.guideData.schedules.Count() > 0 then return
    m.guideData = early
    m.guideDataIdentity = m.guideCountry
    m.guideDataRevision = m.guideDataRevision + 1
    m.guideMessage = "Guide updating"
    if m.guideActive and m.view = "channels" then drawGuide()
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
    setGlowScreen(true)
    m.guide.visible = true
    m.guideOver.visible = true
    m.top.findNode("guideLiveBlink").control = "start"
    m.list.visible = false
    m.guideTrap.setFocus(true)
    m.guideIndex = 0
    m.guideLetters = buildGuideLetterIndex(m.displayList)
    m.guideChannelHeading.text = "CHANNEL"
    m.guideRenderedPage = -1
    m.logo.uri = ""
    m.lastLogoUrl = ""
    m.guideEpoch = CreateObject("roDateTime").AsSeconds()
    m.guideCursor = m.guideEpoch
    loadCountryGuide()
    drawGuide()
    m.guideTimer.control = "start"
    if m.displayList.Count() > 0
        m.guidePreview.text = ""
        m.previewTimer.control = "start"
    else
        stopGuidePlayback()
        m.guidePreview.text = "No channels match this filter"
    end if
end sub

' The video sits outside the 1280 x 720 shell, so it is placed in 1080p coordinates.
' Video placement in 1080p coordinates (full screen is 0, 0, 1920, 1080).
sub placeVideo(x as Integer, y as Integer, w as Integer, h as Integer)
    m.video.translation = [x, y]
    m.video.width = w
    m.video.height = h
end sub

' The guide's live preview box.
sub placePreviewVideo()
    placeVideo(60, 111, 588, 330)
end sub

sub hideGuide()
    stopGuideScan()
    m.guideActive = false
    if m.guide.visible then setGlowScreen(false)
    m.guide.visible = false
    if m.guideOver <> invalid then m.guideOver.visible = false
    if m.top <> invalid
        blink = m.top.findNode("guideLiveBlink")
        if blink <> invalid then blink.control = "stop"
    end if
    m.previewTimer.control = "stop"
    m.guideTimer.control = "stop"
    m.guideRenderedPage = -1
    for each row in m.guidePool
        row.logo.uri = ""
        row.programs = []
        for each cell in row.cells
            cell.program = invalid
            cell.label.text = ""
            cell.sub.text = ""
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
        ' The playlist's own id, matched by the guide builder.
        if ch.guideId <> "" and m.guideData.aliases.DoesExist(ch.guideId)
            id = m.guideData.aliases[ch.guideId]
            if schedules.DoesExist(id) then return schedules[id]
        end if
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
    node.font = glowFont("regular", 20)
    if bold then node.font = glowFont("bold", 20)
    return node
end function

' Rounded tile (card art tinted to a colour).
function guideTile(parent as Object, x as Float, y as Float, width as Float, height as Float, color as String) as Object
    node = parent.createChild("Poster")
    node.uri = "pkg:/images/glow/card.9.png"
    node.translation = [x, y]
    node.width = width
    node.height = height
    node.blendColor = color
    return node
end function

' "1h 33m", "45m"
function guideDuration(seconds as Integer) as String
    if seconds < 60 then seconds = 60
    minutes = Int(seconds / 60)
    if minutes < 60 then return minutes.ToStr() + "m"
    text = Int(minutes / 60).ToStr() + "h"
    if minutes mod 60 > 0 then text = text + " " + (minutes mod 60).ToStr() + "m"
    return text
end function

' Descriptions in the listings files are often cut short mid-word (they are
' kept small). Shows whole sentences where possible, else whole words, never
' a broken word or an added "...". limit: the most characters that fit.
function guideTrim(text as String, limit as Integer) as String
    text = text.Trim()
    cut = text
    if Len(cut) > limit then cut = Left(cut, limit)
    last = Right(cut, 1)
    ended = last = "." or last = "!" or last = "?" or last = Chr(34) or last = ")"
    ' Short texts that fit are complete; long ones with no ending were cut.
    if Len(cut) = Len(text) and (ended or Len(text) < 78) then return cut
    best = 0
    for i = Len(cut) - 1 to 1 step -1
        c = Mid(cut, i, 1)
        if c = "." or c = "!" or c = "?"
            after = Mid(cut, i + 1, 1)
            if after = Chr(34) or after = ")"
                if Mid(cut, i + 2, 1) = " " then best = i + 1
            else if after = " "
                best = i
            end if
            if best > 0 then exit for
        end if
    end for
    if best >= Len(cut) * 0.3 then return Left(cut, best)
    ' No sentence to end on: drop the last (possibly broken) word.
    for i = Len(cut) to 1 step -1
        if Mid(cut, i, 1) = " " then return Left(cut, i - 1).Trim()
    end for
    return cut
end function

function guideRect(parent as Object, x as Float, y as Float, width as Float, height as Float, color as String) as Object
    node = parent.createChild("Rectangle")
    node.translation = [x, y]
    node.width = width
    node.height = height
    node.color = color
    return node
end function

function guideWindow() as Integer
    return 7200
end function

' Row pitch and the x where programmes start (inside guideRows).
function guidePitch() as Integer
    return 92
end function

' Channels a page.
function guideRowsPerPage() as Integer
    return 5
end function

function guideLeft() as Integer
    return 420
end function

' x (inside the rows) for a time: two hours over the 1380 px after the channels.
function guideX(seconds as Integer, startTime as Integer) as Float
    return guideLeft() + (seconds - startTime) * 0.19166667
end function

sub initGuidePool()
    m.guidePool = []
    m.guideTimeLabels = []
    for slot = 0 to 3
        guideRect(m.guideTimes, slot * 345, 4, 2, 32, "0x8391AA40")
        label = guideLabel(m.guideTimes, "", slot * 345 + 14, 0, 300, "0xDCE4F2FF", true)
        label.height = 40
        label.vertAlign = "center"
        label.font = glowFont("bold", 21)
        m.guideTimeLabels.Push(label)
    end for
    ' The small marker over the time row where "now" is (as in Spelunkr).
    m.guideMarker = m.guideTimes.createChild("Poster")
    m.guideMarker.uri = "pkg:/images/glow/now-marker.png"
    m.guideMarker.width = 18
    m.guideMarker.height = 12
    m.guideMarker.blendColor = "0x00C8FFFF"
    m.guideMarker.translation = [0, 36]
    ' Tiles go in their own layer under the now line; text goes above it.
    tiles = m.guideRowsBg
    if tiles = invalid then tiles = m.guideRows
    for index = 0 to guideRowsPerPage()
        group = m.guideRows.createChild("Group")
        group.translation = [0, index * guidePitch()]
        back = tiles.createChild("Group")
        back.translation = [0, index * guidePitch()]
        row = {group: group, back: back, cells: [], channelIndex: -1, programs: []}
        row.background = guideTile(back, 0, 4, 410, 84, "0x0E1520FF")
        row.selection = guideRect(back, 0, 89, 410, 2, "0x39FF14FF")
        row.edge = guideRect(group, 0, 20, 5, 52, "0x39FF14FF")
        ' Wide enough for four digits (1500): numbers are never cut short.
        row.number = guideLabel(group, "", 2, 4, 66, "0x8391AAFF", true)
        row.number.height = 84
        row.number.vertAlign = "center"
        row.number.horizAlign = "center"
        row.number.font = glowFont("bold", 26)
        row.logo = group.createChild("Poster")
        row.logo.translation = [70, 4]
        row.logo.width = 138
        row.logo.height = 84
        row.logo.loadWidth = 320
        row.logo.loadHeight = 168
        row.logo.loadDisplayMode = "scaleToFit"
        row.fav = group.createChild("Poster")
        row.fav.uri = "pkg:/images/glow/pin.png"
        row.fav.translation = [190, 6]
        row.fav.width = 26
        row.fav.height = 26
        row.name = guideLabel(group, "", 214, 4, 188, "0xC3CDDEFF", true)
        row.name.height = 84
        row.name.vertAlign = "center"
        row.name.wrap = true
        row.name.maxLines = 2
        row.empty = guideLabel(group, "No listings  ·  OK to watch live", guideLeft() + 20, 4, 900, "0x8391AAFF")
        row.empty.height = 84
        row.empty.vertAlign = "center"
        row.empty.font = glowFont("regular", 22)
        ' Started before the window: a small arrow before the title.
        row.arrow = group.createChild("Poster")
        row.arrow.uri = "pkg:/images/glow/arrow-left.png"
        row.arrow.width = 12
        row.arrow.height = 21
        row.arrow.visible = false
        for cell = 0 to 11
            tile = guideTile(back, 0, 4, 1, 84, "0x121A26FF")
            label = guideLabel(group, "", 0, 13, 1, "0xAEB9CCFF", true)
            label.height = 34
            label.font = glowFont("bold", 24)
            label.ellipsisText = " "
            detail = guideLabel(group, "", 0, 50, 1, "0x8391AAFF")
            detail.height = 26
            detail.font = glowFont("regular", 19)
            detail.ellipsisText = " "
            tile.visible = false
            label.visible = false
            detail.visible = false
            row.cells.Push({box: tile, label: label, sub: detail, program: invalid})
        end for
        m.guidePool.Push(row)
    end for
end sub

sub drawGuide()
    if not m.guideActive then return
    colors = glowColors()
    count = m.displayList.Count()
    if m.guideIndex >= count then m.guideIndex = count - 1
    if m.guideIndex < 0 then m.guideIndex = 0
    window = guideWindow()
    ' The window starts half an hour before the cursor's half hour, so "now"
    ' sits in the left part of the grid with what has aired shaded.
    startTime = Int(m.guideCursor / 1800#) * 1800 - 1800
    perPage = guideRowsPerPage()
    if m.guideTop = invalid then m.guideTop = 0
    if m.guideScan <> true
        if m.guideIndex < m.guideTop then m.guideTop = m.guideIndex
        if m.guideIndex > m.guideTop + perPage - 1 then m.guideTop = m.guideIndex - perPage + 1
    end if
    if m.guideTop > count - 1 then m.guideTop = count - 1
    if m.guideTop < 0 then m.guideTop = 0
    page = m.guideTop
    rebuild = page <> m.guideRenderedPage or startTime <> m.guideRenderedTime or m.guideDataRevision <> m.guideRenderedRevision
    pageChanged = page <> m.guideRenderedPage
    if rebuild
        for slot = 0 to 3
            m.guideTimeLabels[slot].text = guideTime(startTime + slot * 1800)
        end for
    end if
    now = CreateObject("roDateTime").AsSeconds()
    for rowIndex = 0 to m.guidePool.Count() - 1
        row = m.guidePool[rowIndex]
        index = page + rowIndex
        ' Scan wraps round the lineup.
        if m.guideScan = true and count > 0 then index = index mod count
        row.group.visible = index < count
        row.back.visible = index < count
        if index < count
            ch = m.displayList[index]
            selected = index = m.guideIndex
            ' The whole row is the selection (no single programme is focused).
            row.background.blendColor = "0x0E1520FF"
            row.number.color = colors.muted
            row.name.color = colors.hint
            if selected
                row.background.blendColor = "0x17283CFF"
                row.number.color = colors.green
                row.name.color = colors.white
            end if
            row.edge.visible = selected
            row.selection.visible = selected
            row.number.text = (index + 1).ToStr()
            row.number.font = glowFont("bold", 26)
            if Len(row.number.text) >= 4 then row.number.font = glowFont("bold", 21)
            name = ch.name
            row.fav.visible = isFavorite(ch.url)
            row.name.text = name
            row.name.font = glowFont("bold", 24)
            if Len(name) > 13 then row.name.font = glowFont("bold", 21)
            if Len(name) > 22 then row.name.font = glowFont("bold", 18)
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
                    cell.sub.visible = false
                    cell.program = invalid
                end for
                row.arrow.visible = false
                cellIndex = 0
                for each p in row.programs
                    if p.stop > startTime and p.start < startTime + window
                        leftTime = p.start
                        rightTime = p.stop
                        if leftTime < startTime then leftTime = startTime
                        if rightTime > startTime + window then rightTime = startTime + window
                        x = guideX(leftTime, startTime)
                        width = guideX(rightTime, startTime) - x - 6
                        if width >= 18 and cellIndex < row.cells.Count()
                            cell = row.cells[cellIndex]
                            cell.program = p
                            cell.box.translation = [x, 4]
                            cell.box.width = width
                            cell.box.visible = true
                            textX = x + 16
                            if p.start < startTime
                                ' Started earlier: an arrow, then the title from the edge.
                                row.arrow.translation = [x + 12, 22]
                                row.arrow.visible = width > 60
                                textX = x + 34
                            end if
                            textWidth = x + width - textX - 14
                            if textWidth < 1 then textWidth = 1
                            cell.label.translation = [textX, 13]
                            cell.sub.translation = [textX, 50]
                            cell.label.width = textWidth
                            cell.sub.width = textWidth
                            cell.label.text = p.title
                            detail = guideDuration(p.stop - p.start)
                            if p.start < startTime then detail = "from " + guideTime(p.start)
                            cell.sub.text = detail
                            cell.label.visible = textWidth > 30
                            cell.sub.visible = textWidth > 80
                            cellIndex = cellIndex + 1
                        end if
                    end if
                end for
                row.empty.visible = cellIndex = 0
            end if
            for each cell in row.cells
                if cell.program <> invalid
                    airing = cell.program.start <= now and cell.program.stop > now
                    finished = cell.program.stop <= now
                    cell.box.blendColor = colors.cell
                    cell.label.color = colors.soft
                    cell.sub.color = colors.muted
                    if airing
                        cell.box.blendColor = colors.airing
                        cell.label.color = colors.white
                    else if finished
                        cell.box.blendColor = "0x101823FF"
                        cell.label.color = "0x9AA6BBFF"
                        cell.sub.color = "0x6B7891FF"
                    end if
                    if selected
                        ' The selected row reads a step brighter.
                        if airing
                            cell.box.blendColor = "0x24405EFF"
                        else if finished
                            cell.box.blendColor = "0x16233AFF"
                        else
                            cell.box.blendColor = "0x1C2B40FF"
                        end if
                        cell.label.color = colors.white
                        if not finished then cell.sub.color = "0x9FFFB0FF"
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
    dt.ToLocalTime()
    m.guideClock.text = dt.AsDateString("short-month-no-weekday") + "   " + guideTime(now)
    m.guideInfo.text = m.guideMessage + m.guideCoverage
    m.status.text = "Up/Down Channel | Left/Right A-Z | REW/FF Time | Replay Search | OK Watch | * Menu"
    drawGuideNow(startTime, now, count)
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
    number = (m.guideIndex + 1).ToStr()
    m.guideDetail.text = number + "  ·  " + UCase(ch.name)
    if m.guideNumber <> invalid then m.guideNumber.text = number
    if m.guideGroup <> invalid
        group = ""
        if ch.group <> invalid then group = ch.group
        m.guideGroup.text = group
    end if
    if m.glowHeaderNode <> invalid and m.selectedCountry <> invalid
        m.glowHeaderNode.info = m.selectedCountry.name + "  ·  " + count.ToStr() + " channels"
    end if
    programs = guidePrograms(ch)
    current = invalid
    upcoming = invalid
    for each p in programs
        if current = invalid and p.start <= m.guideCursor and p.stop > m.guideCursor
            current = p
        else if current <> invalid and p.start >= current.stop
            upcoming = p
            exit for
        end if
    end for
    if current = invalid
        guideSetTitle(ch.name)
        m.guideDescription.text = ""
        if m.guideTime <> invalid then m.guideTime.text = "Live channel  ·  no programme listings"
        guideShowProgress(-1)
        if m.guideNext <> invalid then m.guideNext.visible = false
        return
    end if
    guideSetTitle(current.title)
    m.guideDescription.text = guideTrim(current.description, 160)
    if m.guideTime <> invalid
        line = guideTime(current.start) + " – " + guideTime(current.stop)
        if current.start <= now and current.stop > now
            line = line + "   ·   " + guideDuration(current.stop - now) + " left"
        else if current.start > now
            line = line + "   ·   starts in " + guideDuration(current.start - now)
        end if
        m.guideTime.text = line
    end if
    done = 0
    if now >= current.stop then done = 1
    if now > current.start and now < current.stop then done = (now - current.start) / (current.stop - current.start)
    guideShowProgress(done)
    if m.guideNext <> invalid
        m.guideNext.visible = upcoming <> invalid
        if upcoming <> invalid then m.guideNextText.text = guideTime(upcoming.start) + "   ·   " + upcoming.title
    end if
end sub

' Progress bar (0 to 1); below 0 hides it along with its track.
sub guideShowProgress(done as Float)
    if m.guideProgress = invalid then return
    track = m.top.findNode("guideTrack")
    track.visible = done >= 0
    width = Int(840 * done)
    m.guideProgress.visible = width >= 4
    if width >= 4 then m.guideProgress.width = width
end sub

' Title in the now-playing panel: smaller for long titles, never cut short.
sub guideSetTitle(text as String)
    m.guideTitle.text = text
    size = 44
    if Len(text) > 28 then size = 36
    if Len(text) > 38 then size = 30
    if Len(text) > 48 then size = 25
    m.guideTitle.font = glowFont("bold", size)
end sub

' The now line, its glow, the shaded past and the time pill above the grid.
' The thin now line (over the tiles, under the text), the shaded past and the
' small marker in the time row, as in Spelunkr.
sub drawGuideNow(startTime as Integer, now as Integer, count as Integer)
    if m.guideNowLine = invalid then return
    perPage = guideRowsPerPage()
    rows = perPage
    if m.guideScan <> true then rows = count - m.guideTop
    if rows > perPage then rows = perPage
    if rows < 1 then rows = 1
    height = rows * guidePitch()
    inView = now >= startTime and now < startTime + guideWindow()
    x = guideX(now, startTime)
    m.guideNowLine.visible = inView
    m.guideMarker.visible = inView
    m.guidePast.visible = now > startTime
    pastWidth = x - guideLeft()
    if pastWidth > 1380 then pastWidth = 1380
    if pastWidth < 0 then pastWidth = 0
    m.guidePast.width = pastWidth
    m.guidePast.height = height
    if inView
        m.guideNowLine.translation = [x - 1, 0]
        m.guideNowLine.height = height
        m.guideMarker.translation = [x - guideLeft() - 9, 34]
    end if
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
    ' A note from the last channel ("No picture") never shows over the next.
    if not fullScreen then m.guidePreview.text = ""
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
    m.video.subtitleTrack = ""
    m.video.audioTrack = ""
    m.releaseVideo = false
    ch = request.channel
    m.playingChannel = ch
    content = CreateObject("roSGNode", "ContentNode")
    content.url = ch.url
    ' The preview has no title for Roku's player to draw over the picture.
    content.title = ""
    if request.fullScreen then content.title = ch.name
    content.streamFormat = "hls"
    if epgString(ch.streamFormat) then content.streamFormat = ch.streamFormat
    content.live = ch.isMovie <> true
    if ch.isMovie = true
        content.contentType = "movie"
        if type(ch.subtitleTracks) = "roArray" then content.subtitleTracks = ch.subtitleTracks
        if epgNumber(ch.resumePosition) then content.playStart = ch.resumePosition
    end if
    content.httpHeaders = []
    if type(ch.httpHeaders) = "roArray" then content.httpHeaders = ch.httpHeaders
    content.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    m.video.content = content
    m.video.autoPlayAfterSeek = true
    m.seekActive = false
    m.resumeMoviePaused = ch.resumePaused = true
    if epgString(ch.selectedAudio) then m.video.audioTrack = ch.selectedAudio
    if epgString(ch.selectedSubtitle) then m.video.subtitleTrack = ch.selectedSubtitle
    m.previewUrl = ch.url
    m.video.enableUI = false
    if request.fullScreen
        placeVideo(0, 0, 1920, 1080)
    else
        placePreviewVideo()
        m.guidePreview.text = ""
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
        if m.resumeMoviePaused = true
            m.resumeMoviePaused = false
            m.video.control = "pause"
        end if
        if m.view = "video" then showNowPlayingBanner()
    end if
    if state = "paused" and m.view = "video" then showNowPlayingBanner()
    if m.playRequest <> invalid then return
    if m.guideActive and m.view = "channels"
        if state = "playing"
            m.guidePreview.text = ""
        else if state = "buffering"
            m.guidePreview.text = ""
        else if state = "error" or state = "finished"
            stopGuidePlayback()
            m.guidePreview.text = "No picture  ·  OK to retry"
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
    m.guidePreview.text = "No picture  ·  OK to retry"
    print "[zer0 player] preview timed out"
end sub

sub expandGuideVideo()
    stopGuideScan()
    if m.displayList.Count() = 0 then return
    ch = m.displayList[m.guideIndex]
    pushRecent(ch)
    m.playerReturn = "guide"
    m.previewTimer.control = "stop"
    m.previewWatchdog.control = "stop"
    m.view = "video"
    m.guide.visible = false
    if m.guideOver <> invalid then m.guideOver.visible = false
    placeVideo(0, 0, 1920, 1080)
    m.video.enableUI = false
    focusPlayer()
    showNowPlayingBanner(ch)
    requestPlayback(ch, true)
end sub

sub returnFromPlayer()
    m.seekActive = false
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
        if m.guideOver <> invalid then m.guideOver.visible = true
        placePreviewVideo()
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
            m.guidePreview.text = ""
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
    if m.guideScan = true
        if key = "play"
            stopGuideScan()
        else if key = "OK"
            stopGuideScan()
            expandGuideVideo()
        else
            ' The first press stops Scan where it is.
            stopGuideScan()
        end if
        return true
    end if
    if key = "play"
        startGuideScan()
        return true
    end if
    if key = "up" or key = "down"
        delta = 1
        if key = "up" then delta = -1
        m.guideIndex = m.guideIndex + delta
        if m.guideIndex < 0 then m.guideIndex = 0
        if m.guideIndex >= m.displayList.Count() then m.guideIndex = m.displayList.Count() - 1
        drawGuide()
        m.previewTimer.control = "stop"
        m.guidePreview.text = ""
        m.previewTimer.control = "start"
        return true
    else if key = "right" or key = "left"
        direction = 1
        if key = "left" then direction = -1
        target = nextGuideLetterIndex(m.displayList, m.guideLetters, m.guideIndex, direction)
        if target >= 0
            m.guideIndex = target
            m.guideTop = target
            drawGuide()
            m.guideChannelHeading.text = "CHANNEL  ·  " + channelLetter(m.displayList[target].name)
            m.previewTimer.control = "stop"
            m.guidePreview.text = ""
            m.previewTimer.control = "start"
        end if
        return true
    else if key = "fastforward" or key = "rewind"
        delta = 1800
        if key = "rewind" then delta = -delta
        m.guideCursor = m.guideCursor + delta
        if m.guideCursor < m.guideEpoch - 900 then m.guideCursor = m.guideEpoch - 900
        if m.guideCursor > m.guideEpoch + 21600 then m.guideCursor = m.guideEpoch + 21600
        drawGuide()
        return true
    else if key = "OK"
        if m.displayList.Count() > 0
            if m.previewUrl = m.displayList[m.guideIndex].url and m.video.state = "playing"
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

' ---- Scan (Play in the guide), as in Spelunkr ---------------------------------
' The rows roll up one channel every 4 seconds, wrapping round the lineup, and
' every 45 seconds the channel at the top is shown in the preview.

sub startGuideScan()
    if not m.guideActive or m.displayList.Count() < 2 then return
    m.guideScan = true
    if m.guideScanChip <> invalid then m.guideScanChip.visible = true
    m.guideRollTimer.control = "start"
    m.guideFeatureTimer.control = "start"
end sub

sub stopGuideScan()
    if m.guideScan <> true then return
    m.guideScan = false
    m.guideRollTimer.control = "stop"
    m.guideFeatureTimer.control = "stop"
    m.guideRollAnim.control = "stop"
    m.guideRollBg.translation = [0, 0]
    m.guideRollText.translation = [0, 0]
    if m.guideScanChip <> invalid then m.guideScanChip.visible = false
    ' Keep the rows where Scan left them; the cursor goes to the top channel
    ' unless the featured one is still on screen.
    count = m.displayList.Count()
    onScreen = false
    for slot = 0 to guideRowsPerPage() - 1
        if count > 0 and (m.guideTop + slot) mod count = m.guideIndex then onScreen = true
    end for
    if not onScreen then m.guideIndex = m.guideTop
    if m.guideTop + guideRowsPerPage() > count
        ' The rolled rows wrapped past the end: show a normal page there.
        m.guideTop = m.guideIndex
    end if
    m.guideRenderedPage = -1
    drawGuide()
    m.previewTimer.control = "stop"
    m.guidePreview.text = ""
    m.previewTimer.control = "start"
end sub

sub onGuideRollTick()
    if m.guideScan <> true or m.view <> "channels" then return
    if m.guideRollAnim.state = "running" then return
    m.guideRollAnim.control = "start"
end sub

sub onGuideRollState()
    if m.guideRollAnim.state <> "stopped" or m.guideScan <> true then return
    count = m.displayList.Count()
    if count = 0 then return
    m.guideTop = (m.guideTop + 1) mod count
    m.guideRollBg.translation = [0, 0]
    m.guideRollText.translation = [0, 0]
    drawGuide()
end sub

sub onGuideFeature()
    if m.guideScan <> true or m.view <> "channels" then return
    m.guideIndex = m.guideTop
    drawGuide()
    previewGuideChannel()
end sub

