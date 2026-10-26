sub main()
    countries = [
        {code: "_RECENT", countryName: "Recently watched", special: true},
        {code: "AU", countryName: "Australia"},
        {code: "CA", countryName: "Canada"},
        {code: "GB", countryName: "United Kingdom"},
        {code: "US", countryName: "United States"}
    ]
    recent = recentCountryKeys(["ca", "us", "au"], "us", 12)
    require(recent[0] = "us" and recent.Count() = 3, "latest visit moves to front without duplication")
    ordered = orderCountries(countries, ["gb"], recent)
    require(ordered[0].special = true, "preserve special channel collections")
    require(ordered[1].code = "GB" and ordered[2].code = "US", "pins precede latest recent countries")
    require(ordered.Count() = countries.Count(), "all other countries remain available")
    require(recentCountryKeys(["a", "b", "c"], "d", 3).Count() = 3, "bounded saved history")
    m.countryPrefs = {iptvorg: {pinned: ["us"], recent: ["ca"]}, freetv: {pinned: [], recent: ["united states"]}}
    m.source = "freetv"
    prefs = currentCountryPrefs()
    require(prefs.recent[0] = "united states", "Free-TV has its own history")
    prefs.pinned = ["canada"]
    m.countryPrefs = ParseJson(FormatJson(m.countryPrefs))
    require(currentCountryPrefs().pinned[0] = "canada", "pins survive JSON persistence round-trip")
    m.source = "iptvorg"
    require(currentCountryPrefs().pinned[0] = "us", "Free-TV pinning does not change IPTV.org")
    require(Instr(1, countryLabel(countries[4]), "pinned") > 0, "pin label is explicit")
    require(Instr(1, countryLabel(countries[2]), "recent") > 0, "recent label is explicit")
    print "PASS: country history, persistent pins, source isolation and ordering"
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
