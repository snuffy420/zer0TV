' Listings found under the playlist's own tvg-id when the guide builder
' (tools/epg_match.py) matched it to a differently named feed channel.
sub main()
    m.top = {cancelled: false}
    m.schedules = {}
    m.aliases = {}
    m.nameOwners = {}
    m.programCount = 0
    m.now = 1000000
    ' The playlist: A&E East and ABC (KAAL) by id, one Free-TV channel by name.
    m.wanted = {}
    m.wanted[epgId("AE.us@East")] = true
    m.wanted[epgId("ABC.us@KAAL")] = true
    m.names = {}
    m.names[epgName("Local Channel (720p)")] = true
    show = {start: m.now, stop: m.now + 1800, title: "Programme", description: ""}
    entries = [
        {id: "AandENetwork.us", name: "US - A&E Network", ids: ["ae.us@east"], programmes: [show]},
        {id: "ABCKAAL.us", name: "US - ABC KAAL Rochester MN", ids: ["abc.us@kaal"], programmes: [show]},
        {id: "LocalCh.us", name: "US - Local Ch", names: ["localchannel"], programmes: [show]},
        {id: "Unwanted.us", name: "US - Unwanted", ids: ["unwanted.us"], programmes: [show]}
    ]
    storeCountryEntries(entries)
    require(m.programCount = 3, "only the matched listings are kept")
    require(m.aliases["ae.us@east"] = epgId("AandENetwork.us"), "playlist id points at the feed channel")
    require(m.aliases["abc.us@kaal"] = epgId("ABCKAAL.us"), "sub-feed id points at the feed channel")
    require(m.aliases["localchannel"] = epgId("LocalCh.us"), "playlist name points at the feed channel")
    require(m.stationProgramLimit >= 6, "budget shared by matched stations")
    print "PASS: guide builder ids and names reach the playlist's channels"
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
