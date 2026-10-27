sub main()
    m.host = CreateObject("roSGNode", "Group")
    m.font = CreateObject("roSGNode", "Font")
    m.cards = []
    m.items = []
    m.detailCache = {}
    m.title = {text: ""}
    m.meta = {text: ""}
    m.plot = {text: ""}
    m.focus = 0
    for i = 0 to 7
        m.items.Push({id: i.ToStr(), name: "Rare film " + i.ToStr(), description: "Alternate-cut description", year: "1968", genre: "Workprint", poster: "https://example.com/poster" + i.ToStr(), logo: "pkg:/images/providers/archive.png"})
    end for
    initMovieGrid()
    nodes = descendantCount(m.host)
    for i = 0 to 399
        m.focus = i mod 8
        drawMovies()
    end for
    require(m.cards.Count() = 8 and descendantCount(m.host) = nodes, "fixed eight-poster grid after repeated navigation")
    require(m.title.text = "Rare film 7", "focused metadata follows poster selection")
    m.items = []
    drawMovies()
    require(m.title.text = "No matching titles", "empty movie search handled")
    m.top = {visible: false, provider: "archive"}
    m.opened = true
    m.detailPending = invalid
    m.detailCache = {}
    m.cacheKeys = []
    m.detail = {state: "done", cancelled: false, result: {}}
    m.playPending = false
    for i = 0 to 29
        m.detail.result = {item: {id: i.ToStr(), name: "Movie"}, mode: "info", error: ""}
        onDetailState()
    end for
    require(m.cacheKeys.Count() = 24 and m.detailCache.Count() = 24, "bound detail metadata cache")
    m.detail.cancelled = true
    m.detail.result = {item: {id: "stale"}, mode: "info", error: ""}
    onDetailState()
    require(not m.detailCache.DoesExist("stale"), "ignore cancelled detail result")
    m.message = {text: ""}
    m.detailTimer = {control: ""}
    m.detailBusy = true
    requestDetails({id: "old"}, "info")
    requestDetails({id: "latest"}, "play")
    require(m.detail.cancelled and m.detailPending.item.id = "latest", "queue only latest movie selection")
    onDetailState()
    require(m.detailBusy and not m.detail.cancelled and m.detail.item.id = "latest", "wait for previous task completion before resolving movie")
    cancelMovieSelection()
    require(m.detail.cancelled and m.detailPending = invalid and not m.playPending, "opening menus cancels pending playback")
    m.catalog = {state: "done", cancelled: false, page: 99, result: {}}
    m.catalogBusy = true
    m.query = "first"
    m.profile = "workprints"
    requestCatalog(1, true)
    m.query = "latest"
    requestCatalog(2, false)
    require(m.catalog.page = 99 and m.catalog.cancelled, "do not overlap catalog tasks")
    onCatalogState()
    require(m.catalogBusy and m.catalog.page = 2 and m.catalog.query = "latest", "catalog worker consumes latest queued search")
    m.top.visible = true
    m.loading = false
    m.playPending = false
    m.menu = {visible: false}
    m.menuList = {focusOwned: true}
    m.menuList.setFocus = function(value as Boolean) as Boolean
        m.focusOwned = value
        return true
    end function
    m.gridTrap = {focusOwned: false}
    m.gridTrap.setFocus = function(value as Boolean) as Boolean
        m.focusOwned = value
        return true
    end function
    m.menu.visible = true
    m.menuList.focusOwned = true
    closeMovieMenu()
    require(not m.menuList.focusOwned and m.gridTrap.focusOwned, "closing category releases hidden list focus and focuses poster controls")
    m.top.lookup = {movieSearchPanel: {visible: false}, movieSearchKeys: {text: ""}, movieSearchQuery: {text: ""}, movieSearchTrap: m.gridTrap}
    m.top.findNode = function(id as String) as Dynamic
        return m.lookup[id]
    end function
    initMovieSearch()
    m.query = ""
    m.top.selectedMovie = invalid
    openMovieSearch()
    require(onKeyEvent("OK", true) and m.movieSearchText = "A" and m.searchActive, "OK types a search character instead of selecting a movie")
    require(m.top.selectedMovie = invalid and m.detail.cancelled, "typing cancels pending playback and emits no movie selection")
    m.movieSearchRow = 6
    m.movieSearchCol = 0
    require(onKeyEvent("OK", true) and not m.searchActive and m.query = "A", "explicit Search submits the completed title")
    require(onKeyEvent("OK", true) and m.top.selectedMovie = invalid, "held submit button cannot select a result after search closes")
    require(onKeyEvent("OK", false) and m.keyReleaseGate = "", "release clears the held-key barrier")
    openMovieSearch()
    m.movieSearchText = "CANCELLED"
    require(movieSearchKey("back") and m.query = "A", "Back cancels unfinished search without changing the catalog query")
    print "PASS: eight-poster grid, search submission, held keys and focus restoration"
end sub

function descendantCount(node as Object) as Integer
    total = node.getChildCount()
    for i = 0 to node.getChildCount() - 1
        total = total + descendantCount(node.getChild(i))
    end for
    return total
end function

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
