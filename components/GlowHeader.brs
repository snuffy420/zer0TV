sub init()
    m.clock = m.top.findNode("clock")
    m.clock.font = glowFont("bold", 32)
    m.infoLabel = m.top.findNode("info")
    m.infoLabel.font = glowFont("regular", 20)
    m.navHost = m.top.findNode("navItems")
    m.timer = m.top.findNode("clockTimer")
    m.timer.observeField("fire", "onClockTick")
    m.timer.control = "start"
    onClockTick()
end sub

sub onClockTick()
    m.clock.text = glowClock()
end sub

sub onInfoChanged()
    m.infoLabel.text = m.top.info
end sub

' Tabs with the current one white and underlined in green, the rest muted.
sub onNavChanged()
    m.navHost.removeChildrenIndex(m.navHost.getChildCount(), 0)
    items = m.top.nav
    if type(items) <> "roArray" then return
    x = 0
    font = glowFont("bold", 23)
    for i = 0 to items.Count() - 1
        label = m.navHost.createChild("Label")
        label.font = font
        label.text = items[i]
        label.translation = [x, 0]
        label.height = 40
        width = label.boundingRect().width
        if i = m.top.navIndex
            label.color = glowColors().white
            line = m.navHost.createChild("Rectangle")
            line.translation = [x, 44]
            line.width = width
            line.height = 3
            line.color = glowColors().green
        else
            label.color = glowColors().muted
        end if
        x = x + width + 40
    end for
end sub
