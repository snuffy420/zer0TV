sub retainProgram(id as String, p as Object)
    if m.programCount >= 3000 then return
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
    entryIndex = 0
    for each entry in entries
        if entryIndex mod 16 = 0
            if m.top.cancelled then return
        end if
        entryIndex = entryIndex + 1
        if type(entry) = "roAssociativeArray"
            if epgString(entry.id) and type(entry.programmes) = "roArray"
                id = epgId(entry.id)
                name = ""
                if epgString(entry.name) then name = epgName(entry.name)
                if m.wanted.DoesExist(id) or m.names.DoesExist(name)
                    if m.names.DoesExist(name) then registerGuideName(name, id)
                    for each p in entry.programmes
                        if type(p) = "roAssociativeArray"
                            if epgNumber(p.start) and epgNumber(p.stop) and epgString(p.title)
                                if guideProgramAllowed(p.start, p.stop, m.now) then retainProgram(id, compactProgram(p))
                            end if
                        end if
                        if m.programCount >= 3000 then exit for
                    end for
                end if
            end if
        end if
        if m.programCount >= 3000 then exit for
    end for
end sub

