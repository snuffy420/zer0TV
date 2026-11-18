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
    m.backdrop = m.top.findNode("movieBackdrop")
    m.heroPoster = m.top.findNode("movieHeroPoster")
    m.heroLogo = m.top.findNode("movieHeroLogo")
    m.focusRing = m.top.findNode("movieFocus")
    m.count.font = glowFont("bold", 20)
    m.meta.font = glowFont("bold", 24)
    m.plot.font = glowFont("regular", 24)
    m.message.font = glowFont("bold", 22)
    m.menuTitle.font = glowFont("bold", 40)
    m.menuList.font = glowFont("bold", 26)
    m.menuList.focusedFont = glowFont("bold", 26)
    glowHints(m.top.findNode("movieHints"), [{icons: ["dpad-all"], text: "BROWSE"}, {icons: ["rewind", "forward"], text: "JUMP"}, {icons: ["ok"], text: "OPEN"}, {icons: ["replay"], text: "SEARCH"}, {icons: ["star"], text: "MENU"}, {icons: ["back"], text: "SOURCES"}])
    m.tabHost = m.top.findNode("movieTabs")
    m.decadeHost = m.top.findNode("movieDecades")
    m.area = "grid"
    m.tabs = []
    m.tabIndex = 0
    m.decades = []
    m.decadeIndex = 0
    glowHints(m.top.findNode("movieMenuHints"), [{icons: ["dpad-updown"], text: "CHOOSE"}, {icons: ["ok"], text: "SELECT"}, {icons: ["back"], text: "CLOSE"}])
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

' One row of eight tall poster cards under the hero.
sub initMovieGrid()
    for i = 0 to 7
        group = m.host.createChild("Group")
        group.translation = [96 + i * 222, 566]
        border = group.createChild("Poster")
        border.uri = "pkg:/images/glow/card.9.png"
        border.width = 196
        border.height = 400
        border.blendColor = "0x111927FF"
        poster = group.createChild("Poster")
        poster.translation = [8, 8]
        poster.width = 180
        poster.height = 300
        poster.loadWidth = 180
        poster.loadHeight = 300
        poster.loadDisplayMode = "scaleToFit"
        title = group.createChild("Label")
        title.translation = [12, 318]
        title.width = 172
        title.height = 80
        title.wrap = true
        title.maxLines = 3
        title.ellipsisText = " "
        title.horizAlign = "center"
        title.font = glowFont("bold", 18)
        title.color = "0xDCE4F2FF"
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
    ' The first catalog section (the task picks it); * lists every section.
    m.profile = ""
    m.sections = []
    m.browseState = invalid
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
    if m.heroPoster <> invalid then m.heroPoster.uri = ""
    if m.backdrop <> invalid then m.backdrop.uri = ""
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
    m.appending = false
    m.openShowPending = false
    m.moreAvailable = false
    m.catalogPending = {provider: m.top.provider, query: m.query, profile: m.profile, page: page, fresh: fresh}
    m.message.text = "Searching the Archive"
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
    if m.opened and not m.catalog.cancelled and m.openShowPending = true
        m.openShowPending = false
        result = m.catalog.result
        if type(result.items) = "roArray" and result.items.Count() > 0
            m.message.text = ""
            openSeasons(result.items[0])
        else
            m.message.text = "This show's seasons couldn't be read right now."
        end if
        m.catalog.result = {}
        startCatalog()
        return
    end if
    if m.opened and not m.catalog.cancelled and m.appending = true
        ' More titles for the row: add the ones not already shown.
        m.appending = false
        result = m.catalog.result
        added = 0
        target = m.items
        if m.browseState <> invalid and type(m.browseState.savedItems) = "roArray" then target = m.browseState.savedItems
        if type(result.items) = "roArray"
            for each item in result.items
                if not m.shownIds.DoesExist(item.id)
                    m.shownIds[item.id] = true
                    target.Push(item)
                    added = added + 1
                end if
            end for
        end if
        m.morePage = result.page
        m.moreAvailable = result.pages > result.page
        if added > 0 then m.message.text = ""
        if m.items.Count() = 0 and not m.moreAvailable then m.message.text = "Nothing found here yet."
        drawMovies()
        ' A page with nothing new: keep looking (a few pages at a time). A row
        ' shorter than a screen keeps filling itself too.
        if added = 0 and m.moreAvailable and m.emptyMore < 8
            m.emptyMore = m.emptyMore + 1
            requestMore()
        else if added > 0
            m.emptyMore = 0
            if m.items.Count() < 16 and m.moreAvailable and m.browseState = invalid then requestMore()
        end if
        m.catalog.result = {}
        startCatalog()
        return
    end if
    if m.opened and not m.catalog.cancelled
        result = m.catalog.result
        if result.items <> invalid
            m.items = result.items
            m.page = result.page
            m.pages = result.pages
            m.focus = 0
            m.offset = 0
            m.loading = false
            ' Endless rows: a catalog section continues live; a search continues
            ' with its next page.
            m.shownIds = {}
            for each item in m.items
                m.shownIds[item.id] = true
            end for
            m.emptyMore = 0
            m.morePage = result.page
            if m.query = "" and epgString(result.section)
                ' A live section: its next page comes from the same rule.
                m.moreSection = result.section
                m.morePage = result.page
                m.moreAvailable = result.pages > result.page
            else
                m.moreSection = ""
                m.moreAvailable = result.pages > result.page
            end if
            ' Nothing on the first page: keep looking on the next ones.
            if m.items.Count() = 0 and m.moreAvailable = true and result.slow <> true
                m.emptyMore = 1
                m.message.text = "Still searching the Archive"
                requestMore()
            else if m.items.Count() < 16 and m.moreAvailable = true and result.slow <> true
                ' A short first page: the next one straight away.
                requestMore()
            end if
            if type(result.sections) = "roArray"
                m.sections = result.sections
                buildTabs()
            end if
            heading = "Search"
            if epgString(result.sectionTitle)
                heading = result.sectionTitle
                m.profile = result.section
            end if
            if m.query <> "" then heading = "Search  ·  " + m.query
            m.count.text = result.total.ToStr() + " titles   ·   page " + m.page.ToStr() + " of " + m.pages.ToStr()
            if m.query <> "" then m.count.text = "Search  ·  " + m.query + "   ·   page " + m.page.ToStr()
            syncTabs()
            m.message.text = result.message
            m.browseState = invalid
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
    if m.offset = invalid then m.offset = 0
    if m.focus = invalid or m.focus < 0 then m.focus = 0
    if m.focus >= m.items.Count() and m.items.Count() > 0 then m.focus = m.items.Count() - 1
    if m.focus < m.offset then m.offset = m.focus
    if m.focus > m.offset + 7 then m.offset = m.focus - 7
    if m.offset > m.items.Count() - 8 then m.offset = m.items.Count() - 8
    if m.offset < 0 then m.offset = 0
    for slot = 0 to 7
        card = m.cards[slot]
        i = m.offset + slot
        card.group.visible = i < m.items.Count() and gridVisible
        card.border.blendColor = "0x111927FF"
        card.title.color = "0xDCE4F2FF"
        if i = m.focus
            card.border.blendColor = "0x1A2738FF"
            card.title.color = "0xFFFFFFFF"
        end if
        if i < m.items.Count()
            item = m.items[i]
            card.title.text = item.name
            if epgString(item.cardTitle) then card.title.text = item.cardTitle
            card.title.font = glowFont("bold", 18)
            if Len(card.title.text) > 30 then card.title.font = glowFont("bold", 15)
            if Len(card.title.text) > 48 then card.title.font = glowFont("bold", 13)
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
    ' Where you are in a catalog section ("12 of 84").
    if gridVisible and m.items.Count() > 0 and type(m.count) = "roSGNode"
        m.count.text = (m.focus + 1).ToStr() + " of " + m.items.Count().ToStr()
        if m.moreAvailable = true then m.count.text = m.count.text + "+"
        if m.appending = true then m.count.text = m.count.text + "   ·   finding more"
    end if
    if m.focusRing <> invalid
        m.focusRing.visible = gridVisible and m.focus < m.items.Count()
        m.focusRing.translation = [96 + (m.focus - m.offset) * 222 - 58, 566 - 58]
        m.focusRing.width = 196 + 116
        m.focusRing.height = 400 + 116
    end if
    if m.items.Count() = 0
        m.title.text = "No matching titles"
        if m.moreAvailable = true or m.loading = true or m.appending = true then m.title.text = "Searching"
        if type(m.count) = "roSGNode" then m.count.text = ""
        m.meta.text = ""
        m.plot.text = ""
        if m.heroPoster <> invalid then m.heroPoster.uri = ""
        if m.backdrop <> invalid then m.backdrop.uri = ""
        return
    end if
    item = m.items[m.focus]
    if m.detailCache.DoesExist(item.id)
        item = m.detailCache[item.id]
        m.items[m.focus] = item
    end if
    m.title.text = item.name
    if m.heroLogo <> invalid
        logo = movieText(item.logoArt)
        m.heroLogo.visible = logo <> "" and gridVisible
        m.title.visible = not m.heroLogo.visible
        if logo <> "" and m.heroLogo.uri <> logo then m.heroLogo.uri = logo
    end if
    size = 52
    if Len(item.name) > 34 then size = 42
    if Len(item.name) > 48 then size = 34
    if Len(item.name) > 64 then size = 28
    m.title.font = glowFont("bold", size)
    parts = []
    if movieText(item.year) <> "" then parts.Push(movieText(item.year))
    if epgNumber(item.durationSeconds) and item.durationSeconds > 0 then parts.Push(movieRuntime(item.durationSeconds))
    if movieText(item.genre) <> "" then parts.Push(cleanTags(movieText(item.genre), item.name))
    m.meta.text = parts.Join("   ·   ")
    m.plot.text = movieTrim(movieText(item.description), 300)
    if m.plot.text = "" then m.plot.text = "Loading title details"
    if item.kind = "series" and movieText(item.description) = "" then m.plot.text = "Press OK to choose a season."
    if gridVisible
        if m.heroPoster <> invalid and m.heroPoster.uri <> item.poster then m.heroPoster.uri = item.poster
        art = movieText(item.backdrop)
        if art = "" then art = movieText(item.poster)
        if m.backdrop <> invalid and m.backdrop.uri <> art then m.backdrop.uri = art
    end if
end sub

' "1h 42m"
function movieRuntime(seconds as Integer) as String
    minutes = Int(seconds / 60)
    if minutes < 60 then return minutes.ToStr() + "m"
    text = Int(minutes / 60).ToStr() + "h"
    if minutes mod 60 > 0 then text = text + " " + (minutes mod 60).ToStr() + "m"
    return text
end function

' Whole sentences (or whole words) that fit, never a broken word or "...".
function movieTrim(text as String, limit as Integer) as String
    text = text.Trim()
    if Len(text) <= limit then return text
    cut = Left(text, limit)
    best = 0
    for i = Len(cut) - 1 to 1 step -1
        c = Mid(cut, i, 1)
        if (c = "." or c = "!" or c = "?") and Mid(cut, i + 1, 1) = " "
            best = i
            exit for
        end if
    end for
    if best >= Len(cut) * 0.4 then return Left(cut, best)
    for i = Len(cut) to 1 step -1
        if Mid(cut, i, 1) = " " then return Left(cut, i - 1).Trim()
    end for
    return cut
end function

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
                if m.items[i].id = item.id
                    if movieHierarchyView()
                        for each field in item
                            if field <> "name" then m.items[i][field] = item[field]
                        end for
                    else
                        m.items[i] = item
                    end if
                end if
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
        m.menuActions = []
        m.menuSections = {}
        m.menuItem = invalid
        if not movieHierarchyView() and m.items.Count() > 0 and m.focus < m.items.Count()
            m.menuItem = m.items[m.focus]
            if isFavoriteItem(m.menuItem) then m.menuActions.Push("Remove from Favorites") else m.menuActions.Push("Add to Favorites")
        end if
        for each s in m.sections
            if s.id <> "adult" or adultOn()
                m.menuActions.Push(s.title)
                m.menuSections[s.title] = s.id
            end if
        end for
        if adultOn() then m.menuActions.Push("Adult / XXX section: On") else m.menuActions.Push("Adult / XXX section: Off")
        m.menuActions.Push("Search Movies")
        m.menuActions.Push("Search TV Shows")
        m.menuActions.Push("Search Everything")
        m.menuActions.Push("Refresh this section")
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
    if action = "Add to Favorites" or action = "Remove from Favorites"
        toggleFavoriteItem(m.menuItem)
        buildTabs()
        if m.profile = "favorites" then showFavorites()
        return
    else if action = "Refresh this section"
        if m.profile = "favorites" then showFavorites() else requestCatalog(1, true)
        return
    end if
    if m.menuSections <> invalid and m.menuSections.DoesExist(action)
        m.profile = m.menuSections[action]
        m.query = ""
        requestCatalog(1, true)
    else if action = "Search Movies" or action = "Search TV Shows" or action = "Search Everything"
        m.searchMode = "films"
        if action = "Search TV Shows" then m.searchMode = "seasons"
        if action = "Search Everything" then m.searchMode = "mixed"
        openMovieSearch("OK")
    else if action = "Adult / XXX section: On" or action = "Adult / XXX section: Off"
        setting = CreateObject("roRegistrySection", "zer0_archive")
        if adultOn() then setting.Write("adult", "off") else setting.Write("adult", "on")
        setting.Flush()
        if not adultOn() and m.profile = "adult" then m.profile = ""
        buildTabs()
        openMovieMenu()
    else if action = "Refresh catalog"
        DeleteFile("cachefs:/zer0_archive_catalog.stamp")
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
    if pageKey(key) then return true
    if key = "back" then return false
    if key = "options"
        openMovieMenu()
        return true
    else if key = "replay"
        openMovieSearch(key)
        return true
    end if
    if m.area <> "grid" and not movieHierarchyView() then return tabKey(key)
    if m.loading and key = "back"
        m.catalog.cancelled = true
        m.catalogPending = invalid
        m.loading = false
        m.message.text = ""
        return true
    end if
    if m.loading or m.playPending or m.searchActive = true then return true
    if key = "OK" or key = "play"
        if m.items.Count() > 0
            m.keyReleaseGate = key
            item = m.items[m.focus]
            if item.kind = "series" and type(item.seasons) <> "roArray"
                m.openShowPending = true
                m.message.text = "Opening " + item.name
                m.catalogPending = {provider: m.top.provider, query: "", profile: "show:" + item.id, page: 1, fresh: true}
                startCatalog()
            else if item.kind = "series"
                openSeasons(item)
            else
                ' Films, trailers and versions: the title's page.
                showMovieDetails(item, key)
            end if
        end if
        return true
    end if
    target = m.focus
    if movieHierarchyView()
        if key = "up" and target > 0 then target = target - 1
        if key = "down" and target + 1 < m.items.Count() then target = target + 1
        if key = "rewind" then target = target - 8
        if key = "fastforward" then target = target + 8
        if target < 0 then target = 0
        if target >= m.items.Count() then target = m.items.Count() - 1
    else
    if key = "left" and target > 0 then target = target - 1
    if key = "right" and target + 1 < m.items.Count() then target = target + 1
    if key = "rewind" then target = target - 8
    if key = "fastforward" then target = target + 8
    if target < 0 then target = 0
    if target >= m.items.Count() then target = m.items.Count() - 1
    if key = "up" and not movieHierarchyView()
        ' Up from the posters: the decade chips, then the tabs.
        m.area = "tabs"
        if m.decades.Count() > 0 then m.area = "decades"
        drawTabs()
        return true
    end if
    end if
    if target <> m.focus
        m.focus = target
        if not movieHierarchyView() and m.moreAvailable = true and m.focus >= m.items.Count() - 4 then requestMore()
        drawMovies()
        m.detailTimer.control = "stop"
        m.detailTimer.control = "start"
        return true
    end if
    return key = "left" or key = "right" or key = "up" or key = "down"
end function

' ---- A title's page (MovieDetailsUI.brs) -------------------------------------

' A show opens its page (seasons and episode cards).
sub openSeasons(show as Object)
    if type(show.seasons) <> "roArray" or show.seasons.Count() = 0 then return
    openTitlePage(show)
end sub

' Back from a page: the row it came from.
sub closeHierarchyLevel()
    cancelMovieSelection()
    state = m.browseState
    m.browseState = invalid
    m.items = state.savedItems
    m.focus = state.savedFocus
    drawMovies()
    focusMovieGrid()
end sub

' ---- Tabs and decades (Box://Stream style) -------------------------------------

function tabTitle(group as String) as String
    names = {movies: "Movies", tv: "TV Shows", workprints: "Workprints", screeners: "Screeners", film35: "35mm", openmatte: "Open Matte", laserdisc: "Laser Disc", vhs: "VHS", adult: "Adult / XXX", trailers35: "Trailers", anime: "Anime", audiobooks: "Audiobooks"}
    if names.DoesExist(group) then return names[group]
    return group
end function

' The top tab a catalog section belongs to: the film sections (decades,
' workprints, screeners, 35mm, open matte, LaserDisc, adult) sit under Movies.
function sectionTab(s as Object) as String
    group = s.id
    if s.group <> invalid then group = s.group
    if group = "movies" or group = "workprints" or group = "screeners" or group = "film35" or group = "openmatte" or group = "laserdisc" or group = "vhs" or group = "adult" then return "movies"
    if group = "anime" then return "anime"
    return group
end function

' A section's chip under its tab: "1950s", "Workprints", ...
function sectionChip(s as Object) as String
    if s.chip <> invalid and s.chip <> "" then return s.chip
    if s.decade <> invalid and s.decade <> "" then return s.decade + "s"
    group = s.id
    if s.group <> invalid then group = s.group
    return tabTitle(group)
end function

function sectionShown(s as Object) as Boolean
    return s.id <> "adult" or adultOn()
end function

' One tab per catalog group (in catalog order), then Search.
' Top tabs: Movies, TV Shows, Trailers... (in catalog order), then Search.
sub buildTabs()
    m.tabs = []
    seen = {}
    for each s in m.sections
        tabName = sectionTab(s)
        if not seen.DoesExist(tabName) and sectionShown(s)
            seen[tabName] = true
            m.tabs.Push({group: tabName, title: tabTitle(tabName)})
        end if
    end for
    ' Order: Anime, Audiobooks, then Movies, TV Shows, Trailers.
    ordered = []
    for each wanted in ["anime", "audiobooks"]
        for each tabItem in m.tabs
            if tabItem.group = wanted then ordered.Push(tabItem)
        end for
    end for
    for each tabItem in m.tabs
        if tabItem.group <> "anime" and tabItem.group <> "audiobooks" then ordered.Push(tabItem)
    end for
    m.tabs = ordered
    if loadFavorites().Count() > 0 then m.tabs.Push({group: "favorites", title: "Favorites"})
    m.tabs.Push({group: "search", title: "Search"})
    syncTabs()
end sub

' The tabName and decade that hold the section on screen.
' The tabName and chip that hold the section on screen; chips are the sections
' under that tabName (when there is more than one).
sub syncTabs()
    current = invalid
    for each s in m.sections
        if s.id = m.profile then current = s
    end for
    tabName = ""
    if current <> invalid then tabName = sectionTab(current)
    if m.profile = "favorites" then tabName = "favorites"
    if m.query <> "" then tabName = "search"
    for i = 0 to m.tabs.Count() - 1
        if m.tabs[i].group = tabName then m.tabIndex = i
    end for
    m.decades = []
    m.decadeIndex = 0
    for each s in m.sections
        if sectionTab(s) = tabName and sectionShown(s)
            if s.id = m.profile then m.decadeIndex = m.decades.Count()
            m.decades.Push({id: s.id, title: sectionChip(s)})
        end if
    end for
    if m.decades.Count() < 2 then m.decades = []
    drawTabs()
end sub

sub drawTabs()
    if m.tabHost = invalid then return
    m.tabHost.removeChildrenIndex(m.tabHost.getChildCount(), 0)
    x = 0
    for i = 0 to m.tabs.Count() - 1
        label = CreateObject("roSGNode", "Label")
        label.font = glowFont("bold", 26)
        label.text = m.tabs[i].title
        width = label.boundingRect().width
        if width <= 0 then width = Len(label.text) * 14
        if m.area = "tabs" and i = m.tabIndex
            pill = m.tabHost.createChild("Poster")
            pill.uri = "pkg:/images/glow/chip.9.png"
            pill.blendColor = "0x39FF14FF"
            pill.translation = [x - 18, 0]
            pill.width = width + 36
            pill.height = 46
            label.color = "0x06110AFF"
        else if i = m.tabIndex
            label.color = "0xFFFFFFFF"
            line = m.tabHost.createChild("Rectangle")
            line.translation = [x, 44]
            line.width = width
            line.height = 3
            line.color = "0x39FF14FF"
        else
            label.color = "0x8391AAFF"
        end if
        label.translation = [x, 0]
        label.height = 46
        label.vertAlign = "center"
        m.tabHost.appendChild(label)
        x = x + width + 52
    end for
    m.decadeHost.removeChildrenIndex(m.decadeHost.getChildCount(), 0)
    m.decadeHost.visible = m.decades.Count() > 0
    x = 0
    for i = 0 to m.decades.Count() - 1
        probe = CreateObject("roSGNode", "Label")
        probe.font = glowFont("bold", 20)
        probe.text = m.decades[i].title
        chipWidth = probe.boundingRect().width + 40
        if chipWidth < 120 then chipWidth = 120
        chip = m.decadeHost.createChild("Poster")
        chip.uri = "pkg:/images/glow/chip.9.png"
        chip.translation = [x, 0]
        chip.width = chipWidth
        chip.height = 40
        label = m.decadeHost.createChild("Label")
        label.font = glowFont("bold", 20)
        label.text = m.decades[i].title
        label.translation = [x, 0]
        label.width = chipWidth
        label.height = 40
        label.horizAlign = "center"
        label.vertAlign = "center"
        chip.blendColor = "0x111927FF"
        label.color = "0xAEB9CCFF"
        if i = m.decadeIndex
            chip.blendColor = "0x24405EFF"
            label.color = "0xFFFFFFFF"
            if m.area = "decades"
                chip.blendColor = "0x39FF14FF"
                label.color = "0x06110AFF"
            end if
        end if
        x = x + chipWidth + 14
    end for
end sub

' Keys while the tabs or the decade chips have the focus.
function tabKey(key as String) as Boolean
    if key = "down" or key = "OK"
        if m.area = "tabs" and m.decades.Count() > 0 and key = "down"
            m.area = "decades"
        else if m.area = "tabs" and m.tabs.Count() > 0 and m.tabs[m.tabIndex].group = "search"
            m.area = "grid"
            openSearchChooser()
        else
            m.area = "grid"
        end if
        drawTabs()
        drawMovies()
        return true
    else if key = "up"
        if m.area = "decades" then m.area = "tabs"
        drawTabs()
        return true
    else if key = "left" or key = "right"
        delta = 1
        if key = "left" then delta = -1
        if m.area = "tabs"
            target = m.tabIndex + delta
            if target < 0 or target >= m.tabs.Count() then return true
            m.tabIndex = target
            group = m.tabs[target].group
            if group = "favorites"
                showFavorites()
            else if group <> "search"
                for each s in m.sections
                    if sectionTab(s) = group and sectionShown(s)
                        m.profile = s.id
                        m.query = ""
                        requestCatalog(1, true)
                        clearRowForSwitch()
                        exit for
                    end if
                end for
            end if
            drawTabs()
        else
            target = m.decadeIndex + delta
            if target < 0 or target >= m.decades.Count() then return true
            m.decadeIndex = target
            m.profile = m.decades[target].id
            m.query = ""
            requestCatalog(1, true)
            clearRowForSwitch()
            drawTabs()
        end if
        return true
    else if key = "back"
        m.area = "grid"
        drawTabs()
        return true
    end if
    return true
end function

' The Adult section's switch (off unless turned on in the * menu).
function adultOn() as Boolean
    return CreateObject("roRegistrySection", "zer0_archive").Read("adult") = "on"
end function

' "Name;Actor One;Actor Two" -> "Actor One · Actor Two":
' up to two tags, not the title itself.
function cleanTags(text as String, title as String) as String
    parts = CreateObject("roRegex", "[;,]", "").Split(text)
    out = []
    for each p in parts
        p = p.Trim()
        if p <> "" and LCase(p) <> LCase(title) and Len(p) <= 32 and out.Count() < 2 then out.Push(p)
    end for
    return out.Join(" · ")
end function

' The next page of the row: live Archive results for this section or search.
sub requestMore()
    if m.appending = true or m.catalogBusy then return
    m.appending = true
    if m.query <> ""
        m.catalogPending = {provider: m.top.provider, query: m.query, profile: m.profile, page: m.morePage + 1, fresh: true}
    else
        m.catalogPending = {provider: m.top.provider, query: "", profile: "more:" + m.moreSection, page: m.morePage + 1, fresh: true}
    end if
    startCatalog()
end sub

' ---- Favorites (kept on the Roku, compact: Archive path, name, year, poster) ----

function loadFavorites() as Object
    text = CreateObject("roRegistrySection", "zer0_archive").Read("favorites")
    saved = invalid
    if text <> "" then saved = ParseJson(text)
    if type(saved) <> "roArray" then saved = []
    return saved
end function

sub saveFavorites(list as Object)
    section = CreateObject("roRegistrySection", "zer0_archive")
    section.Write("favorites", FormatJson(list))
    section.Flush()
end sub

' The part of a download address after /download/ ("id/file.mp4").
function favoritePath(item as Object) as String
    url = movieText(item.url)
    at = url.Instr("/download/")
    if at >= 0 then return url.Mid(at + 10)
    return ""
end function

function favoriteKey(item as Object) as String
    if item.kind = "series" then return "show:" + movieText(item.id)
    return favoritePath(item)
end function

function isFavoriteItem(item as Object) as Boolean
    key = favoriteKey(item)
    for each f in loadFavorites()
        if f.key = key then return true
    end for
    return false
end function

sub toggleFavoriteItem(item as Object)
    if item = invalid then return
    key = favoriteKey(item)
    if key = "" or key = "show:" then return
    list = []
    removed = false
    for each f in loadFavorites()
        if f.key = key then removed = true else list.Push(f)
    end for
    if not removed
        poster = movieText(item.poster)
        if Len(poster) > 170 then poster = ""
        entry = {key: key, n: Left(movieText(item.name), 80), y: movieText(item.year), k: movieText(item.kind), p: poster}
        if epgNumber(item.durationSeconds) then entry.r = item.durationSeconds
        ' Newest first; a Roku keeps about 16 KB of settings, so up to 40.
        list.Unshift(entry)
        while list.Count() > 40
            list.Pop()
        end while
        m.message.text = "Added to Favorites"
    else
        m.message.text = "Removed from Favorites"
    end if
    saveFavorites(list)
end sub

sub showFavorites()
    m.profile = "favorites"
    m.query = ""
    m.items = []
    for each f in loadFavorites()
        item = {name: movieText(f.n), year: movieText(f.y), kind: movieText(f.k), poster: movieText(f.p), logo: "pkg:/images/providers/archive.png", provider: "archive", streamFormat: "mp4", isMovie: true, curated: true, description: "", genre: "Favorite"}
        key = movieText(f.key)
        if Left(key, 5) = "show:"
            item.id = Mid(key, 6)
            item.kind = "series"
        else
            item.id = key
            item.url = "https://archive.org/download/" + key
            if epgNumber(f.r) then item.durationSeconds = f.r
        end if
        if item.poster = ""
            ident = item.id
            if ident.Instr("/") > 0 then ident = Left(ident, ident.Instr("/"))
            item.poster = "https://archive.org/services/img/" + movieEncode(ident)
        end if
        item.backdrop = item.poster
        m.items.Push(item)
    end for
    m.focus = 0
    m.offset = 0
    m.moreAvailable = false
    m.loading = false
    m.message.text = ""
    if m.items.Count() = 0 then m.message.text = "No favorites yet. Press * on any title to add it."
    syncTabs()
    drawMovies()
end sub

' Search: choose Movies, TV Shows or Everything, then type.
sub openSearchChooser()
    cancelMovieSelection()
    m.menu.visible = true
    m.menuTitle.text = "Search"
    m.menuSections = {}
    m.menuItem = invalid
    m.menuActions = ["Search Movies", "Search TV Shows", "Search Everything"]
    content = CreateObject("roSGNode", "ContentNode")
    for each title in m.menuActions
        item = content.createChild("ContentNode")
        item.title = title
    end for
    m.menuList.content = content
    m.menuList.jumpToItem = 0
    m.menuList.setFocus(true)
end sub

' A new tab or chip: its chips, and an empty row saying it's searching, until
' its titles arrive (the old row would look like the new section's).
sub clearRowForSwitch()
    m.items = []
    m.focus = 0
    m.offset = 0
    m.browseState = invalid
    syncTabs()
    drawMovies()
end sub

