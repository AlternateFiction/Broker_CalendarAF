
-- Setup Addon
_G.Broker_CalendarAF = LibStub("AceAddon-3.0"):NewAddon("Broker_CalendarAF", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
Broker_CalendarAF.AF = {}

-- Upvalues
local Broker_CalendarAF = Broker_CalendarAF
local CalendarGetDate, CalendarGetMonth, CalendarSetAbsMonth, CalendarGetNumDayEvents, CalendarGetDayEvent, CalendarGetDayEventSequenceInfo = CalendarGetDate, CalendarGetMonth, CalendarSetAbsMonth, CalendarGetNumDayEvents, CalendarGetDayEvent, CalendarGetDayEventSequenceInfo
local time, date, ipairs, format, table, floor, print, strsplit, tostring = time, date, ipairs, format, table, floor, print, strsplit, tostring
local LibStub = LibStub

-- Load Libraries
local LibQTip   = LibStub("LibQTip-1.0")
local LibDBIcon = LibStub("LibDBIcon-1.0", true)

-- Setup Variables
local COLOR_GRAY      = {0.50, 0.50, 0.50}
local COLOR_YELLOW    = {1.00, 0.82, 0.00}
local COLOR_ORANGERED = {1.00, 0.45, 0.17}
local PATTERN_POSTFIX_EVENT_START = " Begins$"
local PATTERN_POSTFIX_EVENT_STOP  = " Ends$"

local AF = Broker_CalendarAF.AF
AF.fancyName = "Broker CalendarAF"
AF.debug = false
AF.tooltip = nil
AF.calEvents = {}
AF.serverTimeOffset = 0

AF.ldb = LibStub("LibDataBroker-1.1"):NewDataObject(AF.fancyName, {
    type = "data source",
    label = AF.fancyName,
    text = AF.fancyName,
    icon = "Interface/AddOns/Broker_CalendarAF/icon.tga",
    OnEnter = function(...) Broker_CalendarAF:LDB_OnEnter(...) end,
    OnLeave = function(...) Broker_CalendarAF:LDB_OnLeave(...) end,
    OnClick = function(...) Broker_CalendarAF:LDB_OnClick(...) end,
})


-- local statusDescription = {
--     [CALENDAR_INVITESTATUS_INVITED]      = CALENDAR_STATUS_INVITED,
--     [CALENDAR_INVITESTATUS_ACCEPTED]     = CALENDAR_STATUS_ACCEPTED,
--     [CALENDAR_INVITESTATUS_DECLINED]     = CALENDAR_STATUS_DECLINED,
--     [CALENDAR_INVITESTATUS_CONFIRMED]    = CALENDAR_STATUS_CONFIRMED,
--     [CALENDAR_INVITESTATUS_OUT]          = CALENDAR_STATUS_OUT,
--     [CALENDAR_INVITESTATUS_STANDBY]      = CALENDAR_STATUS_STANDBY,
--     [CALENDAR_INVITESTATUS_SIGNEDUP]     = CALENDAR_STATUS_SIGNEDUP,
--     [CALENDAR_INVITESTATUS_NOT_SIGNEDUP] = CALENDAR_STATUS_NOT_SIGNEDUP,
--     [CALENDAR_INVITESTATUS_TENTATIVE]    = CALENDAR_STATUS_TENTATIVE
-- }



-------------------------------------------------------------------------------
--  Utility
-------------------------------------------------------------------------------

local function debugPrint(...)
    if AF.debug then
        print(...)
    end
end


local function color(text, c)
    return format("|cff%02x%02x%02x%s|r", c[1]*255, c[2]*255, c[3]*255, text)
end


-- yyyy 1999    | yy 99
-- mmmm January | mmm Jan | mm 01 | m 1
-- dddd Monday  | ddd Mon | dd 01 | d 1
local function FormatDate(format, timestamp)
    if not format or format == "" then return "" end
    local format, srvTimestamp = format, (timestamp or time()) + AF.serverTimeOffset
    local replacements = {
        {"yyyy", "%%Y"}, {"yy", "%%y"},
        {"mmmm", "%%B"}, {"mmm", "%%b"}, {"mm", "%%m"}, {"([^%%])m", "%1%%mm"}, {"^m", "%%mm"},
        {"dddd", "%%A"}, {"ddd", "%%a"}, {"dd", "%%d"}, {"([^%%])d", "%1%%dd"}, {"^d", "%%dd"}
    }
    for _, v in ipairs(replacements) do
        format = format:gsub(v[1], v[2])
    end
    return date(format, srvTimestamp):gsub("0(%d)[dm]", "%1"):gsub("([1-3]%d)[dm]", "%1")
end


local function FormatDuration(seconds)
    local m = floor(seconds / 60) % 60
    local h = floor(seconds / 3600) % 24
    local d = floor(seconds / 86400)
    if d > 0 then
        return format("%dd %s", d, color(format("%02dh", h), COLOR_GRAY))
    elseif h > 0 then
        return color(format("%dh %02dm", h, m), COLOR_ORANGERED)
    else
        return color(format("%dm", m), COLOR_ORANGERED)
    end
end


local function GetServerTimeOffset()
    local hour, min = GetGameTime()
    local _, month, day, year = CalendarGetDate()
    local srvTime = time({year=year, month=month, day=day, hour=hour, min=min})
    local locTime = time()
    return srvTime - locTime
end



-------------------------------------------------------------------------------
--  Calendar
-------------------------------------------------------------------------------

function Broker_CalendarAF:UpdateCalendarEventData()

    -- certain function calls in ScanCalendar trigger CALENDAR_* events, to avoid infinite recursion we
    -- ignore any further calls until the function has returned
    if AF.ignoreEventUpdates then return end
    AF.ignoreEventUpdates = true

    -- don't hard switch calendar month when calendar is open
    -- hard switching gives us a longer period we can scan for new events outside of current month
    if CalendarFrame and CalendarFrame:IsShown() then
        -- don't override old events
        if #AF.calEvents == 0 then
            self:ScanCalendar(self.db.daysLookAhead, false)
        end
    else
        self:ScanCalendar(self.db.daysLookAhead, true)
    end

    AF.ignoreEventUpdates = false
end


function Broker_CalendarAF:ScanCalendar(daysToScan, allowCalendarSwitch)
        
    local monthOffset = 0
    local _, month, today, year = CalendarGetDate()
    local _, _, daysInMonth = CalendarGetAbsMonth(month, year)

    table.wipe(AF.calEvents)

    if allowCalendarSwitch then
        CalendarSetAbsMonth(month, year)
    end
    
    debugPrint("Scan for", daysToScan, "days. Full scan:", allowCalendarSwitch)

    -- month/year jump
    for day = today, today + daysToScan do
        if day > daysInMonth then
            day = day - daysInMonth
            if day == 1 then
                if allowCalendarSwitch then
                    CalendarSetMonth(1)

                    month = month + 1
                    if month > 12 then
                        month = 1
                        year = year + 1
                    end
                else
                    monthOffset = 1
                end
            end
        end
        debugPrint("date:", day.."/"..(month+monthOffset))

        for eventIndex = 1, CalendarGetNumDayEvents(monthOffset, day) do
            local title, hour, minute, calendarType, sequenceType, _, _, modStatus, inviteStatus = CalendarGetDayEvent(monthOffset, day, eventIndex)

            if self.db.trackedEvents[calendarType] then
                debugPrint("--", calendarType, sequenceType, title)

                if sequenceType == "START" or (sequenceType == "ONGOING" and day == today) or sequenceType == "" then
                    local startDay, startMonth, startYear = day, month + monthOffset, year
                    local stopDay,  stopMonth,  stopYear  = day, month + monthOffset, year
                    local sequenceIndex, numSequenceDays = CalendarGetDayEventSequenceInfo(monthOffset, day, eventIndex)

                    -- estimate start time
                    if sequenceType == "ONGOING" then
                        startDay = day - sequenceIndex
                        if startDay < 1 then
                            if month == 1 then
                                startYear = year - 1
                                startMonth = 12
                            else
                                startMonth = month - monthOffset - 1
                            end
                            startDay = select(3, CalendarGetMonth(monthOffset-1)) + startDay
                        end
                    end

                    -- estimate stop time
                    stopDay = day + (numSequenceDays - sequenceIndex)
                    if stopDay > daysInMonth then
                        if month == 12 then
                            stopYear = year + 1
                            stopMonth = 1
                        else
                            stopMonth = month + monthOffset + 1
                        end
                        stopDay = stopDay - daysInMonth
                    end

                    AF.calEvents[#AF.calEvents+1] = {
                        start = time({year=startYear, month=startMonth, day=startDay, hour=hour, minute=minute}),
                        stop = time({year=stopYear, month=stopMonth, day=stopDay, hour=hour, minute=minute}),
                        title = title:gsub(PATTERN_POSTFIX_EVENT_START, ""),
                        type = calendarType
                    }

                    debugPrint("---- add:", format("%d-%02d-%02d %02d:%02d",startYear,startMonth,startDay,hour,minute), "=>", format("%d-%02d-%02d %02d:%02d",stopYear,stopMonth,stopDay,hour,minute))

                
                elseif sequenceType == "END" then
                    for _, event in ipairs(AF.calEvents) do
                        if event.title == title:gsub(PATTERN_POSTFIX_EVENT_STOP, "") then
                            if (month + monthOffset) > 12 then
                                event.stop = time({year=year+1, month=1, day=day, hour=hour, minute=minute})
                            else
                                event.stop = time({year=year, month=month+monthOffset, day=day, hour=hour, minute=minute})
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    -- switch back
    if allowCalendarSwitch then
        CalendarSetAbsMonth(month, year)
    end

    debugPrint("-------------------------------")
end



-------------------------------------------------------------------------------
--  Data broker
-------------------------------------------------------------------------------

function Broker_CalendarAF:LDB_Update()
    AF.ldb.text = FormatDate(self.db.ldbText)

    if LibDBIcon then
        if self.db.showMinimapButton then
            LibDBIcon:Show(AF.fancyName)
        else
            LibDBIcon:Hide(AF.fancyName)
        end
    end
end


function Broker_CalendarAF:LDB_UpdateTooltip()

    AF.tooltip:AddHeader(color("CalendarAF", COLOR_YELLOW), "", color(FormatDate(self.db.ttDateFormat), COLOR_YELLOW), "")
    AF.tooltip:AddLine(" ")

    if #AF.calEvents == 0 then
        AF.tooltip:AddLine("No upcoming events")
    else
        local now = time() + AF.serverTimeOffset

        AF.tooltip:AddLine(color("Ongoing events:", COLOR_YELLOW), "", color("Ends in", COLOR_YELLOW))

        -- list ongoing events, ordered by end time
        local sortedEvents = {}
        for _, event in ipairs(AF.calEvents) do
            if event.start and event.stop and event.start < now and event.stop > now then
                table.insert(sortedEvents, event)
            end
        end
        if #sortedEvents > 1 then
            table.sort(sortedEvents, function(a, b) return a.stop < b.stop end)
        end
        for _, event in ipairs(sortedEvents) do
            AF.tooltip:AddLine(color(event.title, self.db.trackedEventColors[event.type]), "", FormatDuration(event.stop - now))
        end
        table.wipe(sortedEvents)


        AF.tooltip:AddLine(" ")
        AF.tooltip:AddLine(color("Upcoming events:", COLOR_YELLOW), "", color("Starts in", COLOR_YELLOW))

        -- list upcoming events, (already) ordered by start time
        for _, event in ipairs(AF.calEvents) do
            if event.start and event.start > now then
                AF.tooltip:AddLine(color(event.title, self.db.trackedEventColors[event.type]), "", FormatDuration(event.start - now))
            end
        end
    end
end


function Broker_CalendarAF:LDB_OnEnter(thisBroker)
    if #AF.calEvents == 0 then
        self:UpdateCalendarEventData()
    end

    AF.tooltip = LibQTip:Acquire("BrokerCalendarTooltip", 4, "LEFT", "RIGHT", "RIGHT")

    self:LDB_UpdateTooltip()

    AF.tooltip:SmartAnchorTo(thisBroker)
    AF.tooltip:Show()
end


function Broker_CalendarAF:LDB_OnLeave(thisBroker)
    LibQTip:Release(AF.tooltip)
    AF.tooltip = nil
end


function Broker_CalendarAF:LDB_OnClick(thisBroker, button)
    if not button or button == "LeftButton" then
        GameTimeFrame_OnClick(GameTimeFrame)

    elseif button == "RightButton" then
        self:OpenOptions()
    end
end



-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------

function Broker_CalendarAF:PLAYER_ENTERING_WORLD()

    -- OnEnable should run after all ADDON_LOADED events
    if IsAddOnLoaded("Blizzard_Calendar") or UIParentLoadAddOn("Blizzard_Calendar") then
        self:UpdateCalendarEventData()
    end

    -- update event data after calendar UI is closed
    -- in case there were any changes made to events while calendar UI was open
    if not self:IsHooked("HideUIPanel") then
        self:SecureHook(nil, "HideUIPanel", function(frame)
            if frame and frame:GetName() == "CalendarFrame" then
                Broker_CalendarAF:UpdateCalendarEventData()
            end
        end)
    end

    -- get (imprecise) offset, in seconds, between server time and local time
    AF.serverTimeOffset = GetServerTimeOffset()

    -- sync server time offset precision to +0-1s instead of +0-60s
    AF.offsetTimer = self:ScheduleRepeatingTimer(function()
        local _, min = GetGameTime()

        if not AF.offsetSyncMin then
            AF.offsetSyncMin = min

        elseif min ~= AF.offsetSyncMin then
            AF.serverTimeOffset = GetServerTimeOffset()
            Broker_CalendarAF:CancelTimer(AF.offsetTimer)
            AF.offsetTimer = nil
            AF.offsetSyncMin = nil
        end
    end, 1)

    -- update broker label when server date changes
    AF.currentWeekDay = CalendarGetDate()
    self:ScheduleRepeatingTimer(function()
        local weekDay, month, day, year = CalendarGetDate()
        if weekDay ~= AF.currentWeekDay then
            local hour, min = GetGameTime()
            local now = time()
            debugPrint("Date changed:")
            debugPrint(
                "local: " .. date("%Y-%m-%d %H:%M:%S", now),
                "server: " .. date("%Y-%m-%d %H:%M:%S", now + AF.serverTimeOffset),
                "actual: " .. format("%d-%02d-%02d %02d:%02d:__", year, month, day, hour, min)
            )
            Broker_CalendarAF:LDB_Update()
            AF.currentWeekDay = weekDay
        end
    end, 60)

    self:LDB_Update()
end


function Broker_CalendarAF:OnInitialize()
    self:InitConfig()

    if LibDBIcon then
        LibDBIcon:Register(AF.fancyName, AF.ldb, {hide=not self.db.showMinimapButton})
    end

    self:RegisterEvent("CALENDAR_NEW_EVENT",          "UpdateCalendarEventData")
    self:RegisterEvent("CALENDAR_UPDATE_EVENT",       "UpdateCalendarEventData")
    self:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST",  "UpdateCalendarEventData")
    self:RegisterEvent("CALENDAR_UPDATE_INVITE_LIST", "UpdateCalendarEventData")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end



-------------------------------------------------------------------------------
--  Command line
-------------------------------------------------------------------------------

local function SlashHandler(argString, ...)
    local addonName = color(Broker_CalendarAF.name, COLOR_YELLOW) .. ":"

    local function PrintUsage()
        local slashCmd = color(SLASH_CALENDARAF1, COLOR_GRAY)
        print(addonName)
        print("   " .. slashCmd .. " config")
    end

    local args = {}
    if argString ~= "" then
        for i, arg in ipairs({strsplit(" ", argString)}) do
            args[i] = arg:lower()
        end
    end

    if #args > 0 then
        if args[1] == "debug" then
            if args[2] then
                if args[2] == "true" or args[2] == "1" then
                    AF.debug = true
                elseif args[2] == "false" or args[2] == "0" then
                    AF.debug = false
                else
                    return
                end
            else
                AF.debug = not AF.debug
            end
            print(addonName .. " debug = " .. tostring(AF.debug))

        elseif args[1] == "config" then
            Broker_CalendarAF:OpenOptions()
        end
    else
        PrintUsage()
    end
end
SlashCmdList["CALENDARAF"] = SlashHandler
SLASH_CALENDARAF1, SLASH_CALENDARAF2 = "/calendaraf", "/calaf"
