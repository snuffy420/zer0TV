sub main()
    m.video = {globalCaptionMode: "Off", subtitleTrack: "", currentSubtitleTrack: "readonly", audioTrack: "", currentAudioTrack: "readonly-audio", state: "playing", control: ""}
    m.video.availableSubtitleTracks = [{TrackName: "cc:en:1", Language: "eng", Description: "English CC"}]
    m.video.availableAudioTracks = [{Track: "audio:en:1", Language: "eng", Name: "English"}]
    m.npBar = {visible: false, opacity: 0}
    m.npText = {visible: false, text: ""}
    m.npLogo = {uri: ""}
    m.npProgramme = {text: ""}
    m.npDetails = {text: ""}
    m.npClock = {text: ""}
    m.npTimer = {control: ""}
    m.npFade = {control: ""}
    m.playerTrap = CreateObject("roSGNode", "Group")
    m.optsList = {content: invalid, visible: false, jumpToItem: 0}
    m.optsList.setFocus = function(value as Boolean) as Boolean
        return true
    end function
    m.optsBg = {visible: false}
    m.optsBox = {visible: false}
    m.optsBoxEdge = {visible: false}
    m.optsTitle = {visible: false, text: ""}
    m.view = "video"
    m.playingChannel = {name: "Test channel", tvgId: "test", logo: "", url: "https://example.com/test"}
    now = CreateObject("roDateTime").AsSeconds()
    m.guideData = {schedules: {test: [{start: now - 600, stop: now + 600, title: "Current programme", description: ""}]}, aliases: {}}
    showNowPlayingBanner()
    require(m.npBar.visible and m.npBar.opacity = 1 and m.npTimer.control = "start", "banner appears with timeout")
    require(m.npText.text = "Test channel" and Instr(1, m.npProgramme.text, "Current programme") > 0, "banner uses actual current programme")
    openPlayerOptions()
    require(m.view = "playeropts" and m.optActions[0].kind = "captions", "app menu exposes captions first")
    require(m.optActions[1].track = "cc:en:1", "subtitle IDs containing colons remain intact")
    handlePlayerOption({kind: "captions"})
    require(m.video.globalCaptionMode = "On", "use writable native caption mode")
    handlePlayerOption({kind: "subtitle", track: "cc:en:1"})
    require(m.video.subtitleTrack = "cc:en:1" and m.video.currentSubtitleTrack = "readonly", "write subtitleTrack without modifying readonly current track")
    handlePlayerOption({kind: "audio", track: "audio:en:1"})
    require(m.video.audioTrack = "audio:en:1" and m.video.currentAudioTrack = "readonly-audio", "correct writable audio selection")
    handlePlayerOption({kind: "captions"})
    require(m.video.globalCaptionMode = "Off", "caption toggle turns off again")
    require(playerKey("play") and m.video.control = "pause", "custom player preserves pause control")
    m.video.state = "paused"
    require(playerKey("play") and m.video.control = "resume", "custom player resumes")
    m.npBar.opacity = 0
    require(playerKey("OK") and m.npBar.opacity = 1, "recall faded banner")
    m.playingChannel = {name: "Movie", tvgId: "", logo: "", isMovie: true, year: "1968", genre: "Rare cut"}
    m.video.position = 5
    m.video.duration = 100
    require(playerKey("left") and m.video.seek = 0, "movie seek clamps at start")
    m.video.position = 95
    require(playerKey("fastforward") and m.video.seek = 99, "movie seek clamps at end")
    require(m.npDetails.text.Instr("ON DEMAND") >= 0 and m.npProgramme.text.Instr("Rare cut") >= 0, "movie banner uses on-demand metadata")
    print "PASS: app captions/audio menu, writable fields and playback banner"
end sub

sub hideOptions()
    m.optsBg.visible = false
    m.optsList.visible = false
end sub

sub require(condition as Boolean, message as String)
    if not condition
        print "FAIL: " + message
        stop
    end if
end sub
