local addonName, ME = ...
local frame = CreateFrame("Frame")
local ready, elapsedSinceScan = false, 0
local function Help()
    ME.Print("/mortal — open your book of rivals.")
    ME.Print("/mortal rival [note] or enemy [note] — mark your target.")
    ME.Print("/mortal note <text> — update your target's note; omit text to clear.")
    ME.Print("/mortal remove [First Last] — remove a named player or your target.")
    ME.Print("/mortal add rival|enemy First Last [note] — add manually.")
    ME.Print("/mortal badges|tooltip [rival|enemy] — toggle a display; /mortal alerts|sound.")
    ME.Print("/mortal preview — sample alert; /mortal diagnose — identity availability.")
end
local function Command(message)
    if not ready then return end
    local command, rest = ME.Trim(message):match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "" or command == "list" then ME.ToggleWindow()
    elseif command == "rival" or command == "enemy" then ME.MarkTarget(command, rest ~= "" and rest or nil)
    elseif command == "help" then Help()
    elseif command == "preview" then ME.Preview()
    elseif command == "diagnose" then ME.Diagnose()
    elseif command == "badges" or command == "tooltip" then
        if rest ~= "" and not ME.styles[rest] then ME.Print("Choose rival or enemy, or omit to toggle both."); return end
        local key = command == "badges" and "badge" or command
        local statuses = rest ~= "" and { rest } or { "rival", "enemy" }
        local enabled = false
        for _, status in ipairs(statuses) do
            if not ME.db.settings.display[status][key] then enabled = true end
        end
        for _, status in ipairs(statuses) do ME.db.settings.display[status][key] = enabled end
        ME.Print(command .. (rest ~= "" and (" (" .. ME.styles[rest].label .. ")") or "") .. ": " .. (enabled and "on" or "off"))
        ME.Changed()
    elseif command == "alerts" or command == "sound" then
        ME.db.settings[command] = not ME.db.settings[command]
        ME.Print(command .. ": " .. (ME.db.settings[command] and "on" or "off"))
        ME.Changed()
    elseif command == "note" then
        local entry = ME.Find(ME.Identity("target"))
        if not entry then ME.Print("Target a saved rival with a readable identity first."); return end
        entry.note = ME.Note(rest)
        ME.Print("Note saved.")
        ME.Changed()
    elseif command == "remove" then
        local key
        if rest ~= "" then
            key = ME.Key(rest)
        else
            local entry
            entry, key = ME.Find(ME.Identity("target"))
        end
        if key and ME.db.entries[key] then ME.Remove(key)
        else ME.Print("No match. Target a saved player or use /mortal remove First Last.") end
    elseif command == "add" then
        local status, name, note = rest:match('^(%S+)%s+"([^"]+)"%s*(.-)$')
        if not status then
            local first, last
            status, first, last, note = rest:match("^(%S+)%s+(%S+)%s+(%S+)%s*(.-)$")
            if first and last then name = first .. " " .. last end
        end
        if not ME.styles[status] or not ME.Key(name) or not name:find("%s") then
            ME.Print("Usage: /mortal add rival|enemy First Last [note]"); return
        end
        ME.Save({ key = ME.Key(name), name = name }, status, note)
    else Help() end
end
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, unit)
    if event == "ADDON_LOADED" then
        if unit ~= addonName then return end
        ME.InitDB()
        ready = true
        ME.InitTooltips()
        ME.InitMinimap()
        self:UnregisterEvent("ADDON_LOADED")
        SLASH_MORTALENEMY1 = "/mortal"
        SLASH_MORTALENEMY2 = "/mortalenemy"
        SlashCmdList.MORTALENEMY = Command
        for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_REGEN_ENABLED" }) do
            self:RegisterEvent(name)
        end
        ME.Print("Loaded. Click the skull on your minimap to open your book. /mortal help for commands.")
    elseif not ready then return
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if ME.IsSecret(unit) or type(unit) ~= "string" then return end
        ME.units[unit] = true
        ME.UpdatePlate(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if ME.IsSecret(unit) or type(unit) ~= "string" then return end
        ME.RemovePlate(unit)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        local entry, key = ME.Find(ME.Identity("mouseover"))
        if entry then ME.Observe(entry, key) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        for token in pairs(ME.units) do ME.RemovePlate(token) end
        ME.InitTooltips()
        ME.InitMinimap()
        ME.SeedNameplates()
        ME.RefreshWorld()
    else ME.RefreshWorld() end
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    if not ready then return end
    elapsedSinceScan = elapsedSinceScan + elapsed
    if elapsedSinceScan < 0.5 then return end
    elapsedSinceScan = 0
    if next(ME.db.entries) then ME.RefreshWorld() end
end)
