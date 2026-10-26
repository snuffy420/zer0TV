' XMLTV exporters may interleave each channel definition with its programmes.
sub initGuideParser()
    m.guideBuffer = ""
    m.matchedGuideIds = {}
    m.elementPattern = CreateObject("roRegex", "<(channel|programme)\s", "i")
    m.channelPattern = guideAttributePattern("channel")
    m.startPattern = guideAttributePattern("start")
    m.stopPattern = guideAttributePattern("stop")
end sub

function guideAttributePattern(name as String) as Object
    return CreateObject("roRegex", name + "=[" + Chr(34) + "']([^" + Chr(34) + "']*)[" + Chr(34) + "']", "i")
end function

function guideAttribute(fragment as String, pattern as Object) as String
    match = pattern.Match(fragment)
    if match.Count() > 1 then return match[1]
    return ""
end function

sub parseGuideChunk(chunk as String)
    m.guideBuffer = m.guideBuffer + chunk
    scanning = true
    while scanning
        if m.top.cancelled or m.programCount >= 3000 then return
        match = m.elementPattern.Match(m.guideBuffer)
        if match.Count() < 2
            m.guideBuffer = Right(m.guideBuffer, 64)
            return
        end if
        mode = LCase(match[1])
        start = Instr(1, m.guideBuffer, match[0])
        finish = Instr(start, m.guideBuffer, "</" + mode + ">")
        if finish = 0
            m.guideBuffer = Mid(m.guideBuffer, start)
            if Len(m.guideBuffer) > 65536 then m.guideBuffer = ""
            return
        end if
        finish = finish + Len(mode) + 3
        fragment = Mid(m.guideBuffer, start, finish - start)
        m.guideBuffer = Mid(m.guideBuffer, finish)
        parseGuideFragment(fragment, mode)
    end while
end sub

sub parseGuideFragment(fragment as String, mode as String)
    if mode = "programme"
        id = epgId(guideAttribute(fragment, m.channelPattern))
        if not m.matchedGuideIds.DoesExist(id) then return
        if m.schedules.DoesExist(id)
            limit = 32
            if m.stationProgramLimit <> invalid then limit = m.stationProgramLimit
            if m.schedules[id].Count() >= limit then return
        end if
        startTime = xmltvTime(guideAttribute(fragment, m.startPattern))
        stopTime = xmltvTime(guideAttribute(fragment, m.stopPattern))
        if not guideProgramAllowed(startTime, stopTime, m.now) then return
    end if
    xml = CreateObject("roXMLElement")
    if not xml.Parse(fragment) then return
    if mode = "channel"
        attrs = xml.GetAttributes()
        if attrs.id = invalid then return
        id = epgId(attrs.id)
        matched = m.wanted.DoesExist(id)
        for each name in xml.GetNamedElements("display-name")
            normalized = epgName(name.GetText())
            if m.names.DoesExist(normalized)
                registerGuideName(normalized, id)
                matched = true
            end if
        end for
        if matched then m.matchedGuideIds[id] = true
    else
        titles = xml.GetNamedElements("title")
        if titles.Count() = 0 then return
        descriptions = xml.GetNamedElements("desc")
        description = ""
        if descriptions.Count() > 0 then description = Left(descriptions[0].GetText(), 240)
        retainProgram(id, {start: startTime, stop: stopTime, title: Left(titles[0].GetText(), 160), description: description})
    end if
end sub
