sub main()
    text = "#EXTM3U" + Chr(10)
    text = text + "#EXTINF:-1 tvg-id=" + Chr(34) + "News.us" + Chr(34) + " group-title=" + Chr(34) + "News, Local" + Chr(34) + " tvg-logo=" + Chr(34) + "https://example.com/logo.png" + Chr(34) + ",News Channel" + Chr(10)
    text = text + "#EXTVLCOPT:http-referrer=test" + Chr(10) + "https://example.com/live.m3u8" + Chr(10)
    text = text + "#EXTINF:-1,No EPG Channel" + Chr(10) + "https://example.com/no-guide.m3u8"
    channels = parseM3U(text)
    require(channels.Count() = 2, "channels without guide IDs remain visible")
    require(channels[0].name = "News Channel", "commas inside attributes")
    require(channels[0].group = "News, Local", "group preservation")
    require(channels[0].tvgId = "News.us", "EPG ID preservation")
    require(channels[0].logo = "https://example.com/logo.png", "logo preservation")
    require(channels[1].tvgId = "", "missing ID")
    print "PASS: playlist runtime parser"
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
