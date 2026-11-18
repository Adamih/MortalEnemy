local _, ME = ...
ME.units = {}
local badges, encounters = {}, {}
local notice
local function MakeBadge(parent)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(18, 18)
    badge:EnableMouse(false)
    badge.icon = badge:CreateTexture(nil, "OVERLAY")
    badge.icon:SetSize(18, 18)
    badge.icon:SetPoint("LEFT")
    badge:Hide()
    return badge
end
local function Paint(badge, entry)
    local style = ME.styles[entry.status]
    badge.icon:SetTexture(style.icon)
    badge:Show()
end
function ME.ShowNotice(entry, preview)
    if not notice then
        notice = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        notice:SetSize(420, 74)
        notice:SetPoint("TOP", UIParent, "TOP", 0, -150)
        notice:SetFrameStrata("HIGH")
        notice:EnableMouse(false)
        notice:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        notice:SetBackdropColor(0.05, 0.03, 0.03, 0.92)
        notice.icon = notice:CreateTexture(nil, "ARTWORK")
        notice.icon:SetSize(42, 42)
        notice.icon:SetPoint("LEFT", 14, 0)
        notice.title = notice:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        notice.title:SetPoint("TOPLEFT", 68, -13)
        notice.title:SetWidth(336)
        notice.title:SetJustifyH("LEFT")
        notice.detail = notice:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        notice.detail:SetPoint("TOPLEFT", notice.title, "BOTTOMLEFT", 0, -7)
        notice.detail:SetWidth(336)
        notice.detail:SetJustifyH("LEFT")
        notice:SetScript("OnUpdate", function(self, elapsed)
            self.remaining = self.remaining - elapsed
            if self.remaining <= 0 then self:Hide() end
        end)
    end
    local style = ME.styles[entry.status]
    notice.icon:SetTexture(style.icon)
    notice.title:SetText((preview and "Preview: " or "Spotted: ") .. entry.name)
    notice.title:SetTextColor(style.r, style.g, style.b)
    notice:SetBackdropBorderColor(style.r, style.g, style.b, 1)
    notice.detail:SetText(style.label .. (entry.note and entry.note ~= "" and (" — " .. entry.note) or ""))
    notice.remaining = 5
    notice:Show()
    if ME.db.settings.sound then PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master") end
end
function ME.Observe(entry, key)
    local now = GetTime()
    local encounter = encounters[key] or {}
    local returning = not encounter.observed or now - encounter.observed > 3
    encounter.observed = now
    encounters[key] = encounter
    -- Update history while visible without writing on every polling tick.
    if not encounter.recorded or now - encounter.recorded >= 10 then
        entry.lastSeen = time()
        entry.lastZone = ME.Read(GetRealZoneText) or "Unknown zone"
        encounter.recorded = now
    end
    if not returning or (encounter.alerted and now - encounter.alerted < 120) then return end
    encounter.alerted = now
    if ME.db.settings.alerts then
        ME.ShowNotice(entry)
        ME.Print("Spotted " .. entry.name .. " (" .. ME.styles[entry.status].label .. ").")
    end
end
local function VisualAnchors(plate)
    local frame = plate.UnitFrame
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return nil end
    -- Forever's root plate includes reserved space for names, auras, and casts.
    -- The visible health bar is much smaller than that root rectangle.
    local container = frame.HealthBarsContainer
    local healthBar = (container and container.healthBar) or frame.healthBar
    if healthBar and healthBar.IsForbidden and healthBar:IsForbidden() then healthBar = nil end
    if healthBar and ME.Read(healthBar.IsShown, healthBar) ~= true then healthBar = nil end
    local name = frame.name
    if name and name.IsForbidden and name:IsForbidden() then name = nil end
    if name and ME.Read(name.IsShown, name) ~= true then name = nil end
    return healthBar, name
end
function ME.UpdatePlate(unit)
    local badge = badges[unit]
    if badge then badge:Hide() end
    if not ME.units[unit] then return end
    local entry, key = ME.Find(ME.Identity(unit))
    if not entry then return end
    ME.Observe(entry, key)
    local options = ME.db.settings.display[entry.status]
    if not options.badge then return end
    local plate = ME.Read(C_NamePlate and C_NamePlate.GetNamePlateForUnit, unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    local healthBar, nameAnchor = VisualAnchors(plate)
    local badgeAnchor = healthBar or nameAnchor
    if options.badge and badgeAnchor then
        if not badge then badge = MakeBadge(plate); badges[unit] = badge end
        badge:SetParent(plate)
        badge:ClearAllPoints()
        badge:SetPoint("RIGHT", badgeAnchor, "LEFT", -6, 0)
        Paint(badge, entry)
    end
end
function ME.RemovePlate(unit)
    ME.units[unit] = nil
    if badges[unit] then badges[unit]:Hide() end
end
function ME.UpdateTarget()
    -- Targeting can still record/announce an encounter, but never creates a
    -- second badge at a fixed screen position. Status belongs to the nameplate.
    local entry, key = ME.Find(ME.Identity("target"))
    if entry then
        ME.Observe(entry, key)
        ME.RefreshCharacterInfo("target")
    end
end
function ME.SeedNameplates()
    -- Recover already-visible plates after /reload or a world transition.
    local plates = ME.Read(C_NamePlate and C_NamePlate.GetNamePlates)
    if type(plates) ~= "table" then return end
    for _, plate in pairs(plates) do
        if not (plate.IsForbidden and plate:IsForbidden()) then
            local unit = ME.Read(plate.GetUnit, plate)
            if type(unit) == "string" then ME.units[unit] = true end
        end
    end
end
function ME.RefreshWorld()
    for unit in pairs(ME.units) do ME.UpdatePlate(unit) end
    ME.UpdateTarget()
end
function ME.Preview()
    ME.ShowNotice({ name = "Your future nemesis", status = "enemy", note = "Killed me while fishing." }, true)
    ME.Print("Preview only; no player was added.")
end

local tooltipHooksInstalled = false
local tooltipAnnotated = false
local rebuildingTooltip = false
local function AnnotateTooltip(tooltip)
    if tooltip ~= GameTooltip or not ME.db then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    if tooltipAnnotated then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or ME.IsSecret(unit) or type(unit) ~= "string" then return end
    local entry = ME.Find(ME.Identity(unit))
    if not entry then return end
    local options = ME.db.settings.display[entry.status]
    if not options.tooltip then return end
    local style = ME.styles[entry.status]
    tooltipAnnotated = true
    tooltip:AddLine(" ")
    tooltip:AddLine("Your " .. style.label, style.r, style.g, style.b)
    if options.tooltipNote and entry.note and entry.note ~= "" then
        tooltip:AddLine(entry.note, 0.9, 0.85, 0.75, true)
    end
end
function ME.InitTooltips()
    if tooltipHooksInstalled then return end
    if not GameTooltip or not TooltipDataProcessor or not Enum or not Enum.TooltipDataType then return end
    tooltipHooksInstalled = true
    GameTooltip:HookScript("OnTooltipCleared", function() tooltipAnnotated = false end)
    GameTooltip:HookScript("OnHide", function() tooltipAnnotated = false end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AnnotateTooltip)
end
function ME.RefreshTooltip()
    if rebuildingTooltip or not tooltipHooksInstalled or not GameTooltip:IsShown() then return end
    if GameTooltip.IsForbidden and GameTooltip:IsForbidden() then return end
    -- Rebuild only in response to edits, never on the nameplate polling timer.
    -- This removes stale notes/status lines rather than appending duplicates.
    if GameTooltip.RebuildFromTooltipInfo then
        rebuildingTooltip = true
        pcall(GameTooltip.RebuildFromTooltipInfo, GameTooltip)
        rebuildingTooltip = false
    end
end
