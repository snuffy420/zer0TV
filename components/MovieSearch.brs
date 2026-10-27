sub initMovieSearch()
    m.movieSearchPanel = m.top.findNode("movieSearchPanel")
    m.movieSearchKeys = m.top.findNode("movieSearchKeys")
    m.movieSearchQuery = m.top.findNode("movieSearchQuery")
    m.movieSearchTrap = m.top.findNode("movieSearchTrap")
    m.searchActive = false
    m.keyReleaseGate = ""
    m.movieKeyboard = [["A","B","C","D","E","F","G"], ["H","I","J","K","L","M","N"], ["O","P","Q","R","S","T","U"], ["V","W","X","Y","Z","-","'"], ["0","1","2","3","4","5","6"], ["7","8","9",".","SPC","DEL","CLR"], ["SEARCH","CLEAR","CANCEL"]]
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
        m.movieSearchRow = (m.movieSearchRow + stepValue + m.movieKeyboard.Count()) mod m.movieKeyboard.Count()
        if m.movieSearchCol >= m.movieKeyboard[m.movieSearchRow].Count() then m.movieSearchCol = m.movieKeyboard[m.movieSearchRow].Count() - 1
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
