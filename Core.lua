local _, ME = ...
ME.styles = {
    rival = { label = "Rival", r = 1, g = 0.72, b = 0.2, icon = "Interface\\Icons\\INV_Sword_04" },
    enemy = { label = "Mortal Enemy", r = 1, g = 0.22, b = 0.22, icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" },
}
function ME.Print(message) print("|cffdf5656Mortal Enemy:|r " .. message) end
function ME.IsSecret(value) return issecretvalue and issecretvalue(value) or false end
-- Never compare, stringify or index restricted values, including in diagnostics.
function ME.Read(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or ME.IsSecret(value) then return nil end
    return value
end
function ME.Trim(value) return (value or ""):match("^%s*(.-)%s*$") end
function ME.Note(value)
    local text = ME.Trim(value)
    if #text <= 240 then return text end
    -- Keep a truncated UTF-8 note from ending halfway through a character.
    local boundary = 241
    while boundary > 1 do
        local byte = text:byte(boundary)
        if byte < 128 or byte >= 192 then break end
        boundary = boundary - 1
    end
    return text:sub(1, boundary - 1)
end
function ME.Key(name)
    if type(name) ~= "string" or name:find("[%c%-]") then return nil end
    name = ME.Trim(name):gsub("%s+", " ")
    if name == "" then return nil end
    return string.lower(name)
end
function ME.InitDB()
    -- Development reset: discard the former account-wide data entirely.
    MortalEnemyDB = nil
    if type(MortalEnemyCharDB) ~= "table" then MortalEnemyCharDB = {} end
    ME.db = MortalEnemyCharDB
    ME.db.version = 3
    if type(ME.db.entries) ~= "table" then ME.db.entries = {} end
    if type(ME.db.settings) ~= "table" then ME.db.settings = {} end
    for _, key in ipairs({ "alerts", "sound", "showMinimap" }) do
        if ME.db.settings[key] == nil then ME.db.settings[key] = true end
    end
    local angle = ME.db.settings.minimapAngle
    if type(angle) ~= "number" or angle ~= angle or angle == math.huge or angle == -math.huge then
        angle = 225
    end
    ME.db.settings.minimapAngle = angle % 360
    if type(ME.db.settings.display) ~= "table" then ME.db.settings.display = {} end
    for status in pairs(ME.styles) do
        local options = ME.db.settings.display[status]
        if type(options) ~= "table" then options = {}; ME.db.settings.display[status] = options end
        for _, key in ipairs({ "badge", "tooltip", "tooltipNote" }) do
            if type(options[key]) ~= "boolean" then
                options[key] = key ~= "badge" or ME.db.settings.badges ~= false
            end
        end
        options.badgeText = nil
        options.glow = nil
    end
    ME.db.settings.badges = nil
    for key, entry in pairs(ME.db.entries) do
        if type(entry) ~= "table" or not ME.styles[entry.status]
            or ME.Key(entry.name) ~= key then
            ME.db.entries[key] = nil
        else
            entry.realm = nil
            if type(entry.note) ~= "string" then entry.note = "" end
            if type(entry.guid) ~= "string" then entry.guid = nil end
            if type(entry.lastSeen) ~= "number" then entry.lastSeen = nil end
            if type(entry.lastZone) ~= "string" then entry.lastZone = nil end
        end
    end
end
function ME.Identity(unit)
    if ME.Read(UnitIsPlayer, unit) ~= true then return nil, "The target is not a readable player unit." end
    -- Forever's tuple APIs can return first name + SURNAME, not name + realm.
    -- GetUnitName formats the complete character name for this client.
    local name = ME.Read(GetUnitName, unit, true)
    if type(name) ~= "string" or name == "" then
        local ok, first, surname = pcall(UnitName, unit)
        if not ok or ME.IsSecret(first) or ME.IsSecret(surname) then
            return nil, "The player's name is restricted. Try outside combat."
        end
        if type(first) ~= "string" or first == "" then return nil, "The player's name is not available yet." end
        name = first
        if not first:find("%s") and type(surname) == "string" and surname ~= "" then
            name = first .. " " .. surname
        end
    end
    if name == UNKNOWNOBJECT or name == UNKNOWN then return nil, "The player's name is not available yet." end
    -- Never infer a realm from a surname. Ask the native same-server API.
    local sameServer = ME.Read(UnitIsSameServer, name)
    if sameServer == false then return nil, "That player is not on your realm." end
    if sameServer ~= true then return nil, "The game could not confirm the player's realm. Run /mortal diagnose." end
    local key = ME.Key(name)
    if not key or not name:find("%s") then return nil, "The player's full first and last name is not available yet." end
    local guid = ME.Read(UnitGUID, unit)
    if type(guid) ~= "string" then guid = nil end
    return { key = key, name = name, guid = guid }
end
function ME.Find(identity)
    if not identity then return nil end
    local entry = ME.db.entries[identity.key]
    if entry and (not entry.guid or not identity.guid or entry.guid == identity.guid) then
        return entry, identity.key
    end
    if identity.guid then
        for key, candidate in pairs(ME.db.entries) do
            if candidate.guid == identity.guid then return candidate, key end
        end
    end
end
function ME.Changed()
    if ME.RefreshWorld then ME.RefreshWorld() end
    if ME.RefreshWindow then ME.RefreshWindow() end
    if ME.RefreshSettings then ME.RefreshSettings() end
    if ME.RefreshTooltip then ME.RefreshTooltip() end
    if ME.UpdateMinimap then ME.UpdateMinimap() end
end
function ME.Save(identity, status, note)
    if not ME.styles[status] or not identity or not identity.key then return end
    local entry, oldKey = ME.Find(identity)
    entry = entry or { added = time() }
    if oldKey and oldKey ~= identity.key then ME.db.entries[oldKey] = nil end
    entry.name, entry.status = identity.name, status
    entry.guid = identity.guid or entry.guid
    if note ~= nil then entry.note = ME.Note(note) end
    ME.db.entries[identity.key] = entry
    ME.Print(entry.name .. " is now your " .. ME.styles[status].label .. ".")
    ME.Changed()
    return identity.key
end
function ME.AddNamedPlayer(name, status, note)
    if not ME.styles[status] then return nil, "Choose Rival or Mortal Enemy." end
    name = ME.Trim(name):gsub("%s+", " ")
    local first, last = name:match("^(%S+) (%S+)$")
    if not first or not last or not ME.Key(name) then return nil, "Enter a first and last name, without a realm suffix." end
    local ownName = ME.Read(GetUnitName, "player", true)
    if ownName and ME.Key(ownName) == ME.Key(name) then return nil, "Choose another player first." end
    return ME.Save({ key = ME.Key(name), name = name }, status, note)
end
function ME.MarkTarget(status, note)
    if ME.Read(UnitIsUnit, "target", "player") == true then ME.Print("Choose another player first."); return end
    local identity, reason = ME.Identity("target")
    if not identity or not identity.key then
        ME.Print(reason or "Target a player on your realm first.")
        return
    end
    return ME.Save(identity, status, note)
end
function ME.Remove(key)
    local entry = ME.db.entries[key]
    if not entry then return end
    ME.db.entries[key] = nil
    ME.Print("Removed " .. entry.name .. ".")
    ME.Changed()
end
function ME.Entries()
    local entries = {}
    for key, entry in pairs(ME.db.entries) do entries[#entries + 1] = { key = key, entry = entry } end
    table.sort(entries, function(a, b)
        if a.entry.status ~= b.entry.status then return a.entry.status == "enemy" end
        return a.key < b.key
    end)
    return entries
end
function ME.Diagnose()
    local version, build, _, interface = GetBuildInfo()
    ME.Print("Client " .. version .. " / build " .. build .. " / interface " .. interface)
    local units = { "target", "mouseover" }
    for unit in pairs(ME.units) do units[#units + 1] = unit end
    for i = 1, math.min(#units, 14) do
        local unit = units[i]
        local function state(func, argument)
            local ok, value = pcall(func, argument or unit)
            if not ok then return "unavailable" end
            if ME.IsSecret(value) then return "restricted" end
            if type(value) == "boolean" then return tostring(value) end
            return value == nil and "missing" or "readable"
        end
        local fullName = ME.Read(GetUnitName, unit, true)
        local sameRealm = type(fullName) == "string" and state(UnitIsSameServer, fullName) or "unknown"
        local identity, reason = ME.Identity(unit)
        ME.Print(unit .. ": player=" .. state(UnitIsPlayer) .. ", full name=" .. state(GetUnitName)
            .. ", name parts=" .. state(UnitName) .. ", same realm=" .. sameRealm .. ", GUID=" .. state(UnitGUID)
            .. (identity and (", matched identity=" .. identity.name) or (", " .. (reason or "unavailable"))))
    end
    if #units > 14 then ME.Print("Additional nameplates omitted.") end
end
