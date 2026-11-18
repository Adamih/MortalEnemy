local _, ME = ...
ME.units = {}
local badges, encounters = {}, {}
local notice, targetBadge
local function MakeBadge(parent)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(180, 26)
    badge:EnableMouse(false)
    badge.icon = badge:CreateTexture(nil, "OVERLAY")
    badge.icon:SetSize(24, 24)
    badge.icon:SetPoint("LEFT")
    badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge.text:SetPoint("LEFT", badge.icon, "RIGHT", 4, 0)
    badge.text:SetShadowOffset(1, -1)
    badge:Hide()
    return badge
end
local function Paint(badge, entry)
    local style = ME.styles[entry.status]
    badge.icon:SetTexture(style.icon)
    badge.text:SetText(style.label)
    badge.text:SetTextColor(style.r, style.g, style.b)
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
function ME.UpdatePlate(unit)
    local badge = badges[unit]
    if badge then badge:Hide() end
    if not ME.units[unit] then return end
    local entry, key = ME.Find(ME.Identity(unit))
    if not entry then return end
    ME.Observe(entry, key)
    if not ME.db.settings.badges then return end
    local plate = ME.Read(C_NamePlate and C_NamePlate.GetNamePlateForUnit, unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    if not badge then badge = MakeBadge(plate); badges[unit] = badge end
    badge:SetParent(plate)
    badge:ClearAllPoints()
    badge:SetPoint("BOTTOM", plate, "TOP", 0, 8)
    Paint(badge, entry)
end
function ME.RemovePlate(unit)
    ME.units[unit] = nil
    if badges[unit] then badges[unit]:Hide() end
end
function ME.UpdateTarget()
    if targetBadge then targetBadge:Hide() end
    local entry, key = ME.Find(ME.Identity("target"))
    if not entry then return end
    ME.Observe(entry, key)
    if not ME.db.settings.badges then return end
    if not targetBadge then
        targetBadge = MakeBadge(UIParent)
        -- Independent of Blizzard's protected target frame and other addon layouts.
        targetBadge:SetPoint("TOP", UIParent, "TOP", 0, -80)
    end
    Paint(targetBadge, entry)
    targetBadge.text:SetText(ME.styles[entry.status].label .. ": " .. entry.name)
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
