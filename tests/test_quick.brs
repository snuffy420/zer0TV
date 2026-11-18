sub main()
    m.displayList = []
    for i = 0 to 11
        m.displayList.Push({name: "Ch" + i.ToStr(), url: "https://example.com/" + i.ToStr(), logo: ""})
    end for
    m.guideIndex = 0
    m.tuned = []
    m.playingChannel = m.displayList[0]
    fullscreenChannelStep(1)
    require(m.guideIndex = 1 and m.tuned[0] = "Ch1", "Up tunes the next channel")
    m.playingChannel = m.displayList[0]
    fullscreenChannelStep(-1)
    require(m.guideIndex = 11 and m.tuned[1] = "Ch11", "Down from the first channel wraps to the last")
    m.playingChannel = m.displayList[11]
    fullscreenChannelStep(1)
    require(m.guideIndex = 0, "Up from the last channel wraps to the first")
    m.playingChannel = m.displayList[5]
    require(playingIndex() = 5, "the playing channel is found by its address")
    m.quickFavOnly = false
    buildQuickList()
    require(m.quickList.Count() = 12 and m.quickPos = 5, "quick list opens on the playing channel")
    m.favoriteUrls = {"https://example.com/3": true}
    m.quickFavOnly = true
    buildQuickList()
    require(m.quickList.Count() = 1 and m.quickList[0] = 3, "favorites view lists only favorites")
    print "PASS: full-screen channel flipping and quick list"
end sub

' Stand-ins for the scene's own routines.
sub pushRecent(ch as Object)
end sub

sub showNowPlayingBanner(ch = invalid as Dynamic)
end sub

sub requestPlayback(ch as Object, fullScreen as Boolean)
    m.tuned.Push(ch.name)
    m.playingChannel = ch
end sub

function isFavorite(url as String) as Boolean
    if m.favoriteUrls = invalid then return false
    return m.favoriteUrls.DoesExist(url)
end function

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
