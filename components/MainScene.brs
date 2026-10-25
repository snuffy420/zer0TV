sub init()
    m.list = m.top.findNode("list")
    m.status = m.top.findNode("status")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.video = m.top.findNode("video")
    m.logo = m.top.findNode("logo")
    m.previewName = m.top.findNode("previewName")
    m.previewMeta = m.top.findNode("previewMeta")
    m.panelHelp = m.top.findNode("panelHelp")
    m.loadBg = m.top.findNode("loadBg")
    m.loadText = m.top.findNode("loadText")
    m.optsBg = m.top.findNode("optsBg")
    m.optsBox = m.top.findNode("optsBox")
    m.optsBoxEdge = m.top.findNode("optsBoxEdge")
    m.optsTitle = m.top.findNode("optsTitle")
    m.optsList = m.top.findNode("optsList")
    m.npBar = m.top.findNode("npBar")
    m.npText = m.top.findNode("npText")

    m.searchBg = m.top.findNode("searchBg")
    m.searchPanel = m.top.findNode("searchPanel")
    m.searchPanelEdge = m.top.findNode("searchPanelEdge")
    m.searchTitle = m.top.findNode("searchTitle")
    m.searchHint = m.top.findNode("searchHint")
    m.searchBarBg = m.top.findNode("searchBarBg")
    m.searchBarEdge = m.top.findNode("searchBarEdge")
    m.searchQuery = m.top.findNode("searchQuery")
    m.searchResults = m.top.findNode("searchResults")
    m.searchList = m.top.findNode("searchList")
    m.kbDisplay = m.top.findNode("kbDisplay")
    m.kbFooter = m.top.findNode("kbFooter")
    m.kbTrap = m.top.findNode("kbTrap")
    m.npTimer = CreateObject("roSGNode", "Timer")
    m.npTimer.repeat = false
    m.npTimer.duration = 3
    m.npTimer.observeField("fire", "hideNowPlayingBar")
    m.captionsOn = false

    m.view = "sources"
    m.source = "" ' iptvorg | freetv
    m.searchFocus = "keyboard"
    m.countries = []
    m.channels = []
    m.allChannels = [] ' full FreeTV playlist in memory
    m.displayList = []
    m.selectedCountry = invalid
    m.searchText = ""
    m.lastLogoUrl = ""
    m.groups = []
    m.activeGroup = ""
    m.favorites = loadFavorites()
    m.recents = loadRecents()
    m.kbRow = 0
    m.kbCol = 0
    m.kbLayout = getKeyboardLayout()
    m.optActions = []
    m.optIndex = 0

    m.list.observeField("itemSelected", "onItemSelected")
    m.list.observeField("itemFocused", "onItemFocused")
    m.optsList.observeField("itemSelected", "onOptsSelected")
    m.searchList.observeField("itemSelected", "onSearchListSelected")

    showSourcePicker()
    m.top.setFocus(true)
    m.list.setFocus(true)
end sub

function loadFavorites() as Object
    reg = CreateObject("roRegistrySection", "iptv_fav")
    raw = reg.Read("urls")
    map = {}
    if raw = invalid or raw = "" then return map
    for each p in raw.Split(Chr(10))
        p = p.Trim()
        if p <> "" then map.AddReplace(p, true)
    end for
    return map
end function

sub saveFavorites()
    reg = CreateObject("roRegistrySection", "iptv_fav")
    lines = []
    for each k in m.favorites
        lines.Push(k)
    end for
    reg.Write("urls", lines.Join(Chr(10)))
    reg.Flush()
end sub

function loadRecents() as Object
    reg = CreateObject("roRegistrySection", "iptv_recent")
    raw = reg.Read("list")
    arr = []
    if raw = invalid or raw = "" then return arr
    for each p in raw.Split(Chr(10))
        p = p.Trim()
        if p = "" then continue for
        parts = p.Split("|")
        if parts.count() >= 2
            logo = ""
            if parts.count() > 2 then logo = parts[2]
            arr.Push({ name: parts[0], url: parts[1], logo: logo, group: "Recent" })
        end if
    end for
    return arr
end function

sub pushRecent(ch as Object)
    if ch = invalid or ch.url = invalid then return
    url = ch.url + ""
    newList = []
    newList.Push({ name: ch.name, url: url, logo: ch.logo, group: "Recent" })
    for each r in m.recents
        if r.url <> url then newList.Push(r)
        if newList.count() >= 15 then exit for
    end for
    m.recents = newList
    reg = CreateObject("roRegistrySection", "iptv_recent")
    lines = []
    for each r in m.recents
        logo = ""
        if r.logo <> invalid then logo = r.logo + ""
        lines.Push(r.name + "|" + r.url + "|" + logo)
    end for
    reg.Write("list", lines.Join(Chr(10)))
    reg.Flush()
end sub

function isFavorite(url as String) as Boolean
    if url = invalid or url = "" then return false
    return m.favorites.DoesExist(url)
end function

sub toggleFavorite(ch as Object)
    if ch = invalid or ch.url = invalid then return
    url = ch.url + ""
    if m.favorites.DoesExist(url)
        m.favorites.Delete(url)
        m.status.text = "Removed from favorites"
    else
        m.favorites.AddReplace(url, true)
        m.status.text = "Added to favorites ★"
    end if
    saveFavorites()
    if m.view = "channels" then fillListFromChannels(m.displayList)
end sub

sub showLoading(msg as String)
    m.loadBg.visible = true
    m.loadText.visible = true
    m.loadText.text = msg
end sub

sub hideLoading()
    m.loadBg.visible = false
    m.loadText.visible = false
end sub


sub showSourcePicker()
    m.view = "sources"
    m.source = ""
    m.allChannels = []
    m.channels = []
    m.countries = []
    m.searchText = ""
    m.activeGroup = ""
    m.title.text = "Choose source"
    m.subtitle.text = "Playlists are fetched fresh each time"
    hideSearch()
    hideOptions()
    hideLoading()
    m.video.visible = false
    m.video.control = "stop"
    m.npBar.visible = false
    m.npText.visible = false
    setPreview("IPTV source", "Select a playlist provider", "", "pkg:/images/no_logo.png")

    content = CreateObject("roSGNode", "ContentNode")
    sources = [
        { id: "iptvorg", title: "IPTV.org", meta: "Country playlists from iptv-org" },
        { id: "freetv", title: "Free-TV IPTV", meta: "Global playlist (playlist.m3u8)" }
    ]
    m.sourceItems = sources
    for each s in sources
        item = content.createChild("ContentNode")
        item.title = s.title
        item.description = s.meta
    end for
    m.displayList = sources
    m.list.content = content
    m.list.visible = true
    m.list.jumpToItem = 0
    m.list.focusable = true
    m.list.setFocus(true)
    m.panelHelp.text = "OK select source" + Chr(10) + "Back exits"
    m.status.text = "Fresh download on every open"
end sub

sub selectSource(sourceId as String)
    m.source = sourceId
    if sourceId = "iptvorg"
        showCountries()
    else if sourceId = "freetv"
        loadFreeTvPlaylist()
    end if
end sub

sub loadFreeTvPlaylist()
    m.view = "loading_freetv"
    m.title.text = "Free-TV IPTV"
    m.subtitle.text = "Downloading fresh playlist..."
    m.list.visible = false
    showLoading("Fetching Free-TV playlist...")
    hideOptions()
    hideSearch()

    m.task = CreateObject("roSGNode", "PlaylistTask")
    m.task.url = "https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8"
    m.task.cacheKey = "freetv"
    m.task.countryCode = ""
    m.task.observeField("done", "onFreeTvResult")
    m.task.control = "RUN"
end sub

sub onFreeTvResult()
    if m.task = invalid then return
    if m.task.done <> true then return
    hideLoading()
    result = m.task.result
    err = m.task.error
    fromCache = m.task.fromCache

    if result = invalid or type(result) <> "roArray" or result.count() = 0
        msg = "Free-TV download failed."
        if err <> invalid and err <> "" then msg = err
        m.subtitle.text = msg
        m.status.text = msg
        m.list.visible = true
        showSourcePicker()
        return
    end if

    m.allChannels = result
    ' Build country list from group-title
    seen = {}
    countries = []
    for each ch in result
        g = ""
        if ch.group <> invalid then g = (ch.group + "").Trim()
        if g = "" then g = "Other"
        if not seen.DoesExist(g)
            seen.AddReplace(g, true)
            countries.Push({ code: g, countryName: g, flag: "", special: false })
        end if
    end for
    ' sort by name
    n = countries.count()
    i = 1
    while i < n
        key = countries[i]
        j = i - 1
        while j >= 0 and countries[j].countryName > key.countryName
            countries[j + 1] = countries[j]
            j = j - 1
        end while
        countries[j + 1] = key
        i = i + 1
    end while

    m.countries = countries
    m.displayList = countries
    m.view = "countries"
    m.title.text = "Free-TV · Countries"
    src = "live"
    if fromCache = true then src = "cached fallback"
    m.subtitle.text = countries.count().toStr() + " regions · " + result.count().toStr() + " channels · " + src
    fillListFromCountries(m.displayList)
    m.panelHelp.text = "Left/Right letter" + Chr(10) + "OK open" + Chr(10) + "Back sources"
    m.status.text = "Fresh list · Back = sources"
end sub

sub showCountries()
    m.view = "countries"
    m.searchText = ""
    if m.source = "freetv"
        m.title.text = "Free-TV · Countries"
    else
        m.title.text = "IPTV.org · Countries"
        m.source = "iptvorg"
    end if
    m.subtitle.text = "Pick a region · lists download fresh"
    m.video.visible = false
    m.video.control = "stop"
    m.npBar.visible = false
    m.npText.visible = false
    hideSearch()
    hideOptions()
    hideLoading()
    setPreview("", "Select a country", "", "pkg:/images/no_logo.png")

    raw = getBuiltInCountries()
    cached = getCachedSet()
    m.countries = []
    if m.recents.count() > 0
        m.countries.Push({ code: "_RECENT", countryName: "Recently Watched", flag: "▶", special: true })
    end if
    if m.favorites.Count() > 0
        m.countries.Push({ code: "_FAV", countryName: "Favorites", flag: "★", special: true })
    end if
    for each c in raw
        if cached.DoesExist(LCase(c.code)) then m.countries.Push(c)
    end for
    for each c in raw
        if not cached.DoesExist(LCase(c.code)) then m.countries.Push(c)
    end for
    m.displayList = m.countries
    fillListFromCountries(m.displayList)
    m.panelHelp.text = "Left/Right letter" + Chr(10) + "OK open" + Chr(10) + "Back sources"
    m.status.text = m.countries.count().toStr() + " countries"
end sub

sub fillListFromCountries(arr as Object)
    content = CreateObject("roSGNode", "ContentNode")
    cached = getCachedSet()
    for each c in arr
        item = content.createChild("ContentNode")
        label = c.countryName
        if c.flag <> invalid and c.flag <> "" then label = c.flag + "  " + c.countryName
        if c.special <> true and cached.DoesExist(LCase(c.code)) then label = label + "  ★"
        item.title = label
        item.description = c.code
    end for
    m.list.content = content
    m.list.visible = true
    m.list.jumpToItem = 0
    m.list.setFocus(true)
end sub

function getCachedSet() as Object
    set = {}
    reg = CreateObject("roRegistrySection", "iptv_cache")
    raw = reg.Read("countries")
    if raw = invalid or raw = "" then return set
    for each p in raw.Split(",")
        p = p.Trim()
        if p <> "" then set.AddReplace(p, true)
    end for
    return set
end function

sub loadChannelsForCountry(code as String, displayName as String)
    if code = "_RECENT"
        m.view = "channels"
        m.selectedCountry = { code: code, name: displayName }
        m.title.text = displayName
        m.subtitle.text = "Recent"
        m.channels = m.recents
        m.displayList = m.recents
        m.activeGroup = ""
        m.groups = []
        fillListFromChannels(m.displayList)
        m.panelHelp.text = "← → letter" + Chr(10) + "* options" + Chr(10) + "OK play"
        m.status.text = m.displayList.count().toStr() + " recent"
        return
    end if
    if code = "_FAV"
        showFavoritesList()
        return
    end if

    m.view = "channels"
    m.selectedCountry = { code: code, name: displayName }
    m.title.text = displayName
    m.searchText = ""
    m.activeGroup = ""
    hideOptions()
    hideSearch()

    ' Free-TV: channels already in memory from full playlist
    if m.source = "freetv"
        filtered = []
        for each ch in m.allChannels
            g = ""
            if ch.group <> invalid then g = (ch.group + "").Trim()
            if g = "" then g = "Other"
            if g = code then filtered.Push(ch)
        end for
        m.channels = filtered
        m.displayList = filtered
        m.groups = buildGroupList(filtered)
        fillListFromChannels(m.displayList)
        m.subtitle.text = filtered.count().toStr() + " channels · Free-TV"
        m.panelHelp.text = "Left/Right letter" + Chr(10) + "* options" + Chr(10) + "OK play"
        m.status.text = "From fresh Free-TV list"
        return
    end if

    ' IPTV.org: always download fresh country playlist
    m.subtitle.text = "Loading fresh list..."
    m.list.visible = false
    showLoading("Fetching fresh " + displayName + " list...")

    m.task = CreateObject("roSGNode", "PlaylistTask")
    m.task.countryCode = code
    m.task.url = ""
    m.task.cacheKey = LCase(code + "")
    m.task.observeField("done", "onChannelsResult")
    m.task.control = "RUN"
end sub

sub showFavoritesList()
    m.view = "channels"
    m.selectedCountry = { code: "_FAV", name: "Favorites" }
    m.title.text = "Favorites"
    m.subtitle.text = "Starred"
    favs = []
    for each r in m.recents
        if isFavorite(r.url) then favs.Push(r)
    end for
    for each url in m.favorites
        found = false
        for each f in favs
            if f.url = url then found = true : exit for
        end for
        if not found then favs.Push({ name: url, url: url, logo: "", group: "Favorite" })
    end for
    m.channels = favs
    m.displayList = favs
    m.activeGroup = ""
    m.groups = []
    fillListFromChannels(m.displayList)
    m.status.text = favs.count().toStr() + " favorites"
end sub

sub onChannelsResult()
    if m.task = invalid then return
    if m.task.done <> true then return
    hideLoading()
    result = m.task.result
    err = m.task.error
    fromCache = m.task.fromCache

    if result = invalid or type(result) <> "roArray" or result.count() = 0
        msg = "No channels loaded."
        if err <> invalid and err <> "" then msg = err
        m.subtitle.text = msg
        m.status.text = msg + " · Back = countries"
        m.list.visible = true
        m.list.setFocus(true)
        return
    end if

    m.channels = result
    m.displayList = result
    m.groups = buildGroupList(result)
    m.searchText = ""
    fillListFromChannels(m.displayList)
    src = "live"
    if fromCache = true then src = "cached fallback"
    m.subtitle.text = result.count().toStr() + " channels · " + src
    m.panelHelp.text = "← → letter" + Chr(10) + "* options / search" + Chr(10) + "replay ★" + Chr(10) + "OK play"
    m.status.text = "←→ letter jump · * options · replay favorite · OK play"
end sub

function buildGroupList(channels as Object) as Object
    seen = {}
    groups = []
    for each ch in channels
        g = ""
        if ch.group <> invalid then g = (ch.group + "").Trim()
        if g = "" then g = "Other"
        if not seen.DoesExist(g)
            seen.AddReplace(g, true)
            groups.Push(g)
        end if
    end for
    n = groups.count()
    for i = 1 to n - 1
        key = groups[i]
        j = i - 1
        while j >= 0 and groups[j] > key
            groups[j + 1] = groups[j]
            j = j - 1
        end while
        groups[j + 1] = key
    end for
    return groups
end function

sub fillListFromChannels(arr as Object)
    content = CreateObject("roSGNode", "ContentNode")
    for each ch in arr
        item = content.createChild("ContentNode")
        title = ch.name
        if isFavorite(ch.url) then title = "★ " + title
        if ch.group <> invalid and ch.group <> "" and m.activeGroup = ""
            title = title + "  ·  " + ch.group
        end if
        item.title = title
        item.description = ch.group
        item.url = ch.url
        item.streamFormat = "hls"
    end for
    m.list.content = content
    m.list.visible = true
    m.list.jumpToItem = 0
    m.list.setFocus(true)
end sub

sub filterByGroup(groupName as String)
    m.activeGroup = groupName
    m.searchText = ""
    filtered = []
    for each ch in m.channels
        g = ""
        if ch.group <> invalid then g = (ch.group + "").Trim()
        if g = "" then g = "Other"
        if g = groupName then filtered.Push(ch)
    end for
    m.displayList = filtered
    fillListFromChannels(m.displayList)
    m.subtitle.text = groupName + " · " + filtered.count().toStr()
    m.status.text = "Group filter · Back clears"
end sub

sub setPreview(name as String, meta as String, helpLine as String, uri as String)
    if m.previewName <> invalid then m.previewName.text = name
    if m.previewMeta <> invalid then m.previewMeta.text = meta
    if uri = invalid then uri = ""
    if uri = ""
        if m.logo <> invalid then m.logo.uri = "pkg:/images/no_logo.png"
        m.lastLogoUrl = ""
    else if uri <> m.lastLogoUrl
        if m.logo <> invalid then m.logo.uri = uri
        m.lastLogoUrl = uri
    end if
end sub

sub onItemFocused()
    idx = m.list.itemFocused
    if idx < 0 then return
    if m.view = "sources"
        if m.sourceItems = invalid or idx >= m.sourceItems.count() then return
        s = m.sourceItems[idx]
        setPreview(s.title, s.meta, "", "pkg:/images/no_logo.png")
        return
    end if
    if idx >= m.displayList.count() then return
    if m.view = "countries"
        c = m.displayList[idx]
        if c.special = true
            setPreview(c.countryName, "Quick access", "", "pkg:/images/no_logo.png")
        else
            setPreview(c.countryName, "Code: " + c.code, "", "https://flagcdn.com/w320/" + LCase(c.code) + ".png")
        end if
    else if m.view = "channels"
        ch = m.displayList[idx]
        logoUrl = "pkg:/images/no_logo.png"
        if ch.logo <> invalid and ch.logo <> "" then logoUrl = ch.logo
        meta = ""
        if ch.group <> invalid then meta = ch.group
        if isFavorite(ch.url) then meta = "★ Favorite" + Chr(10) + meta
        setPreview(ch.name, meta, "", logoUrl)
    end if
end sub

sub onItemSelected()
    index = m.list.itemSelected
    if index < 0 then return
    if m.view = "sources"
        if index >= m.sourceItems.count() then return
        selectSource(m.sourceItems[index].id)
    else if m.view = "countries"
        if index >= m.displayList.count() then return
        c = m.displayList[index]
        loadChannelsForCountry(c.code, c.countryName)
    else if m.view = "channels"
        if index >= m.displayList.count() then return
        playChannel(m.displayList[index])
    end if
end sub

sub hideNowPlayingBar()
    m.npBar.visible = false
    m.npText.visible = false
end sub

sub playChannel(ch as Object)
    if ch = invalid or ch.url = invalid or ch.url = "" then return
    hideOptions()
    hideSearch()
    pushRecent(ch)
    videoContent = CreateObject("roSGNode", "ContentNode")
    videoContent.url = ch.url
    videoContent.streamFormat = "hls"
    videoContent.title = ch.name
    m.view = "video"
    m.video.content = videoContent
    m.video.visible = true
    setCaptionsEnabled(false)
    m.video.control = "play"
    m.video.setFocus(true)
    m.list.visible = false
    m.npBar.visible = true
    m.npText.visible = true
    m.npText.text = "▶  " + ch.name + "   ·   Back = list"
    m.npTimer.control = "stop"
    m.npTimer.control = "start"
    m.title.text = ch.name
    m.subtitle.text = "Playing"
end sub

' ========== SEARCH OVERLAY ==========
function getKeyboardLayout() as Object
    return [
        ["A", "B", "C", "D", "E", "F", "G"],
        ["H", "I", "J", "K", "L", "M", "N"],
        ["O", "P", "Q", "R", "S", "T", "U"],
        ["V", "W", "X", "Y", "Z", "-", "'"],
        ["0", "1", "2", "3", "4", "5", "6"],
        ["7", "8", "9", ".", "SPC", "DEL", "CLR"]
    ]
end function

sub openSearch()
    if m.view <> "channels" and m.view <> "options" then return
    if m.channels.count() = 0 then return

    m.view = "search"
    m.searchFocus = "keyboard"
    m.searchText = ""
    m.kbRow = 0
    m.kbCol = 0
    m.kbLayout = getKeyboardLayout()

    m.list.focusable = false
    m.searchList.focusable = false

    m.searchBg.visible = true
    m.searchPanel.visible = true
    m.searchPanelEdge.visible = true
    m.searchTitle.visible = true
    m.searchHint.visible = true
    m.searchBarBg.visible = true
    m.searchBarEdge.visible = true
    m.searchQuery.visible = true
    m.searchResults.visible = true
    m.searchList.visible = true
    m.kbDisplay.visible = true
    m.kbFooter.visible = true
    m.kbTrap.visible = true
    m.kbTrap.focusable = true

    hideOptions()
    drawKeyboard()
    refreshSearchResults()
    m.kbTrap.setFocus(true)
end sub

sub hideSearch()
    m.searchBg.visible = false
    m.searchPanel.visible = false
    m.searchPanelEdge.visible = false
    m.searchTitle.visible = false
    m.searchHint.visible = false
    m.searchBarBg.visible = false
    m.searchBarEdge.visible = false
    m.searchQuery.visible = false
    m.searchResults.visible = false
    m.searchList.visible = false
    m.kbDisplay.visible = false
    m.kbFooter.visible = false
    m.kbTrap.visible = false
    m.kbTrap.focusable = false
    m.list.focusable = true
end sub

sub drawKeyboard()
    if m.kbLayout = invalid then m.kbLayout = getKeyboardLayout()
    rows = m.kbLayout.count()
    if m.kbRow < 0 then m.kbRow = rows - 1
    if m.kbRow >= rows then m.kbRow = 0
    cols = m.kbLayout[m.kbRow].count()
    if m.kbCol < 0 then m.kbCol = cols - 1
    if m.kbCol >= cols then m.kbCol = cols - 1

    lines = []
    for r = 0 to rows - 1
        parts = []
        rowKeys = m.kbLayout[r]
        for c = 0 to rowKeys.count() - 1
            key = rowKeys[c]
            if m.searchFocus = "keyboard" and r = m.kbRow and c = m.kbCol
                parts.Push("[" + key + "]")
            else
                parts.Push(" " + key + " ")
            end if
        end for
        lines.Push(parts.Join(" "))
    end for
    m.kbDisplay.text = lines.Join(Chr(10) + Chr(10))
    m.searchQuery.text = m.searchText + "_"
end sub

sub keyboardMove(dRow as Integer, dCol as Integer)
    if m.kbLayout = invalid then m.kbLayout = getKeyboardLayout()
    rows = m.kbLayout.count()
    if rows < 1 then return

    if dRow <> 0
        m.kbRow = m.kbRow + dRow
        if m.kbRow < 0 then m.kbRow = rows - 1
        if m.kbRow > rows - 1 then m.kbRow = 0
        cols = m.kbLayout[m.kbRow].count()
        if m.kbCol > cols - 1 then m.kbCol = cols - 1
        if m.kbCol < 0 then m.kbCol = 0
    end if

    if dCol <> 0
        cols = m.kbLayout[m.kbRow].count()
        m.kbCol = m.kbCol + dCol
        if m.kbCol < 0 then m.kbCol = cols - 1
        if m.kbCol > cols - 1 then m.kbCol = 0
    end if

    drawKeyboard()
end sub

sub keyboardType()
    key = m.kbLayout[m.kbRow][m.kbCol]
    if key = "SPC"
        m.searchText = m.searchText + " "
    else if key = "DEL"
        if Len(m.searchText) > 0 then m.searchText = Left(m.searchText, Len(m.searchText) - 1)
    else if key = "CLR"
        m.searchText = ""
    else
        m.searchText = m.searchText + key
    end if
    drawKeyboard()
    refreshSearchResults()
end sub

sub refreshSearchResults()
    query = LCase((m.searchText + "").Trim())
    filtered = []
    if query = ""
        ' show first slice of all channels while typing
        maxShow = 50
        for i = 0 to m.channels.count() - 1
            filtered.Push(m.channels[i])
            if filtered.count() >= maxShow then exit for
        end for
    else
        for each ch in m.channels
            name = LCase(ch.name + "")
            group = ""
            if ch.group <> invalid then group = LCase(ch.group + "")
            if name.Instr(query) >= 0 or group.Instr(query) >= 0
                filtered.Push(ch)
            end if
        end for
    end if

    m.searchMatches = filtered
    content = CreateObject("roSGNode", "ContentNode")
    for each ch in filtered
        item = content.createChild("ContentNode")
        item.title = ch.name
        item.description = ch.group
        item.url = ch.url
        item.streamFormat = "hls"
    end for
    m.searchList.content = content
    m.searchList.focusable = false
    m.searchResults.text = filtered.count().toStr() + " matches"
    if query <> "" then m.searchResults.text = filtered.count().toStr() + " matches for """ + m.searchText + """"
    if m.view = "search" and m.kbTrap <> invalid
        m.kbTrap.setFocus(true)
    end if
end sub

sub applySearchToMainList()
    query = LCase((m.searchText + "").Trim())
    if query = ""
        m.displayList = m.channels
        m.activeGroup = ""
    else
        filtered = []
        for each ch in m.channels
            name = LCase(ch.name + "")
            group = ""
            if ch.group <> invalid then group = LCase(ch.group + "")
            if name.Instr(query) >= 0 or group.Instr(query) >= 0
                filtered.Push(ch)
            end if
        end for
        m.displayList = filtered
    end if
    hideSearch()
    m.view = "channels"
    fillListFromChannels(m.displayList)
    if m.selectedCountry <> invalid then m.title.text = m.selectedCountry.name
    if query = ""
        m.subtitle.text = m.displayList.count().toStr() + " channels"
        m.status.text = "←→ letter · * options · OK play"
    else
        m.subtitle.text = m.displayList.count().toStr() + " match """ + m.searchText + """"
        m.status.text = "Filtered · Back clears filter"
    end if
end sub

sub onSearchListSelected()
    idx = m.searchList.itemSelected
    if idx < 0 or m.searchMatches = invalid then return
    if idx >= m.searchMatches.count() then return
    playChannel(m.searchMatches[idx])
end sub

' ========== Letter jump ==========
function jumpByLetter(direction as Integer) as Boolean
    if m.view <> "countries" and m.view <> "channels" then return false
    if m.displayList.count() = 0 then return false
    idx = m.list.itemFocused
    if idx < 0 then idx = 0
    if idx >= m.displayList.count() then idx = 0
    currentLetter = getSortLetter(m.displayList[idx])
    if direction > 0
        for i = idx + 1 to m.displayList.count() - 1
            if getSortLetter(m.displayList[i]) > currentLetter
                m.list.jumpToItem = i
                return true
            end if
        end for
        m.list.jumpToItem = 0
        return true
    else
        target = 0
        for i = 0 to idx - 1
            if getSortLetter(m.displayList[i]) < currentLetter
                target = i
            end if
        end for
        if target > 0 or getSortLetter(m.displayList[0]) < currentLetter
            letter = getSortLetter(m.displayList[target])
            startIdx = target
            for i = target to 0 step -1
                if getSortLetter(m.displayList[i]) = letter
                    startIdx = i
                else
                    exit for
                end if
            end for
            m.list.jumpToItem = startIdx
        else if m.displayList.count() > 0
            m.list.jumpToItem = m.displayList.count() - 1
        end if
        return true
    end if
end function

function getSortLetter(entry as Object) as String
    name = ""
    if m.view = "countries"
        if entry.countryName <> invalid then name = entry.countryName + ""
    else
        if entry.name <> invalid then name = entry.name + ""
    end if
    name = name.Trim()
    if Len(name) = 0 then return "#"
    ch = UCase(Left(name, 1))
    if ch < "A" or ch > "Z"
        if Len(name) > 2 then ch = UCase(Mid(name, 3, 1))
    end if
    if ch < "A" or ch > "Z" then return "#"
    return ch
end function

' ========== Options ==========


sub setCaptionsEnabled(enabled as Boolean)
    m.captionsOn = enabled
    if m.video = invalid then return
    if enabled
        m.video.closedCaptionMode = "On"
        ' Prefer first available subtitle track when present
        tracks = m.video.availableSubtitleTracks
        if tracks <> invalid and type(tracks) = "roArray" and tracks.count() > 0
            m.video.currentSubtitleTrack = tracks[0].TrackName
        end if
    else
        m.video.closedCaptionMode = "Off"
        m.video.currentSubtitleTrack = ""
    end if
end sub

sub openPlayerOptions()
    if m.view <> "video" and m.view <> "playeropts" then return
    m.view = "playeropts"
    content = CreateObject("roSGNode", "ContentNode")
    items = []
    if m.captionsOn = true
        items.Push("CC / Subtitles: ON  (select to turn OFF)")
    else
        items.Push("CC / Subtitles: OFF  (select to turn ON)")
    end if
    ' List embedded subtitle tracks if the stream exposes any
    tracks = m.video.availableSubtitleTracks
    if tracks <> invalid and type(tracks) = "roArray" and tracks.count() > 0
        items.Push("--- Subtitle tracks ---")
        for each tr in tracks
            label = "Track"
            if tr.Language <> invalid and tr.Language <> "" then label = tr.Language
            if tr.Description <> invalid and tr.Description <> "" then label = label + " - " + tr.Description
            if tr.TrackName <> invalid
                items.Push("SUB:" + tr.TrackName + ":" + label)
            end if
        end for
        items.Push("Disable subtitle track")
    end if
    items.Push("Close menu")
    m.optActions = items
    for each x in items
        n = content.createChild("ContentNode")
        ' Hide internal SUB: prefix in display
        title = x
        if Left(x, 4) = "SUB:"
            parts = x.Split(":")
            if parts.count() >= 3
                title = "  " + parts[2]
                if parts.count() > 3
                    title = "  " + Mid(x, Len(parts[0]) + Len(parts[1]) + 3)
                end if
            end if
        end if
        n.title = title
    end for
    m.optsList.content = content
    m.optsBg.visible = true
    m.optsBox.visible = true
    m.optsBoxEdge.visible = true
    m.optsTitle.text = "Player options"
    m.optsTitle.visible = true
    m.optsList.visible = true
    m.optsList.setFocus(true)
end sub

sub openOptions()
    if m.view <> "channels" then return
    m.view = "options"
    m.optsTitle.text = "Options"
    content = CreateObject("roSGNode", "ContentNode")
    items = ["Search channels...", "Show all channels"]
    if m.groups.count() > 0
        items.Push("--- Groups ---")
        for each g in m.groups
            items.Push("  " + g)
        end for
    end if
    items.Push("Clear favorites")
    items.Push("Close menu")
    m.optActions = items
    for each x in items
        n = content.createChild("ContentNode")
        n.title = x
    end for
    m.optsList.content = content
    m.optsBg.visible = true
    m.optsBox.visible = true
    m.optsBoxEdge.visible = true
    m.optsTitle.visible = true
    m.optsList.visible = true
    m.optsList.setFocus(true)
end sub

sub hideOptions()
    m.optsBg.visible = false
    m.optsBox.visible = false
    m.optsBoxEdge.visible = false
    m.optsTitle.visible = false
    m.optsList.visible = false
end sub

sub onOptsSelected()
    idx = m.optsList.itemSelected
    if idx < 0 or m.optActions = invalid then return
    if idx >= m.optActions.count() then return
    action = m.optActions[idx]
    hideOptions()

    if Left(action, 15) = "CC / Subtitles:"
        setCaptionsEnabled(not m.captionsOn)
        m.view = "video"
        m.video.setFocus(true)
        if m.captionsOn
            m.status.text = "CC / Subtitles ON"
        else
            m.status.text = "CC / Subtitles OFF"
        end if
        return
    end if
    if action = "Disable subtitle track"
        m.video.currentSubtitleTrack = ""
        m.captionsOn = false
        m.video.closedCaptionMode = "Off"
        m.view = "video"
        m.video.setFocus(true)
        m.status.text = "Subtitles disabled"
        return
    end if
    if Left(action, 4) = "SUB:"
        parts = action.Split(":")
        if parts.count() >= 2
            m.video.currentSubtitleTrack = parts[1]
            m.captionsOn = true
            m.video.closedCaptionMode = "On"
        end if
        m.view = "video"
        m.video.setFocus(true)
        m.status.text = "Subtitle track selected"
        return
    end if
    if action = "Close menu" and m.video.visible = true
        m.view = "video"
        m.video.setFocus(true)
        return
    end if
    if action = "--- Subtitle tracks ---"
        m.view = "video"
        m.video.setFocus(true)
        return
    end if

    if action = "Search channels..."
        openSearch()
        return
    end if
    m.view = "channels"
    m.list.setFocus(true)
    if action = "Show all channels"
        m.activeGroup = ""
        m.searchText = ""
        m.displayList = m.channels
        fillListFromChannels(m.displayList)
        m.subtitle.text = m.channels.count().toStr() + " channels"
    else if action = "Clear favorites"
        m.favorites = {}
        saveFavorites()
        m.status.text = "Favorites cleared"
    else if Left(action, 3) = "  "
        filterByGroup(Mid(action, 3).Trim())
    end if
end sub

' ========== Keys ==========
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        if m.view = "search"
            applySearchToMainList()
            return true
        else if m.view = "options"
            hideOptions()
            m.view = "channels"
            m.list.setFocus(true)
            return true
        else if m.view = "playeropts"
            hideOptions()
            m.view = "video"
            m.video.setFocus(true)
            return true
        else if m.view = "video"
            m.video.control = "stop"
            m.video.visible = false
            m.npTimer.control = "stop"
            m.npBar.visible = false
            m.npText.visible = false
            m.view = "channels"
            m.list.visible = true
            m.list.setFocus(true)
            if m.selectedCountry <> invalid
                m.title.text = m.selectedCountry.name
                m.subtitle.text = "Select a channel"
            end if
            return true
        else if m.view = "channels"
            if m.searchText <> "" or m.activeGroup <> ""
                m.searchText = ""
                m.activeGroup = ""
                m.displayList = m.channels
                fillListFromChannels(m.displayList)
                m.subtitle.text = m.channels.count().toStr() + " channels"
                return true
            end if
            if m.source = "freetv"
                m.displayList = m.countries
                m.view = "countries"
                m.title.text = "Free-TV · Countries"
                fillListFromCountries(m.displayList)
                m.status.text = "Back = sources"
            else
                showCountries()
            end if
            return true
        else if m.view = "countries"
            showSourcePicker()
            return true
        else if m.view = "loading_freetv"
            showSourcePicker()
            return true
        end if
        return false
    end if

    if m.view = "search"
        if key = "up"
            keyboardMove(-1, 0)
            m.kbTrap.setFocus(true)
            return true
        end if
        if key = "down"
            keyboardMove(1, 0)
            m.kbTrap.setFocus(true)
            return true
        end if
        if key = "left"
            keyboardMove(0, -1)
            m.kbTrap.setFocus(true)
            return true
        end if
        if key = "right"
            keyboardMove(0, 1)
            m.kbTrap.setFocus(true)
            return true
        end if
        if key = "OK"
            keyboardType()
            m.kbTrap.setFocus(true)
            return true
        end if
        if key = "replay"
            if Len(m.searchText) > 0
                m.searchText = Left(m.searchText, Len(m.searchText) - 1)
                drawKeyboard()
                refreshSearchResults()
            end if
            m.kbTrap.setFocus(true)
            return true
        end if
        if key = "options"
            m.searchText = m.searchText + " "
            drawKeyboard()
            refreshSearchResults()
            m.kbTrap.setFocus(true)
            return true
        end if
        if key = "play"
            applySearchToMainList()
            return true
        end if
        m.kbTrap.setFocus(true)
        return true
    end if

    if m.view = "video"
        if key = "options" or key = "info" or key = "replay"
            openPlayerOptions()
            return true
        end if
    end if

    if m.view = "channels"
        if key = "right"
            return jumpByLetter(1)
        else if key = "left"
            return jumpByLetter(-1)
        else if key = "options"
            openOptions()
            return true
        else if key = "replay"
            idx = m.list.itemFocused
            if idx >= 0 and idx < m.displayList.count()
                toggleFavorite(m.displayList[idx])
                return true
            end if
        end if
    end if

    if m.view = "countries"
        if key = "right"
            return jumpByLetter(1)
        else if key = "left"
            return jumpByLetter(-1)
        end if
    end if

    return false
end function
