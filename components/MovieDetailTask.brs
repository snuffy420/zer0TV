sub init()
    m.top.functionName = "loadDetails"
    m.httpKey = "details"
end sub

sub loadDetails()
    item = m.top.item
    error = ""
    if item.curated = true and item.url <> ""
        if not m.top.cancelled then m.top.result = {item: item, mode: m.top.mode, error: ""}
        return
    end if
    if m.top.mode = "play" then item.url = ""
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
    if not m.top.cancelled then m.top.result = {item: item, mode: m.top.mode, error: error}
end sub
