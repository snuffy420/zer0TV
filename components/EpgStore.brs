sub retainProgram(id as String, p as Object)
    if m.programCount >= 6000 then return
    if not m.schedules.DoesExist(id) then m.schedules[id] = []
    list = m.schedules[id]
    limit = 32
    if m.stationProgramLimit <> invalid then limit = m.stationProgramLimit
    if list.Count() >= limit then return
    ' Ignore repeated entries without a separate growing deduplication map.
    for each existing in list
        if existing.start = p.start and existing.stop = p.stop then return
    end for
    list.Push(p)
    m.programCount = m.programCount + 1
end sub

sub registerGuideName(name as String, id as String)
    if m.nameOwners.DoesExist(name)
        if m.nameOwners[name] <> id
            m.aliases.Delete(name)
            m.nameOwners[name] = ""
            return
        end if
    end if
    m.nameOwners[name] = id
    ' Alias strings reference one station list instead of duplicating programme arrays.
    m.aliases[name] = id
end sub

sub storeCountryEntries(entries as Object)
    ' Only the listings this playlist wants (found once); the programme budget
    ' goes to those stations, not to every channel in the playlist.
    wantedEntries = []
    for each entry in entries
        if type(entry) = "roAssociativeArray" and epgString(entry.id) and type(entry.programmes) = "roArray"
            if guideEntryWanted(entry) then wantedEntries.Push(entry)
        end if
    end for
    if wantedEntries.Count() > 0
        m.stationProgramLimit = Int(6000 / wantedEntries.Count())
        if m.stationProgramLimit > 32 then m.stationProgramLimit = 32
        if m.stationProgramLimit < 6 then m.stationProgramLimit = 6
    end if
    limit = 32
    if m.stationProgramLimit <> invalid then limit = m.stationProgramLimit
    oldest = m.now - 900
    latest = m.now + 21600
    entryIndex = 0
    for each entry in wantedEntries
        if entryIndex mod 32 = 0
            if m.top.cancelled then return
        end if
        entryIndex = entryIndex + 1
        id = epgId(entry.id)
        if epgString(entry.name)
            name = epgName(entry.name)
            if m.names.DoesExist(name) then registerGuideName(name, id)
        end if
        ' The playlist ids and names this listing serves (built by
        ' tools/epg_match.py) point at it.
        if type(entry.ids) = "roArray"
            for each other in entry.ids
                if epgString(other) and other <> id and m.wanted.DoesExist(other) then m.aliases[other] = id
            end for
        end if
        if type(entry.names) = "roArray"
            for each other in entry.names
                if epgString(other) and m.names.DoesExist(other) then registerGuideName(other, id)
            end for
        end if
        ' Programmes come sorted by start: skip what has ended, stop at the
        ' six-hour horizon or when the station has its share.
        list = m.schedules[id]
        if list = invalid
            list = []
            m.schedules[id] = list
        end if
        lastStart = -1
        for each p in entry.programmes
            if type(p) = "roAssociativeArray"
                startTime = p.start
                stopTime = p.stop
                if epgNumber(startTime) and epgNumber(stopTime)
                    if startTime >= latest then exit for
                    if stopTime > oldest and stopTime > startTime and startTime <> lastStart and epgString(p.title)
                        ' The guide builders already trim titles and descriptions:
                        ' the parsed programme is kept as it is (no copy).
                        if p.description = invalid then p.description = ""
                        list.Push(p)
                        lastStart = startTime
                        m.programCount = m.programCount + 1
                        if list.Count() >= limit or m.programCount >= 6000 then exit for
                    end if
                end if
            end if
        end for
        if list.Count() = 0 then m.schedules.Delete(id)
        if m.programCount >= 6000 then exit for
    end for
end sub

' A listing the playlist wants: by its own id or name, or by the playlist ids
' and names the guide builder matched to it.
function guideEntryWanted(entry as Object) as Boolean
    if m.wanted.DoesExist(epgId(entry.id)) then return true
    if epgString(entry.name) and m.names.DoesExist(epgName(entry.name)) then return true
    if type(entry.ids) = "roArray"
        for each other in entry.ids
            if epgString(other) and m.wanted.DoesExist(other) then return true
        end for
    end if
    if type(entry.names) = "roArray"
        for each other in entry.names
            if epgString(other) and m.names.DoesExist(other) then return true
        end for
    end if
    return false
end function

