sub initProviders()
    m.providerDefs = ParseJson(ReadAsciiFile("pkg:/config/providers.json"))
    if type(m.providerDefs) <> "roArray" then m.providerDefs = []
    m.providers = {}
    for each provider in m.providerDefs
        m.providers[provider.id] = provider
    end for
end sub

function isLiveProvider(id as String) as Boolean
    if m.providers = invalid then return false
    return m.providers.DoesExist(id)
end function

sub showProviderCountries()
    if not isLiveProvider(m.source) then return
    hideGuide()
    hideAboutHint()
    hideOptions()
    hideSearch()
    hideLoading()
    provider = m.providers[m.source]
    m.view = "countries"
    m.title.text = provider.title
    m.subtitle.text = "US lineup - channels fetched fresh"
    m.countries = []
    for each country in provider.countries
        m.countries.Push({code: country.code, countryName: country.name, flag: country.flag, special: false})
    end for
    m.countries = orderedSourceCountries(m.countries)
    m.displayList = m.countries
    fillListFromCountries(m.displayList)
    m.panelHelp.text = "OK open US lineup" + Chr(10) + "Replay pin country" + Chr(10) + "Back sources"
    setPreview(provider.title, "US live channels", "", "pkg:/images/no_logo.png")
end sub
