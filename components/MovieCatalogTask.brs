sub init()
    m.top.functionName = "loadCatalog"
    m.httpKey = "catalog"
end sub

sub loadCatalog()
    if m.top.provider = "plutovod"
        result = loadPlutoCatalog()
    else
        result = loadArchiveCatalog()
    end if
    if not m.top.cancelled then m.top.result = result
end sub

function emptyCatalog(message as String) as Object
    return {items: [], total: 0, page: 1, pages: 1, message: message, fromCache: false}
end function

function loadPlutoCatalog() as Object
    path = "tmp:/zer0_plutovod_session.m3u"
    body = invalid
    cached = false
    if not m.top.fresh then body = ReadAsciiFile(path)
    if body = invalid or body = ""
        body = movieHttp("https://raw.githubusercontent.com/OwnerPlugins/pluto-tv-m3u/main/pluto-vod-US.m3u", 4000000)
        if body <> invalid and body <> ""
            WriteAsciiFile(path, body)
        else
            body = ReadAsciiFile(path)
            cached = true
        end if
    end if
    if body = invalid or body = "" then return emptyCatalog("Movie catalog unavailable - use * to retry")
    items = []
    seen = {}
    current = ""
    query = LCase(m.top.query.Trim())
    total = 0
    page = m.top.page
    start = (page - 1) * 8
    for each raw in body.Replace(Chr(13), "").Split(Chr(10))
        if m.top.cancelled then return emptyCatalog("Cancelled")
        line = raw.Trim()
        if Left(line, 8) = "#EXTINF:"
            current = line
        else if Left(line, 8) = "https://" and current <> ""
            movie = plutoMovie(current, line)
            current = ""
            if movie <> invalid
                if not seen.DoesExist(movie.id)
                    seen[movie.id] = true
                    if query = "" or LCase(movie.name).Instr(query) >= 0
                        if total >= start and items.Count() < 8 then items.Push(movie)
                        total = total + 1
                    end if
                end if
            end if
        end if
    end for
    pages = Int((total + 7) / 8)
    if pages < 1 then pages = 1
    message = "Latest available Pluto catalog"
    if cached then message = "Network unavailable - this session's cached catalog"
    return {items: items, total: total, page: page, pages: pages, message: message, fromCache: cached}
end function

function loadArchiveCatalog() as Object
    query = archiveQuery(m.top.profile, m.top.query)
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
