sub main()
    channels = [{name: "Zulu"}, {name: "ABC News"}, {name: "24/7 News"}, {name: "Bravo"}, {name: "another ABC"}]
    index = buildGuideLetterIndex(channels)
    require(index.Count() = 4 and index.a = 1, "one cached first index per letter")
    require(nextGuideLetterIndex(channels, index, 0, 1) = 2, "Z wraps to numeric group")
    require(nextGuideLetterIndex(channels, index, 2, 1) = 1, "numeric group advances to A")
    require(nextGuideLetterIndex(channels, index, 4, 1) = 3, "jump from within A to B despite source ordering")
    require(nextGuideLetterIndex(channels, index, 1, -1) = 2, "previous letter wraps in reverse")
    require(nextGuideLetterIndex(channels, index, 2, -1) = 0, "numeric group reverses to Z")
    require(nextGuideLetterIndex([], {}, 0, 1) = -1, "empty search results")
    require(channelLetter("  bbc News") = "B", "ignore leading spaces and case")
    print "PASS: guide letter jumps, source ordering, wrap and filtered lists"
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
