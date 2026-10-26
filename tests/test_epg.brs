sub main()
    expected = xmltvTime("20261025053000 +0000")
    require(xmltvTime("20261025013000 -0400") = expected, "negative XMLTV offset")
    require(xmltvTime("20261025063000 +0100") = expected, "positive XMLTV offset")
    require(xmltvTime("20261025053000") = expected, "default UTC")
    require(xmltvTime(invalid) = 0, "missing XMLTV timestamp")
    require(epgName("BBC News") = epgName("BBC NEWS"), "case-insensitive name fallback")
    require(epgNumber(123) and not epgNumber("123"), "reject numeric strings in JSON timestamps")
    require(epgId("News.us@HD") = "news.us", "rendition suffix matches station ID")
    require(epgName("US - BBC News") = epgName("BBC News (720p)"), "country prefixes and resolution labels")
    now = 1792969200
    require(guideProgramAllowed(now, now + 600, now), "keep live programme")
    require(not guideProgramAllowed(now - 3600, now - 901, now), "drop old history")
    require(not guideProgramAllowed(now + 21600, now + 22200, now), "bound future listings to six hours")
    require(not guideProgramAllowed(now + 600, now, now), "reject reversed programme")
    p = compactProgram({start: now, stop: now + 600, title: String(200, "T"), description: String(1000, "D")})
    require(Len(p.title) = 160 and Len(p.description) = 240, "bound retained text")
    print "PASS: EPG runtime helpers"
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
