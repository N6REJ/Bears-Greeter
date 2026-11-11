local addonName, addonTable = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

function addonTable.RegisterOptions(addon)
    local function db()
        return addon.db.profile
    end

    local selectedGreetingIndex = nil
    local newGreetingText = ""

    local triggerValues = {
        login = L["Login (on join)"],
        guildchat = L["Guild chat (first message)"],
    }

    local deliveryValues = {
        GUILD = L["Guild chat"],
        WHISPER = L["Whisper"],
    }

    local options = {
        type = "group",
        name = L["Bears Greeter"],
        args = {
            firstNameOnly = {
                type = "toggle",
                order = 0,
                width = "full",
                name = L["First name only"],
                desc = L["Greet with only the first name, for example Newmo instead of Newmo Odell."],
                get = function() return db().firstNameOnly end,
                set = function(_, value) db().firstNameOnly = value end,
            },
            randomGreetings = {
                type = "toggle",
                order = 1,
                width = "full",
                name = L["Random greetings"],
                desc = L["Pick a random greeting from a built-in list instead of the fixed message."],
                get = function() return db().randomGreetings end,
                set = function(_, value) db().randomGreetings = value end,
            },
            randomListHeader = {
                type = "header",
                order = 2,
                name = L["Random greeting list"],
            },
            randomListDesc = {
                type = "description",
                order = 3,
                width = "full",
                name = L["Greetings used when Random greetings is on. Use <name> for the member's name."],
            },
            randomListSelect = {
                type = "select",
                order = 4,
                width = "full",
                name = L["Remove selected"],
                desc = L["Select a greeting to remove."],
                values = function()
                    local vals = {}
                    local list = db().randomGreetingList or {}
                    for i, tmpl in ipairs(list) do
                        vals[i] = tmpl
                    end
                    return vals
                end,
                get = function() return selectedGreetingIndex end,
                set = function(_, value) selectedGreetingIndex = value end,
            },
            randomListRemove = {
                type = "execute",
                order = 5,
                width = "relative",
                relWidth = 0.48,
                name = L["Remove selected"],
                func = function()
                    if selectedGreetingIndex then
                        local list = db().randomGreetingList or {}
                        table.remove(list, selectedGreetingIndex)
                        db().randomGreetingList = list
                        selectedGreetingIndex = nil
                    end
                end,
            },
            randomListAddInput = {
                type = "input",
                order = 6,
                width = "full",
                name = L["New greeting"],
                desc = L["Type a greeting and click Add."],
                get = function() return newGreetingText end,
                set = function(_, value) newGreetingText = value or "" end,
            },
            randomListAdd = {
                type = "execute",
                order = 7,
                width = "relative",
                relWidth = 0.48,
                name = L["Add greeting"],
                func = function()
                    if newGreetingText and newGreetingText ~= "" then
                        local list = db().randomGreetingList or {}
                        list[#list + 1] = newGreetingText
                        db().randomGreetingList = list
                        newGreetingText = ""
                    end
                end,
            },
            about = {
                type = "description",
                order = 16,
                width = "full",
                fontSize = "medium",
                name = L["Greets each guild member the first time they are seen each day."],
            },
            enabled = {
                type = "toggle",
                order = 3,
                width = "full",
                name = L["Enable greetings"],
                desc = L["Turn automatic greetings on or off."],
                get = function() return db().enabled end,
                set = function(_, value) db().enabled = value end,
            },
            trigger = {
                type = "select",
                order = 4,
                width = "full",
                name = L["Trigger"],
                desc = L["When to greet a member: when they log in, or on their first guild chat message."],
                values = triggerValues,
                get = function() return db().trigger end,
                set = function(_, value) db().trigger = value end,
            },
            delay = {
                type = "range",
                order = 5,
                width = "full",
                name = L["Delay (seconds)"],
                desc = L["Seconds to wait after a member is seen before sending the greeting."],
                min = 0,
                max = 60,
                step = 1,
                get = function() return db().delay end,
                set = function(_, value) db().delay = value end,
            },
            cacheHours = {
                type = "range",
                order = 6,
                width = "full",
                name = L["Cache time (hours)"],
                desc = L["How long a member is remembered as greeted. 24 means until the calendar day changes."],
                min = 1,
                max = 168,
                step = 1,
                get = function() return db().cacheHours end,
                set = function(_, value) db().cacheHours = value end,
            },
            timeOfDay = {
                type = "toggle",
                order = 7,
                width = "full",
                name = L["Time of day greeting"],
                desc = L["Use a Good Morning/Afternoon/Evening greeting based on server time."],
                get = function() return db().timeOfDay end,
                set = function(_, value) db().timeOfDay = value end,
            },
            message = {
                type = "input",
                order = 8,
                width = "full",
                name = L["Greeting message"],
                desc = L["Use <name> where the player's name should appear."],
                get = function() return db().message end,
                set = function(_, value)
                    if value and value ~= "" then
                        db().message = value
                    end
                end,
            },
            delivery = {
                type = "select",
                order = 9,
                width = "full",
                name = L["Delivery"],
                desc = L["Choose where the greeting is sent."],
                values = deliveryValues,
                get = function() return db().delivery end,
                set = function(_, value) db().delivery = value end,
            },
            debug = {
                type = "toggle",
                order = 10,
                width = "full",
                name = L["Debug messages"],
                desc = L["Print a local message after each greeting."],
                get = function() return db().debug end,
                set = function(_, value) db().debug = value end,
            },
            minimap = {
                type = "toggle",
                order = 11,
                width = "full",
                name = L["Show minimap button"],
                desc = L["Show or hide the minimap button."],
                get = function() return not db().minimap.hide end,
                set = function(_, value)
                    db().minimap.hide = not value
                    addon:UpdateMinimapButton()
                end,
            },
            actionsHeader = {
                type = "header",
                order = 12,
                name = L["Actions"],
            },
            test = {
                type = "execute",
                order = 13,
                width = "relative",
                relWidth = 0.48,
                name = L["Test"],
                desc = L["Send a test greeting."],
                func = function()
                    addon:SendTestGreeting()
                end,
            },
            actionsSpacer = {
                type = "description",
                order = 14,
                width = "relative",
                relWidth = 0.02,
                name = "",
            },
            resetToday = {
                type = "execute",
                order = 15,
                width = "relative",
                relWidth = 0.48,
                name = L["Reset today"],
                desc = L["Clear today's greeted list so everyone can be greeted again."],
                func = function()
                    addon:ResetToday()
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
