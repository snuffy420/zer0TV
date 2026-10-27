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

function providerCountry(provider as Object, code as String) as Object
    result = {}
    for each key in provider
        result[key] = provider[key]
    end for
    if type(provider.countries) = "roArray"
        for each country in provider.countries
            if LCase(country.code) = LCase(code)
                for each key in country
                    result[key] = country[key]
                end for
                exit for
            end if
        end for
    end if
    return result
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
    m.subtitle.text = "Country lineups - channels fetched fresh"
    m.countries = []
    for each country in provider.countries
        m.countries.Push({code: country.code, countryName: country.name, flag: country.flag, special: false})
    end for
    m.countries = orderedSourceCountries(m.countries)
    m.displayList = m.countries
    fillListFromCountries(m.displayList)
    m.panelHelp.text = "OK open country lineup" + Chr(10) + "Replay pin country" + Chr(10) + "Back sources"
    setPreview(provider.title, "Live channels by country", "", "pkg:/images/no_logo.png")
end sub
