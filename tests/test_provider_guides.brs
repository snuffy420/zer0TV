sub main()
    initProviders()
    require(m.providerDefs.Count() = 4, "four live provider configurations")
    for each provider in m.providerDefs
        require(isLiveProvider(provider.id), "provider catalog lookup")
        data = ParseJson(ReadAsciiFile("pkg:/config/provider-guides/" + provider.id + "/us.json"))
        require(data.provider = provider.id and data.country = "us", "provider/country fixture isolation")
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
        m.stationProgramLimit = Int(3000# / m.wanted.Count())
        if m.stationProgramLimit > 32 then m.stationProgramLimit = 32
        if m.stationProgramLimit < 2 then m.stationProgramLimit = 2
        storeCountryEntries(data.channels)
        require(m.programCount > 0 and m.programCount <= 3000, "bounded actual provider guide")
        for each id in m.schedules
            require(m.wanted.DoesExist(id), "retain provider station IDs")
            require(m.schedules[id].Count() <= m.stationProgramLimit, "fair per-station limit")
        end for
        print "PASS: provider "; provider.id; " · retained stations="; m.schedules.Count(); " programmes="; m.programCount
    end for
    require(not isLiveProvider("iptvorg"), "legacy provider stays outside experimental catalog")
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
