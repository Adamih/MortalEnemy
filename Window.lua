local _, ME = ...
local window, selectedKey
local page, pageSize = 1, 6
local function Button(parent, text, width, x, y, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end
function ME.RefreshWindow()
    if not window or not window:IsShown() then return end
    local entries = ME.Entries()
    local pages = math.max(1, math.ceil(#entries / pageSize))
    page = math.max(1, math.min(page, pages))
    window.counter:SetText(#entries .. " remembered  •  " .. page .. " / " .. pages)
    window.empty:SetShown(#entries == 0)
    for i, row in ipairs(window.rows) do
        local item = entries[(page - 1) * pageSize + i]
        row:Hide()
        if item then
            local entry, style = item.entry, ME.styles[item.entry.status]
            row.key = item.key
            row.icon:SetTexture(style.icon)
            row.name:SetText(entry.name)
            row.name:SetTextColor(style.r, style.g, style.b)
            row.detail:SetText(style.label .. (entry.lastSeen and (" • " .. (entry.lastZone or "Unknown") .. " • " .. date("%d %b %H:%M", entry.lastSeen)) or " • Not seen yet"))
            row.selected:SetShown(selectedKey == item.key)
            row:Show()
        end
    end
    local entry = selectedKey and ME.db.entries[selectedKey]
    window.selection:SetText(entry and ("Selected: " .. entry.name) or "Select a player above to edit their note or status.")
    if window.editingKey ~= selectedKey or not window.note:HasFocus() then
        window.note:SetText(entry and entry.note or "")
        window.editingKey = selectedKey
    end
    for _, button in ipairs(window.editButtons) do button:SetEnabled(entry ~= nil) end
    for key, check in pairs(window.checks) do check:SetChecked(ME.db.settings[key]) end
    for status, checks in pairs(window.displayChecks) do
        for key, check in pairs(checks) do check:SetChecked(ME.db.settings.display[status][key]) end
    end
end
local function CreateWindow()
    window = CreateFrame("Frame", "MortalEnemyWindow", UIParent, "BackdropTemplate")
    window:SetSize(530, 716)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    window:SetBackdropColor(0.055, 0.045, 0.04, 0.98)
    window:SetBackdropBorderColor(0.48, 0.26, 0.2, 1)
    local function Label(text, font, x, y)
        local label = window:CreateFontString(nil, "OVERLAY", font)
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(text)
        return label
    end
    Label("MORTAL ENEMY", "GameFontNormalLarge", 20, -19)
    Label("A familiar face. An unfinished grudge.", "GameFontHighlightSmall", 20, -44)
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    table.insert(UISpecialFrames, "MortalEnemyWindow")
    Button(window, "Target: Rival", 140, 20, -68, function() selectedKey = ME.MarkTarget("rival") or selectedKey; ME.RefreshWindow() end)
    Button(window, "Target: Mortal Enemy", 184, 168, -68, function() selectedKey = ME.MarkTarget("enemy") or selectedKey; ME.RefreshWindow() end)
    Button(window, "Preview alert", 148, 360, -68, ME.Preview)
    window.counter = Label("", "GameFontHighlightSmall", 20, -106)
    window.empty = Label("Your book is empty. Target a player and mark them above.", "GameFontHighlight", 26, -167)
    window.rows = {}
    for i = 1, pageSize do
        local row = CreateFrame("Button", nil, window)
        row:SetSize(486, 39)
        row:SetPoint("TOPLEFT", 22, -128 - (i - 1) * 42)
        row.selected = row:CreateTexture(nil, "BACKGROUND")
        row.selected:SetAllPoints()
        row.selected:SetColorTexture(0.4, 0.22, 0.12, 0.5)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(30, 30)
        row.icon:SetPoint("LEFT", 3, 0)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.name:SetPoint("TOPLEFT", 42, -3)
        row.name:SetWidth(436)
        row.name:SetJustifyH("LEFT")
        row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.detail:SetPoint("TOPLEFT", 42, -21)
        row.detail:SetWidth(436)
        row.detail:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self) selectedKey = self.key; ME.RefreshWindow() end)
        window.rows[i] = row
    end
    Button(window, "Previous", 100, 20, -385, function() page = page - 1; ME.RefreshWindow() end)
    Button(window, "Next", 100, 128, -385, function() page = page + 1; ME.RefreshWindow() end)
    window.selection = Label("", "GameFontHighlightSmall", 20, -423)
    window.note = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    window.note:SetSize(478, 26)
    window.note:SetPoint("TOPLEFT", 26, -444)
    window.note:SetAutoFocus(false)
    window.note:SetMaxLetters(240)
    window.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function SaveNote()
        local entry = selectedKey and ME.db.entries[selectedKey]
        if entry then entry.note = ME.Note(window.note:GetText()); ME.Print("Note saved."); window.note:ClearFocus() end
    end
    window.note:SetScript("OnEnterPressed", SaveNote)
    window.editButtons = {
        Button(window, "Save note", 106, 20, -481, SaveNote),
        Button(window, "Rival", 100, 134, -481, function()
            if selectedKey and ME.db.entries[selectedKey] then ME.db.entries[selectedKey].status = "rival"; ME.Changed() end
        end),
        Button(window, "Mortal Enemy", 140, 242, -481, function()
            if selectedKey and ME.db.entries[selectedKey] then ME.db.entries[selectedKey].status = "enemy"; ME.Changed() end
        end),
        Button(window, "Remove", 118, 390, -481, function() if selectedKey then ME.Remove(selectedKey); selectedKey = nil; ME.RefreshWindow() end end),
    }
    Label("OPEN WORLD DISPLAY", "GameFontNormal", 20, -523)
    local columns = {
        { "badge", "Badge", 180 }, { "tooltip", "Tooltip", 300 },
        { "tooltipNote", "Note", 420 },
    }
    for _, column in ipairs(columns) do Label(column[2], "GameFontHighlightSmall", column[3], -549) end
    window.displayChecks = {}
    for i, status in ipairs({ "rival", "enemy" }) do
        local y = -568 - (i - 1) * 32
        local style = ME.styles[status]
        local label = Label(style.label, "GameFontNormal", 20, y - 9)
        label:SetTextColor(style.r, style.g, style.b)
        window.displayChecks[status] = {}
        for _, column in ipairs(columns) do
            local key = column[1]
            local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", column[3], y)
            check:SetScript("OnClick", function(self)
                ME.db.settings.display[status][key] = self:GetChecked() and true or false
                ME.Changed()
            end)
            window.displayChecks[status][key] = check
        end
    end
    window.checks = {}
    for i, item in ipairs({ { "alerts", "Encounter alerts" }, { "sound", "Sound" } }) do
        local key = item[1]
        local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 20 + (i - 1) * 180, -646)
        local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", check, "RIGHT", 0, 0)
        label:SetText(item[2])
        check:SetScript("OnClick", function(self) ME.db.settings[key] = self:GetChecked() and true or false; ME.Changed() end)
        window.checks[key] = check
    end
    Label("/mortal help  •  /mortal diagnose  •  Drag window to move", "GameFontDisableSmall", 20, -690)
    window:SetScript("OnShow", ME.RefreshWindow)
    window:Hide()
end
function ME.ToggleWindow()
    if not window then CreateWindow() end
    window:SetShown(not window:IsShown())
end

local minimapButton
local function MinimapPosition()
    if not minimapButton or not Minimap or not ME.db then return end
    local angle = math.rad(ME.db.settings.minimapAngle)
    local x, y = math.cos(angle), math.sin(angle)
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local extent = math.max(math.abs(x), math.abs(y))
        x, y = x / extent, y / extent
    end
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER",
        x * (Minimap:GetWidth() / 2 + 8), y * (Minimap:GetHeight() / 2 + 8))
end
local function DragMinimapButton(self)
    local cx, cy = Minimap:GetCenter()
    if not cx or not cy then return end
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    x, y = x / scale - cx, y / scale - cy
    if x == 0 and y == 0 then return end
    local angle
    if math.atan2 then
        angle = math.atan2(y, x)
    elseif x == 0 then
        angle = y > 0 and math.pi / 2 or -math.pi / 2
    else
        angle = math.atan(y / x)
        if x < 0 then angle = angle + math.pi end
    end
    ME.db.settings.minimapAngle = math.deg(angle) % 360
    MinimapPosition()
end
function ME.InitMinimap()
    if not Minimap then return end
    if minimapButton then MinimapPosition(); return end
    minimapButton = CreateFrame("Button", "MortalEnemyMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    minimapButton:RegisterForClicks("LeftButtonUp")
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    local background = minimapButton:CreateTexture(nil, "BACKGROUND")
    background:SetSize(25, 25)
    background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    minimapButton.icon = minimapButton:CreateTexture(nil, "ARTWORK")
    minimapButton.icon:SetSize(20, 20)
    minimapButton.icon:SetPoint("TOPLEFT", 7, -5)
    minimapButton.icon:SetTexture(ME.styles.enemy.icon)
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    minimapButton:SetScript("OnMouseDown", function(self) self.suppressClick = false end)
    minimapButton:SetScript("OnClick", function(self)
        if not self.suppressClick then ME.ToggleWindow() end
    end)
    minimapButton:SetScript("OnDragStart", function(self)
        self.dragging, self.suppressClick = true, true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", DragMinimapButton)
        DragMinimapButton(self)
    end)
    local function StopDragging(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end
    minimapButton:SetScript("OnDragStop", StopDragging)
    minimapButton:SetScript("OnHide", StopDragging)
    minimapButton:SetScript("OnEnter", function(self)
        if self.dragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Mortal Enemy", 1, 0.75, 0.3)
        GameTooltip:AddLine("Click to open or close your nemesis list.", 1, 1, 1)
        GameTooltip:AddLine("Drag to move around the minimap.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    MinimapPosition()
end
