local addonName, addonTable = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

function addonTable.RegisterOptions(addon)
    local deliveryValues = {
        GUILD = L["Guild chat"],
        WHISPER = L["Whisper"],
    }

    local options = {
        type = "group",
        name = L["Bears Greeter"],
        args = {
            about = {
                type = "description",
                order = 0,
                width = "full",
                fontSize = "medium",
                name = L["Greets each guild member the first time they speak in guild chat each day."],
            },
            enabled = {
                type = "toggle",
                order = 1,
                width = "full",
                name = L["Enable greetings"],
                desc = L["Turn automatic greetings on or off."],
                get = function()
                    return addon.db.profile.enabled
                end,
                set = function(_, value)
                    addon.db.profile.enabled = value
                end,
            },
            message = {
                type = "input",
                order = 2,
                width = "full",
                name = L["Greeting message"],
                desc = L["Use %s where the player's name should appear."],
                get = function()
                    return addon.db.profile.message
                end,
                set = function(_, value)
                    addon.db.profile.message = value
                end,
            },
            delivery = {
                type = "select",
                order = 3,
                width = "full",
                name = L["Delivery"],
                desc = L["Choose where the greeting is sent."],
                values = deliveryValues,
                get = function()
                    return addon.db.profile.delivery
                end,
                set = function(_, value)
                    addon.db.profile.delivery = value
                end,
            },
            debug = {
                type = "toggle",
                order = 4,
                width = "full",
                name = L["Debug messages"],
                desc = L["Print a chat message when a guild member is greeted."],
                get = function()
                    return addon.db.profile.debug
                end,
                set = function(_, value)
                    addon.db.profile.debug = value
                end,
            },
            actionsHeader = {
                type = "header",
                order = 10,
                name = L["Actions"],
            },
            test = {
                type = "execute",
                order = 11,
                width = "relative",
                relWidth = 0.48,
                name = L["Test"],
                desc = L["Send a test greeting."],
                func = function()
                    local name = UnitName("player") or L["Friend"]
                    addon:SendGreeting(name)
                    addon:Print(string.format(L["Test greeting sent to %s."], addon.db.profile.delivery == "WHISPER" and name or L["guild chat"]))
                end,
            },
            actionsSpacer = {
                type = "description",
                order = 12,
                width = "relative",
                relWidth = 0.02,
                name = "",
            },
            resetToday = {
                type = "execute",
                order = 13,
                width = "relative",
                relWidth = 0.48,
                name = L["Reset today"],
                desc = L["Clear today's greeted list so everyone can be greeted again."],
                func = function()
                    addon.db.profile.greeted = {}
                    addon.db.profile.greetedDate = date("%Y-%m-%d")
                    addon:Print(L["Today's greeted list cleared."])
                end,
            },
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, L["Bears Greeter"])

    addon.OpenOptionsDialog = function()
        LibStub("AceConfigDialog-3.0"):Open(addonName)
    end
end
