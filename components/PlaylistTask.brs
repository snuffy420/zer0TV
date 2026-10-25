sub init()
    m.top.functionName = "loadPlaylist"
end sub

sub loadPlaylist()
    m.top.done = false
    m.top.error = ""
    m.top.fromCache = false

    url = m.top.url
    code = m.top.countryCode
    cacheKey = m.top.cacheKey

    if url = invalid then url = ""
    if code = invalid then code = ""
    if cacheKey = invalid then cacheKey = ""

    codeLower = LCase(code + "")
    if cacheKey = "" and codeLower <> "" then cacheKey = codeLower
    if cacheKey = "" then cacheKey = "playlist"

    cachePath = "tmp:/iptv_" + cacheKey + ".m3u"

    if url = "" and codeLower <> ""
        url = "https://iptv-org.github.io/iptv/countries/" + codeLower + ".m3u"
    end if

    if url = ""
        finish([], "No playlist URL")
        return
    end if

    ' Always try a fresh download first
    body = httpGet(url)
    usedCache = false

    if body <> invalid and Len(body) > 20
        writeFileText(cachePath, body)
        if codeLower <> "" then markCountryCached(codeLower)
        if cacheKey = "freetv" then markCountryCached("freetv")
    else
        ' Fallback to cache only if network failed
        body = readFileText(cachePath)
        usedCache = true
    end if

    if body = invalid or Len(body) < 20
        finish([], "Download failed. Check internet.")
        return
    end if

    channels = parseM3U(body)
    if channels.count() = 0
        finish([], "Playlist empty or could not parse")
        return
    end if

    m.top.fromCache = usedCache
    finish(channels, "")
end sub

sub finish(channels as Object, err as String)
    m.top.error = err
    m.top.result = channels
    m.top.done = true
end sub

function httpGet(url as String) as Dynamic
    xfer = CreateObject("roUrlTransfer")
    if xfer = invalid then return invalid
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.AddHeader("User-Agent", "Mozilla/5.0 (Roku)")
    xfer.AddHeader("Accept", "*/*")
    body = xfer.GetToString()
    if body = invalid then return invalid
    if Len(body) = 0 then return invalid
    return body
end function

sub markCountryCached(codeLower as String)
    reg = CreateObject("roRegistrySection", "iptv_cache")
    raw = reg.Read("countries")
    if raw = invalid then raw = ""
    set = {}
    for each p in raw.Split(",")
        p = p.Trim()
        if p <> "" then set.AddReplace(p, true)
    end for
    set.AddReplace(codeLower, true)
    out = []
    for each k in set
        out.Push(k)
    end for
    cj = ""
    for i = 0 to out.count() - 1
        if i = 0 then cj = out[i] else cj = cj + "," + out[i]
    end for
    reg.Write("countries", cj)
    now = CreateObject("roDateTime")
    now.Mark()
    reg.Write("ts_" + codeLower, now.AsSeconds().ToStr())
    reg.Flush()
end sub

function readFileText(path as String) as Dynamic
    fs = CreateObject("roFileSystem")
    if fs = invalid or not fs.Exists(path) then return invalid
    ba = CreateObject("roByteArray")
    if not ba.ReadFile(path) then return invalid
    text = ba.ToAsciiString()
    if text = invalid or Len(text) = 0 then return invalid
    return text
end function

sub writeFileText(path as String, body as String)
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(body)
    ba.WriteFile(path)
end sub

function parseM3U(text as String) as Object
    channels = []
    text = text.Replace(Chr(13), "")
    lines = text.Split(Chr(10))
    current = invalid
    for each rawLine in lines
        line = rawLine.Trim()
        if Len(line) = 0 then
            ' skip
        else if Left(line, 8) = "#EXTINF:"
            current = parseExtInf(line)
        else if Left(line, 1) = "#"
            ' skip
        else
            if current <> invalid
                current.url = line
                if Len(current.url) > 4 then channels.Push(current)
                current = invalid
            end if
        end if
    end for
    return channels
end function

function parseExtInf(line as String) as Object
    result = {
        name: "Unknown channel"
        group: ""
        tvgId: ""
        logo: ""
        url: ""
    }
    comma = Instr(1, line, ",")
    if comma > 0
        result.name = Mid(line, comma + 1).Trim()
        attrs = Left(line, comma - 1)
    else
        attrs = line
    end if
    result.group = getAttribute(attrs, "group-title")
    result.tvgId = getAttribute(attrs, "tvg-id")
    result.logo = getAttribute(attrs, "tvg-logo")
    return result
end function

function getAttribute(text as String, key as String) as String
    needle = key + "="
    p = Instr(1, text, needle)
    if p = 0 then return ""
    start = p + Len(needle)
    if start > Len(text) then return ""
    if Mid(text, start, 1) = Chr(34)
        start = start + 1
        finish = Instr(start, text, Chr(34))
        if finish > 0 then return Mid(text, start, finish - start)
    end if
    return ""
end function
