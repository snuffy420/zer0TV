sub initMovieSearch()
    m.movieSearchPanel = m.top.findNode("movieSearchPanel")
    m.movieSearchKeys = m.top.findNode("movieSearchKeys")
    m.movieSearchQuery = m.top.findNode("movieSearchQuery")
    m.movieSearchTrap = m.top.findNode("movieSearchTrap")
    m.searchActive = false
    m.keyReleaseGate = ""
    ' QWERTY, with SEARCH on the bottom row (Back cancels).
    m.movieQwerty = qwertyLayout(true)
    m.movieKeyboard = []
    for each row in m.movieQwerty
        values = []
        for each k in row
            values.Push(k.value)
        end for
        m.movieKeyboard.Push(values)
    end for
    m.movieKeyNodes = []
    grid = m.top.findNode("movieSearchGrid")
    if grid <> invalid
        m.top.findNode("movieSearchTitle").font = glowFont("bold", 40)
        m.movieSearchQuery.font = glowFont("bold", 34)
        glowHints(m.top.findNode("movieSearchHints"), [{icons: ["dpad-all"], text: "KEYS"}, {icons: ["ok"], text: "TYPE"}, {icons: ["playpause"], text: "SEARCH"}, {icons: ["replay"], text: "DELETE"}, {icons: ["back"], text: "CANCEL"}])
        m.movieKeyNodes = qwertyNodes(grid, m.movieQwerty, 84, 80)
    end if
end sub

sub openMovieSearch(entryKey = "" as String)
    cancelMovieSelection()
    m.keyReleaseGate = entryKey
    m.searchActive = true
    m.top.searchActive = true
    m.movieSearchText = m.query
    m.movieSearchRow = 0
    m.movieSearchCol = 0
    m.movieSearchPanel.visible = true
    drawMovieSearch()
    m.movieSearchTrap.setFocus(true)
end sub

sub drawMovieSearch()
    lines = []
    for r = 0 to m.movieKeyboard.Count() - 1
        row = []
        for c = 0 to m.movieKeyboard[r].Count() - 1
            value = m.movieKeyboard[r][c]
            if r = m.movieSearchRow and c = m.movieSearchCol
                row.Push("[" + value + "]")
            else
                row.Push(" " + value + " ")
            end if
        end for
        lines.Push(row.Join(" "))
    end for
    m.movieSearchKeys.text = lines.Join(Chr(10) + Chr(10))
    m.movieSearchQuery.text = m.movieSearchText + "_"
    if m.movieKeyNodes <> invalid then qwertyDraw(m.movieKeyNodes, m.movieSearchRow, m.movieSearchCol, true)
end sub

sub closeThemedMovieSearch(submit as Boolean, key as String)
    m.searchActive = false
    m.top.searchActive = false
    m.movieSearchPanel.visible = false
    m.movieSearchTrap.setFocus(false)
    m.keyReleaseGate = key
    if submit
        m.detailsActive = false
        m.query = m.movieSearchText.Trim()
        ' Replay's quick search looks for full movies; the * menu picks the kind.
        if m.searchMode = invalid then m.searchMode = "mixed"
        m.profile = "archive:" + m.searchMode
        m.searchMode = invalid
        requestCatalog(1, true)
    end if
    focusMovieGrid()
end sub

function movieSearchKey(key as String) as Boolean
    if m.searchActive <> true then return false
    if key = "back"
        closeThemedMovieSearch(false, key)
        return true
    else if key = "play"
        closeThemedMovieSearch(true, key)
        return true
    else if key = "up" or key = "down"
        stepValue = 1
        if key = "up" then stepValue = -1
        target = (m.movieSearchRow + stepValue + m.movieKeyboard.Count()) mod m.movieKeyboard.Count()
        m.movieSearchCol = qwertyColumn(m.movieQwerty, m.movieSearchRow, m.movieSearchCol, target)
        m.movieSearchRow = target
    else if key = "left" or key = "right"
        stepValue = 1
        if key = "left" then stepValue = -1
        cols = m.movieKeyboard[m.movieSearchRow].Count()
        m.movieSearchCol = (m.movieSearchCol + stepValue + cols) mod cols
    else if key = "replay"
        if Len(m.movieSearchText) > 0 then m.movieSearchText = Left(m.movieSearchText, Len(m.movieSearchText) - 1)
    else if key = "options"
        if Len(m.movieSearchText) < 160 then m.movieSearchText = m.movieSearchText + " "
    else if key = "OK"
        value = m.movieKeyboard[m.movieSearchRow][m.movieSearchCol]
        if value = "SEARCH" or value = "CANCEL"
            closeThemedMovieSearch(value = "SEARCH", key)
            return true
        else if value = "CLEAR" or value = "CLR"
            m.movieSearchText = ""
        else if value = "DEL"
            if Len(m.movieSearchText) > 0 then m.movieSearchText = Left(m.movieSearchText, Len(m.movieSearchText) - 1)
        else if Len(m.movieSearchText) < 160
            if value = "SPC" then value = " "
            m.movieSearchText = m.movieSearchText + value
        end if
    end if
    drawMovieSearch()
    m.movieSearchTrap.setFocus(true)
    return true
end function
