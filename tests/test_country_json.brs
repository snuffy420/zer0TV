sub main()
    data = ParseJson(ReadAsciiFile("pkg:/config/guides/us.json"))
    require(type(data) = "roAssociativeArray", "real US guide fixture loads")
    m.top = {cancelled: false}
    m.schedules = {}
    m.aliases = {}
    m.nameOwners = {}
    m.wanted = {}
    m.names = {}
    m.programCount = 0
    m.now = data.generated
    for each entry in data.channels
        m.wanted[epgId(entry.id)] = true
    end for
    storeCountryEntries(data.channels)
    require(m.programCount > 0 and m.programCount <= 3000, "real JSON yields bounded listings")
    for each id in m.schedules
        require(m.schedules[id].Count() <= 32, "per-channel cap applies to real feed")
        for each p in m.schedules[id]
            require(Len(p.title) <= 160 and Len(p.description) <= 240, "retained metadata budget")
            require(guideProgramAllowed(p.start, p.stop, m.now), "six-hour horizon applies to real feed")
        end for
    end for
    print "PASS: real US JSON normalization; programmes="; m.programCount; " stations="; m.schedules.Count()
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
