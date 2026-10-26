sub main()
    id = "5f7631c876c54900134c6126"
    line = "#EXTINF:-1 group-title=" + Chr(34) + "Rare cuts" + Chr(34) + " tvg-name=" + Chr(34) + "A Movie, Alternate Cut" + Chr(34) + ",A Movie"
    movie = plutoMovie(line, "https://example.com/v2/stitch/hls/episode/" + id + "/master.m3u8?test=1")
    require(movie.id = id and movie.name = "A Movie, Alternate Cut", "preserve movie title/cut and stable ID")
    require(movie.isMovie and movie.streamFormat = "hls", "on-demand records are not live channels")
    require(movie.poster = "https://images.pluto.tv/episodes/" + id + "/poster.jpg", "verified poster URL pattern")
    require(plutoMovie(line, "https://example.com/not-an-episode") = invalid, "ignore malformed movie URL")
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
    print "PASS: movie metadata, poster IDs, rare-cut filters and compatible public-file selection"
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
