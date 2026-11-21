local addonName, addonTable = ...

local AceAddon = LibStub("AceAddon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local addon = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local db

local defaults = {
    profile = {
        enabled = true,
        trigger = "login", -- "login" or "guildchat"
        delay = 20,
        cacheHours = 24,
        message = "Welcome back <name>!",
        delivery = "GUILD",
        debug = false,
        greeted = {},
        timeOfDay = false,
        firstNameOnly = false,
        randomGreetings = false,
        randomGreetingList = nil,
        minimap = { hide = false, minimapButtonAngle = 225 },
    },
}

-- Per-session state.
local knownOnline = {}
local initialRosterLoaded = false
local rosterSettleUntil = 0
local pending = {}

-- Send queue: one message per SEND_INTERVAL seconds. A timer runs only while
-- messages are waiting, so there is no per-frame work when the queue is empty.
local SEND_INTERVAL = 15
local sendQueue = {}
local sendTimerActive = false
local scheduleSendQueue

local DEBUG_MAX_LINES = 500
local debugLines = {}
local debugWindow

local function refreshDebugWindow()
    if debugWindow and debugWindow:IsShown() then
        debugWindow.edit:SetText(table.concat(debugLines, "\n"))
    end
end

local function debugPrint(fmt, ...)
    if not (db and db.profile.debug) then
        return
    end
    debugLines[#debugLines + 1] = date("%H:%M:%S ") .. string.format(fmt, ...)
    if #debugLines > DEBUG_MAX_LINES then
        table.remove(debugLines, 1)
    end
    refreshDebugWindow()
end

local function createDebugWindow()
    local f = CreateFrame("Frame", "BearsGreeterDebugFrame", UIParent, "BackdropTemplate")
    f:SetSize(560, 360)
    local pos = db.profile.debugWindowPos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("CENTER")
    end
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        db.profile.debugWindowPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("Bears Greeter debug log")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -40)
    hint:SetText("Click in the box and press Ctrl+A, then Ctrl+C to copy. Drag the title bar to move.")

    local scroll = CreateFrame("ScrollFrame", "BearsGreeterDebugScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -60)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -36, 18)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(500)
    edit:SetMaxLetters(0)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)
    f.edit = edit

    debugWindow = f
    return f
end

local function toggleDebugWindow()
    if not debugWindow then
        createDebugWindow()
    end
    if debugWindow:IsShown() then
        debugWindow:Hide()
        return
    end
    debugWindow.edit:SetText(table.concat(debugLines, "\n"))
    debugWindow:Show()
end

local function clearDebugLog()
    wipe(debugLines)
    refreshDebugWindow()
end

local function processSendQueue()
    sendTimerActive = false
    if #sendQueue == 0 then return end
    if InCombatLockdown() or UnitAffectingCombat("player") then
        debugPrint("send paused: in combat, %d queued", #sendQueue)
        return
    end
    local item = table.remove(sendQueue, 1)
    local ok, err
    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        ok, err = pcall(C_ChatInfo.SendChatMessage, item.msg, item.chatType, nil, item.target)
    else
        ok, err = pcall(SendChatMessage, item.msg, item.chatType, nil, item.target)
    end
    if not ok then
        debugPrint("send failed (%s): %s", item.chatType, tostring(err))
        table.insert(sendQueue, 1, item)
        scheduleSendQueue(SEND_INTERVAL)
        return
    end
    if item.onSuccess then
        item.onSuccess()
    end
    scheduleSendQueue(SEND_INTERVAL)
end

scheduleSendQueue = function(delay)
    if sendTimerActive or #sendQueue == 0 then return end
    sendTimerActive = true
    C_Timer.After(delay or 0, processSendQueue)
end

-- Members seen while the roster is still loading after login are recorded but not greeted.
local ROSTER_SETTLE_SECONDS = 30

local GREETER_ICON = "Interface\\Icons\\ability_priest_heavanlyvoice"

local function RequestGuildRoster()
    -- C_GuildInfo.GuildRoster() exists in both retail (12.1.5) and Forever (1.60.1).
    -- The global GuildRoster() was moved to this namespace in 8.2.0; keep it as a fallback.
    if C_GuildInfo and type(C_GuildInfo.GuildRoster) == "function" then
        C_GuildInfo.GuildRoster()
    elseif type(GuildRoster) == "function" then
        GuildRoster()
    end
end

local function todayKey()
    return date("%Y-%m-%d")
end

local function cacheEntry(name)
    return db.profile.greeted[name]
end

local function isCached(name)
    local entry = cacheEntry(name)
    if not entry then
        return false
    end
    local cacheHours = db.profile.cacheHours or 24
    if cacheHours == 24 then
        -- 24 hours means "until the calendar day changes", not a rolling window.
        return entry.date == todayKey()
    end
    local ts = entry.ts or 0
    return (time() - ts) < (cacheHours * 3600)
end

local function markCached(name)
    db.profile.greeted[name] = { ts = time(), date = todayKey() }
end

local function clearExpired()
    if not db or not db.profile or not db.profile.greeted then
        return
    end
    local now = time()
    local cacheHours = db.profile.cacheHours or 24
    for name, entry in pairs(db.profile.greeted) do
        local expired = false
        if cacheHours == 24 then
            expired = (not entry or entry.date ~= todayKey())
        else
            expired = (not entry or (now - (entry.ts or 0)) >= (cacheHours * 3600))
        end
        if expired then
            db.profile.greeted[name] = nil
        end
    end
end

local function timeOfDayGreeting()
    local now = (GetServerTime and GetServerTime()) or time()
    local hour = tonumber(date("%H", now)) or 0
    if hour < 12 then
        return L["Good Morning"]
    elseif hour < 18 then
        return L["Good Afternoon"]
    else
        return L["Good Evening"]
    end
end

local function formatMessage(name)
    if db.profile.firstNameOnly then
        name = name:match("^%S+") or name
    end
    if db.profile.randomGreetings then
        local list = db.profile.randomGreetingList
        if not list or #list == 0 then
            list = addonTable.DefaultRandomGreetings
        end
        local pool = {}
        for _, tmpl in ipairs(list) do
            pool[#pool + 1] = tmpl
        end
        if db.profile.timeOfDay then
            pool[#pool + 1] = timeOfDayGreeting() .. ", <name>!"
        end
        local chosen = pool[math.random(#pool)]
        local msg = chosen:gsub("<[Nn]ame>", name)
        msg = msg:gsub("%%s", name)
        return msg
    end
    if db.profile.timeOfDay then
        return timeOfDayGreeting() .. ", " .. name .. "!"
    end
    local template = db.profile.message
    if not template or template == "" then
        template = "Welcome back <name>!"
    end
    local msg = template:gsub("<[Nn]ame>", name)
    msg = msg:gsub("%%s", name)
    return msg
end

local function doSend(name)
    if not db.profile.enabled then
        pending[name] = nil
        return
    end
    if name == UnitName("player") then
        pending[name] = nil
        return
    end
    -- SendChatMessage is protected while in combat; defer until combat ends.
    if InCombatLockdown() or UnitAffectingCombat("player") then
        pending[name] = true
        return
    end
    local msg = formatMessage(name)
    local target = (db.profile.delivery == "WHISPER") and name or nil
    local chatType = db.profile.delivery == "WHISPER" and "WHISPER" or "GUILD"
    -- Queue the send so it happens one per frame in a clean context,
    -- avoiding taint from event handlers.
    sendQueue[#sendQueue + 1] = {
        msg = msg,
        chatType = chatType,
        target = target,
        onSuccess = function()
            debugPrint("greeted %s", name)
        end,
    }
    scheduleSendQueue(0)
    pending[name] = nil
end

local function scheduleGreeting(name)
    if not db.profile.enabled then
        return
    end
    if name == UnitName("player") then
        return
    end
    if isCached(name) then
        return
    end
    if pending[name] then
        return
    end
    -- Mark as greeted before sending so repeated triggers cannot duplicate.
    markCached(name)
    pending[name] = true

    local delay = tonumber(db.profile.delay) or 0
    if delay < 0 then
        delay = 0
    end

    if delay == 0 then
        doSend(name)
    else
        C_Timer.After(delay, function()
            doSend(name)
        end)
    end
end

function addon:UpdateMinimapButtonPosition(button)
    button = button or self.minimapButton
    if not button or not _G.Minimap then
        return
    end
    local radius = _G.Minimap:GetWidth() / 2 + 4
    local angle = math.rad(db.profile.minimap.minimapButtonAngle or 225)
    button:ClearAllPoints()
    button:SetPoint("CENTER", _G.Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function addon:CreateMinimapButton()
    if self.minimapButton then
        return
    end
    if not _G.Minimap then
        return
    end
    db.profile.minimap = db.profile.minimap or { hide = false, minimapButtonAngle = 225 }

    local button = CreateFrame("Button", "BearsGreeterMinimapButton", _G.Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(_G.Minimap:GetFrameLevel() + 5)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForDrag("LeftButton")

    self:UpdateMinimapButtonPosition(button)

    local function UpdateAngleFromCursor()
        local scale = _G.Minimap:GetEffectiveScale()
        local mapX, mapY = _G.Minimap:GetCenter()
        local cursorX, cursorY = GetCursorPosition()
        cursorX, cursorY = cursorX / scale, cursorY / scale
        local angle = math.deg(math.atan2(cursorY - mapY, cursorX - mapX))
        db.profile.minimap.minimapButtonAngle = angle
        self:UpdateMinimapButtonPosition(button)
    end

    button:SetScript("OnDragStart", function(buttonFrame)
        buttonFrame:SetScript("OnUpdate", UpdateAngleFromCursor)
        UpdateAngleFromCursor()
    end)
    button:SetScript("OnDragStop", function(buttonFrame)
        buttonFrame:SetScript("OnUpdate", nil)
        UpdateAngleFromCursor()
    end)

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(50, 50)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetVertexColor(1, 0.82, 0.2)
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("CENTER", button, "CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(GREETER_ICON)
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", button, "CENTER")
    button.icon = icon

    button:SetScript("OnEnter", function(buttonFrame)
        GameTooltip:SetOwner(buttonFrame, "ANCHOR_LEFT")
        GameTooltip:SetText(addonName)
        GameTooltip:AddLine(L["Open options."], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            if addon.OpenOptionsDialog then
                addon.OpenOptionsDialog()
            end
        elseif mouseButton == "RightButton" then
            addon:ToggleEnabled()
        end
    end)

    button:SetShown(not db.profile.minimap.hide)
    self.minimapButton = button
end

function addon:UpdateMinimapButton()
    if self.minimapButton then
        self.minimapButton:SetShown(not db.profile.minimap.hide)
    end
end

function addon:OnInitialize()
    db = LibStub("AceDB-3.0"):New("BearsGreeterDB", defaults, true)
    addon.db = db
    if not db.profile.randomGreetingList or #db.profile.randomGreetingList == 0 then
        db.profile.randomGreetingList = {}
        for _, tmpl in ipairs(addonTable.DefaultRandomGreetings) do
            db.profile.randomGreetingList[#db.profile.randomGreetingList + 1] = tmpl
        end
    end
    addonTable.RegisterOptions(addon)
end

function addon:OnEnable()
    clearExpired()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("CHAT_MSG_GUILD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    rosterSettleUntil = GetTime() + ROSTER_SETTLE_SECONDS
    if IsInGuild() then
        RequestGuildRoster()
    end
    self:CreateMinimapButton()
    self:Print(L["Loaded. Type /greeter to open options."])
end

function addon:OnDisable()
    -- nothing
end

function addon:PLAYER_ENTERING_WORLD()
    if not self.minimapButton then
        self:CreateMinimapButton()
    end
    if IsInGuild() then
        RequestGuildRoster()
    end
    -- Reset per-session online tracking so a reload does not re-greet everyone.
    wipe(knownOnline)
    initialRosterLoaded = false
    rosterSettleUntil = GetTime() + ROSTER_SETTLE_SECONDS
    clearExpired()
end

local function getOnlineGuildMembers()
    local result = {}
    local num = GetNumGuildMembers() or 0
    for i = 1, num do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and online then
            local short = Ambiguate(name, "short")
            if not short or short == "" then
                short = name:match("^[^%-]+") or name
            end
            result[short] = true
        end
    end
    return result
end

function addon:GUILD_ROSTER_UPDATE()
    if db.profile.trigger ~= "login" or not db.profile.enabled then
        return
    end
    if not IsInGuild() or (GetNumGuildMembers() or 0) == 0 then
        return
    end
    local current = getOnlineGuildMembers()
    if not initialRosterLoaded then
        for name in pairs(current) do
            knownOnline[name] = true
        end
        initialRosterLoaded = true
        local count = 0
        for _ in pairs(current) do
            count = count + 1
        end
        debugPrint("roster baseline loaded: %d online", count)
        return
    end
    local settling = GetTime() < rosterSettleUntil
    for name in pairs(current) do
        if not knownOnline[name] then
            knownOnline[name] = true
            if settling then
                debugPrint("%s online during login settle, not greeted", name)
            else
                debugPrint("%s came online, scheduling greeting", name)
                scheduleGreeting(name)
            end
        end
    end
    for name in pairs(knownOnline) do
        if not current[name] then
            knownOnline[name] = nil
            debugPrint("%s offline", name)
        end
    end
end

function addon:PLAYER_REGEN_ENABLED()
    -- Combat ended; send any greetings that were deferred.
    for name in pairs(pending) do
        if pending[name] == true then
            pending[name] = nil
            doSend(name)
        end
    end
    scheduleSendQueue(0)
end

function addon:CHAT_MSG_GUILD(_, _, sender)
    if db.profile.trigger ~= "guildchat" then
        return
    end
    if not db.profile.enabled then
        return
    end
    local name = Ambiguate(sender, "short")
    if not name or name == "" then
        name = sender:match("^[^%-]+") or sender
    end
    if name == UnitName("player") then
        return
    end
    scheduleGreeting(name)
end

-- Slash command handling.
local function printHelp()
    addon:Print(L["Commands:"])
    addon:Print("  /greeter            " .. L["Open options."])
    addon:Print("  /greeter test       " .. L["Send a test greeting."])
    addon:Print("  /greeter reset      " .. L["Clear today's greeted list."])
    addon:Print("  /greeter toggle     " .. L["Turn greetings on or off."])
    addon:Print("  /greeter debug      " .. L["Show or hide the debug log window."])
    addon:Print("  /greeter debug clear " .. L["Clear the debug log."])
    addon:Print("  /greeter help       " .. L["Show this help."])
end

function addon:SendTestGreeting()
    local name = UnitName("player") or L["Friend"]
    local msg = formatMessage(name)
    if InCombatLockdown() or UnitAffectingCombat("player") then
        addon:Print("Bears Greeter: cannot send while in combat.")
        return
    end
    local target = (db.profile.delivery == "WHISPER") and name or nil
    local chatType = db.profile.delivery == "WHISPER" and "WHISPER" or "GUILD"
    sendQueue[#sendQueue + 1] = {
        msg = msg,
        chatType = chatType,
        target = target,
        onSuccess = function()
            addon:Print(string.format(L["Test greeting sent to %s."], db.profile.delivery == "WHISPER" and name or L["guild chat"]))
            if db.profile.debug then
                addon:Print("[debug] " .. msg)
                debugPrint("test greeting sent: %s", msg)
            end
        end,
    }
    scheduleSendQueue(0)
end

function addon:ResetToday()
    wipe(db.profile.greeted)
    wipe(pending)
    addon:Print(L["Today's greeted list cleared."])
end

function addon:ToggleEnabled()
    db.profile.enabled = not db.profile.enabled
    if db.profile.enabled then
        addon:Print(L["Greetings enabled."])
    else
        addon:Print(L["Greetings disabled."])
    end
end

local function handleSlash(input)
    input = (input or ""):trim():lower()
    if input == "" then
        if addon.OpenOptionsDialog then
            addon.OpenOptionsDialog()
        end
    elseif input == "test" then
        addon:SendTestGreeting()
    elseif input == "reset" then
        addon:ResetToday()
    elseif input == "toggle" then
        addon:ToggleEnabled()
    elseif input == "debug" then
        toggleDebugWindow()
    elseif input == "debug clear" then
        clearDebugLog()
    elseif input == "help" then
        printHelp()
    else
        addon:Print("Unknown command. Type /greeter help.")
    end
end

addon:RegisterChatCommand("greeter", handleSlash)
addon:RegisterChatCommand("bg", handleSlash)
