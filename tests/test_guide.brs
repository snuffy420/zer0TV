sub main()
    m.guideRows = CreateObject("roSGNode", "Group")
    m.guideTimes = CreateObject("roSGNode", "Group")
    m.guideDetail = CreateObject("roSGNode", "Label")
    m.guideDescription = CreateObject("roSGNode", "Label")
    m.guideDetail.font = CreateObject("roSGNode", "Font")
    m.guideDescription.font = CreateObject("roSGNode", "Font")
    m.guideTitle = CreateObject("roSGNode", "Label")
    m.guideClock = CreateObject("roSGNode", "Label")
    m.guideInfo = CreateObject("roSGNode", "Label")
    m.status = CreateObject("roSGNode", "Label")
    m.subtitle = CreateObject("roSGNode", "Label")
    m.guideLogo = CreateObject("roSGNode", "Poster")
    m.guideActive = true
    m.guideEpoch = 1792969200
    m.guideCursor = m.guideEpoch
    m.guideIndex = 0
    m.guideRenderedPage = -1
    m.guideRenderedTime = -1
    m.guideDataRevision = 1
    m.guideRenderedRevision = -1
    m.guideMessage = "Test guide"
    m.guideCoverage = ""
    m.displayList = []
    m.guideData = {schedules: {}, aliases: {}}
    for i = 0 to 99
        id = "station" + i.ToStr()
        m.displayList.Push({name: id, tvgId: id, logo: "", url: "https://example.com/" + id})
        m.guideData.schedules[id] = [{start: m.guideEpoch - 600, stop: m.guideEpoch + 600, title: "Live", description: "Test"}]
    end for
    initGuidePool()
    originalRows = descendantCount(m.guideRows)
    originalTimes = descendantCount(m.guideTimes)
    for i = 0 to 599
        m.guideIndex = i mod 100
        m.guideCursor = m.guideEpoch + (i mod 6) * 1800
        drawGuide()
    end for
    require(descendantCount(m.guideRows) = originalRows, "row nodes must not grow after 600 navigations")
    require(descendantCount(m.guideTimes) = originalTimes, "time label count must remain fixed")
    require(originalRows <= 250, "fixed row node budget")
    require(m.guidePool[0].cells.Count() = 16, "bounded cell pool")
    m.displayList = []
    drawGuide()
    require(m.guideTitle.text = "No channels in this view", "empty filtered guide")
    require(playerIdle("stopped") and not playerIdle("buffering") and not playerIdle("playing"), "decoder stop barrier")
    print "PASS: fixed-node guide stress test; row nodes="; originalRows
end sub

function descendantCount(node as Object) as Integer
    total = node.getChildCount()
    for i = 0 to node.getChildCount() - 1
        total = total + descendantCount(node.getChild(i))
    end for
    return total
end function

function isFavorite(url as String) as Boolean
    return false
end function

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
