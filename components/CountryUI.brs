sub initCountryUI()
    section = CreateObject("roRegistrySection", "zer0_countries")
    saved = ParseJson(section.Read("history_v1"))
    if type(saved) <> "roAssociativeArray" then saved = {}
    m.countryPrefs = saved
    if not saved.DoesExist("iptvorg")
        recent = []
        cached = getCachedSet()
        for each country in getBuiltInCountries()
            key = countryKey(country)
            if cached.DoesExist(key) and recent.Count() < 12 then recent.Push(key)
        end for
        m.countryPrefs.iptvorg = {recent: recent, pinned: []}
        saveCountryPrefs()
    end if
end sub

function currentCountryPrefs() as Object
    if not m.countryPrefs.DoesExist(m.source) then m.countryPrefs[m.source] = {recent: [], pinned: []}
    if type(m.countryPrefs[m.source]) <> "roAssociativeArray" then m.countryPrefs[m.source] = {recent: [], pinned: []}
    prefs = m.countryPrefs[m.source]
    if type(prefs.recent) <> "roArray" then prefs.recent = []
    if type(prefs.pinned) <> "roArray" then prefs.pinned = []
    return prefs
end function

function countryKey(country as Object) as String
    return LCase(country.code.Trim())
end function

function containsCountry(keys as Object, key as String) as Boolean
    for each value in keys
        if value = key then return true
    end for
    return false
end function

function recentCountryKeys(keys as Object, key as String, limit as Integer) as Object
    output = [key]
    for each value in keys
        if value <> key and output.Count() < limit then output.Push(value)
    end for
    return output
end function

function orderCountries(countries as Object, pinned as Object, recent as Object) as Object
    output = []
    seen = {}
    lookup = {}
    for each country in countries
        key = countryKey(country)
        lookup[key] = country
        if country.special = true
            output.Push(country)
            seen[key] = true
        end if
    end for
    for each keys in [pinned, recent]
        for each key in keys
            if lookup.DoesExist(key) and not seen.DoesExist(key)
                output.Push(lookup[key])
                seen[key] = true
            end if
        end for
    end for
    for each country in countries
        key = countryKey(country)
        if not seen.DoesExist(key)
            output.Push(country)
            seen[key] = true
        end if
    end for
    return output
end function

sub saveCountryPrefs()
    section = CreateObject("roRegistrySection", "zer0_countries")
    section.Write("history_v1", FormatJson(m.countryPrefs))
    section.Flush()
end sub

sub recordCountryVisit()
    if m.selectedCountry = invalid then return
    if Left(m.selectedCountry.code, 1) = "_" then return
    prefs = currentCountryPrefs()
    prefs.recent = recentCountryKeys(prefs.recent, countryKey(m.selectedCountry), 12)
    saveCountryPrefs()
end sub

function orderedSourceCountries(countries as Object) as Object
    prefs = currentCountryPrefs()
    return orderCountries(countries, prefs.pinned, prefs.recent)
end function

function countryLabel(country as Object) as String
    label = country.countryName
    if country.flag <> invalid and country.flag <> "" then label = country.flag + "  " + label
    if country.special = true then return label
    prefs = currentCountryPrefs()
    key = countryKey(country)
    if containsCountry(prefs.pinned, key)
        return "★ " + label + "  ·  pinned"
    else if containsCountry(prefs.recent, key)
        return "★ " + label + "  ·  recent"
    end if
    return label
end function

sub toggleCountryPin()
    index = m.list.itemFocused
    if index < 0 or index >= m.displayList.Count() then return
    country = m.displayList[index]
    if country.special = true then return
    key = countryKey(country)
    prefs = currentCountryPrefs()
    if containsCountry(prefs.pinned, key)
        output = []
        for each value in prefs.pinned
            if value <> key then output.Push(value)
        end for
        prefs.pinned = output
    else
        prefs.pinned = recentCountryKeys(prefs.pinned, key, 32)
    end if
    saveCountryPrefs()
    m.countries = orderedSourceCountries(m.countries)
    m.displayList = m.countries
    fillListFromCountries(m.displayList)
    for i = 0 to m.displayList.Count() - 1
        if countryKey(m.displayList[i]) = key then m.list.jumpToItem = i
    end for
    m.status.text = "OK Open   Left/Right A-Z   Replay Pin/unpin   * Countries menu   Back Sources"
end sub

sub openCountryOptions()
    m.view = "countryopts"
    m.optActions = ["Pin / unpin selected country", "Clear recent countries", "Close menu"]
    content = CreateObject("roSGNode", "ContentNode")
    for each title in m.optActions
        item = content.createChild("ContentNode")
        item.title = title
    end for
    m.optsList.content = content
    m.optsTitle.text = "Countries"
    m.optsBg.visible = true
    m.optsBox.visible = true
    m.optsBoxEdge.visible = true
    m.optsTitle.visible = true
    m.optsList.visible = true
    m.optsList.jumpToItem = 0
    m.optsList.setFocus(true)
end sub

sub handleCountryOption(action as String)
    hideOptions()
    m.view = "countries"
    m.list.setFocus(true)
    if action = "Pin / unpin selected country"
        toggleCountryPin()
    else if action = "Clear recent countries"
        prefs = currentCountryPrefs()
        prefs.recent = []
        saveCountryPrefs()
        ' Restore alphabetical base order before applying persistent pins.
        m.countries.SortBy("countryName")
        m.countries = orderedSourceCountries(m.countries)
        m.displayList = m.countries
        fillListFromCountries(m.displayList)
        m.status.text = "Recent countries cleared · pinned countries kept"
    end if
end sub
