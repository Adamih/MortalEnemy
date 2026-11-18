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
    if type(name) ~= "string" or name == "" or name:find("[%s%-]") then return nil end
    return string.lower(name)
end
local function NormalizeRealm(realm)
    if type(realm) ~= "string" then return nil end
    return string.lower(realm:gsub("%s", ""))
end
function ME.InitDB()
    -- Development reset: discard the former account-wide data entirely.
    MortalEnemyDB = nil
    if type(MortalEnemyCharDB) ~= "table" then MortalEnemyCharDB = {} end
    ME.db = MortalEnemyCharDB
    ME.db.version = 3
    if type(ME.db.entries) ~= "table" then ME.db.entries = {} end
    if type(ME.db.settings) ~= "table" then ME.db.settings = {} end
    for _, key in ipairs({ "alerts", "sound" }) do
        if ME.db.settings[key] == nil then ME.db.settings[key] = true end
    end
    if type(ME.db.settings.display) ~= "table" then ME.db.settings.display = {} end
    for status in pairs(ME.styles) do
        local options = ME.db.settings.display[status]
        if type(options) ~= "table" then options = {}; ME.db.settings.display[status] = options end
        for _, key in ipairs({ "badge", "glow", "tooltip", "badgeText", "tooltipNote" }) do
            if type(options[key]) ~= "boolean" then
                options[key] = key ~= "badge" or ME.db.settings.badges ~= false
            end
        end
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
    if ME.Read(UnitIsPlayer, unit) ~= true then return nil end
    local ok, name, realm = pcall(UnitName, unit)
    if not ok or ME.IsSecret(realm) then return nil end
    local currentRealm = NormalizeRealm(ME.Read(GetNormalizedRealmName))
    if not currentRealm or currentRealm == "" then return nil end
    -- An empty realm from UnitName denotes the player's own realm.
    if realm ~= nil and realm ~= "" and NormalizeRealm(realm) ~= currentRealm then return nil end
    local guid = ME.Read(UnitGUID, unit)
    if type(guid) ~= "string" then guid = nil end
    if ME.IsSecret(name) then return guid and { guid = guid } or nil end
    local key = ME.Key(name)
    if not key then return nil end
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
    if ME.RefreshTooltip then ME.RefreshTooltip() end
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
function ME.MarkTarget(status, note)
    if ME.Read(UnitIsUnit, "target", "player") == true then ME.Print("Choose another player first."); return end
    local identity = ME.Identity("target")
    if not identity or not identity.key then
        ME.Print("Target a player on your realm with a readable identity. Try outside combat, or use /mortal add.")
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
        local function state(func)
            local ok, value = pcall(func, unit)
            if not ok then return "unavailable" end
            if ME.IsSecret(value) then return "restricted" end
            return value == nil and "missing" or "readable"
        end
        local identity = ME.Identity(unit)
        ME.Print(unit .. ": name=" .. state(UnitName) .. ", GUID=" .. state(UnitGUID)
            .. (identity and identity.key and (", player=" .. identity.name)
                or (identity and ", GUID-only identity" or ", no usable player identity")))
    end
    if #units > 14 then ME.Print("Additional nameplates omitted.") end
end
