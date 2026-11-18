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
function Methods:SetText(text)
    safe(text); self.text = text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
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
function Methods:SetFocus() self.focused = true end
function Methods:SetEnabled(value) self.enabled = value end
function Methods:SetScrollChild(child) self.scrollChild = child end
function Methods:SetVerticalScroll(value) self.scrollValue = value end
function Methods:SetMinMaxValues(low, high) self.minimum, self.maximum = low, high end
function Methods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function Methods:SetThumbTexture(texture) self.thumb = object("texture", self) end
function Methods:GetThumbTexture() return self.thumb end
function PanelTemplates_TabResize(tab, padding, width) tab.tabWidth = width end
function PanelTemplates_SelectTab(tab) tab.active = true end
function PanelTemplates_DeselectTab(tab) tab.active = false end

function Methods:GetWidth() return 160 end
function Methods:GetHeight() return 160 end
function Methods:GetFrameLevel() return 1 end
function Methods:GetEffectiveScale() return 2 end
function Methods:GetCenter() return 300, 300 end
function Methods:SetOwner(owner) self.owner = owner; self.unitToken = nil; self:ClearLines() end
function Methods:IsOwned(owner) return self.owner == owner end
for _, name in ipairs({"SetOrientation", "SetValueStep", "EnableMouseWheel", "SetFontObject", "SetMultiLine", "SetWordWrap", "SetVertexColor", "SetHeight", "RegisterForClicks", "SetFrameLevel", "SetSize", "SetPoint", "SetWidth", "SetJustifyH", "SetShadowOffset", "EnableMouse", "SetFrameStrata", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "ClearAllPoints", "SetClampedToScreen", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetAllPoints", "SetColorTexture", "SetHighlightTexture", "SetAutoFocus", "SetMaxLetters", "SetTextColor"}) do
    Methods[name] = function(...) end
end
function Methods:SetPoint(...) self.point = {...} end
function CreateFrame(kind, name, parent, template)
    local result = object(kind, parent)
    result.name, result.template = name, template
    if template == "PortraitFrameTemplate" then
        result.TitleContainer = { TitleText = object("font", result) }
        result.PortraitContainer = { portrait = object("texture", result) }
    end
    if name then _G[name] = result end
    return result
end
UIParent = object("root")
Minimap = object("minimap", UIParent)
function GetCursorPosition() return 800, 600 end
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
LOCALIZED_CLASS_NAMES_MALE = { WARLOCK = "Warlock", MAGE = "Mage", PRIEST = "Priest", ROGUE = "Rogue" }
function UnitClass(unit)
    local u = units[unit]
    if not u then return nil end
    local token = u.classFile
    if token == nil then
        for file, label in pairs(LOCALIZED_CLASS_NAMES_MALE) do if u.class == label then token = file end end
    end
    return u.class, token
end
function UnitFactionGroup(unit) return units[unit] and units[unit].faction end
function UnitRace(unit) return units[unit] and units[unit].race end
function UnitLevel(unit) return units[unit] and units[unit].level end
function UnitIsUnit(a, b) return units[a] ~= nil and units[a] == units[b] end
function PlaySound() sounds = sounds + 1 end
C_NamePlate = {
    GetNamePlateForUnit = function(unit) return plates[unit] end,
    GetNamePlates = function() local result = {}; for _, plate in pairs(plates) do result[#result + 1] = plate end; return result end,
}
local menuCallbacks = {}
Menu = { ModifyMenu = function(tag, fn) menuCallbacks[tag] = fn end }
local entryMenu
MenuUtil = { CreateContextMenu = function(owner, generator)
    entryMenu = {owner = owner, items = {}}
    local root = {
        CreateTitle = function(_, title) entryMenu.title = title end,
        CreateDivider = function() end,
        CreateButton = function(_, title, callback) entryMenu.items[title] = {click = callback} end,
        CreateRadio = function(_, title, selected, callback) entryMenu.items[title] = {selected = selected, click = callback} end,
    }
    generator(owner, root)
end }

local registeredSettings
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        registeredSettings = panel
        return { GetID = function() return 42 end }
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) assert(id == 42); registeredSettings:Show() end,
}
function HideUIPanel(panel) panel:Hide() end
function InCombatLockdown() return false end
local pendingPopup
StaticPopupDialogs = {}
function StaticPopup_Show(which, name, _, data)
    pendingPopup = { which = which, text = StaticPopupDialogs[which].text:format(name), data = data }
    return pendingPopup
end
local ME = {}
for _, file in ipairs({"Core.lua", "Display.lua", "Window.lua", "MortalEnemy.lua"}) do assert(loadfile(file))("MortalEnemy", ME) end
local controller = frames[#frames]
local function event(name, unit) controller.scripts.OnEvent(controller, name, unit) end
local function command(text)
    SlashCmdList.MORTALENEMY(text)
    -- Existing removal scenarios exercise the accept path; dedicated tests
    -- below verify that cancellation and opening alone never delete an entry.
    if text:match("^remove") and pendingPopup then
        StaticPopupDialogs[pendingPopup.which].OnAccept(pendingPopup, pendingPopup.data)
        pendingPopup = nil
    end
end
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
check(MortalEnemyMinimapButton and MortalEnemyMinimapButton.parent == Minimap, "minimap launcher exists")
local launcher = MortalEnemyMinimapButton
launcher.scripts.OnClick(launcher)
check(MortalEnemyWindow:IsShown(), "minimap click opens panel")
launcher.scripts.OnClick(launcher)
check(not MortalEnemyWindow:IsShown(), "minimap click closes panel")
ME.OpenSettings()
check(MortalEnemySettingsPanel:IsShown() and not MortalEnemyWindow:IsShown(), "settings open in registered AddOns category")
local visibilityCheck = MortalEnemySettingsPanel.checks.showMinimap
check(visibilityCheck and visibilityCheck:GetChecked(), "minimap visibility control defaults on")
visibilityCheck:SetChecked(false)
visibilityCheck.scripts.OnClick(visibilityCheck)
check(not launcher:IsShown(), "visibility checkbox hides minimap button immediately")
event("PLAYER_ENTERING_WORLD")
check(not launcher:IsShown(), "world transition preserves hidden button")
command("list")
check(MortalEnemyWindow:IsShown(), "slash command opens panel with minimap button hidden")
visibilityCheck:SetChecked(true)
visibilityCheck.scripts.OnClick(visibilityCheck)
check(launcher:IsShown(), "visibility checkbox restores minimap button")
command("list")

launcher.scripts.OnEnter(launcher)
check(GameTooltip:IsShown() and GameTooltip:IsOwned(launcher) and #GameTooltip.lines == 3, "launcher tooltip explains click and drag")
launcher.scripts.OnLeave(launcher)
check(not GameTooltip:IsShown(), "launcher tooltip hides on leave")
launcher.scripts.OnMouseDown(launcher)
launcher.scripts.OnDragStart(launcher)
check(ME.db.settings.minimapAngle == 0 and launcher.point[4] == 88 and launcher.point[5] == 0,
    "drag uses scaled cursor and saves position on minimap edge")
launcher.scripts.OnDragStop(launcher)
check(not launcher.scripts.OnUpdate, "drag polling stops on release")
launcher.scripts.OnClick(launcher)
check(not MortalEnemyWindow:IsShown(), "drag release does not open panel")
launcher.scripts.OnMouseDown(launcher)
launcher.scripts.OnClick(launcher)
check(MortalEnemyWindow:IsShown(), "ordinary click works after dragging")
launcher.scripts.OnClick(launcher)
event("PLAYER_ENTERING_WORLD")
check(MortalEnemyMinimapButton == launcher and launcher.point[4] == 88, "world re-entry reuses launcher and saved position")
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
check(badge.point[2] == plates.nameplate1.UnitFrame.HealthBarsContainer.healthBar
    and badge.point[1] == "RIGHT" and badge.point[3] == "LEFT" and badge.point[4] == -6,
    "badge sits just left of the health bar")
check(badge.text == "", "badge has no status label")
for _, f in ipairs(frames) do check(not (f.parent == UIParent and f.icon and not f.title), "no duplicate fixed-screen target badge") end
local bar = plates.nameplate1.UnitFrame.HealthBarsContainer.healthBar
bar:Hide()
ME.RefreshWorld()
check(badge:IsShown(), "name-only plates keep badge")
bar:Show()
ME.RefreshWorld()

command("badges enemy")
check(not badge:IsShown(), "badge toggles off")
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
check(not badge:IsShown(), "removed nameplate hides badge")
now = now + 5
event("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(sounds == soundCount + 1, "return after cooldown alerts")
-- Recycled unit tokens must not leave a badge on the next player.
units.nameplate1 = player("Bob", "OtherRealm", "Player-2")
ME.UpdatePlate("nameplate1")
check(not badge:IsShown(), "nameplate recycling clears badge")
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
local rivalBadgeCheck = MortalEnemySettingsPanel.displayChecks.rival.badge
check(rivalBadgeCheck, "per-status display controls exist")
rivalBadgeCheck:SetChecked(false)
rivalBadgeCheck.scripts.OnClick(rivalBadgeCheck)
check(not ME.db.settings.display.rival.badge and ME.db.settings.display.enemy.badge,
    "rival badge checkbox changes only its own setting")
local row
for _, f in ipairs(frames) do if f.key == "bob stone" then row = f end end
check(row, "list row rendered")
row.scripts.OnClick(row)
local edit
for _, f in ipairs(frames) do if f.kind == "EditBox" and f.parent == MortalEnemyWindow then edit = f end end
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
check(#ME.Note(string.rep("a", 241)) == 100, "ASCII note limit")
check(ME.Note(string.rep("a", 99) .. "é" .. "x") == string.rep("a", 99) .. "é", "UTF-8 note truncation")
check(#ME.Note(string.rep("é", 121)) == 200, "UTF-8 boundary at limit")
-- Preserve the old badge preference when initializing the new display options.
local configuredDisplay = ME.db.settings.display
ME.db.settings.display = nil
ME.db.settings.badges = false
ME.InitDB()
check(not ME.db.settings.display.enemy.badge and not ME.db.settings.display.rival.badge,
    "legacy disabled badges migrate without re-enabling")
check(ME.db.settings.display.enemy.tooltip, "tooltip defaults enabled")
ME.db.settings.display.enemy.glow = true
ME.InitDB()
check(ME.db.settings.display.enemy.glow == nil, "obsolete glow preference is removed")
ME.db.settings.display = configuredDisplay
local saved = MortalEnemyCharDB
ME.InitDB()
check(MortalEnemyCharDB == saved and ME.db.entries["alice redfen"] and ME.db.settings.minimapAngle == 0,
    "initialization preserves saved records and minimap angle")
-- Simulate WoW supplying a separate SavedVariables table for another character.
MortalEnemyCharDB = nil
ME.InitDB()
check(next(ME.db.entries) == nil and ME.db.settings.sound and ME.db.settings.minimapAngle == 225
    and ME.db.settings.display.enemy.badge
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
-- Target strip follows target changes and never enables actions for NPCs/self.
units.target = player("Alice", "HomeRealm", "Player-1")
event("PLAYER_TARGET_CHANGED")
if not MortalEnemyWindow:IsShown() then command("list") end
check(MortalEnemyWindow.targetName:GetText():find("Alice Redfen", 1, true)
    and MortalEnemyWindow.targetButtons[1].enabled, "target strip names eligible target")
units.target = units.player
event("PLAYER_TARGET_CHANGED")
check(not MortalEnemyWindow.targetButtons[1].enabled, "self target disables mark buttons")
-- Right-click callback captures the player before the target changes.
units.target = player("Alice", "HomeRealm", "Player-1")
local buttons = {}
local root = {
    CreateDivider = function() end, CreateTitle = function() end,
    CreateButton = function(_, text, callback) buttons[text] = callback end,
}
menuCallbacks.MENU_UNIT_PLAYER(nil, root, { unit = "target" })
check(buttons["Mark as Rival"] and buttons["Mark as Mortal Enemy"], "player menu offers both relationships")
units.target = player("Bob", "HomeRealm", "Player-2")
buttons["Mark as Rival"]()
check(ME.db.entries["alice redfen"] and not ME.db.entries["bob stone"], "menu marks original player after retarget")
buttons = {}
menuCallbacks.MENU_UNIT_PLAYER(nil, root, { unit = "player", isSelf = true })
check(next(buttons) == nil, "self menu unchanged")
units.target = player("Bob", "OtherRealm", "Player-2")
local nativeSameServer = UnitIsSameServer
UnitIsSameServer = function() return false end
menuCallbacks.MENU_UNIT_ENEMY_PLAYER(nil, root, { unit = "target" })
check(next(buttons) == nil, "off-realm menu unchanged")
UnitIsSameServer = nativeSameServer
menuCallbacks.MENU_UNIT_PLAYER(nil, root, { name = secret })
check(next(buttons) == nil, "restricted menu unchanged")
local oldCombat = InCombatLockdown
InCombatLockdown = function() return true end
menuCallbacks.MENU_UNIT_PLAYER(nil, root, {unit = "target"})
check(next(buttons) == nil, "combat menu left unchanged")
InCombatLockdown = oldCombat
-- Add-by-name form supports validation, both statuses, and optional notes.
ME.ShowAddPlayer()
local dialog = MortalEnemyAddDialog
local addRival, addEnemy
for _, f in ipairs(frames) do
    if f.parent == dialog and f.text == "Add Rival" then addRival = f end
    if f.parent == dialog and f.text == "Add Mortal Enemy" then addEnemy = f end
end
addRival.scripts.OnClick(addRival)
check(dialog:IsShown() and dialog.error:GetText() ~= "", "invalid name keeps form open with explanation")
dialog.first:SetText("Charlie")
dialog.last:SetText("Story")
dialog.note:SetText("An old grudge")
addEnemy.scripts.OnClick(addEnemy)
check(not dialog:IsShown() and ME.db.entries["charlie story"].status == "enemy"
    and ME.db.entries["charlie story"].note == "An old grudge", "name form saves relationship and note")
check(MortalEnemyWindow:IsShown(), "adding by name returns to nemesis list")
check(MortalEnemyWindow.template == "PortraitFrameTemplate" and MortalEnemyAddDialog.template == "PortraitFrameTemplate",
    "main window and add dialog use native portrait frames")
local book = MortalEnemyWindow
book.search:SetText("Charlie")
check(book.counter:GetText():find("1 shown", 1, true) and book.rows[1].key == "charlie story", "search filters full names")
book.search:SetText("old grudge")
check(book.rows[1].key == "charlie story", "search also matches notes")
book.filterTabs[2].scripts.OnClick(book.filterTabs[2])
check(book.empty:IsShown(), "relationship filter combines with search")
book.filterTabs[3].scripts.OnClick(book.filterTabs[3])
check(not book.empty:IsShown() and book.rows[1].key == "charlie story", "enemy filter shows matching entry")
book.search:SetText("Nobody matches this")
check(book.empty:IsShown() and not book.editButtons[1].enabled, "empty search disables detail actions")
book.search:SetText("")
book.filterTabs[1].scripts.OnClick(book.filterTabs[1])
for i = 1, 12 do ME.AddNamedPlayer("Extra Person" .. i, "rival") end
check(book.maxScroll > 0 and book.scrollbar:IsShown(), "long lists have a scrollbar")
book.listScroll.scripts.OnMouseWheel(book.listScroll, -3)
check(book.scrollOffset > 0 and book.listScroll.scrollValue == book.scrollOffset, "mouse wheel scrolls list")
book.scrollbar:SetValue(12)
check(book.listScroll.scrollValue == 12, "scrollbar moves list")
ME.SelectEntry("extra person9")
check(book.search:GetText() == "" and book.filterTabs[1].active and book.selection:GetText() == "Extra Person9",
    "selecting newly added entry clears filters and displays its details")
book.search:SetText("No results")
check(book.scrollOffset == 0 and not book.scrollbar:IsShown(), "filter shrink resets scroll and hides scrollbar")
-- Character details are snapshots from the saved player's readable target.
local profileTarget = player("Profile Example", "HomeRealm", "Player-profile")
profileTarget.class, profileTarget.race, profileTarget.level = "Warlock", "Human", 20
units.target = profileTarget
ME.MarkTarget("enemy", "Keep my note")
local profileEntry = ME.db.entries["profile example"]
check(profileEntry.class == "Warlock" and profileEntry.race == "Human" and profileEntry.level == 20,
    "mark target captures class race and level")
ME.SelectEntry("profile example")
check(book.characterInfo:GetText() == "Level 20 • Human • Warlock" and book.characterUpdated:GetText():find("Details updated", 1, true),
    "detail pane displays snapshot and a single update date")
local previousStamp = profileEntry.characterUpdatedAt
now = now + 10
profileTarget.level = 27
event("PLAYER_TARGET_CHANGED")
check(profileEntry.level == 27 and profileEntry.characterUpdatedAt > previousStamp
    and book.characterInfo:GetText():find("Level 27", 1, true), "retarget updates saved level and visible details")
local oldStamp = profileEntry.characterUpdatedAt
now = now + 10
profileTarget.level, profileTarget.race, profileTarget.class = secret, secret, secret
event("PLAYER_TARGET_CHANGED")
check(profileEntry.level == 27 and profileEntry.race == "Human" and profileEntry.class == "Warlock"
    and profileEntry.characterUpdatedAt == oldStamp, "fully restricted reads preserve values and update date")
profileTarget.level, profileTarget.race, profileTarget.class = -1, nil, "Mage"
event("PLAYER_TARGET_CHANGED")
check(profileEntry.class == "Mage" and profileEntry.characterUpdatedAt > oldStamp
    and profileEntry.level == 27 and profileEntry.race == "Human", "partial update preserves missing values with one snapshot date")
profileTarget.level = 28
event("UNIT_LEVEL", "target")
check(profileEntry.level == 28, "level event refreshes current target")
profileTarget.level = 29
now = now + 6
ME.UpdateTarget()
check(profileEntry.level == 29, "held target retries and refreshes through throttled polling")
units.target = player("Not Saved", "HomeRealm", "Player-unknown")
units.target.level = 55
event("PLAYER_TARGET_CHANGED")
check(profileEntry.level == 29 and not ME.db.entries["not saved"], "untracked targets do not alter or create entries")
ME.AddNamedPlayer("Manual Example", "rival")
check(not ME.db.entries["manual example"].level, "manual name entry starts with unknown details")
units.target = player("Manual Example", "HomeRealm", "Player-manual")
units.target.class, units.target.race, units.target.level = "Priest", "Dwarf", 23
event("PLAYER_TARGET_CHANGED")
check(ME.db.entries["manual example"].level == 23 and ME.db.entries["manual example"].race == "Dwarf", "targeting fills manually added profile")
-- Right-click data belongs to the player at menu-open time, even after retargeting.
units.target = player("Menu Example", "HomeRealm", "Player-menu")
units.target.class, units.target.race, units.target.level = "Rogue", "Orc", 31
buttons = {}
menuCallbacks.MENU_UNIT_ENEMY_PLAYER(nil, root, {unit = "target"})
units.target = profileTarget
buttons["Mark as Rival"]()
check(ME.db.entries["menu example"].level == 31 and ME.db.entries["menu example"].race == "Orc", "menu captures original player's character details")
check(profileEntry.note == "Keep my note", "automatic detail refresh never changes personal notes")
ME.InitDB()
check(ME.db.entries["profile example"].level == 29 and ME.db.entries["profile example"].class == "Mage",
    "recorded character info survives database reinitialization")
units.target = profileTarget
profileTarget.class, profileTarget.classFile, profileTarget.faction = "Warlock", "WARLOCK", "Horde"
now = now + 10
event("PLAYER_TARGET_CHANGED")
ME.SelectEntry("profile example")
check(book.detailIcon.texture == "Interface\\Icons\\ClassIcon_WARLOCK", "detail header uses class icon")
check(book.factionIcon:IsShown() and book.factionIcon.texture == "Interface\\PVPFrame\\PVP-Currency-Horde", "detail header displays Horde emblem")
check(profileEntry.classFile == "WARLOCK" and profileEntry.faction == "Horde", "class token and faction saved")
local factionStamp = profileEntry.characterUpdatedAt
profileTarget.classFile, profileTarget.faction = secret, secret
now = now + 10
event("PLAYER_TARGET_CHANGED")
check(profileEntry.classFile == "WARLOCK" and profileEntry.faction == "Horde" and profileEntry.characterUpdatedAt > factionStamp,
    "restricted class token and faction preserve previous snapshots")
profileTarget.classFile, profileTarget.faction = "MAGE", "Alliance"
event("PLAYER_TARGET_CHANGED")
check(book.detailIcon.texture == "Interface\\Icons\\ClassIcon_MAGE" and book.factionIcon.texture == "Interface\\PVPFrame\\PVP-Currency-Alliance",
    "header icons update with newly observed class and faction")
for _, row in ipairs(book.rows) do
    if row.key == "profile example" then check(row.icon.texture == ME.styles.enemy.icon, "list relationship icon remains unchanged") end
end
ME.SelectEntry("extra person9")
check(book.detailIcon.texture == "Interface\\Icons\\INV_Misc_QuestionMark" and not book.factionIcon:IsShown(), "unknown class and faction have neutral fallback without stale emblem")
check(ME.ClassToken({class = "Warlock"}) == "WARLOCK", "existing localized class records resolve icon before next encounter")
ME.SelectEntry("profile example")
check(not book.saveNote.enabled, "unchanged note cannot be saved again")
book.note:SetText("A new short grudge")
check(book.saveNote.enabled, "editing a note enables save")
now = now + 6
ME.UpdateTarget()
check(book.note:GetText() == "A new short grudge", "background character refresh preserves unsaved note draft")
book.saveNote.scripts.OnClick(book.saveNote)
check(not book.saveNote.enabled and profileEntry.note == "A new short grudge", "saving clears dirty state")
local profileRow
for _, row in ipairs(book.rows) do if row.key == "profile example" then profileRow = row end end
check(profileRow, "saved player is present in the list")
profileRow.scripts.OnClick(profileRow, "RightButton")
check(entryMenu.title == "Profile Example" and entryMenu.items["Mortal Enemy"].selected()
    and not entryMenu.items.Rival.selected(), "entry menu shows current relationship")
entryMenu.items.Rival.click()
check(profileEntry.status == "rival" and entryMenu.items.Rival.selected(), "context menu changes relationship")
entryMenu.items.Forgive.click()
check(pendingPopup and pendingPopup.text == "Are you sure you want to forgive Profile Example?"
    and ME.db.entries["profile example"] == profileEntry, "forgive requires named confirmation")
pendingPopup = nil -- Cancel/Escape: no accept callback.
check(ME.db.entries["profile example"] == profileEntry, "cancel leaves entry unchanged")
entryMenu.items.Forgive.click()
ME.SelectEntry("manual example")
StaticPopupDialogs[pendingPopup.which].OnAccept(pendingPopup, pendingPopup.data)
check(not ME.db.entries["profile example"] and ME.db.entries["manual example"], "confirmation forgives original player even after selection changes")
pendingPopup = nil
SlashCmdList.MORTALENEMY("forgive Manual Example")
check(pendingPopup and ME.db.entries["manual example"], "forgive command also asks for confirmation")
StaticPopupDialogs[pendingPopup.which].OnAccept(pendingPopup, pendingPopup.data)
check(not ME.db.entries["manual example"], "confirmed command forgives player")
pendingPopup = nil
local migrated = ME.db.entries["menu example"]
migrated.classObservedAt, migrated.levelObservedAt = 1000, 2000
migrated.characterUpdatedAt = nil
ME.InitDB()
check(migrated.characterUpdatedAt == 2000 and not migrated.classObservedAt and not migrated.levelObservedAt,
    "legacy field dates migrate into one date and are removed")
check(ME.Note("One\nshort\tgrudge") == "One short grudge", "notes stay single-line")
ME.SelectEntry("menu example")
ME.ShowEntryMenu(book, "menu example")
entryMenu.items["Edit note"].click()
check(book.note:HasFocus() and book.selection:GetText() == "Menu Example", "context edit note focuses selected player's input")
local originalMenu = entryMenu
ME.SelectEntry("extra person9")
originalMenu.items["Mortal Enemy"].click()
check(ME.db.entries["menu example"].status == "enemy" and ME.db.entries["extra person9"].status == "rival",
    "context action keeps original player after selection changes")
local beforeRemoval = ME.db.entries["menu example"]
ME.Remove("menu example")
ME.AddNamedPlayer("Menu Example", "rival")
originalMenu.items["Mortal Enemy"].click()
check(ME.db.entries["menu example"] ~= beforeRemoval and ME.db.entries["menu example"].status == "rival",
    "stale context menu cannot change a replacement entry")
check(not book.relationshipChecks and #book.editButtons == 1, "relationship and forgive controls removed from detail pane")
io.write("PASS: initialization, identity safety, matching, CRUD, sightings, cooldowns, nameplate reuse, independent badges/tooltips, tooltip lifecycle, commands, UI, settings category, target strip, player menus, add-by-name form, per-character persistence, current-realm enforcement\n")
