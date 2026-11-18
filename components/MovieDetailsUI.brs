' The title page, laid out as in Box://Stream, for every film, show and book:
' the poster on its bezel, the logo (or title), a green facts line, the tags,
' the plot and the buttons; then, for a show, its seasons and a row of episode
' cards (a picture, title, air date and plot each); for a film, its versions
' and extras as cards.

sub initMovieDetailsUI()
    m.detailPanel = m.top.findNode("movieDetailPanel")
    m.detailArtwork = m.top.findNode("movieDetailArtwork")
    m.detailPoster = m.top.findNode("movieDetailPoster")
    m.detailLogo = m.top.findNode("movieDetailLogo")
    m.detailHeading = m.top.findNode("movieDetailHeading")
    m.detailMetaLabel = m.top.findNode("movieDetailMetaLabel")
    m.detailGenres = m.top.findNode("movieDetailGenres")
    m.detailOverview = m.top.findNode("movieDetailOverview")
    m.detailTrap = m.top.findNode("movieDetailTrap")
    m.detailHints = m.top.findNode("movieDetailHints")
    m.pageButtons = m.top.findNode("moviePageButtons")
    m.pageChips = m.top.findNode("movieSeasonChips")
    m.detailHeading.font = glowFont("bold", 52)
    m.detailMetaLabel.font = glowFont("bold", 26)
    m.detailGenres.font = glowFont("regular", 22)
    m.detailOverview.font = glowFont("regular", 24)
    ' Four episode cards on screen; the row slides under the focus.
    m.pageCards = []
    host = m.top.findNode("movieEpisodeCards")
    m.pageRing = host.createChild("Poster")
    m.pageRing.uri = "pkg:/images/glow/focus.9.png"
    m.pageRing.width = 404 + 116
    m.pageRing.height = 227 + 116
    for i = 0 to 3
        group = host.createChild("Group")
        group.translation = [i * 430, 0]
        bezel = group.createChild("Poster")
        bezel.uri = "pkg:/images/glow/card.9.png"
        bezel.blendColor = "0x111927FF"
        bezel.width = 404
        bezel.height = 227
        still = group.createChild("Poster")
        still.width = 404
        still.height = 227
        still.loadWidth = 404
        still.loadHeight = 227
        still.loadDisplayMode = "scaleToZoom"
        title = group.createChild("Label")
        title.translation = [0, 240]
        title.width = 404
        title.maxLines = 1
        title.font = glowFont("bold", 22)
        detail = group.createChild("Label")
        detail.translation = [0, 274]
        detail.width = 404
        detail.maxLines = 1
        detail.font = glowFont("bold", 19)
        detail.color = "0x39FF14FF"
        overview = group.createChild("Label")
        overview.translation = [0, 304]
        overview.width = 404
        overview.wrap = true
        overview.maxLines = 2
        overview.font = glowFont("regular", 19)
        overview.color = "0x8391AAFF"
        ' Text that doesn't fit is cut at a word, never ended with "...".
        title.ellipsisText = ""
        detail.ellipsisText = ""
        overview.ellipsisText = ""
        m.pageCards.Push({group: group, still: still, title: title, detail: detail, overview: overview})
    end for
    m.detailsActive = false
end sub

function movieHierarchyView() as Boolean
    if type(m.browseState) <> "roAssociativeArray" then return false
    return m.browseState.section = "page"
end function

' A film's page.
sub showMovieDetails(item as Object, key as String)
    openTitlePage(item)
    m.keyReleaseGate = key
end sub

' Any title's page. Shows open on their first season.
sub openTitlePage(item as Object)
    cancelMovieSelection()
    m.browseState = {section: "page", series: item, savedItems: m.items, savedFocus: m.focus, zone: "buttons", button: 0, seasonIndex: 0, cardOffset: 0}
    m.focus = 0
    if item.kind = "series" and type(item.seasons) = "roArray" and item.seasons.Count() > 0
        m.items = seasonCards(item, 0)
    else
        m.items = versionCards(item)
        if not m.detailCache.DoesExist(item.id) then requestDetails(item, "info")
    end if
    drawMovies()
    focusMovieGrid()
end sub

' A season's episodes as cards: TVmaze's title, still, air date and plot when
' known, else the Archive's file name and thumbnail.
function seasonCards(show as Object, seasonIndex as Integer) as Object
    cards = []
    season = show.seasons[seasonIndex]
    for each e in season.episodes
        ' Catalog episodes are compact (t title, e number, r runtime, f file,
        ' i item when not the season's); search results carry full fields.
        thumb = ""
        if e.f <> invalid
            owner = movieText(season.item)
            if e.i <> invalid then owner = movieText(e.i)
            title = movieText(e.t)
            number = e.e
            runtime = e.r
            url = "https://archive.org/download/" + movieEncode(owner) + "/" + movieEncode(movieText(e.f))
            id = owner + "/" + movieText(e.f)
        else
            title = movieText(e.title)
            number = e.episode
            runtime = e.runtime
            url = movieText(e.url)
            id = movieText(e.id)
            thumb = movieText(e.thumb)
        end if
        episodeText = ""
        still = ""
        aired = ""
        if type(show.episodeInfo) = "roAssociativeArray"
            known = show.episodeInfo[season.season.ToStr() + "x" + number.ToStr()]
            if known <> invalid
                if known.t <> "" then title = known.t
                episodeText = known.d
                if known.i <> invalid then still = known.i
                if known.a <> invalid then aired = known.a
            end if
        end if
        if still = "" then still = thumb
        details = []
        if show.isBook = true then details.Push("Chapter " + number.ToStr()) else details.Push("S" + season.season.ToStr() + " E" + number.ToStr())
        if aired <> "" then details.Push(aired)
        if epgNumber(runtime) and runtime > 0 then details.Push(movieRuntime(runtime))
        format = "mp4"
        if e.format <> invalid then format = movieText(e.format)
        cards.Push({id: id, kind: "episode", name: title, url: url, provider: "archive", streamFormat: format, isMovie: true, curated: true, poster: show.poster, logo: show.logo, description: episodeText, year: show.year, genre: show.genre, still: still, pageTitle: number.ToStr() + ".  " + title, pageDetail: details.Join("   ·   ")})
    end for
    return cards
end function

' A film's versions (longest first) and extras; none when it has only one copy.
function versionCards(film as Object) as Object
    cards = []
    base = {provider: "archive", streamFormat: "mp4", isMovie: true, curated: true, kind: "episode", poster: film.poster, logo: film.logo, description: "", year: film.year, genre: film.genre}
    if type(film.versions) = "roArray" and film.versions.Count() > 1
        for each v in film.versions
            card = {}
            card.Append(base)
            card.id = movieText(v.id)
            card.url = movieText(v.url)
            card.name = film.name
            card.pageTitle = movieText(v.label)
            card.pageDetail = movieRuntime(v.runtime)
            cards.Push(card)
        end for
    end if
    if type(film.extras) = "roArray"
        for each x in film.extras
            card = {}
            card.Append(base)
            card.id = film.id + "/" + movieText(x.title)
            card.url = movieText(x.url)
            card.name = movieText(x.title)
            card.pageTitle = movieText(x.title)
            card.pageDetail = "Extra   ·   " + movieRuntime(x.runtime)
            cards.Push(card)
        end for
    end if
    return cards
end function

' The page's buttons: play, then favorites.
function pageButtonLabels() as Object
    state = m.browseState
    item = state.series
    play = "PLAY"
    if item.kind = "series" and m.items.Count() > 0
        play = "PLAY  S" + item.seasons[state.seasonIndex].season.ToStr() + " E1"
        if item.isBook = true then play = "PLAY  CHAPTER 1"
    end if
    favorite = "ADD TO FAVORITES"
    if isFavoriteItem(item) then favorite = "IN FAVORITES"
    return [play, favorite]
end function

sub drawMovieDetailsPanel()
    if m.detailPanel = invalid then return
    active = movieHierarchyView()
    m.detailPanel.visible = active
    if not active
        m.detailPoster.uri = ""
        m.detailArtwork.uri = ""
        m.detailLogo.uri = ""
        return
    end if
    state = m.browseState
    item = state.series
    if m.detailCache.DoesExist(item.id)
        ' Fuller details (plot, director...) for a film once they arrive.
        fuller = m.detailCache[item.id]
        for each field in fuller
            if field <> "versions" and field <> "extras" and field <> "seasons" then item[field] = fuller[field]
        end for
    end if
    isShow = item.kind = "series" and type(item.seasons) = "roArray"
    ' The banner: background art, poster, logo or title, facts, tags and plot.
    art = movieText(item.backdrop)
    if art = "" then art = movieText(item.poster)
    if m.detailArtwork.uri <> art then m.detailArtwork.uri = art
    if m.detailPoster.uri <> item.poster then m.detailPoster.uri = item.poster
    logo = movieText(item.logoArt)
    m.detailLogo.visible = logo <> ""
    if logo <> "" and m.detailLogo.uri <> logo then m.detailLogo.uri = logo
    m.detailHeading.visible = logo = ""
    m.detailHeading.text = item.name
    facts = []
    if movieText(item.year) <> "" then facts.Push(movieText(item.year))
    if not isShow and epgNumber(item.durationSeconds) and item.durationSeconds > 0 then facts.Push(movieRuntime(item.durationSeconds))
    if isShow
        count = 0
        for each s in item.seasons
            if type(s.episodes) = "roArray" then count = count + s.episodes.Count()
        end for
        if item.isBook = true
            facts.Push(count.ToStr() + " chapters")
        else
            seasonWord = " seasons"
            if item.seasons.Count() = 1 then seasonWord = " season"
            facts.Push(item.seasons.Count().ToStr() + seasonWord)
            facts.Push(count.ToStr() + " episodes")
        end if
    else if type(item.versions) = "roArray" and item.versions.Count() > 1
        facts.Push(item.versions.Count().ToStr() + " versions")
    end if
    m.detailMetaLabel.text = facts.Join("   ·   ")
    tags = []
    genre = movieText(item.genre)
    if genre <> "" and not isShow and genre.Instr("versions") < 0 then tags.Push(genre)
    if movieText(item.director) <> "" then tags.Push("Director: " + movieText(item.director))
    m.detailGenres.text = tags.Join("   ·   ")
    m.detailOverview.text = movieTrim(movieText(item.description), 420)
    ' Buttons.
    m.pageButtons.removeChildrenIndex(m.pageButtons.getChildCount(), 0)
    labels = pageButtonLabels()
    x = 0
    for i = 0 to labels.Count() - 1
        probe = CreateObject("roSGNode", "Label")
        probe.font = glowFont("bold", 22)
        probe.text = labels[i]
        width = probe.boundingRect().width + 60
        if width < 200 then width = 200
        chip = m.pageButtons.createChild("Poster")
        chip.uri = "pkg:/images/glow/chip.9.png"
        chip.translation = [x, 0]
        chip.width = width
        chip.height = 60
        label = m.pageButtons.createChild("Label")
        label.font = glowFont("bold", 22)
        label.text = labels[i]
        label.translation = [x, 0]
        label.width = width
        label.height = 60
        label.horizAlign = "center"
        label.vertAlign = "center"
        chip.blendColor = "0x1A2738FF"
        label.color = "0xDCE4F2FF"
        if state.zone = "buttons" and state.button = i
            chip.blendColor = "0x39FF14FF"
            label.color = "0x06110AFF"
        end if
        x = x + width + 20
    end for
    ' Seasons (or "Chapters", or "Versions and extras").
    m.pageChips.removeChildrenIndex(m.pageChips.getChildCount(), 0)
    chips = []
    if isShow
        if item.isBook = true
            chips.Push("Chapters")
        else
            for each s in item.seasons
                chips.Push("Season " + s.season.ToStr())
            end for
        end if
    else if m.items.Count() > 0
        chips.Push("Versions and extras")
    end if
    x = 0
    for i = 0 to chips.Count() - 1
        probe = CreateObject("roSGNode", "Label")
        probe.font = glowFont("bold", 20)
        probe.text = chips[i]
        width = probe.boundingRect().width + 44
        if width < 140 then width = 140
        chip = m.pageChips.createChild("Poster")
        chip.uri = "pkg:/images/glow/chip.9.png"
        chip.translation = [x, 0]
        chip.width = width
        chip.height = 44
        label = m.pageChips.createChild("Label")
        label.font = glowFont("bold", 20)
        label.text = chips[i]
        label.translation = [x, 0]
        label.width = width
        label.height = 44
        label.horizAlign = "center"
        label.vertAlign = "center"
        chip.blendColor = "0x111927FF"
        label.color = "0xAEB9CCFF"
        if i = state.seasonIndex
            chip.blendColor = "0x24405EFF"
            label.color = "0xFFFFFFFF"
            if state.zone = "seasons"
                chip.blendColor = "0x39FF14FF"
                label.color = "0x06110AFF"
            end if
        end if
        x = x + width + 14
    end for
    ' Cards: a picture for every episode (or version) from the start.
    if m.focus < state.cardOffset then state.cardOffset = m.focus
    if m.focus > state.cardOffset + 3 then state.cardOffset = m.focus - 3
    if state.cardOffset < 0 then state.cardOffset = 0
    fallback = movieText(item.backdrop)
    if fallback = "" then fallback = movieText(item.poster)
    for slot = 0 to 3
        card = m.pageCards[slot]
        index = state.cardOffset + slot
        card.group.visible = index < m.items.Count()
        if card.group.visible
            entry = m.items[index]
            picture = movieText(entry.still)
            if picture = "" then picture = fallback
            if card.still.uri <> picture then card.still.uri = picture
            card.title.text = movieText(entry.pageTitle)
            card.detail.text = movieText(entry.pageDetail)
            card.overview.text = movieTrim(movieText(entry.description), 88)
            card.title.color = "0xDCE4F2FF"
            if index = m.focus and state.zone = "cards" then card.title.color = "0xFFFFFFFF"
        else
            card.still.uri = ""
        end if
    end for
    m.pageRing.visible = state.zone = "cards" and m.items.Count() > 0
    m.pageRing.translation = [(m.focus - state.cardOffset) * 430 - 58, -58]
    ' Remote hints for where the focus is.
    hints = []
    if state.zone = "cards"
        hints.Push({icons: ["dpad-leftright"], text: "BROWSE"})
        hints.Push({icons: ["rewind", "forward"], text: "JUMP"})
        hints.Push({icons: ["ok"], text: "PLAY"})
    else if state.zone = "seasons"
        hints.Push({icons: ["dpad-leftright"], text: "SEASON"})
        hints.Push({icons: ["ok"], text: "EPISODES"})
    else
        hints.Push({icons: ["dpad-leftright"], text: "CHOOSE"})
        hints.Push({icons: ["ok"], text: "SELECT"})
    end if
    if m.items.Count() > 0 then hints.Push({icons: ["dpad-updown"], text: "MOVE"})
    hints.Push({icons: ["back"], text: "BACK"})
    glowHints(m.detailHints, hints)
end sub

' Keys on a title page. Options (*) and Replay go on to the browse screen.
function pageKey(key as String) as Boolean
    if not movieHierarchyView() then return false
    state = m.browseState
    item = state.series
    isShow = item.kind = "series" and type(item.seasons) = "roArray"
    if key = "options" or key = "replay" then return false
    if m.playPending then return true
    if key = "back"
        closeHierarchyLevel()
        return true
    end if
    if key = "play"
        if state.zone = "cards" and m.items.Count() > 0 then playPageItem(m.items[m.focus]) else playPageItem(invalid)
        return true
    end if
    if key = "OK"
        m.keyReleaseGate = key
        if state.zone = "buttons"
            if state.button = 0
                playPageItem(invalid)
            else
                toggleFavoriteItem(item)
                if m.tabs <> invalid then buildTabs()
            end if
        else if state.zone = "seasons"
            state.zone = "cards"
        else if m.items.Count() > 0
            playPageItem(m.items[m.focus])
        end if
        drawMovieDetailsPanel()
        return true
    end if
    if key = "up"
        if state.zone = "cards" and isShow and item.isBook <> true and item.seasons.Count() > 1
            state.zone = "seasons"
        else if state.zone <> "buttons"
            state.zone = "buttons"
        end if
    else if key = "down"
        if state.zone = "buttons" and isShow and item.isBook <> true and item.seasons.Count() > 1
            state.zone = "seasons"
        else if m.items.Count() > 0
            state.zone = "cards"
        end if
    else if key = "left" or key = "right" or key = "rewind" or key = "fastforward"
        delta = 1
        if key = "left" then delta = -1
        if key = "rewind" then delta = -4
        if key = "fastforward" then delta = 4
        if state.zone = "buttons"
            if Abs(delta) = 1 then state.button = state.button + delta
            if state.button < 0 then state.button = 0
            if state.button > 1 then state.button = 1
        else if state.zone = "seasons"
            target = state.seasonIndex + delta
            if target < 0 then target = 0
            if target >= item.seasons.Count() then target = item.seasons.Count() - 1
            if target <> state.seasonIndex
                state.seasonIndex = target
                m.items = seasonCards(item, target)
                m.focus = 0
                state.cardOffset = 0
            end if
        else
            target = m.focus + delta
            if target < 0 then target = 0
            if target >= m.items.Count() then target = m.items.Count() - 1
            m.focus = target
        end if
    else
        return true
    end if
    drawMovieDetailsPanel()
    return true
end function

' Play a card, or (invalid) the page's first: the film, or episode 1.
sub playPageItem(entry as Dynamic)
    if entry = invalid
        if m.browseState.series.kind = "series"
            if m.items.Count() = 0 then return
            entry = m.items[0]
        else
            entry = m.browseState.series
        end if
    end if
    requestDetails(entry, "play")
end sub
