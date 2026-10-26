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
    require(m.title.text = "No matching movies", "empty movie search handled")
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
    print "PASS: eight-poster grid, fixed node count and movie details"
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
