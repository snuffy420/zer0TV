sub main()
    m.source = "iptvorg"
    m.selectedCountry = {code: "US", name: "United States"}
    m.channels = [{name: "Station", tvgId: "station.us", url: "https://example.com/live", logo: "logo"}]
    m.epgTask = {state: "init", done: false, cancelled: false, channels: [], result: {}}
    m.guideCountry = ""
    m.guideDataIdentity = ""
    m.guideData = {}
    m.guideDataRevision = 0
    m.guideTaskBusy = false
    m.guidePending = invalid
    m.guideRequestCount = 0
    m.guideActive = false
    m.view = "countries"
    loadCountryGuide()
    require(m.guideTaskBusy and m.epgTask.country = "us", "first country starts")
    require(not m.epgTask.channels[0].DoesExist("url") and not m.epgTask.channels[0].DoesExist("logo"), "worker receives minimal matching metadata")
    m.selectedCountry = {code: "CA", name: "Canada"}
    loadCountryGuide()
    require(m.epgTask.cancelled and m.epgTask.country = "us", "country change cancels cooperatively without overlapping worker")
    m.selectedCountry = {code: "UK", name: "United Kingdom"}
    loadCountryGuide()
    require(m.guidePending.code = "gb", "only the latest country remains queued")
    m.epgTask.state = "done"
    onGuideTaskState()
    require(m.guideTaskBusy and m.epgTask.country = "gb" and m.guideRequestCount = 2, "latest request starts after previous completion")
    require(not m.epgTask.cancelled, "reset cancellation only for the new run")
    m.epgTask.result = {schedules: {"station.us": [{title: "Current"}]}, aliases: {}}
    m.epgTask.message = "Test guide"
    m.epgTask.done = true
    m.epgTask.state = "done"
    onGuideTaskState()
    require(not m.guideTaskBusy, "completed worker becomes idle")
    require(m.guideData.schedules["station.us"].Count() = 1, "deliver result before clearing Task payload")
    require(m.epgTask.result.Count() = 0 and m.epgTask.channels.Count() = 0, "release completed worker payloads")
    m.selectedCountry = {code: "FR", name: "France"}
    loadCountryGuide()
    cancelCountryGuide()
    require(m.epgTask.cancelled and m.guidePending = invalid, "Back cancels active and queued work")
    m.epgTask.state = "done"
    onGuideTaskState()
    require(not m.guideTaskBusy and m.guideCountry = "", "late completion cannot restore an exited guide")
    print "PASS: single-worker queue, cancellation and result lifetime"
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
