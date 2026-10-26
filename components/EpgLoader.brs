sub init()
    m.top.functionName = "loadGuide"
end sub

sub loadGuide()
    loadGuideData()
    m.schedules = invalid
    m.aliases = invalid
    m.wanted = invalid
    m.names = invalid
    m.nameOwners = invalid
end sub

sub loadGuideData()
    m.now = CreateObject("roDateTime").AsSeconds()
    m.schedules = {}
    m.aliases = {}
    m.nameOwners = {}
    m.wanted = {}
    m.names = {}
    m.programCount = 0
    providerGuide = m.top.provider <> "iptvorg" and m.top.provider <> "freetv"
    for each ch in m.top.channels
        if ch.tvgId <> invalid and ch.tvgId <> "" then m.wanted[epgId(ch.tvgId)] = true
        name = epgName(ch.name)
        if name <> "" then m.names[name] = true
    end for
    m.stationProgramLimit = 32
    if providerGuide and m.wanted.Count() > 0
        m.stationProgramLimit = Int(3000# / m.wanted.Count())
        if m.stationProgramLimit > 32 then m.stationProgramLimit = 32
        if m.stationProgramLimit < 2 then m.stationProgramLimit = 2
    end if
    code = LCase(m.top.country)
    identity = m.top.provider + ":" + code
    cache = "tmp:/zer0_guide.json"
    ' A single compact cache replaces the previous unbounded per-country tmp files.
    stored = readGuideJson(cache, 2000000)
    suffix = m.top.requestId
    download = "cachefs:/zer0_epg_" + suffix
    loaded = false
    message = "Guide updated · six-hour window"

    if m.top.jsonBase <> ""
        if epgDownload(m.top.jsonBase + "/" + code + ".json", download + ".json", 15000, 4000000)
            loaded = readCountryJson(download + ".json")
        end if
        DeleteFile(download + ".json")
    end if
    if m.top.cancelled then return

    if not loaded and providerGuide and m.top.xmlUrl <> ""
        path = download + ".xml"
        if epgDownload(m.top.xmlUrl, path, 45000, 16000000)
            parseGuideFile(path)
            loaded = m.programCount > 0
        end if
        DeleteFile(path)
        message = "Fresh provider guide - bounded live window"
    end if
    if m.top.cancelled then return

    if not loaded and not providerGuide
        loaded = readCountryJson("pkg:/config/guides/" + code + ".json")
        if loaded then message = "Included country guide - six-hour window"
    end if
    if not loaded and type(stored) = "roAssociativeArray"
        if stored.identity = identity and stored.data <> invalid
            publishGuide(stored.data, "Network unavailable - this session's cached guide")
            return
        end if
    end if
    if m.top.cancelled then return

    if loaded
        data = {schedules: m.schedules, aliases: m.aliases}
        serialized = FormatJson({identity: identity, fetched: m.now, data: data})
        if Len(serialized) < 2000000 then WriteAsciiFile(cache, serialized)
        serialized = invalid
        publishGuide(data, message)
    else
        if m.tooLarge <> true then message = "Listings unavailable · all channels remain watchable"
        if providerGuide then message = "Provider guide unavailable · channels remain watchable"
        publishGuide({schedules: {}, aliases: {}}, message)
    end if
    m.schedules = invalid
    m.aliases = invalid
    m.wanted = invalid
    m.names = invalid
    m.nameOwners = invalid
end sub

sub publishGuide(data as Object, message as String)
    if m.top.cancelled then return
    m.top.result = data
    m.top.message = message
    m.top.done = true
    print "[zer0 guide] "; message; " · programmes="; m.programCount
end sub

function readGuideJson(path as String, limit as Integer) as Dynamic
    stat = CreateObject("roFileSystem").Stat(path)
    if stat = invalid then return invalid
    if stat.size = invalid then return invalid
    if stat.size <= 0 or stat.size > limit then return invalid
    return ParseJson(ReadAsciiFile(path))
end function

function readCountryJson(path as String) as Boolean
    data = readGuideJson(path, 4000000)
    if type(data) <> "roAssociativeArray" then return false
    if not epgString(data.country) then return false
    if LCase(data.country) <> LCase(m.top.country) then return false
    if not epgNumber(data.generated) then return false
    if m.now - data.generated > 86400 or data.generated > m.now + 3600 then return false
    if type(data.channels) <> "roArray" then return false
    if m.top.provider <> "iptvorg" and m.top.provider <> "freetv"
        if data.provider <> m.top.provider then return false
    end if
    storeCountryEntries(data.channels)
    data = invalid
    return m.programCount > 0
end function

function epgDownload(url as String, path as String, timeout as Integer, limit as Integer) as Boolean
    m.tooLarge = false
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.SetUrl(url)
    transfer.EnableEncodings(true)
    if not transfer.AsyncGetToFile(path) then return false
    clock = CreateObject("roTimespan")
    fs = CreateObject("roFileSystem")
    success = false
    while clock.TotalMilliseconds() < timeout
        event = Wait(50, port)
        if m.top.cancelled then exit while
        stat = fs.Stat(path)
        if stat <> invalid and stat.size <> invalid
            if stat.size > limit
                m.tooLarge = true
                exit while
            end if
        end if
        if type(event) = "roUrlEvent"
            if event.GetInt() = 1
                success = event.GetResponseCode() >= 200 and event.GetResponseCode() < 300
                exit while
            end if
        end if
    end while
    transfer.AsyncCancel()
    if not success then DeleteFile(path)
    return success
end function

sub parseGuideFile(path as String)
    initGuideParser()
    offset = 0
    timer = CreateObject("roTimespan")
    while timer.TotalMilliseconds() < 30000 and m.programCount < 3000
        if m.top.cancelled then exit while
        bytes = CreateObject("roByteArray")
        if not bytes.ReadFile(path, offset, 32768) then exit while
        size = bytes.Count()
        if size = 0 then exit while
        offset = offset + size
        parseGuideChunk(bytes.ToAsciiString())
        bytes = invalid
        if size < 32768 then exit while
    end while
    m.guideBuffer = invalid
    m.matchedGuideIds = invalid
end sub
