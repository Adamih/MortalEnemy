-- A standalone smoke client. It checks addon logic, not actual WoW rendering,
-- protected-frame behavior, or the runtime rules for enemy player identities.
local frames, messages, units, plates = {}, {}, {}, {}
local now, sounds = 0, 0
local secret = setmetatable({}, { __tostring = function() error("secret stringified") end })
function issecretvalue(value) return rawequal(value, secret) end
local function safe(value) assert(not issecretvalue(value), "secret passed into UI") end
local Methods = {}
local function object(kind, parent)
    local obj = setmetatable({ kind = kind, parent = parent, scripts = {}, shown = true, text = "" }, { __index = Methods })
    frames[#frames + 1] = obj
    return obj
end
function Methods:SetScript(name, fn) self.scripts[name] = fn end
function Methods:RegisterEvent(name) self.events = self.events or {}; self.events[name] = true end
function Methods:UnregisterEvent(name) self.events[name] = nil end
function Methods:SetText(text) safe(text); self.text = text end
function Methods:GetText() return self.text end
function Methods:Hide() self.shown = false end
function Methods:Show()
    local was = self.shown
    self.shown = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Methods:IsShown() return self.shown end
function Methods:SetShown(value) if value then self:Show() else self:Hide() end end
function Methods:SetParent(parent) self.parent = parent end
function Methods:IsForbidden() return self.forbidden or false end
function Methods:GetUnit() return self.unitToken end
function Methods:CreateTexture() return object("texture", self) end
function Methods:CreateFontString() return object("font", self) end
function Methods:SetTexture(value) safe(value); self.texture = value end
function Methods:SetChecked(value) self.checked = value end
function Methods:GetChecked() return self.checked end
function Methods:HasFocus() return self.focused or false end
function Methods:ClearFocus() self.focused = false end
function Methods:SetEnabled(value) self.enabled = value end
for _, name in ipairs({"SetSize", "SetPoint", "SetWidth", "SetJustifyH", "SetShadowOffset", "EnableMouse", "SetFrameStrata", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "ClearAllPoints", "SetClampedToScreen", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetAllPoints", "SetColorTexture", "SetHighlightTexture", "SetAutoFocus", "SetMaxLetters", "SetTextColor"}) do
    Methods[name] = function(...) end
end
function CreateFrame(kind, name, parent)
    local result = object(kind, parent)
    result.name = name
    if name then _G[name] = result end
    return result
end
UIParent = object("root")
UISpecialFrames, SlashCmdList = {}, {}
function print(message) messages[#messages + 1] = message end
function GetTime() return now end
function time() return 1795000000 + math.floor(now) end
function date(format, stamp) return os.date(format, stamp) end
function GetNormalizedRealmName() return "HomeRealm" end
function GetRealZoneText() return "Elwynn Forest" end
function GetBuildInfo() return "1.60.1", "70938", "", 16001 end
function UnitIsPlayer(unit) return units[unit] and units[unit].player end
function UnitName(unit) local u = units[unit]; if u then return u.name, u.realm end end
function UnitGUID(unit) return units[unit] and units[unit].guid end
function UnitIsUnit(a, b) return units[a] ~= nil and units[a] == units[b] end
function PlaySound() sounds = sounds + 1 end
C_NamePlate = {
    GetNamePlateForUnit = function(unit) return plates[unit] end,
    GetNamePlates = function() local result = {}; for _, plate in pairs(plates) do result[#result + 1] = plate end; return result end,
}
local ME = {}
for _, file in ipairs({"Core.lua", "Display.lua", "Window.lua", "MortalEnemy.lua"}) do assert(loadfile(file))("MortalEnemy", ME) end
local controller = frames[#frames]
local function event(name, unit) controller.scripts.OnEvent(controller, name, unit) end
local function command(text) SlashCmdList.MORTALENEMY(text) end
local function check(value, message) assert(value, message) end
local function player(name, realm, guid) return { player = true, name = name, realm = realm, guid = guid } end

event("ADDON_LOADED", "OtherAddon")
check(not MortalEnemyCharDB, "ignore other addons")
MortalEnemyDB = { entries = { old = { name = "Old", realm = "HomeRealm", status = "enemy" } } }
event("ADDON_LOADED", "MortalEnemy")
check(MortalEnemyDB == nil and next(ME.db.entries) == nil, "legacy shared data is discarded")
check(MortalEnemyCharDB.version == 2 and SlashCmdList.MORTALENEMY, "initialization")
local toc = assert(io.open("MortalEnemy.toc")):read("*a")
check(toc:find("## SavedVariablesPerCharacter: MortalEnemyCharDB", 1, true), "character-specific TOC persistence")
check(not toc:find("## SavedVariables:", 1, true), "no shared saved variables")
command("list")
check(MortalEnemyWindow:IsShown(), "empty book opens")
command("list")
command("rival")
check(next(ME.db.entries) == nil, "no target must not add")
units.player = player("Me", "HomeRealm", "Player-self")
units.target = units.player
command("enemy")
check(next(ME.db.entries) == nil, "self must not add")
units.target = { player = false, name = "Wolf", realm = "", guid = "Creature-1" }
command("enemy")
check(next(ME.db.entries) == nil, "NPC must not add")
units.target = player("Alice", "", "Player-1")
command("rival Helped me once")
local alice = ME.db.entries["alice"]
check(alice and alice.status == "rival" and alice.note == "Helped me once", "save target on current realm")
command("enemy")
check(alice.status == "enemy" and alice.note == "Helped me once", "change status preserves note")
command("note Killed me while fishing")
check(alice.note == "Killed me while fishing", "edit note")
command("note")
check(alice.note == "", "clear note")
local originalTarget = units.target
units.target = player("Alice", "OtherRealm", "Player-1")
command("rival")
check(ME.Identity("target") == nil and alice.status == "enemy", "off-realm target rejected even with matching GUID")
units.target = player("Alice", secret, "Player-1")
check(ME.Identity("target") == nil, "restricted realm cannot establish eligibility")
units.target = originalTarget
check(ME.Find({key = "alice", guid = "Player-other"}) == nil, "GUID conflict must not match")
check(ME.Find({key = "renamed", guid = "Player-1"}) == alice, "GUID matches renamed player")
units.nameplate1 = units.target
plates.nameplate1 = object("plate")
plates.nameplate1.unitToken = "nameplate1"
event("NAME_PLATE_UNIT_ADDED", "nameplate1")
local badge
for _, f in ipairs(frames) do if f.parent == plates.nameplate1 and f.icon then badge = f end end
check(badge and badge:IsShown(), "saved player's nameplate gets badge")
event("PLAYER_ENTERING_WORLD")
check(ME.units.nameplate1 and badge:IsShown(), "world transition recovers visible plates")
plates.nameplate1.forbidden = true
ME.UpdatePlate("nameplate1")
check(not badge:IsShown(), "forbidden nameplate is not decorated")
plates.nameplate1.forbidden = false
ME.UpdatePlate("nameplate1")

check(alice.lastSeen and alice.lastZone == "Elwynn Forest", "sighting history")
local soundCount = sounds
for i = 1, 300 do now = now + 0.5; controller.scripts.OnUpdate(controller, 0.5) end
check(sounds == soundCount, "continuous visibility does not repeat alert")
units.target = nil
event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
check(not badge:IsShown(), "removed nameplate hides badge")
now = now + 5
event("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(sounds == soundCount + 1, "return after cooldown alerts")
-- Recycled unit tokens must not leave a badge on the next player.
units.nameplate1 = player("Bob", "OtherRealm", "Player-2")
ME.UpdatePlate("nameplate1")
check(not badge:IsShown(), "nameplate recycling")
units.nameplate1 = player(secret, "HomeRealm", secret)
ME.UpdatePlate("nameplate1")
check(not badge:IsShown(), "restricted name skips matching")
units.nameplate1.guid = "Player-1"
ME.UpdatePlate("nameplate1")
check(badge:IsShown(), "known readable GUID matches when name is restricted")

units.nameplate1 = player("Alice", "HomeRealm", secret)
ME.UpdatePlate("nameplate1")
check(badge:IsShown(), "readable full name works with restricted GUID")
event("NAME_PLATE_UNIT_ADDED", secret)
units.nameplate1.player = secret
ME.UpdatePlate("nameplate1")
check(not badge:IsShown(), "restricted player flag skips matching")
units.target = player(secret, "", secret)
command("enemy")
command("diagnose")
local oldUnitName = UnitName
UnitName = function() error("API unavailable") end
check(ME.Identity("target") == nil, "failed identity query with restricted GUID is safe")
UnitName = oldUnitName

command("add enemy Bob-OtherRealm A grudge")
command("add enemy Bob-HomeRealm A grudge")
check(not ME.db.entries.bob, "realm suffixes are rejected, including own realm")
command("add enemy Bob A grudge")
check(ME.db.entries.bob.note == "A grudge" and ME.db.entries.bob.realm == nil, "plain-name manual add")
command("add")
command("add dragon Bob-OtherRealm")
command("remove Alice-HomeRealm")
check(ME.db.entries["alice"] ~= nil, "realm suffix is not accepted when removing")
command("list")
check(MortalEnemyWindow:IsShown(), "window opens")
local row
for _, f in ipairs(frames) do if f.key == "bob" then row = f end end
check(row, "list row rendered")
row.scripts.OnClick(row)
local edit
for _, f in ipairs(frames) do if f.kind == "EditBox" then edit = f end end
edit:SetText("New note")
edit.scripts.OnEnterPressed(edit)
check(ME.db.entries["bob"].note == "New note", "window saves note")
command("sound")
check(not ME.db.settings.sound, "sound toggle")
command("badges")
check(not badge:IsShown(), "disable badges hides existing")
command("preview")
command("remove Bob")
check(not ME.db.entries["bob"], "remove named player")
check(#ME.Note(string.rep("a", 241)) == 240, "ASCII note limit")
check(ME.Note(string.rep("a", 239) .. "é") == string.rep("a", 239), "UTF-8 note truncation")
check(#ME.Note(string.rep("é", 121)) == 240, "UTF-8 boundary at limit")
local saved = MortalEnemyCharDB
ME.InitDB()
check(MortalEnemyCharDB == saved and ME.db.entries["alice"], "initialization preserves saved records")
-- Simulate WoW supplying a separate SavedVariables table for another character.
MortalEnemyCharDB = nil
ME.InitDB()
check(next(ME.db.entries) == nil and ME.db.settings.sound, "new character gets independent empty list and default settings")
command("add rival Charlie Another story")
check(not saved.entries.charlie and saved.entries.alice, "second character cannot change first character's list")
MortalEnemyCharDB = saved
ME.InitDB()
check(ME.db.entries.alice and not ME.db.entries.charlie and not ME.db.settings.sound, "returning character restores their own list and settings")
command("remove Alice")
check(next(ME.db.entries) == nil, "remove final entry")
ME.db.entries.bad = {status = "invalid"}
ME.InitDB()
check(next(ME.db.entries) == nil, "malformed records ignored")
io.write("PASS: initialization, identity safety, matching, CRUD, sightings, cooldowns, nameplate reuse, commands, UI, per-character persistence, current-realm enforcement\n")
