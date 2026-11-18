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
            row.name:SetText(entry.name .. "-" .. entry.realm)
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
end
local function CreateWindow()
    window = CreateFrame("Frame", "MortalEnemyWindow", UIParent, "BackdropTemplate")
    window:SetSize(530, 586)
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
    window.checks = {}
    for i, item in ipairs({ { "badges", "Badges" }, { "alerts", "Alerts" }, { "sound", "Sound" } }) do
        local key = item[1]
        local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 20 + (i - 1) * 125, -522)
        local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", check, "RIGHT", 0, 0)
        label:SetText(item[2])
        check:SetScript("OnClick", function(self) ME.db.settings[key] = self:GetChecked() and true or false; ME.RefreshWorld() end)
        window.checks[key] = check
    end
    Label("/mortal help  •  /mortal diagnose  •  Drag window to move", "GameFontDisableSmall", 20, -562)
    window:SetScript("OnShow", ME.RefreshWindow)
    window:Hide()
end
function ME.ToggleWindow()
    if not window then CreateWindow() end
    window:SetShown(not window:IsShown())
end
