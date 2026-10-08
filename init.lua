-- ONE PACE SKIP INTRO
-- Official Stremio 5.1.28 / macOS
-- Stable reference: countdown + skipping transition

hs.dockicon.hide()

local settings = hs.settings
local target = settings.get("onepace_skip_seconds") or 102

local AUTO_SKIP_DELAY = 3
local INITIAL_DISPLAY_DELAY = 1
local CHECK_INTERVAL = 4
local SKIP_DISPLAY_DELAY = 2.5

local editingTimestamp = false
local scanInProgress = false
local countdownTimer = nil
local countdownTextTimers = {}
local countdownGeneration = 0
local skipAlreadyTriggered = false
local skipFinishing = false
local skipFinishDeadline = 0
local skipHideTimer = nil

local updateSkipVisibility

-- ==========================================
-- TIME FORMATTING
-- ==========================================

local function formatTime(seconds)
    return string.format(
        "%d:%02d",
        math.floor(seconds / 60),
        seconds % 60
    )
end

local function parseTime(value)
    if type(value) ~= "string" then return nil end

    value = value:match("^%s*(.-)%s*$")

    local h, m, s = value:match("^(%d+):(%d%d):(%d%d)$")

    if h then
        h, m, s = tonumber(h), tonumber(m), tonumber(s)

        if m < 60 and s < 60 then
            return h * 3600 + m * 60 + s
        end

        return nil
    end

    local mm, ss = value:match("^(%d+):(%d%d)$")

    if mm then
        mm, ss = tonumber(mm), tonumber(ss)

        if ss < 60 then
            return mm * 60 + ss
        end
    end

    return nil
end

local function isStremioActive()
    local front = hs.application.frontmostApplication()

    return front ~= nil and front:name() == "Stremio"
end

-- ==========================================
-- SEEK TO SAVED TIMESTAMP
-- ORIGINAL WORKING IMPLEMENTATION
-- ==========================================

local function skipIntro()

    local originalMousePosition = hs.mouse.absolutePosition()

    local a = settings.get("onepace_seek_start")
    local b = settings.get("onepace_seek_end")

    if not a or not b or b.x <= a.x then
        hs.alert.show("Seek bar not calibrated")
        return
    end

    local app = hs.axuielement.applicationElement("Stremio")

    if not app then
        hs.alert.show("Stremio not found")
        return
    end

    -- Reveal playback controls
    hs.mouse.absolutePosition({
        x = (a.x + b.x) / 2,
        y = (a.y + b.y) / 2
    })

    hs.timer.doAfter(0.4, function()

        app:elementSearch(function(_, results)

            local duration = 0

            for _, element in ipairs(results) do

                local seconds = parseTime(
                    element:attributeValue("AXValue")
                )

                if seconds and seconds > duration
                    and seconds < 14400 then

                    duration = seconds
                end
            end

            if duration <= target then
                hs.alert.show("Could not detect video duration")
                hs.mouse.absolutePosition(originalMousePosition)
                return
            end

            local fraction = target / duration

            local x = a.x + (b.x - a.x) * fraction
            local y = (a.y + b.y) / 2

            hs.mouse.absolutePosition({x = x, y = y})

            hs.timer.doAfter(0.35, function()

                -- Avoid clicking another application if focus changed.
                if not isStremioActive() then
                    hs.mouse.absolutePosition(originalMousePosition)
                    return
                end

                hs.eventtap.leftClick({x = x, y = y})

                -- Restore cursor position
                hs.timer.doAfter(0.25, function()
                    hs.mouse.absolutePosition(originalMousePosition)
                end)

            end)

        end, function(element)

            return parseTime(
                element:attributeValue("AXValue")
            ) ~= nil

        end, {
            depth = 20,
            count = 12
        })

    end)
end

-- ==========================================
-- FLOATING INTERFACE
-- COMPACT NETFLIX-STYLE DESIGN
-- ==========================================

local screen = hs.screen.mainScreen():fullFrame()
local seekEnd = settings.get("onepace_seek_end")

local buttonWidth = 195
local buttonHeight = 42
local gapAboveBar = 35

local x = screen.x + screen.w - buttonWidth - 20
local y = screen.y + screen.h - 170

if seekEnd then
    x = seekEnd.x - buttonWidth - 10
    y = seekEnd.y - buttonHeight - gapAboveBar
end

local skipUI = hs.canvas.new({
    x = x,
    y = y,
    w = buttonWidth,
    h = buttonHeight
})

-- Background
skipUI[1] = {
    type = "rectangle",
    frame = {x = 1, y = 1, w = 193, h = 40},
    action = "strokeAndFill",

    fillColor = {
        white = 0,
        alpha = 0.88
    },

    strokeColor = {
        white = 1,
        alpha = 0.90
    },

    strokeWidth = 1.2,

    roundedRectRadii = {
        xRadius = 0,
        yRadius = 0
    }
}

-- Skip hover highlight
skipUI[2] = {
    type = "rectangle",
    frame = {x = 2, y = 2, w = 148, h = 38},
    action = "skip",

    fillColor = {
        white = 1,
        alpha = 0.14
    }
}

-- Settings hover highlight
skipUI[3] = {
    type = "rectangle",
    frame = {x = 152, y = 2, w = 41, h = 38},
    action = "skip",

    fillColor = {
        white = 1,
        alpha = 0.14
    }
}

-- Main label
skipUI[4] = {
    type = "text",
    frame = {x = 8, y = 10, w = 135, h = 24},

    text = "SKIP INTRO",

    textFont = "HelveticaNeue-Bold",
    textSize = 16,
    textAlignment = "center",
    textLineBreak = "clip",

    textColor = {
        white = 1
    }
}

-- Separator
skipUI[5] = {
    type = "rectangle",
    frame = {x = 151, y = 9, w = 1, h = 24},
    action = "fill",

    fillColor = {
        white = 1,
        alpha = 0.55
    }
}

-- Settings icon
skipUI[6] = {
    type = "text",
    frame = {x = 152, y = 9, w = 42, h = 24},

    text = "⚙",
    textSize = 19,
    textAlignment = "center",

    textColor = {
        white = 1
    }
}

-- Skip clickable region
skipUI[7] = {
    type = "rectangle",
    id = "skip",

    frame = {x = 0, y = 0, w = 151, h = 42},

    action = "fill",
    fillColor = {white = 1, alpha = 0.001},

    trackMouseUp = true,
    trackMouseEnterExit = true,
    trackMouseByBounds = true
}

-- Settings clickable region
skipUI[8] = {
    type = "rectangle",
    id = "edit",

    frame = {x = 151, y = 0, w = 44, h = 42},

    action = "fill",
    fillColor = {white = 1, alpha = 0.001},

    trackMouseUp = true,
    trackMouseEnterExit = true,
    trackMouseByBounds = true
}

-- ==========================================
-- COUNTDOWN / SKIPPING TRANSITION
-- ==========================================

local function setCountdownLabel(text)
    skipUI[4].text = text
end

local function cancelCountdown()
    countdownGeneration = countdownGeneration + 1

    if countdownTimer then
        countdownTimer:stop()
        countdownTimer = nil
    end

    for _, timer in ipairs(countdownTextTimers) do
        timer:stop()
    end
    countdownTextTimers = {}

    setCountdownLabel("SKIP INTRO")
end

-- Cleanup is scheduled before seeking and also has a monitor fallback.
local function finishSkipTransition()
    if skipHideTimer then
        skipHideTimer:stop()
        skipHideTimer = nil
    end

    skipFinishing = false
    skipUI:hide()
    setCountdownLabel("SKIP INTRO")
end

local function executeSkip()
    if skipAlreadyTriggered or skipFinishing then return end

    cancelCountdown()
    skipAlreadyTriggered = true
    skipFinishing = true
    skipFinishDeadline = hs.timer.secondsSinceEpoch() + SKIP_DISPLAY_DELAY

    setCountdownLabel("SKIPPING...")

    skipHideTimer = hs.timer.doAfter(
        SKIP_DISPLAY_DELAY,
        finishSkipTransition
    )

    skipIntro()
end

local function scheduleCountdownText(delay, text, generation)
    local timer = hs.timer.doAfter(delay, function()
        if generation ~= countdownGeneration then return end

        if editingTimestamp
            or not countdownTimer
            or not skipUI:isShowing() then
            return
        end
        setCountdownLabel(text)
    end)

    table.insert(countdownTextTimers, timer)
end

local function startCountdown()
    if countdownTimer
        or skipAlreadyTriggered
        or skipFinishing
        or editingTimestamp
        or not isStremioActive()
        or not skipUI:isShowing() then
        return
    end

    local generation = countdownGeneration
    setCountdownLabel("SKIP INTRO")

    scheduleCountdownText(INITIAL_DISPLAY_DELAY, "SKIP IN 3", generation)
    scheduleCountdownText(INITIAL_DISPLAY_DELAY + 1, "SKIP IN 2", generation)
    scheduleCountdownText(INITIAL_DISPLAY_DELAY + 2, "SKIP IN 1", generation)

    countdownTimer = hs.timer.doAfter(
        INITIAL_DISPLAY_DELAY + AUTO_SKIP_DELAY,
        function()
            countdownTimer = nil
            if generation ~= countdownGeneration then return end

            if editingTimestamp
                or skipAlreadyTriggered
                or not isStremioActive()
                or not skipUI:isShowing() then
                setCountdownLabel("SKIP INTRO")
                return
            end

            executeSkip()
        end
    )
end

-- ==========================================
-- EDIT TIMESTAMP
-- ==========================================

local function editTimestamp()

    editingTimestamp = true

    -- Stop countdown while editing
    cancelCountdown()

    local button, value = hs.dialog.textPrompt(
        "Skip Intro",
        "Enter the timestamp (minutes:seconds)",
        formatTime(target),
        "Save",
        "Cancel"
    )

    if button == "Save" then

        local seconds = parseTime(value)

        if not seconds or seconds > 14399 then
            hs.alert.show("Invalid timestamp. Example: 1:42")
        else
            target = seconds
            settings.set("onepace_skip_seconds", target)
        end
    end

    -- Restore Stremio focus
    hs.timer.doAfter(0.1, function()

        local stremio = hs.application.get("Stremio")

        if stremio then
            stremio:activate()
        end

        hs.timer.doAfter(0.6, function()

            editingTimestamp = false

            -- Recheck playback and start fresh countdown
            updateSkipVisibility()

        end)

    end)

end

-- ==========================================
-- BUTTON ACTIONS
-- ==========================================

skipUI:mouseCallback(function(_, event, id)

    if event == "mouseEnter" then

        if id == "skip" then
            skipUI[2].action = "fill"

        elseif id == "edit" then
            skipUI[3].action = "fill"
        end

    elseif event == "mouseExit" then

        if id == "skip" then
            skipUI[2].action = "skip"

        elseif id == "edit" then
            skipUI[3].action = "skip"
        end

    elseif event == "mouseUp" then

        if id == "skip" then

            executeSkip()

        elseif id == "edit" then

            editTimestamp()

        end

    end

end)

skipUI:clickActivating(false)
skipUI:behavior({"canJoinAllSpaces", "transient"})
skipUI:show():bringToFront(true)

-- ==========================================
-- MANUAL VISIBILITY TOGGLE
-- ==========================================

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "0", function()

    if skipUI:isShowing() then
        skipUI:hide()
        cancelCountdown()
    else
        skipUI:show():bringToFront(true)
    end

end)

-- ==========================================
-- DEBUG TIMESTAMPS
-- ==========================================

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "P", function()

    local app = hs.axuielement.applicationElement("Stremio")

    if not app then return end

    app:elementSearch(function(_, results)

        local times = {}

        for _, element in ipairs(results) do
            table.insert(
                times,
                tostring(element:attributeValue("AXValue"))
            )
        end

        hs.alert.show(
            #times > 0
            and table.concat(times, " | ")
            or "No timestamps found"
        )

    end, function(element)

        return parseTime(
            element:attributeValue("AXValue")
        ) ~= nil

    end, {
        depth = 20,
        count = 6
    })

end)

-- ==========================================
-- AUTOMATIC VISIBILITY WITH TRANSITION FAIL-SAFE
-- ==========================================

local function setSkipVisibility(visible)
    -- Never leave the overlay on top of other applications.
    if not isStremioActive() then
        if skipFinishing then
            finishSkipTransition()
        end
        cancelCountdown()
        skipAlreadyTriggered = false
        skipUI:hide()
        return
    end

    -- Preserve the SKIPPING... state briefly, but never indefinitely.
    if skipFinishing then
        if hs.timer.secondsSinceEpoch() >= skipFinishDeadline then
            finishSkipTransition()
        else
            return
        end
    end

    if visible then
        if skipAlreadyTriggered then return end
        if not skipUI:isShowing() then
            skipUI:show():bringToFront(true)
        end
        startCountdown()
    else
        cancelCountdown()
        skipAlreadyTriggered = false
        if skipUI:isShowing() then
            skipUI[2].action = "skip"
            skipUI[3].action = "skip"
            skipUI:hide()
        end
    end
end

updateSkipVisibility = function()

    if editingTimestamp then return end

    if not isStremioActive() then
        setSkipVisibility(false)
        return
    end

    if scanInProgress then return end

    local app = hs.axuielement.applicationElement("Stremio")

    if not app then
        setSkipVisibility(false)
        return
    end

    scanInProgress = true

    app:elementSearch(function(_, results)

        scanInProgress = false

        if editingTimestamp then return end

        if not isStremioActive() then
            setSkipVisibility(false)
            return
        end

        local times = {}
        local seen = {}

        for _, element in ipairs(results) do

            local value = element:attributeValue("AXValue")
            local seconds = parseTime(value)

            if seconds and seconds >= 0
                and seconds < 14400
                and not seen[seconds] then

                seen[seconds] = true
                table.insert(times, seconds)

            end

        end

        if #times ~= 2 then
            setSkipVisibility(false)
            return
        end

        local current = math.min(times[1], times[2])
        local duration = math.max(times[1], times[2])

        if duration < 180 or duration <= target then
            setSkipVisibility(false)
            return
        end

        -- Show only while inside the intro
        setSkipVisibility(current < target)

    end, function(element)

        return parseTime(
            element:attributeValue("AXValue")
        ) ~= nil

    end, {
        depth = 20,
        count = 8
    })

end

-- ==========================================
-- START MONITORING
-- ==========================================

skipUI:hide()

autoIntroTimer = hs.timer.doEvery(
    CHECK_INTERVAL,
    updateSkipVisibility
)

updateSkipVisibility()

-- Edit shortcut
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "E", editTimestamp)