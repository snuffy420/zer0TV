sub main()
    m.schedules = {}
    m.aliases = {}
    m.nameOwners = {}
    m.programCount = 0
    for station = 0 to 199
        id = "station" + station.ToStr()
        for p = 0 to 39
            retainProgram(id, {start: p * 600, stop: (p + 1) * 600, title: "Programme", description: ""})
        end for
    end for
    require(m.programCount = 3000, "country-wide programme budget")
    for each id in m.schedules
        require(m.schedules[id].Count() <= 32, "per-station programme budget")
    end for
    m.schedules = {}
    m.programCount = 0
    p = {start: 1000, stop: 2000, title: "Live", description: ""}
    retainProgram("one", p)
    retainProgram("one", p)
    require(m.programCount = 1, "deduplicate repeated entries")
    registerGuideName("station", "one")
    require(m.aliases.station = "one", "name alias stores ID, not a copied programme array")
    registerGuideName("station", "two")
    require(not m.aliases.DoesExist("station"), "exclude ambiguous name fallback")
    registerGuideName("station", "one")
    require(not m.aliases.DoesExist("station"), "ambiguity remains excluded")
    print "PASS: guide object budgets, deduplication and compact aliases"
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
