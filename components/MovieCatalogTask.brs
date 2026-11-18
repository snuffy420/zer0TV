sub init()
    m.top.functionName = "loadCatalog"
    m.httpKey = "catalog"
end sub

sub loadCatalog()
    ' A search goes to the Archive live; browsing reads zer0TV's catalog, and
    ' "more:SECTION" keeps finding more of a section live, page after page.
    if Left(m.top.profile, 5) = "more:"
        result = loadMore(Mid(m.top.profile, 6), m.top.page)
    else if Left(m.top.profile, 5) = "show:"
        result = loadShow(Mid(m.top.profile, 6))
    else if m.top.query = "" and Left(m.top.profile, 8) <> "archive:"
        result = loadCuratedSection(m.top.profile, m.top.page, m.top.fresh)
    else
        result = loadArchiveCatalog()
    end if
    if not m.top.cancelled then m.top.result = result
end sub

' A section, searched live with its rule from config/archive.json (no titles
' are built in): the first page now; scrolling asks for "more:" pages.
function loadCuratedSection(sectionId as String, page as Integer, fresh as Boolean) as Object
    config = ParseJson(ReadAsciiFile("pkg:/config/archive.json"))
    if type(config) <> "roAssociativeArray" or type(config.sections) <> "roArray" or config.sections.Count() = 0 then return emptyCatalog("No Archive sections are set up.")
    chosen = config.sections[0]
    for each s in config.sections
        if s.id = sectionId then chosen = s
    end for
    result = loadMore(chosen.id, 1)
    result.sections = config.sections
    result.section = chosen.id
    result.sectionTitle = chosen.title
    result.live = true
    if result.items.Count() = 0 then result.message = "Searching the Archive found nothing new here yet. Scroll or try another section."
    return result
end function

function emptyCatalog(message as String) as Object
    return {items: [], total: 0, page: 1, pages: 1, message: message, fromCache: false}
end function

function loadArchiveCatalog() as Object
    profile = m.top.profile
    if Left(profile, 8) = "archive:" then profile = Mid(profile, 9)
    ' Searches: full-length movies or full TV seasons first (checked against
    ' the real files), or everything as the Archive returns it.
    if m.top.query <> "" and (profile = "full" or profile = "seasons" or profile = "films" or profile = "mixed") then return searchFullLength(profile)
    query = archiveQuery(profile, m.top.query)
    url = "https://archive.org/advancedsearch.php?q=" + movieEncode(query) + "&rows=8&page=" + m.top.page.ToStr() + "&sort%5B%5D=downloads%20desc&output=json"
    for each field in ["identifier", "title", "description", "year", "creator", "runtime", "subject", "licenseurl"]
        url = url + "&fl%5B%5D=" + field
    end for
    body = movieHttp(url)
    cached = false
    cache = "tmp:/zer0_archive_session.json"
    if body = invalid
        old = ParseJson(ReadAsciiFile(cache))
        if type(old) = "roAssociativeArray"
            if old.url = url
                body = old.body
                cached = true
            end if
        end if
    else
        WriteAsciiFile(cache, FormatJson({url: url, body: body}))
    end if
    if body = invalid then return emptyCatalog("Archive unavailable - use * to retry")
    data = ParseJson(body)
    if type(data) <> "roAssociativeArray" then return emptyCatalog("Archive returned an invalid catalog")
    if type(data.response) <> "roAssociativeArray" then return emptyCatalog("Archive query unavailable")
    if type(data.response.docs) <> "roArray" then return emptyCatalog("No matching Archive items")
    items = []
    for each entry in data.response.docs
        id = movieText(entry.identifier)
        if id <> ""
            items.Push({id: id, provider: "archive", name: movieText(entry.title), description: Left(movieText(entry.description), 1200), year: movieText(entry.year), genre: Left(movieText(entry.subject), 100), creator: movieText(entry.creator), poster: "https://archive.org/services/img/" + movieEncode(id), logo: "pkg:/images/providers/archive.png", url: "", streamFormat: "mp4", isMovie: true})
        end if
    end for
    total = data.response.numFound
    pages = Int((total + 7) / 8)
    if pages < 1 then pages = 1
    message = "Fresh Archive catalog - " + m.top.profile
    if cached then message = "Network unavailable - this session's cached catalog"
    return {items: items, total: total, page: m.top.page, pages: pages, message: message, fromCache: cached}
end function

' ---- Search: full movies / full TV seasons ------------------------------------

' Each item's file list (archive.org/metadata/ID/files), several at a time.
function fetchFileLists(ids as Object) as Object
    port = CreateObject("roMessagePort")
    jobs = {}
    for each id in ids
        transfer = CreateObject("roUrlTransfer")
        transfer.SetMessagePort(port)
        transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        transfer.InitClientCertificates()
        transfer.EnableEncodings(true)
        transfer.SetUrl("https://archive.org/metadata/" + movieEncode(id) + "/files")
        if transfer.AsyncGetToString() then jobs[transfer.GetIdentity().ToStr()] = {transfer: transfer, id: id}
    end for
    results = {}
    pending = jobs.Count()
    clock = CreateObject("roTimespan")
    ' Up to 20 s when the Archive is slow, but once 3 in 4 have answered (after
    ' 3 s) a few stragglers don't hold up the whole page.
    total = jobs.Count()
    while pending > 0 and clock.TotalMilliseconds() < 20000
        if m.top.cancelled then exit while
        if clock.TotalMilliseconds() > 3000 and (total - pending) * 4 >= total * 3 then exit while
        event = Wait(100, port)
        if type(event) = "roUrlEvent" and event.GetInt() = 1
            key = event.GetSourceIdentity().ToStr()
            if jobs.DoesExist(key)
                pending = pending - 1
                if event.GetResponseCode() = 200
                    data = ParseJson(event.GetString())
                    if type(data) = "roAssociativeArray" and type(data.result) = "roArray" then results[jobs[key].id] = data.result
                end if
            end if
        end if
    end while
    ' Remember whether the Archive answered in time (for the "slow" note), and
    ' whether a quarter or more never answered (that page isn't kept).
    m.slowArchive = pending > 0 and pending = jobs.Count()
    m.listsShort = pending * 4 > jobs.Count()
    for each key in jobs
        jobs[key].transfer.AsyncCancel()
    end for
    return results
end function

' "5432.1" or "1:30:32" -> seconds
function fileSeconds(value as Dynamic) as Integer
    text = movieText(value)
    if text = "" then return 0
    if text.Instr(":") >= 0
        total = 0
        for each part in text.Split(":")
            total = total * 60 + Val(part)
        end for
        return Int(total)
    end if
    return Int(Val(text))
end function

' Playable MP4s: {name, length, score}, best encoding first per name.
function mp4Files(files as Object) as Object
    ' Thumbnails the Archive made from each video, by the video's base name.
    baseOf = CreateObject("roRegex", "(\.ia|_512kb|\.h264)?\.[A-Za-z0-9]+$", "i")
    thumbs = {}
    for each f in files
        if movieText(f.format) = "Thumbnail"
            key = baseOf.ReplaceAll(movieText(f.original), "")
            if not thumbs.DoesExist(key) then thumbs[key] = []
            thumbs[key].Push(movieText(f.name))
        end if
    end for
    found = []
    for each f in files
        name = movieText(f.name)
        lowered = LCase(name)
        if Right(lowered, 4) = ".mp4" and not movieFlag(f.private) and lowered.Instr("sample") < 0 and lowered.Instr("trailer") < 0
            fmt = LCase(movieText(f.format))
            score = 10
            if fmt.Instr("h.264") >= 0 then score = 100
            if fmt = "mpeg4" then score = 80
            if fmt.Instr("512") >= 0 then score = 40
            thumb = ""
            list = thumbs[baseOf.ReplaceAll(name, "")]
            if list <> invalid
                list.Sort()
                ' The second frame: the first is often black.
                thumb = list[0]
                if list.Count() > 1 then thumb = list[1]
            end if
            found.Push({name: name, length: fileSeconds(f.length), score: score, thumb: thumb})
        end if
    end for
    return found
end function

' Archive search, several ways in turn until a page of results is found:
' the exact phrase in the title, then every word in the title or subject,
' then the same with spelling tolerance (word~).
' Archive search for typed words, ranked by the Archive's own relevance:
' the exact phrase in the title, then every word in the title, then every
' word anywhere, then with spelling tolerance; stops at the first that finds
' anything. sizeFilter screens out items too small to be what was asked for.
function archiveDocs(words as String, page as Integer, rows as Integer, sizeFilter = "" as String) as Object
    base = "mediatype:movies AND -access-restricted-item:true AND "
    if sizeFilter <> "" then base = base + sizeFilter + " AND "
    list = words.Split(" ")
    allWords = list.Join(" AND ")
    fuzzy = []
    for each w in list
        if Len(w) >= 4 then fuzzy.Push(w + "~") else fuzzy.Push(w)
    end for
    attempts = []
    if list.Count() > 1 then attempts.Push(base + "title:(" + Chr(34) + words + Chr(34) + ")")
    attempts.Push(base + "title:(" + allWords + ")")
    attempts.Push(base + "(subject:(" + allWords + ") OR description:(" + allWords + "))")
    attempts.Push(base + "title:(" + fuzzy.Join(" AND ") + ")")
    docs = []
    seen = {}
    more = false
    for each query in attempts
        url = "https://archive.org/advancedsearch.php?q=" + movieEncode(query) + "&rows=" + rows.ToStr() + "&page=" + page.ToStr() + "&output=json"
        for each field in ["identifier", "title", "description", "year", "subject", "collection"]
            url = url + "&fl%5B%5D=" + field
        end for
        body = movieHttp(url)
        if body <> invalid
            data = ParseJson(body)
            if type(data) = "roAssociativeArray" and type(data.response) = "roAssociativeArray" and type(data.response.docs) = "roArray"
                if data.response.docs.Count() >= rows then more = true
                for each d in data.response.docs
                    id = movieText(d.identifier)
                    if id <> "" and not seen.DoesExist(id)
                        seen[id] = true
                        docs.Push(d)
                    end if
                end for
            end if
        end if
        if m.top.cancelled then exit for
        if docs.Count() > 0 then exit for
    end for
    return {docs: docs, more: more}
end function

' A film's name without upload notes: brackets, "Full Movie", version words,
' a trailing year.
function filmName(title as String) as String
    text = CreateObject("roRegex", "[_]+", "").ReplaceAll(title, " ")
    text = CreateObject("roRegex", "\([^)]*\)|\[[^\]]*\]", "").ReplaceAll(text, " ")
    text = CreateObject("roRegex", "\b(full movie|full film|hd|720p|1080p|2160p|4k|uhd|dvd ?rip|bd ?rip|blu-?ray|vhs|laser ?disc|work ?print|rough cut|director'?s cut|extended( cut| edition)?|alternate( cut| version)?|open matte|uncut|unrated|35 ?mm|16 ?mm|screener|tv (cut|version)|remastered|restored|upscaled?)\b", "i").ReplaceAll(text, " ")
    text = CreateObject("roRegex", "\s+", "").ReplaceAll(text, " ").Trim()
    text = CreateObject("roRegex", "[\s,:-]+((19|20)\d\d)$", "").ReplaceAll(text, "")
    text = CreateObject("roRegex", "[\s:,-]+(the|a|an)$", "i").ReplaceAll(text, "")
    text = CreateObject("roRegex", "^[\s\-:.|,]+|[\s\-:.|,]+$", "").ReplaceAll(text, "")
    if text = "" then return title
    return text
end function

' What a copy is: "35mm · Workprint", or "" for an ordinary copy.
function versionLabel(title as String) as String
    labels = []
    checks = [["35mm", "35 ?mm"], ["16mm", "16 ?mm"], ["Workprint", "work ?print"], ["Rough cut", "rough cut"], ["Director's cut", "director'?s cut"], ["Extended cut", "\bextended\b"], ["Alternate cut", "\balternat"], ["Open matte", "open matte"], ["Uncut", "\buncut\b|\bunrated\b"], ["Screener", "\bscreener\b"], ["TV version", "\btv (cut|version)\b"], ["Laserdisc", "laser ?disc"], ["VHS", "\bvhs\b"]]
    for each c in checks
        if CreateObject("roRegex", c[1], "i").IsMatch(title) then labels.Push(c[0])
    end for
    return labels.Join(" · ")
end function

function yearIn(text as String) as Integer
    match = CreateObject("roRegex", "\b(19\d\d|20[0-2]\d)\b", "").Match(text)
    if match.Count() > 1 then return Val(match[1])
    return 0
end function

function normName(text as String) as String
    return CreateObject("roRegex", "[^a-z0-9]", "").ReplaceAll(LCase(text.Replace("&", "and")), "")
end function

' IMDb's public title search for each name, several at a time: the real title,
' year and poster when a film matches. Slow or failed lookups are skipped.
function imdbMatches(films as Object) as Object
    port = CreateObject("roMessagePort")
    jobs = {}
    for i = 0 to films.Count() - 1
        query = LCase(CreateObject("roRegex", "[^\w\s']", "").ReplaceAll(films[i].film, " ").Trim())
        if query <> ""
            transfer = CreateObject("roUrlTransfer")
            transfer.SetMessagePort(port)
            transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
            transfer.InitClientCertificates()
            transfer.SetUrl("https://v3.sg.media-imdb.com/suggestion/" + Left(query, 1) + "/" + transfer.Escape(query) + ".json")
            if transfer.AsyncGetToString() then jobs[transfer.GetIdentity().ToStr()] = {transfer: transfer, index: i}
        end if
    end for
    found = {}
    pending = jobs.Count()
    clock = CreateObject("roTimespan")
    while pending > 0 and clock.TotalMilliseconds() < 4000
        if m.top.cancelled then exit while
        event = Wait(100, port)
        if type(event) = "roUrlEvent" and event.GetInt() = 1
            key = event.GetSourceIdentity().ToStr()
            if jobs.DoesExist(key)
                pending = pending - 1
                data = invalid
                if event.GetResponseCode() = 200 then data = ParseJson(event.GetString())
                film = films[jobs[key].index]
                if type(data) = "roAssociativeArray" and type(data.d) = "roArray"
                    for each entry in data.d
                        kind = movieText(entry.q)
                        y = 0
                        if epgNumber(entry.y) then y = entry.y
                        close = film.year = 0 or y = 0 or Abs(y - film.year) <= 1
                        if (kind = "feature" or kind = "TV movie") and close and normName(movieText(entry.l)) = normName(film.film)
                            poster = ""
                            if type(entry.i) = "roAssociativeArray" then poster = movieText(entry.i.imageUrl).Replace("._V1_.jpg", "._V1_QL75_UX400_.jpg")
                            found[jobs[key].index.ToStr()] = {title: movieText(entry.l), year: y, poster: poster}
                            exit for
                        end if
                    end for
                end if
            end if
        end if
    end while
    for each key in jobs
        jobs[key].transfer.AsyncCancel()
    end for
    return found
end function

' Adult by its title, subject or description.
function isAdultDoc(doc as Object) as Boolean
    ' Title, tags (subject), collections and description.
    words = LCase(movieText(doc.title) + " " + movieText(doc.subject) + " " + movieText(doc.collection) + " " + movieText(doc.description))
    for each w in ["porn", "xxx", "erotic", "sexploitation", "adultfilm", "adult_film", "adult-film", "nsfw", "hentai", "hardcore", "softcore", "nude", "nudist", "nympho", "playboy", "kama sutra", "kamasutra", "adult film", "adult movie", "adult star", "adult film star", " sex ", "sex tape", "explicit sex", "sexual fantas", "orgy", "stripper", "escort", "fetish", "bdsm", "x-rated", "x rated"]
        if words.Instr(w) >= 0 then return true
    end for
    return false
end function

function searchFullLength(mode as String) as Object
    words = CreateObject("roRegex", "[^a-zA-Z0-9' ]", "").ReplaceAll(m.top.query, " ")
    words = CreateObject("roRegex", "\s+", "").ReplaceAll(words, " ").Trim()
    if words = "" then return emptyCatalog("Type something to search for.")
    ' "films": films only; "seasons": full TV seasons only; "full"/"mixed": both.
    ' Size screens: a film is a few hundred MB at least; a season, gigabytes.
    if mode = "full" then mode = "mixed"
    sizeFilter = "item_size:[250000000 TO *]"
    if mode = "seasons" then sizeFilter = "item_size:[1000000000 TO *]"
    result = archiveDocs(words, m.top.page, 40, sizeFilter)
    if mode = "films" then mode = "full"
    items = tvEnrich(docsToItems(result.docs, mode, 3600))
    pages = m.top.page
    if result.more then pages = m.top.page + 1
    label = "full movies"
    if mode = "seasons" then label = "full TV seasons"
    message = ""
    if items.Count() = 0
        message = "No " + label + " found for " + Chr(34) + m.top.query + Chr(34) + " on this page."
        if result.more then message = message + " FF looks further."
    end if
    return {items: items, total: items.Count(), page: m.top.page, pages: pages, message: message, fromCache: false}
end function

' Every film-length file (an hour or more) in an item, best encoding per film.
function collectionItems(doc as Object, files as Object) as Object
    byName = {}
    for each f in files
        if f.length >= 3600
            base = CreateObject("roRegex", "(\.ia|_512kb|\.h264)?\.mp4$", "i").ReplaceAll(f.name, "")
            if not byName.DoesExist(base) or f.score > byName[base].score then byName[base] = f
        end if
    end for
    out = []
    if byName.Count() < 2 then return out
    id = movieText(doc.identifier)
    for each base in byName
        f = byName[base]
        raw = episodeName(f.name)
        out.Push({raw: raw, item: {id: id + "/" + f.name, provider: "archive", name: raw, description: "", year: movieText(doc.year), genre: "", poster: "https://archive.org/services/img/" + movieEncode(id), logo: "pkg:/images/providers/archive.png", url: "https://archive.org/download/" + movieEncode(id) + "/" + movieEncode(f.name), streamFormat: "mp4", isMovie: true, kind: "movie", curated: true, durationSeconds: f.length}})
    end for
    return out
end function

function fullMovieItem(doc as Object, files as Object, minSeconds = 3600 as Integer) as Dynamic
    best = invalid
    for each f in files
        if f.length >= minSeconds
            if best = invalid or f.score > best.score or (f.score = best.score and f.length > best.length) then best = f
        end if
    end for
    if best = invalid then return invalid
    id = movieText(doc.identifier)
    return {id: id, provider: "archive", name: movieText(doc.title), description: Left(movieText(doc.description), 1200), year: movieText(doc.year), genre: Left(movieText(doc.subject), 100), poster: "https://archive.org/services/img/" + movieEncode(id), logo: "pkg:/images/providers/archive.png", url: "https://archive.org/download/" + movieEncode(id) + "/" + movieEncode(best.name), streamFormat: "mp4", isMovie: true, kind: "movie", curated: true, durationSeconds: best.length}
end function

' A full season: 8 or more episode-length files (10 min+), numbered 1..n.
function fullSeasonItem(doc as Object, files as Object) as Dynamic
    byName = {}
    for each f in files
        if f.length >= 600
            base = CreateObject("roRegex", "(\.ia|_512kb|\.h264)?\.mp4$", "i").ReplaceAll(f.name, "")
            if not byName.DoesExist(base) or f.score > byName[base].score then byName[base] = f
        end if
    end for
    if byName.Count() < 8 then return invalid
    pattern = CreateObject("roRegex", "[Ss](\d{1,2})[ ._-]?[Ee](\d{1,3})|(\d{1,2})x(\d{1,3})", "")
    seasons = {}
    unnumbered = []
    id = movieText(doc.identifier)
    for each base in byName
        f = byName[base]
        match = pattern.Match(f.name)
        episode = {id: id + "/" + f.name, kind: "episode", title: episodeName(f.name), runtime: f.length, url: "https://archive.org/download/" + movieEncode(id) + "/" + movieEncode(f.name)}
        if f.thumb <> invalid and f.thumb <> "" then episode.thumb = "https://archive.org/download/" + movieEncode(id) + "/" + movieEncode(f.thumb)
        ' A season folder: "Season 2/04 - Title.mp4", "S2/E04.mp4".
        folder = CreateObject("roRegex", "(?:^|/)(?:season|series|s)[ ._-]*0*(\d{1,2})[^/]*/", "i").Match(f.name)
        if folder.Count() > 1 and match.Count() <= 1
            own = f.name.Mid(f.name.Instr("/") + 1)
            while own.Instr("/") >= 0
                own = own.Mid(own.Instr("/") + 1)
            end while
            number = CreateObject("roRegex", "(?:^|[ ._-])(?:e|ep|episode)?[ ._-]*0*(\d{1,3})(?=[ ._-]|$)", "i").Match(CreateObject("roRegex", "\.mp4$", "i").ReplaceAll(own, ""))
            if number.Count() > 1
                episode.season = Val(folder[1])
                episode.episode = Val(number[1])
                episode.title = episodeName(own)
            end if
        end if
        if episode.season <> invalid
            ' numbered from its season folder
        else if match.Count() > 2 and match[1] <> ""
            episode.season = Val(match[1])
            episode.episode = Val(match[2])
        else if match.Count() > 4 and match[3] <> ""
            episode.season = Val(match[3])
            episode.episode = Val(match[4])
        end if
        if episode.season = invalid
            unnumbered.Push(episode)
        else
            key = episode.season.ToStr()
            if not seasons.DoesExist(key) then seasons[key] = []
            seasons[key].Push(episode)
        end if
    end for
    if seasons.Count() = 0
        ' No numbers in the names: one season in file order.
        unnumbered.SortBy("title")
        for i = 0 to unnumbered.Count() - 1
            unnumbered[i].season = 1
            unnumbered[i].episode = i + 1
        end for
        seasons["1"] = unnumbered
    end if
    list = []
    for each key in seasons
        episodes = seasons[key]
        episodes.SortBy("episode")
        complete = episodes.Count() >= 8
        for i = 0 to episodes.Count() - 1
            if episodes[i].episode <> i + 1 then complete = false
        end for
        if complete then list.Push({season: Val(key), episodes: episodes})
    end for
    if list.Count() = 0 then return invalid
    list.SortBy("season")
    count = 0
    for each s in list
        count = count + s.episodes.Count()
    end for
    seasonWord = " seasons"
    if list.Count() = 1 then seasonWord = " season"
    return {id: id, provider: "archive", name: movieText(doc.title), description: Left(movieText(doc.description), 1200), year: movieText(doc.year), genre: list.Count().ToStr() + seasonWord + "   ·   " + count.ToStr() + " episodes", poster: "https://archive.org/services/img/" + movieEncode(id), logo: "pkg:/images/providers/archive.png", url: "", streamFormat: "mp4", isMovie: true, kind: "series", curated: true, seasons: list}
end function

' "Show.S01E02.The.Pilot.mp4" -> "The Pilot"
function episodeName(name as String) as String
    text = CreateObject("roRegex", "\.mp4$", "i").ReplaceAll(name, "")
    text = CreateObject("roRegex", "(\.ia|_512kb|\.h264)$", "i").ReplaceAll(text, "")
    text = CreateObject("roRegex", "[._]+", "").ReplaceAll(text, " ")
    text = CreateObject("roRegex", "[Ss]\d{1,2}[ -]?[Ee]\d{1,3}|\d{1,2}x\d{1,3}", "").ReplaceAll(text, " ")
    text = CreateObject("roRegex", "\s+", "").ReplaceAll(text, " ").Trim()
    return text
end function

' Archive results -> items: full films (minSeconds and longer, collections
' split, IMDb-matched, versions grouped), full TV seasons, or trailers.
function docsToItems(docs as Object, mode as String, minSeconds as Integer) as Object
    ' Adult results are listed only in the Adult section ("adult" modes).
    wantAdult = Right(mode, 6) = ":adult"
    if wantAdult then mode = Left(mode, Len(mode) - 6)
    kept = []
    for each d in docs
        if isAdultDoc(d) = wantAdult then kept.Push(d)
    end for
    docs = kept
    ids = []
    for each d in docs
        ids.Push(movieText(d.identifier))
    end for
    lists = fetchFileLists(ids)
    items = []
    if mode = "mixed"
        ' Search: full TV seasons first, then films from everything else.
        rest = []
        for each d in docs
            id = movieText(d.identifier)
            show = invalid
            if lists.DoesExist(id) then show = fullSeasonItem(d, mp4Files(lists[id]))
            if show <> invalid
                show.name = filmName(movieText(d.title))
                items.Push(show)
            else
                rest.Push(d)
            end if
        end for
        docs = rest
        mode = "full"
    end if
    if mode = "full"
        films = []
        for each d in docs
            id = movieText(d.identifier)
            if lists.DoesExist(id)
                files = mp4Files(lists[id])
                collection = collectionItems(d, files)
                if collection.Count() >= 2
                    ' Several films in one item: each film on its own.
                    for each c in collection
                        year = yearIn(c.raw)
                        if year = 0 and movieText(d.year) <> "" then year = Val(movieText(d.year))
                        films.Push({item: c.item, raw: c.raw, film: filmName(c.raw), year: year})
                    end for
                else
                    item = fullMovieItem(d, files, minSeconds)
                    if item <> invalid
                        raw = movieText(d.title)
                        year = yearIn(raw)
                        if year = 0 and movieText(d.year) <> "" then year = Val(movieText(d.year))
                        films.Push({item: item, raw: raw, film: filmName(raw), year: year})
                    end if
                end if
            end if
        end for
        matches = imdbMatches(films)
        ' Group copies of the same film: real films (an IMDb match) first.
        groups = []
        byKey = {}
        for i = 0 to films.Count() - 1
            f = films[i]
            match = matches[i.ToStr()]
            if match <> invalid
                f.item.name = match.title
                if match.year > 0 then f.year = match.year
                if match.poster <> "" then f.item.poster = match.poster
            else
                f.item.name = f.film
            end if
            if f.year > 0 then f.item.year = f.year.ToStr()
            key = normName(f.item.name) + "|" + f.year.ToStr()
            if not byKey.DoesExist(key)
                byKey[key] = {matched: match <> invalid, copies: []}
                groups.Push(byKey[key])
            end if
            label = versionLabel(f.raw)
            if label = "" then label = "Regular copy"
            byKey[key].copies.Push({item: f.item, label: label, runtime: f.item.durationSeconds})
        end for
        ordered = []
        for each pass in [true, false]
            for each g in groups
                if g.matched = pass then ordered.Push(g)
            end for
        end for
        for each g in ordered
            g.copies.SortBy("runtime")
            ' Longest copy first.
            copies = []
            for i = g.copies.Count() - 1 to 0 step -1
                copies.Push(g.copies[i])
            end for
            first = copies[0].item
            if copies.Count() > 1
                first.versions = []
                for each c in copies
                    first.versions.Push({id: c.item.id, label: c.label, runtime: c.item.durationSeconds, url: c.item.url})
                end for
                first.genre = copies.Count().ToStr() + " versions"
            else if copies[0].label <> "Regular copy"
                first.genre = copies[0].label
            end if
            items.Push(first)
        end for
    else if mode = "book"
        ' Audiobooks: an item's MP3 chapters, in order.
        for each d in docs
            id = movieText(d.identifier)
            if lists.DoesExist(id)
                book = bookItem(d, lists[id])
                if book <> invalid then items.Push(book)
            end if
        end for
    else if mode = "trailer"
        for each d in docs
            id = movieText(d.identifier)
            if lists.DoesExist(id)
                best = invalid
                for each f in mp4Files(lists[id])
                    if f.length >= 30 and f.length <= 720 and (best = invalid or f.score > best.score) then best = f
                end for
                if best <> invalid
                    raw = movieText(d.title)
                    items.Push({id: id, provider: "archive", name: trailerName(raw), description: Left(movieText(d.description), 600), year: movieText(d.year), genre: "35mm trailer", poster: "https://archive.org/services/img/" + movieEncode(id), logo: "pkg:/images/providers/archive.png", url: "https://archive.org/download/" + movieEncode(id) + "/" + movieEncode(best.name), streamFormat: "mp4", isMovie: true, kind: "trailer", curated: true, durationSeconds: best.length, raw: raw})
                end if
            end if
        end for
        ' Each trailer gets its film's poster and year (IMDb).
        films = []
        for each item in items
            films.Push({film: item.name, year: yearIn(item.raw)})
        end for
        matches = imdbMatches(films)
        for i = 0 to items.Count() - 1
            match = matches[i.ToStr()]
            if match <> invalid
                items[i].name = match.title
                if match.poster <> "" then items[i].poster = match.poster
                if match.year > 0 then items[i].year = match.year.ToStr()
            else if films[i].year > 0
                items[i].year = films[i].year.ToStr()
            end if
        end for
    else
        for each d in docs
            id = movieText(d.identifier)
            if lists.DoesExist(id)
                item = fullSeasonItem(d, mp4Files(lists[id]))
                if item <> invalid
                    item.name = filmName(movieText(d.title))
                    items.Push(item)
                end if
            end if
        end for
    end if
    return items
end function

' One more page of a catalog section, searched live with its recipe.
function loadMore(sectionId as String, page as Integer) as Object
    cached = cachedSectionPage(sectionId, page)
    if cached <> invalid then return cached
    index = ParseJson(ReadAsciiFile("pkg:/config/archive.json"))
    spec = invalid
    if type(index) = "roAssociativeArray" and type(index.sections) = "roArray"
        for each s in index.sections
            if s.id = sectionId and type(s.more) = "roAssociativeArray" then spec = s.more
        end for
    end if
    if spec = invalid or not epgString(spec.q) then return {items: [], total: 0, page: page, pages: page, message: "", fromCache: false}
    url = "https://archive.org/advancedsearch.php?q=" + movieEncode(spec.q) + "&rows=20&page=" + page.ToStr() + "&sort%5B%5D=downloads%20desc&output=json"
    for each field in ["identifier", "title", "description", "year", "subject", "collection"]
        url = url + "&fl%5B%5D=" + field
    end for
    body = movieHttp(url)
    docs = []
    if body <> invalid
        data = ParseJson(body)
        if type(data) = "roAssociativeArray" and type(data.response) = "roAssociativeArray" and type(data.response.docs) = "roArray" then docs = data.response.docs
    end if
    ' A section can insist its results mention something (LaserDisc, VHS...)
    ' in their title, tags or description, or that they don't.
    rawCount = docs.Count()
    if epgString(spec.must) or epgString(spec.mustNot)
        kept = []
        for each d in docs
            words = movieText(d.title) + " " + movieText(d.subject) + " " + movieText(d.description)
            ok = true
            if epgString(spec.must) and not CreateObject("roRegex", spec.must, "i").IsMatch(words) then ok = false
            if epgString(spec.mustNot) and CreateObject("roRegex", spec.mustNot, "i").IsMatch(movieText(d.title)) then ok = false
            if ok then kept.Push(d)
        end for
        docs = kept
    end if
    minSeconds = 3600
    if epgNumber(spec.min) then minSeconds = Int(spec.min * 60)
    mode = movieText(spec.mode)
    if sectionId = "adult" then mode = mode + ":adult"
    items = docsToItems(docs, mode, minSeconds)
    if Left(sectionId, 6) = "anime-" then items = animeEnrich(items) else items = tvEnrich(items)
    if items.Count() = 0 and docs.Count() > 0 and m.slowArchive = true
        return {items: [], total: 0, page: page, pages: page + 1, message: "The Internet Archive is responding slowly right now - try again in a moment.", fromCache: false, slow: true}
    end if
    ' Titles the TV font can't draw are cleaned (or replaced by a match above).
    for each item in items
        item.name = asciiTitle(movieText(item.name))
    end for
    pages = page
    if rawCount >= 20 then pages = page + 1
    result = {items: items, total: items.Count(), page: page, pages: pages, message: "", fromCache: false}
    saveSectionPage(sectionId, page, result)
    return result
end function

' A section page kept for 6 hours, so going back to a category is instant.
function sectionPagePath(sectionId as String, page as Integer) as String
    safe = CreateObject("roRegex", "[^a-zA-Z0-9_-]", "").ReplaceAll(sectionId, "_")
    return "cachefs:/zer0_sec5_" + safe + "_" + page.ToStr() + ".json"
end function

sub saveSectionPage(sectionId as String, page as Integer, result as Object)
    if result.items.Count() = 0 or m.listsShort = true then return
    WriteAsciiFile(sectionPagePath(sectionId, page), FormatJson({saved: CreateObject("roDateTime").AsSeconds(), result: result}))
end sub

function cachedSectionPage(sectionId as String, page as Integer) as Dynamic
    text = ReadAsciiFile(sectionPagePath(sectionId, page))
    if text = "" then return invalid
    data = ParseJson(text)
    if type(data) <> "roAssociativeArray" or not epgNumber(data.saved) then return invalid
    if CreateObject("roDateTime").AsSeconds() - data.saved > 21600 then return invalid
    return data.result
end function

' A favorite show: its seasons read fresh from the Archive item.
function loadShow(id as String) as Object
    url = "https://archive.org/advancedsearch.php?q=" + movieEncode("identifier:" + Chr(34) + id + Chr(34)) + "&rows=1&output=json&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=description&fl%5B%5D=year"
    doc = {identifier: id, title: id, description: "", year: ""}
    body = movieHttp(url)
    if body <> invalid
        data = ParseJson(body)
        if type(data) = "roAssociativeArray" and type(data.response) = "roAssociativeArray" and type(data.response.docs) = "roArray" and data.response.docs.Count() > 0 then doc = data.response.docs[0]
    end if
    lists = fetchFileLists([id])
    items = []
    if lists.DoesExist(id)
        item = fullSeasonItem(doc, mp4Files(lists[id]))
        if item <> invalid then items.Push(item)
    end if
    items = tvEnrich(items)
    return {items: items, total: items.Count(), page: 1, pages: 1, message: "", fromCache: false}
end function

' A trailer's film name: drops "Official Trailer", "Teaser", "35mm Scan",
' "4K ProRes", "FLAT", "SCOPE" and similar, then the usual title clean-up.
function trailerName(title as String) as String
    text = CreateObject("roRegex", "\b(official |theatrical |original |teaser |re-?issue |reissue |promo |japanese |international )*(trailers?|teasers?)\b.*$", "i").ReplaceAll(title, " ")
    text = CreateObject("roRegex", "\b(35 ?mm|film|print)? ?scans?\b|\bprores\b|\bflat\b|\bscope\b|\b4k\b|\buhd\b", "i").ReplaceAll(text, " ")
    return filmName(text)
end function

' A book: its MP3 chapters (one copy each, the 64 kb one when there is a
' choice), in file order, as one "season" the app opens straight away.
function bookItem(doc as Object, files as Object) as Dynamic
    byName = {}
    for each f in files
        name = movieText(f.name)
        lowered = LCase(name)
        if Right(lowered, 4) = ".mp3" and not movieFlag(f.private)
            base = CreateObject("roRegex", "(_64kb|_128kb|_vbr)?\.mp3$", "i").ReplaceAll(name, "")
            prefer = lowered.Instr("_64kb") >= 0
            if not byName.DoesExist(base) or prefer then byName[base] = {name: name, length: fileSeconds(f.length), title: movieText(f.title)}
        end if
    end for
    if byName.Count() = 0 then return invalid
    names = []
    for each base in byName
        names.Push(base)
    end for
    names.Sort()
    id = movieText(doc.identifier)
    chapters = []
    number = 0
    for each base in names
        f = byName[base]
        number = number + 1
        title = f.title
        if title = "" then title = episodeName(CreateObject("roRegex", "\.mp3$", "i").ReplaceAll(f.name, ".mp4"))
        chapters.Push({id: id + "/" + f.name, kind: "episode", title: title, season: 1, episode: number, runtime: f.length, url: "https://archive.org/download/" + movieEncode(id) + "/" + movieEncode(f.name), format: "mp3"})
    end for
    total = 0
    for each c in chapters
        total = total + c.runtime
    end for
    genre = chapters.Count().ToStr() + " chapters"
    if total > 0 then genre = genre + "   ·   " + Int(total / 3600).ToStr() + "h " + (Int(total / 60) mod 60).ToStr() + "m"
    return {id: id, provider: "archive", name: movieText(doc.title), description: Left(movieText(doc.description), 1200), year: movieText(doc.year), genre: genre, poster: "https://archive.org/services/img/" + movieEncode(id), logo: "pkg:/images/providers/archive.png", url: "", streamFormat: "mp3", isMovie: true, kind: "series", isBook: true, curated: true, seasons: [{season: 1, episodes: chapters}]}
end function

' AniList (the anime database): every name in ONE request (aliased queries),
' so its rate limit never empties a page. Gives its English (or romaji) title,
' cover and year when the names agree.
function anilistMatches(names as Object) as Object
    found = {}
    params = []
    fields = []
    vars = {}
    for i = 0 to names.Count() - 1
        if names[i] <> ""
            params.Push("$s" + i.ToStr() + ":String")
            fields.Push("a" + i.ToStr() + ":Page(perPage:1){media(search:$s" + i.ToStr() + ",type:ANIME){title{english romaji}coverImage{large}seasonYear startDate{year}}}")
            vars["s" + i.ToStr()] = names[i]
        end if
    end for
    if params.Count() = 0 then return found
    query = "query(" + params.Join(",") + "){" + fields.Join(" ") + "}"
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.SetUrl("https://graphql.anilist.co")
    transfer.AddHeader("Content-Type", "application/json")
    transfer.AddHeader("Accept", "application/json")
    if not transfer.AsyncPostFromString(FormatJson({query: query, variables: vars})) then return found
    data = invalid
    clock = CreateObject("roTimespan")
    while clock.TotalMilliseconds() < 5000
        if m.top.cancelled then exit while
        event = Wait(100, port)
        if type(event) = "roUrlEvent" and event.GetInt() = 1
            ' Names it doesn't know come back as empty lists.
            data = ParseJson(event.GetString())
            exit while
        end if
    end while
    transfer.AsyncCancel()
    if type(data) <> "roAssociativeArray" or type(data.data) <> "roAssociativeArray" then return found
    for i = 0 to names.Count() - 1
        media = invalid
        page = data.data["a" + i.ToStr()]
        if type(page) = "roAssociativeArray" and type(page.media) = "roArray" and page.media.Count() > 0 then media = page.media[0]
        if type(media) = "roAssociativeArray" and type(media.title) = "roAssociativeArray"
            title = movieText(media.title.english)
            if title = "" then title = movieText(media.title.romaji)
            poster = ""
            if type(media.coverImage) = "roAssociativeArray" then poster = movieText(media.coverImage.large)
            y = 0
            if epgNumber(media.seasonYear) then y = media.seasonYear
            if y = 0 and type(media.startDate) = "roAssociativeArray" and epgNumber(media.startDate.year) then y = media.startDate.year
            ' AniList always answers with its closest anime: keep it only
            ' when the names agree (one contains the other).
            wanted = normName(names[i])
            agree = false
            for each candidate in [normName(movieText(media.title.english)), normName(movieText(media.title.romaji))]
                if Len(candidate) >= 3 and Len(wanted) >= 3 and (candidate.Instr(wanted) >= 0 or wanted.Instr(candidate) >= 0) then agree = true
            end for
            if title <> "" and agree then found[i.ToStr()] = {title: title, poster: poster, year: y}
        end if
    end for
    return found
end function

' Anime sections: AniList's title, cover and year where it knows the name;
' everything else stays as the Archive has it.
function animeEnrich(items as Object) as Object
    names = []
    for each item in items
        names.Push(filmName(asciiTitle(movieText(item.name))))
    end for
    matches = anilistMatches(names)
    for i = 0 to items.Count() - 1
        match = matches[i.ToStr()]
        if match <> invalid
            items[i].name = match.title
            if match.poster <> "" then items[i].poster = match.poster
            if match.year > 0 then items[i].year = match.year.ToStr()
        end if
    end for
    return items
end function

' Characters the TV font can't draw (Japanese, Chinese, Korean...) left out.
function asciiTitle(text as String) as String
    clean = CreateObject("roRegex", "[^\x20-\x7E\xA0-\xFF\x{2018}-\x{201D}\x{2013}\x{2014}]", "").ReplaceAll(text, "")
    clean = CreateObject("roRegex", "\s+", "").ReplaceAll(clean, " ").Trim()
    if clean = "" then return text
    return clean
end function

' Several GETs at once: {index: parsed JSON} for those that answered in time.
function fetchJsonBatch(urls as Object, limitMs as Integer) as Object
    port = CreateObject("roMessagePort")
    jobs = {}
    for i = 0 to urls.Count() - 1
        if urls[i] <> ""
            transfer = CreateObject("roUrlTransfer")
            transfer.SetMessagePort(port)
            transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
            transfer.InitClientCertificates()
            transfer.EnableEncodings(true)
            transfer.SetUrl(urls[i])
            if transfer.AsyncGetToString() then jobs[transfer.GetIdentity().ToStr()] = {transfer: transfer, index: i}
        end if
    end for
    found = {}
    pending = jobs.Count()
    clock = CreateObject("roTimespan")
    while pending > 0 and clock.TotalMilliseconds() < limitMs
        if m.top.cancelled then exit while
        event = Wait(100, port)
        if type(event) = "roUrlEvent" and event.GetInt() = 1
            key = event.GetSourceIdentity().ToStr()
            if jobs.DoesExist(key)
                pending = pending - 1
                if event.GetResponseCode() = 200
                    data = ParseJson(event.GetString())
                    if data <> invalid then found[jobs[key].index.ToStr()] = data
                end if
            end if
        end if
    end while
    for each key in jobs
        jobs[key].transfer.AsyncCancel()
    end for
    return found
end function

' TV shows: TVmaze (an open TV database) gives the real name, poster, summary,
' premiere year, a background, the title logo, and every episode's title and
' description. Only used when the names agree.
function tvEnrich(items as Object) as Object
    shows = []
    urls = []
    for each item in items
        if item.kind = "series" and item.isBook <> true
            shows.Push(item)
            name = filmName(asciiTitle(movieText(item.name)))
            urls.Push("https://api.tvmaze.com/singlesearch/shows?q=" + movieEncode(name) + "&embed%5B%5D=episodes")
        end if
    end for
    if shows.Count() = 0 then return items
    found = fetchJsonBatch(urls, 4000)
    imageUrls = []
    matched = []
    for i = 0 to shows.Count() - 1
        show = found[i.ToStr()]
        item = shows[i]
        if type(show) = "roAssociativeArray"
            wanted = normName(filmName(asciiTitle(movieText(item.name))))
            have = normName(movieText(show.name))
            if Len(have) >= 3 and (have.Instr(wanted) >= 0 or wanted.Instr(have) >= 0)
                item.name = movieText(show.name)
                if type(show.image) = "roAssociativeArray"
                    poster = movieText(show.image.original)
                    if poster = "" then poster = movieText(show.image.medium)
                    if poster <> "" then item.poster = poster
                end if
                summary = movieText(show.summary)
                if summary <> "" then item.description = summary
                premiered = movieText(show.premiered)
                if Len(premiered) >= 4 then item.year = Left(premiered, 4)
                info = {}
                if type(show._embedded) = "roAssociativeArray" and type(show._embedded.episodes) = "roArray"
                    for each ep in show._embedded.episodes
                        if epgNumber(ep.season) and epgNumber(ep.number)
                            still = ""
                            if type(ep.image) = "roAssociativeArray" then still = movieText(ep.image.medium)
                            info[ep.season.ToStr() + "x" + ep.number.ToStr()] = {t: movieText(ep.name), d: Left(movieText(ep.summary), 400), i: still, a: movieText(ep.airdate)}
                        end if
                    end for
                end if
                item.episodeInfo = info
                matched.Push(item)
                imageUrls.Push("https://api.tvmaze.com/shows/" + show.id.ToStr() + "/images")
            end if
        end if
    end for
    ' The background (or banner) behind the hero and the title logo.
    images = fetchJsonBatch(imageUrls, 3000)
    for i = 0 to matched.Count() - 1
        list = images[i.ToStr()]
        if type(list) = "roArray"
            background = ""
            banner = ""
            logo = ""
            for each img in list
                url = ""
                if type(img.resolutions) = "roAssociativeArray" and type(img.resolutions.original) = "roAssociativeArray" then url = movieText(img.resolutions.original.url)
                kind = movieText(img.type)
                if kind = "background" and background = "" then background = url
                if kind = "banner" and banner = "" then banner = url
                if kind = "typography" and logo = "" then logo = url
            end for
            if background <> "" then matched[i].backdrop = background else if banner <> "" then matched[i].backdrop = banner
            if logo <> "" then matched[i].logoArt = logo
        end if
    end for
    return items
end function

