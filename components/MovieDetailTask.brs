sub init()
    m.top.functionName = "loadDetails"
    m.httpKey = "details"
end sub

sub loadDetails()
    item = m.top.item
    error = ""
    if m.top.mode = "play" then item.url = ""
    if item.provider = "plutovod"
        body = movieHttp("https://api.pluto.tv/v2/episodes/" + item.id, 500000)
        if body <> invalid
            data = ParseJson(body)
            if type(data) = "roAssociativeArray"
                item.description = Left(movieText(data.summary), 1200)
                if epgString(data.genre) then item.genre = data.genre
                if epgNumber(data.duration) then item.durationSeconds = Int(data.duration / 1000#)
            end if
        end if
        if m.top.mode = "play"
            body = movieHttp("https://raw.githubusercontent.com/OwnerPlugins/pluto-tv-m3u/main/pluto-vod-US.m3u", 4000000)
            if body <> invalid
                for each line in body.Replace(Chr(13), "").Split(Chr(10))
                    if line.Instr("/episode/" + item.id + "/") >= 0
                        item.url = line.Trim()
                        exit for
                    end if
                end for
            end if
            if item.url = "" then error = "This title is no longer available in the current Pluto catalog. Refresh or try another title."
        end if
    else
        body = movieHttp("https://archive.org/metadata/" + movieEncode(item.id), 2000000)
        if body <> invalid
            data = ParseJson(body)
            if type(data) = "roAssociativeArray"
                metadata = data.metadata
                if type(metadata) = "roAssociativeArray"
                    item.description = Left(movieText(metadata.description), 1200)
                    item.year = movieText(metadata.year)
                    item.creator = movieText(metadata.creator)
                    item.genre = Left(movieText(metadata.subject), 100)
                    item.license = movieText(metadata.licenseurl)
                    restricted = movieFlag(data.is_dark) or movieFlag(metadata["access-restricted-item"])
                    if not restricted and type(data.files) = "roArray"
                        file = archiveFile(data.files)
                        if file <> "" then item.url = "https://archive.org/download/" + movieEncode(item.id) + "/" + movieEncode(file)
                    end if
                end if
            end if
        end if
        if m.top.mode = "play" and item.url = "" then error = "This item is restricted, unavailable, or has no compatible public MP4."
    end if
    if not m.top.cancelled then m.top.result = {item: item, mode: m.top.mode, error: error}
end sub
