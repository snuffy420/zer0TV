function movieText(value as Dynamic) as String
    if type(value) = "roArray"
        parts = []
        for each entry in value
            if epgString(entry) then parts.Push(entry)
        end for
        value = parts.Join(", ")
    end if
    if epgNumber(value) then return value.ToStr()
    if not epgString(value) then return ""
    value = CreateObject("roRegex", "<[^>]*>", "i").ReplaceAll(value, " ")
    value = value.Replace("&amp;", "&").Replace("&quot;", Chr(34)).Replace("&#39;", "'").Replace("&nbsp;", " ")
    return value.Trim()
end function

function movieEncode(value as String) as String
    return CreateObject("roUrlTransfer").Escape(value)
end function

function movieHttp(url as String, limit = 2000000 as Integer) as Dynamic
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.EnableEncodings(true)
    transfer.AddHeader("User-Agent", "zer0TV/1.5.0")
    transfer.AddHeader("Cache-Control", "no-cache")
    transfer.SetUrl(url)
    path = "cachefs:/zer0_movie_" + m.httpKey + ".dat"
    DeleteFile(path)
    if not transfer.AsyncGetToFile(path) then return invalid
    fs = CreateObject("roFileSystem")
    clock = CreateObject("roTimespan")
    success = false
    while clock.TotalMilliseconds() < 20000
        event = Wait(50, port)
        if m.top.cancelled then exit while
        stat = fs.Stat(path)
        if stat <> invalid and stat.size <> invalid
            if stat.size > limit then exit while
        end if
        if type(event) = "roUrlEvent"
            if event.GetInt() = 1
                success = event.GetResponseCode() >= 200 and event.GetResponseCode() < 300
                exit while
            end if
        end if
    end while
    transfer.AsyncCancel()
    body = invalid
    if success then body = ReadAsciiFile(path)
    DeleteFile(path)
    return body
end function

function movieAttribute(line as String, name as String) as String
    pattern = CreateObject("roRegex", name + "=" + Chr(34) + "([^" + Chr(34) + "]*)" + Chr(34), "i")
    match = pattern.Match(line)
    if match.Count() > 1 then return match[1]
    return ""
end function

function plutoMovie(line as String, url as String) as Dynamic
    match = CreateObject("roRegex", "/episode/([a-f0-9]{24})/", "i").Match(url)
    if match.Count() < 2 then return invalid
    title = movieAttribute(line, "tvg-name")
    if title = ""
        comma = Instr(1, line, ",")
        if comma > 0 then title = Mid(line, comma + 1)
    end if
    if title = "" then return invalid
    id = match[1]
    return {id: id, provider: "plutovod", name: title, url: url, poster: "https://images.pluto.tv/episodes/" + id + "/poster.jpg", logo: "pkg:/images/providers/plutotv.png", genre: movieAttribute(line, "group-title"), description: "", year: "", streamFormat: "hls", isMovie: true}
end function

function archiveFile(files as Object) as String
    selected = ""
    best = -1
    for each file in files
        name = movieText(file.name)
        if LCase(Right(name, 4)) = ".mp4" and not movieFlag(file.private)
            score = 10
            format = LCase(movieText(file.format))
            if format = "h.264" then score = 100
            if format = "mpeg4" then score = 80
            if format.Instr("512") >= 0 then score = 40
            if LCase(name).Instr("sample") >= 0 or LCase(name).Instr("trailer") >= 0 then score = score - 50
            if score > best
                best = score
                selected = name
            end if
        end if
    end for
    return selected
end function

function movieFlag(value as Dynamic) as Boolean
    if type(value) = "Boolean" or type(value) = "roBoolean" then return value
    text = LCase(movieText(value))
    return text = "true" or text = "1"
end function

function archiveQuery(profile as String, search as String) as String
    base = "mediatype:movies AND -access-restricted-item:true"
    search = CreateObject("roRegex", "[^a-zA-Z0-9 ]", "").ReplaceAll(search, " ").Trim()
    if search <> ""
        words = CreateObject("roRegex", "\s+", "").ReplaceAll(search, " AND ")
        return base + " AND (title:(" + words + ") OR subject:(" + words + "))"
    end if
    filters = {
        rare: "(title:workprint OR subject:workprint OR title:" + Chr(34) + "alternate cut" + Chr(34) + " OR title:rare OR title:uncut)"
        workprints: "(title:workprint OR subject:workprint OR title:" + Chr(34) + "work print" + Chr(34) + ")"
        alternate: "(title:" + Chr(34) + "alternate cut" + Chr(34) + " OR title:" + Chr(34) + "extended cut" + Chr(34) + " OR title:" + Chr(34) + "director's cut" + Chr(34) + " OR title:" + Chr(34) + "rough cut" + Chr(34) + ")"
        trailers: "(title:trailer OR subject:trailers)"
        behind: "(title:" + Chr(34) + "behind the scenes" + Chr(34) + " OR title:" + Chr(34) + "making of" + Chr(34) + " OR subject:" + Chr(34) + "production footage" + Chr(34) + ")"
        classics: "collection:feature_films AND licenseurl:(*publicdomain*)"
    }
    if not filters.DoesExist(profile) then profile = "rare"
    return base + " AND " + filters[profile]
end function
