local addonName, addonTable = ...

local AceAddon = LibStub("AceAddon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local addon = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
addonTable.addon = addon

local DEFAULT_MESSAGE = L["Welcome back, %s!"]

local defaults = {
    profile = {
        enabled = true,
        message = DEFAULT_MESSAGE,
        -- "GUILD" or "WHISPER"
        delivery = "GUILD",
        -- Roster is reset when the calendar day changes.
        greetedDate = "",
        greeted = {},
        debug = false,
    },
}

local function TodayKey()
    return date("%Y-%m-%d")
end

local function ShortName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    if Ambiguate then
        local short = Ambiguate(name, "short")
        if short and short ~= "" then
            return short
        end
    end

    return name:match("^([^%-]+)") or name
end

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BearsGreeterDB", defaults, true)
    self:EnsureToday()
    addonTable.RegisterOptions(self)

    self:RegisterChatCommand("greeter", "HandleSlashCommand")
    self:RegisterChatCommand("bgreet", "HandleSlashCommand")

    self:Print(L["Loaded. Type /greeter to open options."])
end

function addon:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    -- Add more CHAT_MSG_* events here if the greeting should react to them.
    self:RegisterEvent("CHAT_MSG_GUILD", "OnGuildChat")
end

function addon:OnPlayerEnteringWorld()
    self:EnsureToday()
end

function addon:EnsureToday()
    local profile = self.db and self.db.profile
    if not profile then
        return
    end

    local today = TodayKey()
    if profile.greetedDate ~= today then
        profile.greetedDate = today
        profile.greeted = {}
    end

    profile.greeted = profile.greeted or {}
end

function addon:IsGreeted(name)
    local key = name and name:lower()
    return key and self.db.profile.greeted[key] == true or false
end

function addon:MarkGreeted(name)
    local key = name and name:lower()
    if key then
        self.db.profile.greeted[key] = true
    end
end

function addon:BuildGreeting(name)
    local template = self.db.profile.message or DEFAULT_MESSAGE
    if template == "" then
        return nil
    end

    local ok, text = pcall(string.format, template, name)
    if not ok then
        -- A malformed format string should still be usable as plain text.
        text = template
    end

    return text
end

function addon:SendGreeting(name)
    local text = self:BuildGreeting(name)
    if not text or text == "" then
        return false
    end

    if self.db.profile.delivery == "WHISPER" then
        SendChatMessage(text, "WHISPER", nil, name)
    else
        SendChatMessage(text, "GUILD")
    end

    return true
end

function addon:OnGuildChat(_, _, author)
    if not self.db.profile.enabled then
        return
    end

    local name = ShortName(author)
    if not name or name == UnitName("player") then
        return
    end

    self:EnsureToday()
    if self:IsGreeted(name) then
        return
    end

    -- Mark first so a rapid follow-up message cannot queue a second greeting.
    self:MarkGreeted(name)
    self:SendGreeting(name)

    if self.db.profile.debug then
        self:Print(string.format(L["Greeted %s."], name))
    end
end

function addon:PrintHelp()
    self:Print(L["Commands:"])
    self:Print("  /greeter - " .. L["Open options."])
    self:Print("  /greeter test - " .. L["Send a test greeting."])
    self:Print("  /greeter reset - " .. L["Clear today's greeted list."])
    self:Print("  /greeter toggle - " .. L["Turn greetings on or off."])
    self:Print("  /greeter help - " .. L["Show this help."])
end

function addon:HandleSlashCommand(input)
    local command = strtrim(input or ""):lower()

    if command == "test" then
        local name = UnitName("player") or L["Friend"]
        self:SendGreeting(name)
        self:Print(string.format(L["Test greeting sent to %s."], self.db.profile.delivery == "WHISPER" and name or L["guild chat"]))
    elseif command == "reset" then
        self.db.profile.greeted = {}
        self.db.profile.greetedDate = TodayKey()
        self:Print(L["Today's greeted list cleared."])
    elseif command == "toggle" then
        self.db.profile.enabled = not self.db.profile.enabled
        self:Print(self.db.profile.enabled and L["Greetings enabled."] or L["Greetings disabled."])
    elseif command == "help" then
        self:PrintHelp()
    elseif self.OpenOptionsDialog then
        self.OpenOptionsDialog()
    else
        self:PrintHelp()
    end
end
