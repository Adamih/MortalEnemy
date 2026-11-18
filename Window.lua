local _, ME = ...
local window, selectedKey
local filter, query = "all", ""
local rowHeight, listHeight = 48, 374
local function Button(parent, text, width, x, y, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetFrameLevel(parent:GetFrameLevel() + 4)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end
local function ScrollList(value)
    value = math.max(0, math.min(window.maxScroll or 0, value))
    window.scrollOffset = value
    window.listScroll:SetVerticalScroll(value)
    window.scrollbar:SetValue(value)
end
local function MakeRow(index)
    local row = CreateFrame("Button", nil, window.listContent)
    row:SetSize(268, 44)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * rowHeight)
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints()
    row.selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.selected:SetVertexColor(1, 0.72, 0.3, 0.65)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 3, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 39, -5)
    row.name:SetWidth(224)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.detail:SetPoint("TOPLEFT", 39, -24)
    row.detail:SetWidth(224)
    row.detail:SetJustifyH("LEFT")
    row:SetScript("OnClick", function(self)
        window.note:ClearFocus()
        selectedKey = self.key
        ME.RefreshWindow()
    end)
    return row
end
function ME.RefreshWindow()
    if not window or not window:IsShown() then return end
    local allEntries, entries = ME.Entries(), {}
    for _, item in ipairs(allEntries) do
        local entry = item.entry
        if (filter == "all" or entry.status == filter)
            and (query == "" or string.lower(entry.name):find(query, 1, true)
                or string.lower(entry.note or ""):find(query, 1, true)) then
            entries[#entries + 1] = item
        end
    end
    local selectedVisible = false
    for _, item in ipairs(entries) do if item.key == selectedKey then selectedVisible = true end end
    if not selectedVisible then selectedKey = entries[1] and entries[1].key end
    window.counter:SetText(#entries .. " shown / " .. #allEntries .. " remembered")
    window.empty:SetText(#allEntries == 0 and "Your book is empty.\nAdd a player or mark your target."
        or "No matching nemeses.")
    window.empty:SetShown(#entries == 0)
    for _, row in ipairs(window.rows) do row:Hide(); row.key = nil end
    for i, item in ipairs(entries) do
        local row = window.rows[i]
        if not row then row = MakeRow(i); window.rows[i] = row end
        local entry, style = item.entry, ME.styles[item.entry.status]
        row.key = item.key
        row.icon:SetTexture(style.icon)
        row.name:SetText(entry.name)
        row.name:SetTextColor(style.r, style.g, style.b)
        row.detail:SetText(style.label)
        row.selected:SetShown(selectedKey == item.key)
        row:Show()
    end
    window.listContent:SetHeight(math.max(listHeight, #entries * rowHeight))
    window.maxScroll = math.max(0, #entries * rowHeight - listHeight)
    window.scrollbar:SetMinMaxValues(0, window.maxScroll)
    window.scrollbar:SetShown(window.maxScroll > 0)
    ScrollList(window.scrollOffset or 0)
    local entry = selectedKey and ME.db.entries[selectedKey]
    window.selection:SetText(entry and entry.name or "Choose a nemesis")
    window.status:SetText(entry and ME.styles[entry.status].label or "Select a name from the list.")
    window.detailIcon:SetShown(entry ~= nil)
    if entry then
        local style = ME.styles[entry.status]
        window.detailIcon:SetTexture(style.icon)
        window.status:SetTextColor(style.r, style.g, style.b)
    end
    window.characterInfo:SetText(entry and ((entry.level and ("Level " .. entry.level) or "Level unknown")
        .. " • " .. (entry.race or "Race unknown") .. " • " .. (entry.class or "Class unknown")) or "")
    local observed = {}
    if entry then
        for _, field in ipairs({ "level", "race", "class" }) do
            local stamp = entry[field .. "ObservedAt"]
            if stamp then
                observed[#observed + 1] = field:sub(1, 1):upper() .. field:sub(2) .. " observed: " .. date("%d %b %Y, %H:%M", stamp)
            end
        end
    end
    window.characterUpdated:SetText(entry and (#observed > 0 and table.concat(observed, "\n")
        or "Target this player to record their character details.") or "")
    window.lastSeen:SetText(entry and (entry.lastSeen
        and ("Last seen: " .. date("%d %b %Y, %H:%M", entry.lastSeen) .. "\n" .. (entry.lastZone or "Unknown zone"))
        or "Last seen: not yet recorded") or "")
    window.added:SetText(entry and entry.added and ("Remembered since " .. date("%d %b %Y", entry.added)) or "")
    if window.editingKey ~= selectedKey or not window.note:HasFocus() then
        window.note:SetText(entry and entry.note or "")
        window.editingKey = selectedKey
    end
    for _, button in ipairs(window.editButtons) do button:SetEnabled(entry ~= nil) end
    ME.RefreshTargetStrip()
end
function ME.RefreshTargetStrip()
    if not window or not window:IsShown() then return end
    local identity = ME.Identity("target")
    local valid = identity and ME.Read(UnitIsUnit, "target", "player") ~= true
    window.targetName:SetText(valid and ("Target: " .. identity.name) or "Target another player on your realm.")
    for _, button in ipairs(window.targetButtons) do button:SetEnabled(valid and true or false) end
end
local function CreateWindow()
    window = CreateFrame("Frame", "MortalEnemyWindow", UIParent, "PortraitFrameTemplate")
    window:SetSize(780, 650)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window.TitleContainer.TitleText:SetText("Mortal Enemy — Book of Grudges")
    window.PortraitContainer.portrait:SetTexture(ME.styles.enemy.icon)
    -- Put our content above the native inset backgrounds without altering them.
    window.Content = CreateFrame("Frame", nil, window)
    window.Content:SetAllPoints(window)
    window.Content:SetFrameLevel(window:GetFrameLevel() + 3)
    window.Content:EnableMouse(false)
    local function Label(text, font, x, y, width)
        local label = window.Content:CreateFontString(nil, "OVERLAY", font)
        label:SetPoint("TOPLEFT", x, y)
        label:SetJustifyH("LEFT")
        if width then label:SetWidth(width) end
        label:SetText(text)
        return label
    end
    Label("A familiar face. An unfinished grudge.", "GameFontHighlightSmall", 70, -38)
    table.insert(UISpecialFrames, "MortalEnemyWindow")
    Button(window, "Add player", 130, 20, -67, function() ME.ShowAddPlayer() end)
    Button(window, "Settings", 110, 650, -67, function() ME.OpenSettings() end)
    local strip = CreateFrame("Frame", nil, window, "InsetFrameTemplate")
    strip:SetPoint("TOPLEFT", 20, -102)
    strip:SetSize(740, 50)
    window.targetName = Label("", "GameFontHighlightSmall", 30, -119, 372)
    window.targetButtons = {
        Button(window, "Mark as Rival", 145, 414, -116, function() ME.SelectEntry(ME.MarkTarget("rival")); end),
        Button(window, "Mark as Mortal Enemy", 183, 567, -116, function() ME.SelectEntry(ME.MarkTarget("enemy")); end),
    }
    local listInset = CreateFrame("Frame", nil, window, "InsetFrameTemplate")
    listInset:SetPoint("TOPLEFT", 20, -170)
    listInset:SetSize(304, 458)
    local detailInset = CreateFrame("Frame", nil, window, "InsetFrameTemplate")
    detailInset:SetPoint("TOPLEFT", 338, -170)
    detailInset:SetSize(422, 458)
    window.search = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    window.search:SetFrameLevel(window:GetFrameLevel() + 4)
    window.search:SetSize(278, 24)
    window.search:SetPoint("TOPLEFT", 30, -180)
    window.search:SetAutoFocus(false)
    window.search:SetMaxLetters(80)
    window.searchHint = window.search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.searchHint:SetPoint("LEFT", 6, 0)
    window.searchHint:SetText("Search names or notes…")
    window.search:SetScript("OnTextChanged", function(self)
        query = string.lower(ME.Trim(self:GetText()))
        window.searchHint:SetShown(query == "")
        window.scrollOffset = 0
        ME.RefreshWindow()
    end)
    window.search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    window.counter = Label("", "GameFontHighlightSmall", 28, -211)
    window.listScroll = CreateFrame("ScrollFrame", nil, window)
    window.listScroll:SetFrameLevel(window:GetFrameLevel() + 4)
    window.listScroll:SetSize(268, listHeight)
    window.listScroll:SetPoint("TOPLEFT", 28, -236)
    window.listContent = CreateFrame("Frame", nil, window.listScroll)
    window.listContent:SetSize(268, listHeight)
    window.listScroll:SetScrollChild(window.listContent)
    window.rows = {}
    window.scrollbar = CreateFrame("Slider", nil, window)
    window.scrollbar:SetFrameLevel(window:GetFrameLevel() + 5)
    window.scrollbar:SetSize(16, listHeight)
    window.scrollbar:SetPoint("TOPLEFT", 304, -236)
    window.scrollbar:SetOrientation("VERTICAL")
    window.scrollbar:SetMinMaxValues(0, 0)
    window.scrollbar:SetValueStep(1)
    window.scrollbar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    window.scrollbar:GetThumbTexture():SetSize(16, 24)
    window.scrollbar:SetScript("OnValueChanged", function(_, value)
        window.scrollOffset = value
        window.listScroll:SetVerticalScroll(value)
    end)
    window.listScroll:EnableMouseWheel(true)
    window.listScroll:SetScript("OnMouseWheel", function(_, delta) ScrollList((window.scrollOffset or 0) - delta * rowHeight) end)
    window.empty = Label("", "GameFontHighlightSmall", 38, -260, 240)
    window.detailIcon = window.Content:CreateTexture(nil, "ARTWORK")
    window.detailIcon:SetSize(36, 36)
    window.detailIcon:SetPoint("TOPLEFT", 354, -188)
    window.selection = Label("", "GameFontNormalLarge", 400, -188, 342)
    window.selection:SetWordWrap(false)
    window.status = Label("", "GameFontHighlight", 400, -215, 342)
    window.characterInfo = Label("", "GameFontHighlight", 354, -249, 386)
    window.characterInfo:SetWordWrap(false)
    window.characterUpdated = Label("", "GameFontDisableSmall", 354, -271, 386)
    window.lastSeen = Label("", "GameFontHighlightSmall", 354, -326, 386)
    window.added = Label("", "GameFontDisableSmall", 354, -364, 386)
    Label("Your grudge", "GameFontNormal", 354, -397)
    local noteInset = CreateFrame("Frame", nil, window, "InsetFrameTemplate")
    noteInset:SetPoint("TOPLEFT", 350, -419)
    noteInset:SetSize(394, 108)
    window.note = CreateFrame("EditBox", nil, window)
    window.note:SetFrameLevel(window:GetFrameLevel() + 4)
    window.note:SetSize(378, 92)
    window.note:SetPoint("TOPLEFT", 358, -427)
    window.note:SetFontObject("ChatFontNormal")
    window.note:SetTextColor(0.95, 0.9, 0.8)
    window.note:SetMultiLine(true)
    window.note:SetAutoFocus(false)
    window.note:SetMaxLetters(240)
    window.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function SaveNote()
        local entry = selectedKey and ME.db.entries[selectedKey]
        if entry then
            entry.note = ME.Note(window.note:GetText())
            window.note:ClearFocus()
            ME.Print("Note saved.")
            ME.Changed()
        end
    end
    window.note:SetScript("OnEnterPressed", SaveNote)
    window.editButtons = {
        Button(window, "Save note", 120, 354, -537, SaveNote),
        Button(window, "Remove", 120, 622, -537, function() if selectedKey then ME.Remove(selectedKey) end end),
        Button(window, "Rival", 150, 354, -575, function()
            if selectedKey and ME.db.entries[selectedKey] then ME.db.entries[selectedKey].status = "rival"; ME.Changed() end
        end),
        Button(window, "Mortal Enemy", 182, 512, -575, function()
            if selectedKey and ME.db.entries[selectedKey] then ME.db.entries[selectedKey].status = "enemy"; ME.Changed() end
        end),
    }
    window.filterTabs = {}
    for i, item in ipairs({ { "all", "All" }, { "rival", "Rivals" }, { "enemy", "Enemies" } }) do
        local tab = CreateFrame("Button", nil, window, "PanelTabButtonTemplate")
        tab:SetText(item[2])
        tab:SetPoint("TOPLEFT", 24 + (i - 1) * 104, -645)
        PanelTemplates_TabResize(tab, 0, 96)
        tab:SetScript("OnClick", function()
            filter = item[1]
            window.scrollOffset = 0
            for _, other in ipairs(window.filterTabs) do PanelTemplates_DeselectTab(other) end
            PanelTemplates_SelectTab(tab)
            ME.RefreshWindow()
        end)
        window.filterTabs[i] = tab
        if item[1] == filter then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
    end
    window:SetScript("OnShow", ME.RefreshWindow)
    window:Hide()
end
function ME.SelectEntry(key)
    if not key then return end
    selectedKey, filter, query = key, "all", ""
    if not window then CreateWindow() end
    window.search:SetText("")
    window:Show()
    for i, tab in ipairs(window.filterTabs) do
        if i == 1 then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
    end
    ME.RefreshWindow()
    for i, item in ipairs(ME.Entries()) do if item.key == key then ScrollList((i - 1) * rowHeight); break end end
end
function ME.ToggleWindow()
    if not window then CreateWindow() end
    window:SetShown(not window:IsShown())
end

local addDialog
function ME.ShowAddPlayer()
    if not addDialog then
        addDialog = CreateFrame("Frame", "MortalEnemyAddDialog", UIParent, "PortraitFrameTemplate")
        addDialog:SetSize(400, 286)
        addDialog:SetPoint("CENTER")
        addDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        addDialog:SetClampedToScreen(true)
        addDialog:EnableMouse(true)
        addDialog.TitleContainer.TitleText:SetText("Add a player")
        addDialog.PortraitContainer.portrait:SetTexture(ME.styles.enemy.icon)
        local function Label(text, x, y)
            local label = addDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("TOPLEFT", x, y)
            label:SetText(text)
            return label
        end
        table.insert(UISpecialFrames, "MortalEnemyAddDialog")
        local function Edit(label, width, x, y, maxLetters)
            Label(label, x, y)
            local edit = CreateFrame("EditBox", nil, addDialog, "InputBoxTemplate")
            edit:SetSize(width, 26)
            edit:SetPoint("TOPLEFT", x + 4, y - 20)
            edit:SetAutoFocus(false)
            edit:SetMaxLetters(maxLetters)
            edit:SetScript("OnEscapePressed", function() addDialog:Hide() end)
            return edit
        end
        addDialog.first = Edit("First name", 164, 20, -58, 48)
        addDialog.last = Edit("Last name", 164, 208, -58, 48)
        addDialog.note = Edit("Note (optional)", 352, 20, -128, 240)
        addDialog.first:SetScript("OnTabPressed", function() addDialog.last:SetFocus() end)
        addDialog.last:SetScript("OnTabPressed", function() addDialog.note:SetFocus() end)
        addDialog.error = Label("", 20, -194)
        addDialog.error:SetTextColor(1, 0.3, 0.3)
        addDialog.error:SetWidth(360)
        addDialog.error:SetJustifyH("LEFT")
        local function Add(status)
            local key, reason = ME.AddNamedPlayer(addDialog.first:GetText() .. " " .. addDialog.last:GetText(), status, addDialog.note:GetText())
            if not key then addDialog.error:SetText(reason); return end
            addDialog:Hide()
            ME.SelectEntry(key)
        end
        Button(addDialog, "Add Rival", 164, 20, -234, function() Add("rival") end)
        Button(addDialog, "Add Mortal Enemy", 184, 196, -234, function() Add("enemy") end)
    end
    addDialog.first:SetText("")
    addDialog.last:SetText("")
    addDialog.note:SetText("")
    addDialog.error:SetText("")
    addDialog:Show()
    addDialog.first:SetFocus()
end

local settingsPanel, settingsCategory
function ME.RefreshSettings()
    if not settingsPanel or not settingsPanel:IsShown() then return end
    for key, check in pairs(settingsPanel.checks) do check:SetChecked(ME.db.settings[key]) end
    for status, checks in pairs(settingsPanel.displayChecks) do
        for key, check in pairs(checks) do check:SetChecked(ME.db.settings.display[status][key]) end
    end
end
function ME.InitSettings()
    if settingsCategory or not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    settingsPanel = CreateFrame("Frame", "MortalEnemySettingsPanel")
    local function Label(text, font, x, y)
        local label = settingsPanel:CreateFontString(nil, "OVERLAY", font)
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(text)
        return label
    end
    Label("Mortal Enemy", "GameFontNormalLarge", 20, -20)
    Label("Display and encounter preferences for this character.", "GameFontHighlight", 20, -50)
    Label("Open-world display", "GameFontNormal", 20, -94)
    local columns = { { "badge", "Icon badge", 180 }, { "tooltip", "Tooltip", 300 }, { "tooltipNote", "Note", 420 } }
    for _, column in ipairs(columns) do Label(column[2], "GameFontHighlightSmall", column[3], -120) end
    settingsPanel.displayChecks = {}
    for i, status in ipairs({ "rival", "enemy" }) do
        local y = -140 - (i - 1) * 36
        local style = ME.styles[status]
        local label = Label(style.label, "GameFontNormal", 20, y - 9)
        label:SetTextColor(style.r, style.g, style.b)
        settingsPanel.displayChecks[status] = {}
        for _, column in ipairs(columns) do
            local key = column[1]
            local check = CreateFrame("CheckButton", nil, settingsPanel, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", column[3], y)
            check:SetScript("OnClick", function(self)
                ME.db.settings.display[status][key] = self:GetChecked() and true or false
                ME.Changed()
            end)
            settingsPanel.displayChecks[status][key] = check
        end
    end
    settingsPanel.checks = {}
    for i, item in ipairs({ { "alerts", "Encounter alerts" }, { "sound", "Alert sound" }, { "showMinimap", "Show minimap button" } }) do
        local key = item[1]
        local check = CreateFrame("CheckButton", nil, settingsPanel, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 20, -234 - (i - 1) * 34)
        local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 0, 0)
        label:SetText(item[2])
        check:SetScript("OnClick", function(self) ME.db.settings[key] = self:GetChecked() and true or false; ME.Changed() end)
        settingsPanel.checks[key] = check
    end
    Button(settingsPanel, "Preview alert", 150, 20, -356, ME.Preview)
    Button(settingsPanel, "Open nemesis list", 170, 180, -356, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if not window then CreateWindow() end
        window:Show()
    end)
    settingsPanel:SetScript("OnShow", ME.RefreshSettings)
    settingsPanel:Hide()
    settingsCategory = Settings.RegisterCanvasLayoutCategory(settingsPanel, "Mortal Enemy")
    Settings.RegisterAddOnCategory(settingsCategory)
end
function ME.OpenSettings()
    ME.InitSettings()
    if not settingsCategory then ME.Print("The game's AddOns settings are not available yet."); return end
    if window then window:Hide() end
    Settings.OpenToCategory(settingsCategory:GetID())
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
    ME.UpdateMinimap()
end
function ME.UpdateMinimap()
    if minimapButton then minimapButton:SetShown(ME.db.settings.showMinimap) end
end
function ME.InitMinimap()
    if not Minimap then return end
    if minimapButton then MinimapPosition(); ME.UpdateMinimap(); return end
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
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
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
    ME.UpdateMinimap()
end
