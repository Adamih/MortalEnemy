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
function Methods:HookScript(name, fn)
    local previous = self.scripts[name]
    self.scripts[name] = function(...) if previous then previous(...) end; fn(...) end
end
function Methods:AddLine(text, r, g, b, wrap)
    safe(text)
    self.lines[#self.lines + 1] = {text = text, r = r, g = g, b = b, wrap = wrap}
end
function Methods:GetUnit() return "ignored name", self.unitToken end
function Methods:ClearLines()
    self.lines = {}
    if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
end
function Methods:RebuildFromTooltipInfo()
    self:ClearLines()
    self:AddLine("Original unit information")
    TooltipDataProcessor.callback(self, {})
end
function Methods:SetText(text) safe(text); self.text = text end
function Methods:GetText() return self.text end
function Methods:GetStringWidth() return #self.text * 6 end
function Methods:Hide()
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Methods:Show()
    local was = self.shown
    self.shown = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Methods:IsShown() return self.shown end
function Methods:SetShown(value) if value then self:Show() else self:Hide() end end
function Methods:SetParent(parent) self.parent = parent end
function Methods:IsForbidden() return self.forbidden or false end

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
function Methods:SetPoint(...) self.point = {...} end
function CreateFrame(kind, name, parent)
    local result = object(kind, parent)
    result.name = name
    if name then _G[name] = result end
    return result
end
UIParent = object("root")
UISpecialFrames, SlashCmdList = {}, {}
Enum = { TooltipDataType = { Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, callback)
    assert(kind == Enum.TooltipDataType.Unit)
    TooltipDataProcessor.callback = callback
end }
GameTooltip = object("tooltip")
GameTooltip.lines = {}
GameTooltip:Hide()

function print(message) messages[#messages + 1] = message end
function GetTime() return now end
function time() return 1795000000 + math.floor(now) end
function date(format, stamp) return os.date(format, stamp) end
function GetNormalizedRealmName() return "HomeRealm" end
function GetRealZoneText() return "Elwynn Forest" end
function GetBuildInfo() return "1.60.1", "70938", "", 16001 end
function UnitIsPlayer(unit) return units[unit] and units[unit].player end
local surnames = { Alice = "Redfen", Bob = "Stone", Me = "Self", Nobody = "Else", Charlie = "Story" }
local function FullName(u)
    if not u then return nil end
    if issecretvalue(u.name) then return u.name end
    return u.name:find(" ") and u.name or (surnames[u.name] and (u.name .. " " .. surnames[u.name]) or u.name)
end
function GetUnitName(unit) return FullName(units[unit]) end
function UnitName(unit)
    local u = units[unit]
    if not u then return nil end
    if issecretvalue(u.name) then return secret, secret end
    return u.name, surnames[u.name]
end
function UnitIsSameServer(name)
    for _, u in pairs(units) do
        local full = FullName(u)
        if not issecretvalue(full) and full == name then
            if issecretvalue(u.realm) then return secret end
            return not u.realm or u.realm == "" or u.realm == "HomeRealm"
        end
    end
    return false
end
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
check(MortalEnemyCharDB.version == 3 and SlashCmdList.MORTALENEMY, "initialization")
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
local alice = ME.db.entries["alice redfen"]
check(alice and alice.status == "rival" and alice.note == "Helped me once", "save target on current realm")
check(alice.name == "Alice Redfen", "Forever surname is part of the name, never a realm")
local originalGetUnitName = GetUnitName
GetUnitName = nil
local fallback = ME.Identity("target")
check(fallback and fallback.name == "Alice Redfen", "first/surname fallback preserves full name")
GetUnitName = originalGetUnitName
units.target = player("Alice Other", "HomeRealm", "Player-different-alice")
check(ME.Find(ME.Identity("target")) == nil, "same first name with different surname is not a match")
units.target = player("Alice", "", "Player-1")

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
check(ME.Find({key = "alice redfen", guid = "Player-other"}) == nil, "GUID conflict must not match")
check(ME.Find({key = "renamed", guid = "Player-1"}) == alice, "GUID matches renamed player")
units.nameplate1 = units.target
plates.nameplate1 = object("plate")
plates.nameplate1.UnitFrame = object("unitframe", plates.nameplate1)
plates.nameplate1.UnitFrame.HealthBarsContainer = { healthBar = object("healthbar", plates.nameplate1.UnitFrame) }
plates.nameplate1.UnitFrame.name = object("font", plates.nameplate1.UnitFrame)
plates.nameplate1.GetUnit = function(self) return self.unitToken end
plates.nameplate1.unitToken = "nameplate1"
event("NAME_PLATE_UNIT_ADDED", "nameplate1")
local badge
for _, f in ipairs(frames) do if f.parent == plates.nameplate1 and f.icon then badge = f end end
check(badge and badge:IsShown(), "saved player's nameplate gets badge")
local glow
for _, f in ipairs(frames) do if f.parent == plates.nameplate1 and f.borders then glow = f end end
check(glow and glow:IsShown(), "saved player's nameplate gets glow")
check(glow.point[2] == plates.nameplate1.UnitFrame.HealthBarsContainer.healthBar, "glow hugs health bar, not oversized plate root")
check(badge.point[2] == plates.nameplate1.UnitFrame.HealthBarsContainer.healthBar
    and badge.point[1] == "RIGHT" and badge.point[3] == "LEFT" and badge.point[4] == -6,
    "badge sits just left of the health bar")
check(badge.text == "", "badge has no status label")
for _, f in ipairs(frames) do check(not (f.parent == UIParent and f.icon and not f.title), "no duplicate fixed-screen target badge") end
local bar = plates.nameplate1.UnitFrame.HealthBarsContainer.healthBar
bar:Hide()
ME.RefreshWorld()
check(not glow:IsShown() and badge:IsShown(), "name-only plates keep badge without a floating glow box")
bar:Show()
ME.RefreshWorld()

command("glow enemy")
check(not glow:IsShown() and badge:IsShown(), "glow toggles independently of badge")
check(ME.db.settings.display.rival.glow, "enemy setting does not change rival setting")
command("glow enemy")
check(glow:IsShown(), "glow re-enables immediately")
command("badges enemy")
check(not badge:IsShown() and glow:IsShown(), "badge toggles independently of glow")
command("badges enemy")
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
check(not badge:IsShown() and not glow:IsShown(), "removed nameplate hides badge and glow")
now = now + 5
event("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(sounds == soundCount + 1, "return after cooldown alerts")
-- Recycled unit tokens must not leave a badge on the next player.
units.nameplate1 = player("Bob", "OtherRealm", "Player-2")
ME.UpdatePlate("nameplate1")
check(not badge:IsShown() and not glow:IsShown(), "nameplate recycling clears badge and glow")
units.nameplate1 = player(secret, "HomeRealm", secret)
ME.UpdatePlate("nameplate1")
check(not badge:IsShown(), "restricted name skips matching")
units.nameplate1.guid = "Player-1"
ME.UpdatePlate("nameplate1")
check(not badge:IsShown(), "restricted full name cannot establish same-realm identity")

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
local oldGetUnitName = GetUnitName
GetUnitName = nil
check(ME.Identity("target") == nil, "failed identity query with restricted GUID is safe")
GetUnitName = oldGetUnitName
UnitName = oldUnitName

command("add enemy Bob-OtherRealm A grudge")
command("add enemy Bob-HomeRealm A grudge")
check(not ME.db.entries["bob stone"], "realm suffixes are rejected, including own realm")
command('add rival "Charlie Story" A quoted name')
check(ME.db.entries["charlie story"].note == "A quoted name", "quoted full names can carry notes")
command("remove Charlie Story")
command("add enemy Bob Stone A grudge")
check(ME.db.entries["bob stone"].note == "A grudge" and ME.db.entries["bob stone"].realm == nil, "full-name manual add")
command("add")
command("add dragon Bob-OtherRealm")
command("remove Alice-HomeRealm")
check(ME.db.entries["alice redfen"] ~= nil, "realm suffix is not accepted when removing")
command("list")
check(MortalEnemyWindow:IsShown(), "window opens")
local rivalGlowCheck
for _, f in ipairs(frames) do
    if f.kind == "CheckButton" and f.point and f.point[2] == 260 and f.point[3] == -568 then rivalGlowCheck = f end
end
check(rivalGlowCheck, "per-status display controls exist")
rivalGlowCheck:SetChecked(false)
rivalGlowCheck.scripts.OnClick(rivalGlowCheck)
check(not ME.db.settings.display.rival.glow and ME.db.settings.display.enemy.glow,
    "rival glow checkbox changes only its own setting")

local row
for _, f in ipairs(frames) do if f.key == "bob stone" then row = f end end
check(row, "list row rendered")
row.scripts.OnClick(row)
local edit
for _, f in ipairs(frames) do if f.kind == "EditBox" then edit = f end end
edit:SetText("New note")
edit.scripts.OnEnterPressed(edit)
check(ME.db.entries["bob stone"].note == "New note", "window saves note")
-- Tooltip hooks operate on the tooltip's own unit, not an unrelated mouseover.
units.tooltipunit = player("Bob", "HomeRealm", "Player-2")
units.mouseover = player("Nobody", "HomeRealm", "Player-3")
GameTooltip.unitToken = "tooltipunit"
GameTooltip:Show()
GameTooltip:RebuildFromTooltipInfo()
check(#GameTooltip.lines == 4 and GameTooltip.lines[3].text == "Your Mortal Enemy"
    and GameTooltip.lines[4].text == "New note", "tooltip includes status and personal note")
TooltipDataProcessor.callback(GameTooltip, {})
check(#GameTooltip.lines == 4, "postprocessing same tooltip does not duplicate lines")
command("tooltip enemy")
check(#GameTooltip.lines == 1, "disabling tooltip removes existing annotation immediately")
command("tooltip rival")
check(not ME.db.settings.display.rival.tooltip and not ME.db.settings.display.enemy.tooltip, "per-status tooltip settings independent")
command("tooltip enemy")
check(#GameTooltip.lines == 4, "re-enabling tooltip updates current hover")
ME.db.settings.display.enemy.tooltipNote = false
ME.Changed()
check(#GameTooltip.lines == 3, "tooltip note can be hidden independently")
ME.db.settings.display.enemy.tooltipNote = true
ME.Changed()
units.tooltipunit = player("Bob", "OtherRealm", "Player-2")
GameTooltip:RebuildFromTooltipInfo()
check(#GameTooltip.lines == 1, "off-realm tooltip excluded")
units.tooltipunit = {player = false, name = "Wolf"}
GameTooltip:RebuildFromTooltipInfo()
check(#GameTooltip.lines == 1, "NPC tooltip excluded")
units.tooltipunit = player(secret, "", secret)
GameTooltip:RebuildFromTooltipInfo()
check(#GameTooltip.lines == 1, "restricted tooltip identity skipped")
GameTooltip.unitToken = secret
GameTooltip:RebuildFromTooltipInfo()
check(#GameTooltip.lines == 1, "restricted tooltip token skipped")
GameTooltip.unitToken = "tooltipunit"
units.tooltipunit = player("Bob", "", "Player-2")
GameTooltip:RebuildFromTooltipInfo()
command("remove Bob Stone")
check(#GameTooltip.lines == 1, "removing entry removes current tooltip annotation")
GameTooltip:Hide()
command("sound")
check(not ME.db.settings.sound, "sound toggle")
command("badges")
check(not badge:IsShown(), "disable badges hides existing")
command("preview")
check(not ME.db.entries["bob stone"], "remove named player")
check(#ME.Note(string.rep("a", 241)) == 240, "ASCII note limit")
check(ME.Note(string.rep("a", 239) .. "é") == string.rep("a", 239), "UTF-8 note truncation")
check(#ME.Note(string.rep("é", 121)) == 240, "UTF-8 boundary at limit")
-- Preserve the old badge preference when initializing the new display options.
local configuredDisplay = ME.db.settings.display
ME.db.settings.display = nil
ME.db.settings.badges = false
ME.InitDB()
check(not ME.db.settings.display.enemy.badge and not ME.db.settings.display.rival.badge,
    "legacy disabled badges migrate without re-enabling")
check(ME.db.settings.display.enemy.glow and ME.db.settings.display.enemy.tooltip, "new display options default enabled")
ME.db.settings.display = configuredDisplay
local saved = MortalEnemyCharDB
ME.InitDB()
check(MortalEnemyCharDB == saved and ME.db.entries["alice redfen"], "initialization preserves saved records")
-- Simulate WoW supplying a separate SavedVariables table for another character.
MortalEnemyCharDB = nil
ME.InitDB()
check(next(ME.db.entries) == nil and ME.db.settings.sound and ME.db.settings.display.enemy.badge
    and ME.db.settings.display.enemy.tooltip, "new character gets independent empty list and default settings")
ME.db.settings.display.enemy.tooltip = false
command("add rival Charlie Story Another story")
check(not saved.entries["charlie story"] and saved.entries["alice redfen"], "second character cannot change first character's list")
MortalEnemyCharDB = saved
ME.InitDB()
check(ME.db.entries["alice redfen"] and not ME.db.entries["charlie story"] and not ME.db.settings.sound
    and ME.db.settings.display.enemy.tooltip, "returning character restores their own list and display settings")
command("remove Alice Redfen")
check(next(ME.db.entries) == nil, "remove final entry")
ME.db.entries.bad = {status = "invalid"}
ME.InitDB()
check(next(ME.db.entries) == nil, "malformed records ignored")
io.write("PASS: initialization, identity safety, matching, CRUD, sightings, cooldowns, nameplate reuse, independent badges/glows/tooltips, tooltip lifecycle, commands, UI, per-character persistence, current-realm enforcement\n")
