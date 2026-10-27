sub init()
    m.top.focusable = true
    m.count = m.top.findNode("movieCount")
    m.title = m.top.findNode("movieTitle")
    m.meta = m.top.findNode("movieMeta")
    m.plot = m.top.findNode("moviePlot")
    m.message = m.top.findNode("movieMessage")
    m.host = m.top.findNode("movieCards")
    m.font = m.top.findNode("movieFont").font
    m.menu = m.top.findNode("movieMenu")
    m.menuTitle = m.top.findNode("movieMenuTitle")
    m.menuList = m.top.findNode("movieMenuList")
    m.gridTrap = m.top.findNode("movieGridTrap")
    m.menuList.observeField("itemSelected", "onMovieMenuSelected")
    m.catalog = CreateObject("roSGNode", "MovieCatalogTask")
    m.catalog.observeField("state", "onCatalogState")
    m.detail = CreateObject("roSGNode", "MovieDetailTask")
    m.detail.observeField("state", "onDetailState")
    m.detailTimer = CreateObject("roSGNode", "Timer")
    m.detailTimer.duration = 0.5
    m.detailTimer.observeField("fire", "loadFocusedDetails")
    m.catalogBusy = false
    m.detailBusy = false
    m.catalogPending = invalid
    m.detailPending = invalid
    m.items = []
    m.cards = []
    m.opened = false
    m.playPending = false
    m.detailCache = {}
    m.cacheKeys = []
    m.top.observeField("openRequest", "openMovies")
    initMovieGrid()
    initMovieSearch()
    initMovieDetailsUI()
end sub

sub initMovieGrid()
    for i = 0 to 7
        group = m.host.createChild("Group")
        group.translation = [40 + (i mod 4) * 166, 115 + Int(i / 4) * 263]
        border = group.createChild("Rectangle")
        border.width = 154
        border.height = 246
        background = group.createChild("Rectangle")
        background.translation = [2, 2]
        background.width = 150
        background.height = 242
        background.color = "0x1A282EFF"
        poster = group.createChild("Poster")
        poster.translation = [5, 5]
        poster.width = 144
        poster.height = 190
        poster.loadWidth = 144
        poster.loadHeight = 190
        poster.loadDisplayMode = "scaleToFit"
        title = group.createChild("Label")
        title.translation = [7, 200]
        title.width = 140
        title.height = 43
        title.wrap = true
        title.maxLines = 2
        title.font = m.font
        title.color = "0xE3EEEBFF"
        m.cards.Push({group: group, border: border, poster: poster, title: title})
    end for
end sub

sub openMovies()
    m.opened = true
    m.detailsActive = false
    m.searchActive = false
    m.top.searchActive = false
    m.detailPanel.visible = false
    m.movieSearchPanel.visible = false
    m.query = ""
    m.profile = "rare"
    m.page = 1
    m.pages = 1
    m.focus = 0
    m.items = []
    m.detailCache = {}
    m.cacheKeys = []
    requestCatalog(1, true)
    focusMovieGrid()
end sub

sub closeBrowsing()
    suspendArtwork()
    m.searchActive = false
    m.top.searchActive = false
    m.movieSearchPanel.visible = false
    m.detailsActive = false
    m.detailPanel.visible = false
    m.opened = false
    m.catalog.cancelled = true
    m.detail.cancelled = true
    m.catalogPending = invalid
    m.detailPending = invalid
    m.detailTimer.control = "stop"
    m.playPending = false
    m.menu.visible = false
    m.items = []
    m.detailCache = {}
    m.cacheKeys = []
    for each card in m.cards
        card.poster.uri = ""
        card.group.visible = false
    end for
    if m.keyboard <> invalid then m.keyboard.close = true
end sub

sub suspendArtwork()
    for each card in m.cards
        card.poster.uri = ""
    end for
    m.detailArtwork.uri = ""
    m.detailPoster.uri = ""
    m.detailTimer.control = "stop"
end sub

sub resumeBrowsing(message = "Choose a title to play, or press * for options." as String)
    m.top.visible = true
    m.playPending = false
    focusMovieGrid()
    m.message.text = message
    drawMovies()
end sub

sub requestCatalog(page as Integer, fresh as Boolean)
    m.detailsActive = false
    m.catalog.cancelled = true
    m.detail.cancelled = true
    m.detailPending = invalid
    m.detailTimer.control = "stop"
    m.playPending = false
    m.catalogPending = {provider: m.top.provider, query: m.query, profile: m.profile, page: page, fresh: fresh}
    m.message.text = "Loading the latest available catalog..."
    m.loading = true
    startCatalog()
end sub

sub startCatalog()
    if m.catalogBusy or m.catalogPending = invalid or not m.opened then return
    request = m.catalogPending
    m.catalogPending = invalid
    m.catalog.provider = request.provider
    m.catalog.query = request.query
    m.catalog.profile = request.profile
    m.catalog.page = request.page
    m.catalog.fresh = request.fresh
    m.catalog.result = {}
    m.catalog.cancelled = false
    m.catalogBusy = true
    m.catalog.control = "RUN"
end sub

sub onCatalogState()
    if m.catalog.state <> "done" and m.catalog.state <> "stop" then return
    m.catalogBusy = false
    if m.opened and not m.catalog.cancelled
        result = m.catalog.result
        if result.items <> invalid
            m.items = result.items
            m.page = result.page
            m.pages = result.pages
            m.focus = 0
            m.loading = false
            m.count.text = result.total.ToStr() + " titles | Page " + m.page.ToStr() + " / " + m.pages.ToStr()
            if m.query <> "" then m.count.text = m.count.text + " | " + m.query
            m.message.text = result.message
            drawMovies()
            if m.menu <> invalid and not m.menu.visible then focusMovieGrid()
            m.detailTimer.control = "start"
        else
            m.loading = false
            m.items = []
            m.message.text = "Unable to load this catalog. Press * to retry."
            drawMovies()
        end if
    end if
    m.catalog.result = {}
    startCatalog()
end sub

sub drawMovies()
    gridVisible = m.detailsActive <> true and not movieHierarchyView()
    drawMovieDetailsPanel()
    for i = 0 to 7
        card = m.cards[i]
        card.group.visible = i < m.items.Count() and gridVisible
        card.border.color = "0x2D4248FF"
        if i = m.focus then card.border.color = "0x39FF14FF"
        if i < m.items.Count()
            item = m.items[i]
            card.title.text = item.name
            if epgString(item.cardTitle) then card.title.text = item.cardTitle
            card.poster.failedBitmapUri = item.logo
            card.poster.loadingBitmapUri = item.logo
            if gridVisible
                if card.poster.uri <> item.poster then card.poster.uri = item.poster
            else
                card.poster.uri = ""
            end if
        else
            card.poster.uri = ""
        end if
    end for
    if m.items.Count() = 0
        m.title.text = "No matching titles"
        m.meta.text = "Replay to search | * to change filters"
        m.plot.text = ""
        return
    end if
    item = m.items[m.focus]
    if m.detailCache.DoesExist(item.id)
        item = m.detailCache[item.id]
        m.items[m.focus] = item
    end if
    m.title.text = item.name
    parts = []
    if movieText(item.year) <> "" then parts.Push(movieText(item.year))
    if movieText(item.genre) <> "" then parts.Push(movieText(item.genre))
    if movieText(item.addedDate) <> "" then parts.Push("Added " + movieText(item.addedDate))
    if epgNumber(item.durationSeconds) then parts.Push(Int(item.durationSeconds / 60).ToStr() + " min")
    m.meta.text = parts.Join(" | ")
    m.plot.text = movieText(item.description)
    if m.plot.text = "" then m.plot.text = "Loading title details..."
    if item.kind = "series" and movieText(item.description) = "" then m.plot.text = "Press OK to choose a season."
end sub

sub loadFocusedDetails()
    if not m.opened or not m.top.visible or m.loading or m.items.Count() = 0 or m.playPending or m.searchActive = true then return
    item = m.items[m.focus]
    if item.kind = "series" or item.kind = "season" then return
    if m.detailCache.DoesExist(item.id) then return
    requestDetails(item, "info")
end sub

sub requestDetails(item as Object, mode as String)
    m.detail.cancelled = true
    m.detailPending = {item: item, mode: mode}
    if mode = "play"
        m.playPending = true
        m.message.text = "Checking the latest playable file..."
    end if
    startDetails()
end sub

sub startDetails()
    if m.detailBusy or m.detailPending = invalid or not m.opened then return
    request = m.detailPending
    m.detailPending = invalid
    m.detail.item = request.item
    m.detail.mode = request.mode
    m.detail.result = {}
    m.detail.cancelled = false
    m.detailBusy = true
    m.detail.control = "RUN"
end sub

sub onDetailState()
    if m.detail.state <> "done" and m.detail.state <> "stop" then return
    m.detailBusy = false
    if m.opened and not m.detail.cancelled
        result = m.detail.result
        if result.item <> invalid
            item = result.item
            if not m.detailCache.DoesExist(item.id) then m.cacheKeys.Push(item.id)
            m.detailCache[item.id] = item
            if m.cacheKeys.Count() > 24
                old = m.cacheKeys.Shift()
                m.detailCache.Delete(old)
            end if
            for i = 0 to m.items.Count() - 1
                if m.items[i].id = item.id then m.items[i] = item
            end for
            if m.top.visible then drawMovies()
            if result.mode = "play"
                m.playPending = false
                if result.error <> ""
                    m.message.text = result.error
                else if item.url <> "" and m.top.visible and m.searchActive <> true
                    m.top.selectedMovie = item
                end if
            end if
        else if m.playPending
            m.playPending = false
            m.message.text = "Unable to check this title. Please try again."
        end if
    end if
    m.detail.result = {}
    m.detail.item = {}
    startDetails()
end sub

sub openMovieMenu(filters = false as Boolean)
    cancelMovieSelection()
    m.menu.visible = true
    m.menuTitle.text = "Movies"
    if filters
        m.menuTitle.text = "Archive discovery filters"
        m.menuActions = ["Rare finds", "Workprints", "Alternate cuts", "Trailers", "Behind the scenes", "Public-domain-marked classics", "Back"]
    else
        m.menuActions = ["Search movies", "Refresh catalog"]
        if m.top.provider = "archive" then m.menuActions.Push("Archive discovery filters")
        m.menuActions.Push("Close menu")
    end if
    content = CreateObject("roSGNode", "ContentNode")
    for each title in m.menuActions
        item = content.createChild("ContentNode")
        item.title = title
    end for
    m.menuList.content = content
    m.menuList.jumpToItem = 0
    m.menuList.setFocus(true)
end sub

sub cancelMovieSelection()
    m.detail.cancelled = true
    m.detailPending = invalid
    m.detailTimer.control = "stop"
    m.playPending = false
end sub

sub closeMovieMenu()
    m.menu.visible = false
    ' A hidden LabelList can still own focus. Move to a sibling leaf explicitly.
    m.menuList.setFocus(false)
    focusMovieGrid()
end sub

sub focusMovieGrid()
    if m.searchActive = true
        m.movieSearchTrap.setFocus(true)
        return
    end if
    if m.detailsActive = true
        m.detailTrap.setFocus(true)
        return
    end if
    if m.gridTrap <> invalid then m.gridTrap.setFocus(true)
end sub

sub onMovieMenuSelected()
    if m.searchActive = true then return
    index = m.menuList.itemSelected
    if index < 0 or index >= m.menuActions.Count() then return
    action = m.menuActions[index]
    closeMovieMenu()
    if action = "Search movies"
        openMovieSearch("OK")
    else if action = "Refresh catalog"
        requestCatalog(1, true)
    else if action = "Archive discovery filters"
        openMovieMenu(true)
    else if action = "Back"
        openMovieMenu()
    else
        filters = {"Rare finds": "rare", "Workprints": "workprints", "Alternate cuts": "alternate", "Trailers": "trailers", "Behind the scenes": "behind", "Public-domain-marked classics": "classics"}
        if filters.DoesExist(action)
            m.profile = filters[action]
            m.query = ""
            requestCatalog(1, true)
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not m.top.visible then return false
    if m.keyReleaseGate <> invalid and m.keyReleaseGate = key
        if not press then m.keyReleaseGate = ""
        return true
    end if
    if not press then return false
    if movieSearchKey(key) then return true
    if m.menu.visible
        if key = "back" or key = "options"
            closeMovieMenu()
            return true
        end if
        return false
    end if
    if movieDetailsKey(key) then return true
    if key = "back" then return false
    if key = "options"
        openMovieMenu()
        return true
    else if key = "replay"
        openMovieSearch(key)
        return true
    end if
    if m.loading or m.playPending or m.searchActive = true then return true
    if key = "fastforward" and m.page < m.pages
        requestCatalog(m.page + 1, false)
        return true
    else if key = "rewind" and m.page > 1
        requestCatalog(m.page - 1, false)
        return true
    else if key = "OK" or key = "play"
        if m.items.Count() > 0
            m.keyReleaseGate = key
            showMovieDetails(m.items[m.focus], key)
        end if
        return true
    end if
    target = m.focus
    if movieHierarchyView()
        if key = "up" and target > 0 then target = target - 1
        if key = "down" and target + 1 < m.items.Count() then target = target + 1
    else
    if key = "left" and target mod 4 > 0 then target = target - 1
    if key = "right" and target mod 4 < 3 and target + 1 < m.items.Count() then target = target + 1
    if key = "up" and target >= 4 then target = target - 4
    if key = "down" and target < 4 and m.items.Count() > 4
        target = target + 4
        if target >= m.items.Count() then target = m.items.Count() - 1
    end if
    end if
    if target <> m.focus
        m.focus = target
        drawMovies()
        m.detailTimer.control = "stop"
        m.detailTimer.control = "start"
        return true
    end if
    return key = "left" or key = "right" or key = "up" or key = "down"
end function
