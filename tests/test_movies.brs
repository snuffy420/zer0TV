sub main()
    files = [
        {name: "original.mkv", format: "Matroska"},
        {name: "movie_512kb.mp4", format: "512Kb MPEG4"},
        {name: "movie.mp4", format: "h.264"},
        {name: "private.mp4", format: "h.264", private: "true"}
    ]
    require(archiveFile(files) = "movie.mp4", "prefer public H.264 MP4 over low quality and restricted files")
    require(archiveFile([{name: "locked.mp4", private: true}]) = "", "restricted file is not playable")
    require(movieFlag("true") and movieFlag(true) and not movieFlag(invalid), "public/restricted flag types")
    require(movieText("<b>Alternate</b> &amp; rare") = "Alternate  & rare", "strip HTML metadata")
    require(archiveQuery("workprints", "").Instr("workprint") >= 0, "workprint discovery filter")
    require(archiveQuery("alternate", "").Instr("extended cut") >= 0, "alternate-cut discovery filter")
    require(archiveQuery("rare", "night: living").Instr("night AND living") >= 0, "safe title keyword query")
    print "PASS: movie metadata, rare-cut filters and compatible public-file selection"
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
