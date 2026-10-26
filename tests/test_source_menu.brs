sub main()
    m.top = {choices: [
        {id: "iptvorg", title: "IPTV.org"},
        {id: "freetv", title: "Free-TV IPTV"},
        {id: "plutotv", title: "Pluto TV"},
        {id: "samsungtvplus", title: "Samsung TV Plus"},
        {id: "plex", title: "Plex Live TV"},
        {id: "tubi", title: "Tubi"},
        {id: "plutovod", title: "Pluto On Demand"},
        {id: "archive", title: "Internet Archive"}
    ], focusedIndex: 0, selectedIndex: -1, visible: true}
    m.top.helpTitle = {visible: true}
    m.top.helpText = {visible: true}
    m.top.findNode = function(id)
        if id = "sourceHelpTitle" then return m.helpTitle
        if id = "sourceHelpText" then return m.helpText
        return invalid
    end function
    m.host = CreateObject("roSGNode", "Group")
    m.titleFont = CreateObject("roSGNode", "Font")
    m.detailFont = CreateObject("roSGNode", "Font")
    m.cards = []
    onChoicesChanged()
    require(m.cards.Count() = 8, "eight live/movie provider logo cards")
    require(not m.top.helpTitle.visible and not m.top.helpText.visible, "full source grid hides help that would overlap last card")
    require(m.cards[3].title.text = "Samsung TV Plus", "clean prominent provider title")
    require(m.cards[1].logo.uri = "pkg:/images/providers/freetv.jpg", "correct avatar format")
    nodes = descendantCount(m.host)
    for i = 0 to 49
        onChoicesChanged()
    end for
    require(descendantCount(m.host) = nodes, "reuse menu card nodes on reopen")
    require(sourceGridMove(0, 5, "right") = 1, "move right")
    require(sourceGridMove(1, 5, "left") = 0, "move left")
    require(sourceGridMove(3, 5, "down") = 4, "last odd row keeps nearest valid card")
    require(sourceGridMove(4, 5, "up") = 2, "move up from last row")
    require(sourceGridMove(4, 5, "right") = 4, "no off-grid focus")
    require(sourceGridMove(5, 8, "down") = 7, "full four-row source grid")
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
