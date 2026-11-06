local addonName, addonTable = ...

local AceAddon = LibStub("AceAddon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local addon = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local db

local defaults = {
    profile = {
        enabled = true,
        trigger = "login", -- "login" or "guildchat"
        delay = 15,
        cacheHours = 24,
        message = "Welcome back <name>!",
        delivery = "GUILD",
        debug = false,
        greeted = {},
        timeOfDay = false,
        minimap = { hide = false, minimapButtonAngle = 225 },
    },
}

-- Per-session state.
local knownOnline = {}
local initialRosterLoaded = false
local rosterSettleUntil = 0
local pending = {}

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
    if hour >= 5 and hour < 12 then
        return L["Good Morning"]
    elseif hour >= 12 and hour < 18 then
        return L["Good Afternoon"]
    else
        return L["Good Evening"]
    end
end

local function formatMessage(name)
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
    local msg = formatMessage(name)
    if db.profile.delivery == "WHISPER" then
        SendChatMessage(msg, "WHISPER", nil, name)
    else
        SendChatMessage(msg, "GUILD")
    end
    if db.profile.debug then
        addon:Print(string.format(L["Greeted %s."], name))
    end
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

function addon:OnInitialize()
    db = LibStub("AceDB-3.0"):New("BearsGreeterDB", defaults, true)
    addon.db = db
    addonTable.RegisterOptions(addon)
end

function addon:OnEnable()
    clearExpired()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("CHAT_MSG_GUILD")
    -- Request an initial roster so login detection has a baseline.
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
    clearExpired()
end

function addon:GUILD_ROSTER_UPDATE()
    if db.profile.trigger ~= "login" then
        return
    end
    if not IsInGuild() then
        return
    end
    if (GetNumGuildMembers() or 0) == 0 then
        return
    end
    local current = getOnlineGuildMembers()
    if not initialRosterLoaded then
        for name in pairs(current) do
            knownOnline[name] = true
        end
        initialRosterLoaded = true
        rosterSettleUntil = GetTime() + ROSTER_SETTLE_SECONDS
        return
    end
    local settling = GetTime() < rosterSettleUntil
    for name in pairs(current) do
        if not knownOnline[name] then
            knownOnline[name] = true
            if not settling then
                scheduleGreeting(name)
            end
        end
    end
    for name in pairs(knownOnline) do
        if not current[name] then
            knownOnline[name] = nil
        end
    end
end

function addon:CHAT_MSG_GUILD(message, sender)
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
    addon:Print("  /greeter help       " .. L["Show this help."])
end

function addon:SendTestGreeting()
    local name = UnitName("player") or L["Friend"]
    local msg = formatMessage(name)
    if db.profile.delivery == "WHISPER" then
        SendChatMessage(msg, "WHISPER", nil, name)
    else
        SendChatMessage(msg, "GUILD")
    end
    addon:Print(string.format(L["Test greeting sent to %s."], db.profile.delivery == "WHISPER" and name or L["guild chat"]))
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
    elseif input == "help" then
        printHelp()
    else
        addon:Print("Unknown command. Type /greeter help.")
    end
end

addon:RegisterChatCommand("greeter", handleSlash)
addon:RegisterChatCommand("bg", handleSlash)
