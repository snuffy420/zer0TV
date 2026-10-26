' A fixed playback HUD and a focus trap keep * available to the app's CC menu.
sub initPlayerUI()
    m.playerTrap = m.top.findNode("playerTrap")
    m.npLogo = m.top.findNode("npLogo")
    m.npProgramme = m.top.findNode("npProgramme")
    m.npDetails = m.top.findNode("npDetails")
    m.npClock = m.top.findNode("npClock")
    m.npFade = m.top.findNode("npFade")
    m.npTimer.duration = 5
    m.playingChannel = invalid
    m.video.observeField("availableSubtitleTracks", "onPlayerTracksChanged")
    m.video.observeField("availableAudioTracks", "onPlayerTracksChanged")
end sub

sub focusPlayer()
    m.playerTrap.visible = true
    m.playerTrap.setFocus(true)
end sub

sub showNowPlayingBanner(ch = invalid as Dynamic)
    if m.view <> "video" then return
    if ch <> invalid then m.playingChannel = ch
    ch = m.playingChannel
    if ch = invalid then return
    m.npFade.control = "stop"
    m.npBar.opacity = 1
    m.npBar.visible = true
    m.npText.visible = true
    m.npText.text = ch.name
    uri = "pkg:/images/no_logo.png"
    if ch.logo <> invalid and ch.logo <> "" then uri = ch.logo
    if m.npLogo.uri <> uri then m.npLogo.uri = uri
    now = CreateObject("roDateTime").AsSeconds()
    m.npClock.text = guideTime(now)
    m.npProgramme.text = "Live programming · no schedule information"
    for each p in guidePrograms(ch)
        if p.start <= now and p.stop > now
            m.npProgramme.text = p.title + "   " + guideTime(p.start) + " – " + guideTime(p.stop)
            exit for
        end if
    end for
    mode = m.video.globalCaptionMode
    m.npDetails.text = "LIVE   ·   CC " + mode + "   ·   * Captions / audio   ·   OK Info   ·   Back Guide"
    if ch.isMovie = true
        parts = []
        if epgString(ch.year) and ch.year <> "" then parts.Push(ch.year)
        if epgString(ch.genre) and ch.genre <> "" then parts.Push(ch.genre)
        if epgNumber(m.video.position) then parts.Push(movieClock(m.video.position))
        m.npProgramme.text = parts.Join(" | ")
        m.npDetails.text = "ON DEMAND | CC " + mode + " | Play Pause | Left/Right Seek | * Audio/CC | Back Movies"
    end if
    m.npTimer.control = "stop"
    m.npTimer.control = "start"
end sub

sub hidePlayerBanner()
    m.npTimer.control = "stop"
    m.npFade.control = "stop"
    m.npBar.visible = false
    m.npLogo.uri = ""
end sub

sub setCaptionsEnabled(enabled as Boolean)
    ' These are the writable Roku fields. currentSubtitleTrack is read-only.
    m.captionsOn = enabled
    if enabled
        m.video.globalCaptionMode = "On"
    else
        m.video.globalCaptionMode = "Off"
    end if
end sub

sub playbackOption(content as Object, title as String, action as Object)
    item = content.createChild("ContentNode")
    item.title = title
    m.optActions.Push(action)
end sub

sub openPlayerOptions()
    if m.view <> "video" and m.view <> "playeropts" then return
    hidePlayerBanner()
    m.view = "playeropts"
    content = CreateObject("roSGNode", "ContentNode")
    m.optActions = []
    mode = m.video.globalCaptionMode
    playbackOption(content, "Closed captions: " + mode + "  (select to toggle)", {kind: "captions"})
    tracks = m.video.availableSubtitleTracks
    count = 0
    if type(tracks) = "roArray"
        for each track in tracks
            if epgString(track.TrackName)
                label = "Subtitle"
                if epgString(track.Language) then label = label + " · " + track.Language
                if epgString(track.Description) then label = label + " · " + track.Description
                if track.TrackName = m.video.currentSubtitleTrack then label = "[On] " + label
                playbackOption(content, label, {kind: "subtitle", track: track.TrackName})
                count = count + 1
                if count >= 16 then exit for
            end if
        end for
    end if
    if count = 0 then playbackOption(content, "No subtitle tracks reported · in-band CC may still work", {kind: "refresh"})
    tracks = m.video.availableAudioTracks
    count = 0
    if type(tracks) = "roArray"
        for each track in tracks
            if epgString(track.Track)
                label = "Audio"
                if epgString(track.Language) then label = label + " · " + track.Language
                if epgString(track.Name) then label = label + " · " + track.Name
                if track.Track = m.video.currentAudioTrack then label = "[On] " + label
                playbackOption(content, label, {kind: "audio", track: track.Track})
                count = count + 1
                if count >= 16 then exit for
            end if
        end for
    end if
    playbackOption(content, "Refresh available tracks", {kind: "refresh"})
    playbackOption(content, "Close menu", {kind: "close"})
    m.optsList.content = content
    m.optsBg.visible = true
    m.optsBox.visible = true
    m.optsBoxEdge.visible = true
    m.optsTitle.text = "Captions & audio"
    m.optsTitle.visible = true
    m.optsList.visible = true
    m.optsList.jumpToItem = 0
    m.optsList.setFocus(true)
end sub

sub handlePlayerOption(action as Object)
    if action.kind = "refresh"
        openPlayerOptions()
        return
    end if
    hideOptions()
    m.view = "video"
    if action.kind = "captions"
        setCaptionsEnabled(m.video.globalCaptionMode <> "On")
    else if action.kind = "subtitle"
        m.video.subtitleTrack = action.track
        setCaptionsEnabled(true)
    else if action.kind = "audio"
        m.video.audioTrack = action.track
    end if
    focusPlayer()
    showNowPlayingBanner()
end sub

sub onPlayerTracksChanged()
    if m.view = "playeropts" then openPlayerOptions()
end sub

function playerKey(key as String) as Boolean
    if m.playingChannel <> invalid
        if m.playingChannel.isMovie = true and (key = "left" or key = "right" or key = "rewind" or key = "fastforward")
            stepSeconds = 10
            if key = "rewind" or key = "fastforward" then stepSeconds = 60
            if key = "left" or key = "rewind" then stepSeconds = -stepSeconds
            if epgNumber(m.video.position)
                target = m.video.position + stepSeconds
                if target < 0 then target = 0
                if epgNumber(m.video.duration) and m.video.duration > 0
                    if target >= m.video.duration then target = m.video.duration - 1
                end if
                m.video.seek = target
            end if
            showNowPlayingBanner()
            return true
        end if
    end if
    if key = "options" or key = "replay"
        openPlayerOptions()
        return true
    else if key = "OK" or key = "info" or key = "up" or key = "down"
        showNowPlayingBanner()
        return true
    else if key = "play"
        if m.video.state = "playing"
            m.video.control = "pause"
        else if m.video.state = "paused"
            m.video.control = "resume"
        end if
        showNowPlayingBanner()
        return true
    end if
    return false
end function

function movieClock(seconds as Float) as String
    minutes = Int(seconds / 60)
    remainder = Int(seconds) mod 60
    suffix = remainder.ToStr()
    if remainder < 10 then suffix = "0" + suffix
    return minutes.ToStr() + ":" + suffix
end function

function channelLetter(name as String) as String
    name = name.Trim()
    if name = "" then return "#"
    letter = UCase(Left(name, 1))
    if letter < "A" or letter > "Z" then return "#"
    return letter
end function

function buildGuideLetterIndex(channels as Object) as Object
    result = {}
    for i = 0 to channels.Count() - 1
        letter = channelLetter(channels[i].name)
        if not result.DoesExist(letter) then result[letter] = i
    end for
    return result
end function

function nextGuideLetterIndex(channels as Object, index as Object, current as Integer, direction as Integer) as Integer
    if channels.Count() = 0 then return -1
    if current < 0 or current >= channels.Count() then current = 0
    alphabet = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    letter = channelLetter(channels[current].name)
    position = Instr(1, alphabet, letter) - 1
    for stepNumber = 1 to 27
        position = (position + direction + 27) mod 27
        candidate = Mid(alphabet, position + 1, 1)
        if index.DoesExist(candidate) then return index[candidate]
    end for
    return current
end function
