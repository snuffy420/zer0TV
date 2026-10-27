sub init()
    m.list = m.top.findNode("list")
    m.sourceMenu = m.top.findNode("sourceMenu")
    m.movieUI = m.top.findNode("movieUI")
    m.movieOpenCount = 0
    m.movieUI.observeField("selectedMovie", "onMoviePlaySelected")
    m.sourceMenu.observeField("selectedIndex", "onSourceCardSelected")
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
    m.aboutBg = m.top.findNode("aboutBg")
    m.aboutBox = m.top.findNode("aboutBox")
    m.aboutBoxEdge = m.top.findNode("aboutBoxEdge")
    m.aboutTitle = m.top.findNode("aboutTitle")
    m.aboutBody = m.top.findNode("aboutBody")
    m.aboutQr = m.top.findNode("aboutQr")
    m.aboutFooter = m.top.findNode("aboutFooter")
    m.aboutTrap = m.top.findNode("aboutTrap")
    m.aboutHintGlow = m.top.findNode("aboutHintGlow")
    m.aboutHintBg = m.top.findNode("aboutHintBg")
    m.aboutHintText = m.top.findNode("aboutHintText")
    m.aboutHintSub = m.top.findNode("aboutHintSub")
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

    initGuide()
    initPlayerUI()
    initCountryUI()
    initProviders()
    showSourcePicker()
    m.top.setFocus(true)
    m.sourceMenu.setFocus(true)
end sub

function loadFavorites() as Object
    reg = CreateObject("roRegistrySection", "iptv_fav")
    stored = ParseJson(reg.Read("channels"))
    if type(stored) = "roAssociativeArray" then return stored
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
    reg.Write("channels", FormatJson(m.favorites))
    lines = []
    for each k in m.favorites
        lines.Push(k)
    end for
    reg.Write("urls", lines.Join(Chr(10)))
    reg.Flush()
end sub

function loadRecents() as Object
    reg = CreateObject("roRegistrySection", "iptv_recent")
    stored = ParseJson(reg.Read("channels"))
    if type(stored) = "roArray" then return stored
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
    newList.Push(ch)
    for each r in m.recents
        if r.url <> url then newList.Push(r)
        if newList.count() >= 15 then exit for
    end for
    m.recents = newList
    reg = CreateObject("roRegistrySection", "iptv_recent")
    reg.Write("channels", FormatJson(m.recents))
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
        m.favorites.AddReplace(url, ch)
        m.status.text = "Added to favorites ★"
    end if
    saveFavorites()
    if m.view = "channels" and not m.guideActive then fillListFromChannels(m.displayList)
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
    cancelPlaylist()
    hideGuide()
    cancelCountryGuide()
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
    for each provider in m.providerDefs
        sources.Push({id: provider.id, title: provider.title, meta: provider.meta})
    end for
    sources.Push({id: "plutovod", title: "Pluto On Demand", meta: "Movies and shows - US catalog"})
    sources.Push({id: "archive", title: "Internet Archive", meta: "Rare cinema, workprints and alternate cuts"})
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
    m.panelHelp.text = "OK select source" + Chr(10) + "* About" + Chr(10) + "Back exits"
    m.status.text = ""
    m.panelHelp.text = "OK = open source" + Chr(10) + "Back = exit"
    showAboutHint()
    m.list.visible = false
    m.sourceMenu.choices = sources
    m.sourceMenu.visible = true
    m.sourceMenu.setFocus(true)
    m.subtitle.text = "Choose a provider - live TV and on-demand movies"
    m.status.text = "Arrow keys Choose source   |   OK Open   |   * About   |   Back Exit"
end sub

sub onSourceCardSelected()
    if m.view <> "sources" then return
    index = m.sourceMenu.selectedIndex
    if index < 0 or index >= m.sourceItems.Count() then return
    selectSource(m.sourceItems[index].id)
end sub

sub selectSource(sourceId as String)
    m.sourceMenu.visible = false
    hideAboutHint()
    m.source = sourceId
    if sourceId = "iptvorg"
        showCountries()
    else if sourceId = "freetv"
        loadFreeTvPlaylist()
    else if isLiveProvider(sourceId)
        showProviderCountries()
    else if sourceId = "plutovod" or sourceId = "archive"
        hideGuide()
        hideSearch()
        hideOptions()
        m.view = "movies"
        m.title.text = "Pluto On Demand"
        if sourceId = "archive" then m.title.text = "Internet Archive Movies"
        m.subtitle.text = ""
        m.status.text = ""
        m.list.visible = false
        m.selectedCountry = invalid
        m.movieUI.provider = sourceId
        m.movieUI.visible = true
        m.movieOpenCount = m.movieOpenCount + 1
        m.movieUI.openRequest = m.movieOpenCount
        m.movieUI.setFocus(true)
    end if
end sub

sub onMoviePlaySelected()
    if m.view <> "movies" then return
    if m.movieUI.searchActive then return
    movie = m.movieUI.selectedMovie
    if movie = invalid then return
    if movie.url = invalid or movie.url = "" then return
    m.movieUI.callFunc("suspendArtwork")
    m.movieUI.visible = false
    m.playerReturn = "movies"
    m.view = "video"
    m.video.translation = [0, 0]
    m.video.width = 1280
    m.video.height = 720
    requestPlayback(movie, true)
    focusPlayer()
    showNowPlayingBanner(movie)
end sub

sub loadFreeTvPlaylist()
    hideAboutHint()
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
    if m.view <> "loading_freetv" then return
    if m.task = invalid then return
    if m.task.done <> true then return
    hideLoading()
    result = m.task.result
    err = m.task.error
    fromCache = m.task.fromCache
    releasePlaylistResult()

    if result = invalid or type(result) <> "roArray" or result.count() = 0
        msg = "Free-TV download failed."
        if err <> invalid and err <> "" then msg = err
        m.subtitle.text = msg
        m.status.text = msg
        m.list.visible = true
        showSourcePicker()
        m.status.text = msg
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

    m.countries = orderedSourceCountries(countries)
    m.displayList = m.countries
    m.view = "countries"
    m.title.text = "Free-TV · Countries"
    src = "live"
    if fromCache = true then src = "cached fallback"
    m.subtitle.text = countries.count().toStr() + " regions · " + result.count().toStr() + " channels · " + src
    fillListFromCountries(m.displayList)
    m.panelHelp.text = "Left/Right letter" + Chr(10) + "OK open" + Chr(10) + "Back sources"
    m.status.text = "OK Open   Left/Right A-Z   Replay Pin/unpin   * Countries menu   Back Sources"
end sub

sub showCountries()
    cancelPlaylist()
    hideGuide()
    cancelCountryGuide()
    hideAboutHint()
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
        m.countries.Push(c)
    end for
    m.countries = orderedSourceCountries(m.countries)
    m.displayList = m.countries
    fillListFromCountries(m.displayList)
    m.panelHelp.text = "Left/Right letter" + Chr(10) + "OK open" + Chr(10) + "Back sources"
    m.status.text = "OK Open   Left/Right A-Z   Replay Pin/unpin   * Countries menu   Back Sources"
end sub

sub fillListFromCountries(arr as Object)
    m.countryLetterRows = []
    m.countryLetterIndex = {}
    for i = 0 to arr.Count() - 1
        m.countryLetterRows.Push({name: arr[i].countryName})
        letter = channelLetter(arr[i].countryName)
        if arr[i].special <> true and not m.countryLetterIndex.DoesExist(letter) then m.countryLetterIndex[letter] = i
    end for
    content = CreateObject("roSGNode", "ContentNode")
    cached = getCachedSet()
    for each c in arr
        item = content.createChild("ContentNode")
        label = countryLabel(c)
        item.title = label
        item.description = c.code
    end for
    m.list.content = content
    m.list.visible = true
    m.list.jumpToItem = 0
    m.list.setFocus(true)
    m.status.text = "OK Open   Left/Right A-Z   Replay Pin/unpin   * Countries menu   Back Sources"
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
    cancelPlaylist()
    hideGuide()
    m.channels = []
    m.displayList = []
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
        m.panelHelp.text = "Left/Right letter" + Chr(10) + "* options" + Chr(10) + "OK play"
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
        recordCountryVisit()
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
    if isLiveProvider(m.source)
        provider = providerCountry(m.providers[m.source], code)
        m.task.countryCode = ""
        m.task.url = provider.playlistUrl
        m.task.cacheKey = m.source + "_" + LCase(code)
    end if
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
        if not found
            saved = m.favorites[url]
            if type(saved) = "roAssociativeArray"
                favs.Push(saved)
            else
                favs.Push({ name: url, url: url, logo: "", group: "Favorite" })
            end if
        end if
    end for
    m.channels = favs
    m.displayList = favs
    m.activeGroup = ""
    m.groups = []
    fillListFromChannels(m.displayList)
    m.status.text = favs.count().toStr() + " favorites"
end sub

sub onChannelsResult()
    if m.view <> "channels" then return
    if m.task = invalid then return
    if m.task.done <> true then return
    hideLoading()
    result = m.task.result
    err = m.task.error
    fromCache = m.task.fromCache
    releasePlaylistResult()

    if result = invalid or type(result) <> "roArray" or result.count() = 0
        msg = "No channels loaded."
        if err <> invalid and err <> "" then msg = err
        m.subtitle.text = msg
        m.status.text = msg + " · Back = countries"
        m.list.visible = true
        m.list.setFocus(true)
        return
    end if

    recordCountryVisit()
    m.channels = result
    m.displayList = result
    m.groups = buildGroupList(result)
    m.searchText = ""
    fillListFromChannels(m.displayList)
    src = "live"
    if fromCache = true then src = "cached fallback"
    m.subtitle.text = result.count().toStr() + " channels · " + src
    m.panelHelp.text = "Left/Right letter" + Chr(10) + "* options / search" + Chr(10) + "Replay search" + Chr(10) + "OK play"
    m.status.text = "Left/Right letter jump · * options · Replay search · OK play"
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
    if m.guideWanted
        m.list.content = invalid
        showGuide()
        return
    end if
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
    if m.guideActive then return
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
        if m.guideActive then return
        if index >= m.displayList.count() then return
        playChannel(m.displayList[index])
    end if
end sub

sub hideNowPlayingBar()
    if m.view = "video"
        m.npFade.control = "start"
    else
        m.npBar.visible = false
    end if
end sub

sub playChannel(ch as Object)
    if ch = invalid or ch.url = invalid or ch.url = "" then return
    hideOptions()
    hideSearch()
    m.playerReturn = "channels"
    m.video.translation = [0, 0]
    m.video.width = 1280
    m.video.height = 720
    m.video.enableUI = false
    pushRecent(ch)
    m.view = "video"
    requestPlayback(ch, true)
    focusPlayer()
    m.list.visible = false
    showNowPlayingBanner(ch)
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
    m.list.focusable = true
    m.searchList.content = invalid
    m.searchMatches = []
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
    shown = 0
    for each ch in filtered
        if shown >= 50 then exit for
        item = content.createChild("ContentNode")
        item.title = ch.name
        item.description = ch.group
        item.url = ch.url
        item.streamFormat = "hls"
        shown = shown + 1
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
        m.status.text = "Left/Right letter · * options · OK play"
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
    if m.view = "countries"
        target = nextGuideLetterIndex(m.countryLetterRows, m.countryLetterIndex, idx, direction)
        if target >= 0 then m.list.jumpToItem = target
        return true
    end if
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


sub showAboutHint()
    if m.aboutHintBg = invalid then return
    m.aboutHintGlow.visible = true
    m.aboutHintBg.visible = true
    m.aboutHintText.visible = true
    if m.aboutHintSub <> invalid then m.aboutHintSub.visible = false
end sub

sub hideAboutHint()
    if m.aboutHintBg = invalid then return
    m.aboutHintGlow.visible = false
    m.aboutHintBg.visible = false
    m.aboutHintText.visible = false
    if m.aboutHintSub <> invalid then m.aboutHintSub.visible = false
end sub

sub showAbout()
    hideOptions()
    hideSearch()
    hideAboutHint()
    m.prevView = m.view
    if m.prevView = "options" then m.prevView = "channels"
    m.view = "about"
    body = "zer0 Software" + Chr(10)
    body = body + "Created by snuffy420" + Chr(10)
    body = body + "Version 1.5.5" + Chr(10) + Chr(10)
    body = body + "Live TV and on-demand movies for Roku." + Chr(10)
    body = body + "Public playlists and Archive catalogs." + Chr(10) + Chr(10)
    body = body + "Donate BTC:" + Chr(10)
    body = body + "bc1qz8877p6vusc22qrctdj4h7w0uk2l9l9h8lwphy" + Chr(10) + Chr(10)
    body = body + "Scan the QR code with a wallet app."
    m.aboutBody.text = body
    m.aboutBg.visible = true
    m.aboutBox.visible = true
    m.aboutBoxEdge.visible = true
    m.aboutTitle.visible = true
    m.aboutBody.visible = true
    m.aboutQr.visible = true
    m.aboutFooter.visible = true
    m.aboutTrap.visible = true
    m.aboutTrap.setFocus(true)
end sub

sub hideAbout()
    m.aboutBg.visible = false
    m.aboutBox.visible = false
    m.aboutBoxEdge.visible = false
    m.aboutTitle.visible = false
    m.aboutBody.visible = false
    m.aboutQr.visible = false
    m.aboutFooter.visible = false
    m.aboutTrap.visible = false
    if m.prevView <> invalid and m.prevView <> ""
        m.view = m.prevView
    else
        m.view = "sources"
    end if
    if m.view = "sources"
        showAboutHint()
    end if
    focusChannels()
end sub

sub openOptions()
    if m.view <> "channels" then return
    m.view = "options"
    m.optsTitle.text = "Options"
    content = CreateObject("roSGNode", "ContentNode")
    items = ["Search channels...", "Favorite / unfavorite channel", "Show all channels", "Switch guide / list", "Jump to live time", "Refresh guide"]
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
        item = content.createChild("ContentNode")
    item.title = "About zer0 TV"
    m.optActions.Push("about")

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
    if m.view = "countryopts"
        handleCountryOption(action)
        return
    end if
    if type(action) = "roAssociativeArray"
        handlePlayerOption(action)
        return
    end if
    if action = "about"
        showAbout()
        return
    end if
    hideOptions()

    if action = "Search channels..."
        openSearch()
        return
    end if
    m.view = "channels"
    focusChannels()
    if action = "Favorite / unfavorite channel"
        index = m.list.itemFocused
        if m.guideActive then index = m.guideIndex
        if index >= 0 and index < m.displayList.Count()
            toggleFavorite(m.displayList[index])
            if m.guideActive then drawGuide()
        end if
    else if action = "Switch guide / list"
        m.guideWanted = not m.guideWanted
        preferences = CreateObject("roRegistrySection", "zer0_preferences")
        mode = "list"
        if m.guideWanted then mode = "guide"
        preferences.Write("channelView", mode)
        preferences.Flush()
        if m.guideWanted
            showGuide()
        else
            hideGuide()
            fillListFromChannels(m.displayList)
        end if
    else if action = "Jump to live time"
        m.guideCursor = CreateObject("roDateTime").AsSeconds()
        m.guideEpoch = m.guideCursor
        drawGuide()
    else if action = "Refresh guide"
        code = countryForGuide()
        DeleteFile("tmp:/zer0_guide.json")
        m.guideCountry = ""
        loadCountryGuide()
        drawGuide()
    else if action = "Show all channels"
        m.activeGroup = ""
        m.searchText = ""
        m.displayList = m.channels
        fillListFromChannels(m.displayList)
        m.subtitle.text = m.channels.count().toStr() + " channels"
    else if action = "Clear favorites"
        m.favorites = {}
        saveFavorites()
        m.status.text = "Favorites cleared"
    else if Left(action, 2) = "  "
        filterByGroup(Mid(action, 3).Trim())
    end if
end sub

' ========== Keys ==========
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back" and m.view = "about"
        hideAbout()
        return true
    end if

    if key = "back"
        if m.view = "search"
            applySearchToMainList()
            return true
        else if m.view = "options"
            hideOptions()
            m.view = "channels"
            focusChannels()
            return true
        else if m.view = "countryopts"
            hideOptions()
            m.view = "countries"
            m.list.setFocus(true)
            return true
        else if m.view = "playeropts"
            hideOptions()
            m.view = "video"
            focusPlayer()
            return true
        else if m.view = "video"
            if m.seekActive = true
                finishMovieSeek(false)
                return true
            end if
            returnFromPlayer()
            return true
        else if m.view = "movies"
            m.movieUI.callFunc("closeBrowsing")
            m.movieUI.visible = false
            showSourcePicker()
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
            cancelPlaylist()
            hideLoading()
            hideGuide()
            cancelCountryGuide()
            if isLiveProvider(m.source)
                showProviderCountries()
            else if m.source = "freetv"
                m.countries = orderedSourceCountries(m.countries)
                m.displayList = m.countries
                m.view = "countries"
                m.title.text = "Free-TV · Countries"
                fillListFromCountries(m.displayList)
                m.status.text = "OK Open   Left/Right A-Z   Replay Pin/unpin   * Countries menu   Back Sources"
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

    if key = "options" and (m.view = "options" or m.view = "countryopts")
        oldView = m.view
        hideOptions()
        if oldView = "countryopts"
            m.view = "countries"
            m.list.setFocus(true)
        else
            m.view = "channels"
            focusChannels()
        end if
        return true
    end if

    if m.view = "about"
        if key = "OK" or key = "back" or key = "options"
            hideAbout()
            return true
        end if
        m.aboutTrap.setFocus(true)
        return true
    end if

    if m.loadBg.visible then return true

    if m.view = "sources"
        if key = "options" or key = "info"
            showAbout()
            return true
        end if
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
        if playerKey(key) then return true
    end if

    if m.view = "playeropts" and key = "options"
        hideOptions()
        m.view = "video"
        focusPlayer()
        showNowPlayingBanner()
        return true
    end if

    if m.view = "channels"
        if m.guideActive
            if guideKey(key) then return true
        end if
        if key = "right"
            return jumpByLetter(1)
        else if key = "left"
            return jumpByLetter(-1)
        else if key = "options"
            openOptions()
            return true
        else if key = "replay"
            openSearch()
            return true
        end if
    end if

    if m.view = "countries"
        if key = "replay"
            toggleCountryPin()
            return true
        else if key = "options"
            openCountryOptions()
            return true
        else if key = "right"
            return jumpByLetter(1)
        else if key = "left"
            return jumpByLetter(-1)
        end if
    end if

    return false
end function

sub cancelPlaylist()
    if m.task <> invalid
        m.task.unobserveField("done")
        m.task.control = "STOP"
        m.task = invalid
    end if
end sub

sub releasePlaylistResult()
    if m.task = invalid then return
    m.task.unobserveField("done")
    m.task.result = []
    m.task = invalid
end sub


