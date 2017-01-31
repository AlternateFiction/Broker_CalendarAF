local Broker_CalendarAF = _G.Broker_CalendarAF

local LibDBIcon = LibStub("LibDBIcon-1.0", true)

local DATE_SUB_DESC = [[
Substitutions: (ex. 1991-02-09)
yyyy = 1991
yy = 91
mmmm = February
mmm = Feb
mm = 02
m = 2
dddd = Saturday
ddd = Sat
dd = 09
d = 9
]]


-- create shallow copy of table (taken from AceDB-3.0.lua)
local function CopyTable(src, dest)
    if type(dest) ~= "table" then dest = {} end
    if type(src) == "table" then
        for k,v in pairs(src) do
            if type(v) == "table" then
                -- try to index the key first so that the metatable creates the defaults, if set, and use that table
                v = CopyTable(v, dest[k])
            end
            dest[k] = v
        end
    end
    return dest
end


local function CreateDb()
    return {
        profile = {
            daysLookAhead = 14,
            showMinimapButton = false,
            ldbText = "yyyy-mm-dd",
            ttDateFormat = "dddd, d mmm",
            trackedEvents = {
                HOLIDAY            = true,
                PLAYER             = true,
                GUILD_EVENT        = true,
                GUILD_ANNOUNCEMENT = true,
                RAID_LOCKOUT       = true,
                RAID_RESET         = true,
                SYSTEM             = true,
            },
            trackedEventColors = {
                HOLIDAY            = {1, 1, 1},
                PLAYER             = {1, 1, 1},
                GUILD_EVENT        = {0.25, 0.88, 0.25},
                GUILD_ANNOUNCEMENT = {0.25, 0.88, 0.25},
                RAID_LOCKOUT       = {1, 1, 1},
                RAID_RESET         = {1, 1, 1},
                SYSTEM             = {1, 1, 1},
            }
        }
    }
end


local function CreateConfig()
    return {
        type = "group",
        name = Broker_CalendarAF.name,
        order = 1,
        get = function(info)
            return Broker_CalendarAF.db[info[#info]]
        end,
        set = function(info, value)
            Broker_CalendarAF.db[info[#info]] = value
        end,
        args = {
            GroupGeneral = {
                type = "group",
                name = "",
                order = 1,
                inline = true,
                args = {
                    ldbText = {
                        type = "input",
                        name = "Broker text",
                        desc = DATE_SUB_DESC,
                        order = 1,
                        set = function(info, value)
                            Broker_CalendarAF.db[info[#info]] = value
                            Broker_CalendarAF:LDB_Update()
                        end,
                    },
                    ttDateFormat = {
                        type = "input",
                        name = "Broker tooltip date",
                        desc = DATE_SUB_DESC,
                        order = 2,
                    },
                    divider = {
                        type = "description",
                        name = "",
                        order = 3,
                    },
                    daysLookAhead = {
                        type = "range",
                        name = "Days monitored",
                        desc = "Show upcoming events occurring up to this many days in the future.",
                        order = 4,
                        min = 1,
                        max = 28,
                        step = 1,
                        set = function(info, value)
                            Broker_CalendarAF.db[info[#info]] = value
                            Broker_CalendarAF:UpdateCalendarEventData()
                        end,
                    },
                    showMinimapButton = {
                        type = "toggle",
                        name = "Show minimap button",
                        order = 5,
                        disabled = not LibDBIcon,
                        set = function(info, value)
                            Broker_CalendarAF.db[info[#info]] = value
                            Broker_CalendarAF:LDB_Update()
                        end,
                    },
                },
            },
            GroupTrackedEvents = {
                type = "group",
                name = "Monitored events",
                order = 2,
                inline = true,
                get = function(info)
                    return Broker_CalendarAF.db.trackedEvents[info[#info]]
                end,
                set = function(info, value)
                    Broker_CalendarAF.db.trackedEvents[info[#info]] = value
                end,
                args = {
                    HOLIDAY = {
                        type = "toggle",
                        name = "HOLIDAY",
                        desc = "World events (e.g. Winter Veil Festival, Darkmoon Faire, Dungeon Events)",
                        order = 1,
                    },
                    GUILD_EVENT = {
                        type = "toggle",
                        name = "GUILD_EVENT",
                        desc = "Guild created events (with signup)",
                        order = 2,
                    },
                    GUILD_ANNOUNCEMENT = {
                        type = "toggle",
                        name = "GUILD_ANNOUNCEMENT",
                        desc = "Guild created events (no signup)",
                        order = 3,
                    },
                    PLAYER = {
                        type = "toggle",
                        name = "PLAYER",
                        desc = "Player created events",
                        order = 4,
                    },
                    RAID_LOCKOUT = {
                        type = "toggle",
                        name = "RAID_LOCKOUT",
                        order = 5,
                    },
                    RAID_RESET = {
                        type = "toggle",
                        name = "RAID_RESET",
                        order = 6,
                    },
                    SYSTEM = {
                        type = "toggle",
                        name = "SYSTEM",
                        order = 7,
                    },
                },
            },
            GroupTrackedEventColors = {
                type = "group",
                name = "Monitored event colors",
                order = 3,
                inline = true,
                get = function(info)
                    local r, g, b = unpack(Broker_CalendarAF.db.trackedEventColors[info[#info]])
                    return r, g, b, 1
                end,
                set = function(info, r, g, b)
                    Broker_CalendarAF.db.trackedEventColors[info[#info]] = {r,g,b}
                end,
                args = {
                    HOLIDAY = {
                        type = "color",
                        name = "HOLIDAY",
                        order = 1,
                    },
                    GUILD_EVENT = {
                        type = "color",
                        name = "GUILD_EVENT",
                        order = 2,
                    },
                    GUILD_ANNOUNCEMENT = {
                        type = "color",
                        name = "GUILD_ANNOUNCEMENT",
                        order = 3,
                    },
                    PLAYER = {
                        type = "color",
                        name = "PLAYER",
                        order = 4,
                    },
                    RAID_LOCKOUT = {
                        type = "color",
                        name = "RAID_LOCKOUT",
                        order = 5,
                    },
                    RAID_RESET = {
                        type = "color",
                        name = "RAID_RESET",
                        order = 6,
                    },
                    SYSTEM = {
                        type = "color",
                        name = "SYSTEM",
                        order = 7,
                    },
                },
            },
        },
    }
end



function Broker_CalendarAF:InitConfig()
    self.dbStored = LibStub("AceDB-3.0"):New("BrokerCalendarAFDB", CreateDb(), "Default").profile
    self.db = CopyTable(self.dbStored)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(self.name, CreateConfig)
    local f = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.name)
    self:Hook(f, "okay", "SaveOptions", true)
    self:Hook(f, "cancel", "DiscardOptions", true)
    self:Hook(f, "default", "ResetOptions", true)
end

function Broker_CalendarAF:SaveOptions()
    -- if we use CopyTable we mess up the metatables
    for k,v in pairs(self.db) do
        self.dbStored[k] = v
    end
end

function Broker_CalendarAF:DiscardOptions()
    self.db = CopyTable(self.dbStored)
    self:LDB_Update()
    self:UpdateCalendarEventData()
end

function Broker_CalendarAF:ResetOptions()
    self.db = CreateDb().profile
    LibStub("AceConfigRegistry-3.0"):NotifyChange(self.name) -- refresh dialog
    self:LDB_Update()
    self:UpdateCalendarEventData()
end

function Broker_CalendarAF:OpenOptions()
    -- open interface options panel before calling OpenToCategory function to fix an issue
    -- where the options frame will be opened without any category being selected
    -- occurs when:
    --  * calling OpenToCategory with an options label name instead of a menu object reference
    --  * first time opening the options panel
    InterfaceOptionsFrame_Show()
    InterfaceOptionsFrame_OpenToCategory(self.name)
end
