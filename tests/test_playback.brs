sub main()
    m.video = {state: "playing", visible: true, content: {url: "old"}, control: "", errorCode: 0}
    m.previewUrl = "old"
    m.previewTimer = {control: ""}
    m.switchTimer = {control: ""}
    m.previewWatchdog = {control: ""}
    m.guidePreview = {text: ""}
    m.guideActive = true
    m.view = "channels"
    m.releaseVideo = false
    a = {name: "A", url: "https://example.com/a.m3u8"}
    b = {name: "B", url: "https://example.com/b.m3u8"}
    m.displayList = [a, b]
    m.guideIndex = 0
    requestPlayback(a, false)
    require(m.video.content.url = "old", "do not replace a running decoder's content")
    require(m.video.control = "stop", "stop the previous stream first")
    startPendingPlayback()
    require(m.video.content.url = "old", "wait for stopped state before replacement")
    m.guideIndex = 1
    requestPlayback(b, false)
    m.video.state = "stopped"
    onVideoState()
    require(m.video.content = invalid, "release old content after stop")
    startPendingPlayback()
    require(m.video.content.url = b.url, "only the latest pending tune starts")
    require(m.playRequest = invalid, "clear consumed tune request")
    require(m.video.control = "play", "start after the stop barrier")
    m.video.state = "playing"
    stopGuidePlayback()
    require(m.video.content <> invalid, "do not clear content until decoder stops")
    m.video.state = "stopped"
    onVideoState()
    require(m.video.content = invalid and m.previewUrl = "", "release decoder references on exit")
    m.view = "countries"
    requestPlayback(a, false)
    startPendingPlayback()
    require(m.playRequest = invalid and m.video.content = invalid, "cancel stale tune after leaving guide")
    print "PASS: serialized playback, rapid retune and cleanup"
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
