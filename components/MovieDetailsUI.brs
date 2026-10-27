sub initMovieDetailsUI()
    m.detailPanel = m.top.findNode("movieDetailPanel")
    m.detailArtwork = m.top.findNode("movieDetailArtwork")
    m.detailPoster = m.top.findNode("movieDetailPoster")
    m.detailHeading = m.top.findNode("movieDetailHeading")
    m.detailMetaLabel = m.top.findNode("movieDetailMetaLabel")
    m.detailActions = m.top.findNode("movieDetailActions")
    m.detailPrompt = m.top.findNode("movieDetailPrompt")
    m.detailOverview = m.top.findNode("movieDetailOverview")
    m.detailTrap = m.top.findNode("movieDetailTrap")
    m.episodeRows = []
    host = m.top.findNode("movieEpisodeRows")
    for i = 0 to 7
        group = host.createChild("Group")
        group.translation = [0, i * 36]
        rowBox = group.createChild("Rectangle")
        rowBox.width = 652
        rowBox.height = 33
        label = group.createChild("Label")
        label.translation = [12, 2]
        label.width = 628
        label.height = 29
        label.font = m.font
        m.episodeRows.Push({group: group, box: rowBox, label: label})
    end for
    m.detailsActive = false
    m.detailButton = 0
end sub

function movieHierarchyView() as Boolean
    if type(m.browseState) <> "roAssociativeArray" then return false
    return m.browseState.section = "seasons" or m.browseState.section = "episodes"
end function

sub showMovieDetails(item as Object, key as String)
    cancelMovieSelection()
    m.detailsActive = true
    m.detailItem = item
    m.detailButton = 0
    m.keyReleaseGate = key
    drawMovies()
    focusMovieGrid()
    if item.kind <> "series" and item.kind <> "season" and not m.detailCache.DoesExist(item.id) then requestDetails(item, "info")
end sub

sub drawMovieDetailsPanel()
    if m.detailPanel = invalid then return
    nested = movieHierarchyView()
    active = m.detailsActive = true or nested
    m.detailPanel.visible = active
    if not active
        m.detailPoster.uri = ""
        m.detailArtwork.uri = ""
        return
    end if
    item = invalid
    if m.detailsActive = true
        item = m.detailItem
        if m.detailCache.DoesExist(item.id) then item = m.detailCache[item.id]
        m.detailItem = item
    else
        item = m.browseState.series
    end if
    if type(item) <> "roAssociativeArray" then return
    if m.detailPoster.uri <> item.poster then m.detailPoster.uri = item.poster
    art = movieText(item.backdrop)
    if art = "" then art = movieText(item.poster)
    if m.detailArtwork.uri <> art then m.detailArtwork.uri = art
    m.detailHeading.text = item.name
    parts = []
    if movieText(item.year) <> "" then parts.Push(movieText(item.year))
    if epgNumber(item.durationSeconds) and item.durationSeconds > 0 then parts.Push(Int(item.durationSeconds / 60).ToStr() + " min")
    if movieText(item.genre) <> "" then parts.Push(movieText(item.genre))
    if movieText(item.director) <> "" then parts.Push("Director: " + movieText(item.director))
    m.detailMetaLabel.text = parts.Join(" | ")
    m.detailActions.visible = m.detailsActive = true
    m.detailOverview.visible = m.detailsActive = true
    m.detailOverview.text = Left(movieText(item.description), 600)
    if m.detailsActive = true
        m.detailActions.text = "[ PLAY ]        BACK TO BROWSE"
        if m.detailButton = 1 then m.detailActions.text = "PLAY        [ BACK TO BROWSE ]"
        m.detailPrompt.text = "OK select | Play starts this title | Back returns | * Browse"
    else
        m.detailPrompt.text = "Choose a season"
        if m.browseState.section = "episodes" then m.detailPrompt.text = "Choose an episode | REW/FF page | Back seasons"
        if m.loading then m.detailPrompt.text = "Loading the latest available episodes..."
    end if
    for i = 0 to 7
        row = m.episodeRows[i]
        row.group.visible = m.detailsActive <> true and i < m.items.Count()
        if row.group.visible
            row.label.text = m.items[i].name
            if epgString(m.items[i].cardTitle) then row.label.text = m.items[i].cardTitle
            row.box.color = "0x1B2A30FF"
            row.label.color = "0xD9E8E3FF"
            if i = m.focus
                row.box.color = "0x39FF14FF"
                row.label.color = "0x0A1711FF"
            end if
        end if
    end for
end sub

function movieDetailsKey(key as String) as Boolean
    if m.detailsActive <> true then return false
    if key = "back"
        cancelMovieSelection()
        m.detailsActive = false
        m.keyReleaseGate = key
        drawMovies()
        focusMovieGrid()
        return true
    else if key = "left" or key = "right"
        m.detailButton = 1 - m.detailButton
        drawMovieDetailsPanel()
        return true
    else if key = "OK" or key = "play"
        if key = "OK" and m.detailButton = 1 then return movieDetailsKey("back")
        if not m.playPending then requestDetails(m.detailItem, "play")
        m.keyReleaseGate = key
        return true
    end if
    return key <> "options" and key <> "replay"
end function
