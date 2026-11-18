sub main()
    m.top = {choices: [
        {id: "iptvorg", title: "IPTV.org"},
        {id: "freetv", title: "Free-TV IPTV"},
        {id: "plutotv", title: "Pluto TV"},
        {id: "samsungtvplus", title: "Samsung TV Plus"},
        {id: "plex", title: "Plex Live TV"},
        {id: "tubi", title: "Tubi"},
        {id: "archive", title: "Internet Archive"},
        {id: "boxstream", title: "Box://Stream"}
    ], focusedIndex: 0, selectedIndex: -1, visible: true}
    m.host = CreateObject("roSGNode", "Group")
    m.cards = []
    onChoicesChanged()
    require(m.cards.Count() = 8, "eight source cards")
    require(m.cards[3].title.text = "Samsung TV Plus", "clean prominent provider title")
    require(m.cards[1].logo.uri = "pkg:/images/providers/freetv.png", "transparent Free-TV logo")
    require(m.cards[7].logo.uri = "pkg:/images/mark.png", "Box://Stream uses its own mark")
    require(m.cards[4].place.x = 96 and m.cards[4].place.y > m.cards[0].place.y, "four cards a row")
    nodes = descendantCount(m.host)
    for i = 0 to 49
        onChoicesChanged()
    end for
    require(descendantCount(m.host) = nodes, "reuse menu card nodes on reopen")
    require(sourceGridMove(0, 8, "right") = 1, "move right")
    require(sourceGridMove(1, 8, "left") = 0, "move left")
    require(sourceGridMove(3, 8, "right") = 3, "no wrap off the row end")
    require(sourceGridMove(4, 8, "left") = 4, "no wrap off the row start")
    require(sourceGridMove(2, 8, "down") = 6, "move down a row")
    require(sourceGridMove(6, 8, "up") = 2, "move up a row")
    require(sourceGridMove(3, 7, "down") = 6, "short last row keeps nearest valid card")
    require(sourceGridMove(6, 8, "down") = 6, "no off-grid focus")
    require(onKeyEvent("right", true), "D-pad handled")
    require(m.top.focusedIndex = 1, "D-pad updates highlight")
    require(onKeyEvent("OK", true) and m.top.selectedIndex = 1, "OK selects highlighted provider")
    m.top.visible = false
    require(not onKeyEvent("OK", true), "hidden menu cannot capture playback keys")
    print "PASS: source logo cards, fixed nodes, grid focus and selection"
end sub

function descendantCount(node as Object) as Integer
    total = node.getChildCount()
    for i = 0 to node.getChildCount() - 1
        total = total + descendantCount(node.getChild(i))
    end for
    return total
end function

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
