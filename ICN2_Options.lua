-- ============================================================
-- ICN2_Options.lua
-- Scalable, tabbed options for HUD, immersion, emotes, manual
-- controls, and decay rates. Settings and callbacks remain unchanged.
-- ============================================================

ICN2 = ICN2 or {}

local L = setmetatable({}, { __index = function(_, k)
    return ICN2.L and ICN2.L[k] or k
end })

local optFrame
local panelGeneral
local panelDecay
local tabBtnGeneral
local tabBtnDecay
local presetBtns = {}
local decaySliders = {}
local labelDropdown
local barLengthSlider

local COLORS = {
    orange = { 1.0, 0.55, 0.08 },
    gold = { 1.0, 0.82, 0.25 },
    text = { 0.92, 0.92, 0.92 },
    muted = { 0.62, 0.64, 0.68 },
    panel = { 0.055, 0.065, 0.085, 0.96 },
    card = { 0.075, 0.085, 0.11, 0.98 },
    cardBorder = { 0.22, 0.24, 0.30, 0.9 },
}

local function setTextColor(fs, color)
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function makeLabel(parent, text, x, y, font, color, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then fs:SetWidth(width) end
    fs:SetText(text)
    if color then setTextColor(fs, color) end
    return fs
end

local function makeCard(parent, title, y, height)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    -- Reserve room for Blizzard template chrome (dropdown arrows and slider
    -- endpoint labels), which extends slightly beyond the nominal width.
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, y)
    card:SetHeight(height)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    card:SetBackdropColor(unpack(COLORS.card))
    card:SetBackdropBorderColor(unpack(COLORS.cardBorder))
    makeLabel(card, title, 16, -14, "GameFontNormalLarge", COLORS.gold)
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -38)
    rule:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -38)
    rule:SetHeight(1)
    rule:SetColorTexture(1.0, 0.55, 0.08, 0.35)
    local bottomRule = card:CreateTexture(nil, "ARTWORK")
    bottomRule:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 1)
    bottomRule:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -16, 1)
    bottomRule:SetHeight(1)
    bottomRule:SetColorTexture(0.22, 0.24, 0.30, 0.9)
    return card
end

local function makeCheckbox(parent, label, x, y, getter, setter, width)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetSize(26, 26)
    cb.text:ClearAllPoints()
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.text:SetText(label)
    cb.text:SetTextColor(unpack(COLORS.text))
    cb.text:SetWidth(width or 430)
    cb.text:SetJustifyH("LEFT")
    cb:SetChecked(getter())
    cb:SetScript("OnClick", function(self) setter(self:GetChecked()) end)
    return cb
end

local function formatSliderValue(value, decimals)
    return string.format(decimals == 0 and "%.0f" or "%.2f", value)
end

local function makeSlider(parent, labelText, x, y, width, minVal, maxVal, step, getter, setter, decimals)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(width or 280)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(getter())
    slider.Low:SetText(formatSliderValue(minVal, decimals))
    slider.High:SetText(formatSliderValue(maxVal, decimals))
    slider.Text:SetText(labelText .. ": " .. formatSliderValue(getter(), decimals))
    slider.Text:SetTextColor(unpack(COLORS.text))
    slider:SetScript("OnValueChanged", function(self, val)
        setter(val)
        self.Text:SetText(labelText .. ": " .. formatSliderValue(val, decimals))
    end)
    return slider
end

local function makeActionButton(parent, text, x, y, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 92, 28)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function makeSeparator(parent, x, y, width)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    tex:SetSize(width or 350, 1)
    tex:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    return tex
end

local function roundBias(n) return math.floor((tonumber(n) or 0) + 0.5) end

local function getBiasForUI(needKey)
    local s = ICN2DB.settings
    if s.preset == "custom" then
        return roundBias((s.customDecayBias and s.customDecayBias[needKey]) or 1)
    end
    return roundBias(ICN2:PresetMultiplierToBiasDisplay(ICN2.PRESETS[s.preset] or 1.0))
end

local function formatBiasLabel(needLabel, sliderPos, decayMult, readOnly)
    return string.format(L[readOnly and "BIAS_LABEL_READONLY" or "BIAS_LABEL"], needLabel, sliderPos, decayMult)
end

local function refreshDecaySliders()
    local s, isCustom = ICN2DB.settings, ICN2DB.settings.preset == "custom"
    local presetGlobal = ICN2.PRESETS[s.preset] or 1.0
    for _, row in ipairs(decaySliders) do
        local bias = getBiasForUI(row.needKey)
        local mult = isCustom and ICN2:DecayBiasToMultiplier((s.customDecayBias and s.customDecayBias[row.needKey]) or 1) or presetGlobal
        row.slider:SetValue(bias)
        row.slider.Text:SetText(formatBiasLabel(row.needLabel, bias, mult, not isCustom))
        if isCustom then row.slider:Enable() else row.slider:Disable() end
    end
end

local function makeDecayBiasSlider(parent, needKey, needLabel, y)
    local maxM = ICN2.CUSTOM_DECAY_MULTIPLIER_MAX or 30
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
    slider:SetWidth(450)
    slider:SetMinMaxValues(0, maxM)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("0"); slider.High:SetText(tostring(maxM))
    slider:SetScript("OnValueChanged", function(self, val)
        val = math.max(0, math.min(maxM, math.floor(val + 0.5)))
        if ICN2DB.settings.preset ~= "custom" then self:SetValue(getBiasForUI(needKey)); return end
        ICN2DB.settings.customDecayBias = ICN2DB.settings.customDecayBias or { hunger = 1, thirst = 1, fatigue = 1 }
        ICN2DB.settings.customDecayBias[needKey] = val
        self.Text:SetText(formatBiasLabel(needLabel, val, ICN2:DecayBiasToMultiplier(val), false))
    end)
    table.insert(decaySliders, { slider = slider, needKey = needKey, needLabel = needLabel })
    return slider
end

local function selectOptionsTab(which)
    local general = which == 1
    panelGeneral:SetShown(general)
    panelDecay:SetShown(not general)
    tabBtnGeneral:SetSelected(general)
    tabBtnDecay:SetSelected(not general)
    if not general then refreshDecaySliders() end
end

local function makeTabButton(parent, text, y, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(144, 42)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    b:SetNormalFontObject("GameFontNormal")
    b:SetHighlightFontObject("GameFontHighlight")
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    b.SetSelected = function(self, selected)
        self.selected = selected
        self:SetAlpha(selected and 1 or 0.58)
        self:GetFontString():SetTextColor(selected and 1 or 0.78, selected and 0.82 or 0.78, selected and 0.25 or 0.78)
    end
    return b
end

local function UpdateThemeDependencies()
    if not labelDropdown or not barLengthSlider then return end
    local theme = ICN2.HUD_THEMES and ICN2.HUD_THEMES[ICN2DB.settings.barTheme or "colorful"]
    local showBars = not (theme and theme.layout and theme.layout.showBars == false)
    UIDropDownMenu_EnableDropDown(labelDropdown)
    labelDropdown:SetAlpha(1)
    if showBars then barLengthSlider:Enable(); barLengthSlider:SetAlpha(1) else barLengthSlider:Disable(); barLengthSlider:SetAlpha(0.5) end
end

local function makeDropdown(parent, name, label, x, y, width, getText, values, onSelect)
    makeLabel(parent, label, x, y + 4, "GameFontHighlight", COLORS.muted)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 112, y + 12)
    UIDropDownMenu_SetWidth(dropdown, width or 170)
    UIDropDownMenu_SetText(dropdown, getText())
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        for _, item in ipairs(values()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value, info.checked = item.label, item.id, item.id == getText(true)
            info.func = function() onSelect(item); UIDropDownMenu_SetText(dropdown, item.label); CloseDropDownMenus() end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    return dropdown
end

function ICN2:BuildOptions()
    optFrame = CreateFrame("Frame", "ICN2OptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    optFrame:SetSize(780, 690)
    optFrame:SetPoint("CENTER")
    optFrame:SetFrameStrata("HIGH")
    optFrame:SetMovable(true); optFrame:EnableMouse(true); optFrame:RegisterForDrag("LeftButton")
    optFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    optFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    optFrame:Hide()
    optFrame.TitleText:SetText(L["OPT_TITLE"])

    local sidebar = CreateFrame("Frame", nil, optFrame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 8, -28); sidebar:SetPoint("BOTTOMLEFT", optFrame, "BOTTOMLEFT", 8, 8); sidebar:SetWidth(168)
    sidebar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" }); sidebar:SetBackdropColor(0.035, 0.04, 0.055, 0.96)
    makeLabel(sidebar, "ICN2", 18, -24, "GameFontNormalLarge", COLORS.orange)
    makeLabel(sidebar, "Character needs", 18, -47, "GameFontHighlightSmall", COLORS.muted)
    tabBtnGeneral = makeTabButton(sidebar, L["TAB_GENERAL"], -78, function() selectOptionsTab(1) end)
    tabBtnDecay = makeTabButton(sidebar, L["TAB_DECAY"], -124, function() selectOptionsTab(2) end)
    makeLabel(sidebar, "3.1.0", 18, -184, "GameFontDisableSmall", COLORS.muted)
    makeLabel(sidebar, "Changes apply instantly", 18, -207, "GameFontDisableSmall", COLORS.muted, 130)

    local content = CreateFrame("Frame", nil, optFrame)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 12, 0); content:SetPoint("BOTTOMRIGHT", optFrame, "BOTTOMRIGHT", -14, 8)
    local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -4); scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -16, 4)
    local scrollChild = CreateFrame("Frame", nil, scroll)
    -- Keep the scroll child inside the window's usable width. The old 575px
    -- child was wider than the viewport at the default UI scale and clipped
    -- the right-hand HUD controls.
    scrollChild:SetWidth(540); scrollChild:SetHeight(1400); scroll:SetScrollChild(scrollChild)
    panelGeneral = CreateFrame("Frame", nil, scrollChild); panelGeneral:SetAllPoints(scrollChild)
    panelDecay = CreateFrame("Frame", nil, scrollChild); panelDecay:SetAllPoints(scrollChild); panelDecay:Hide()

    local hud = makeCard(panelGeneral, L["OPT_SEC_HUD"], -4, 330)
    makeCheckbox(hud, L["OPT_HUD_ENABLED"], 18, -52, function() return ICN2DB.settings.hudEnabled end, function(v) ICN2DB.settings.hudEnabled = v; ICN2:UpdateHUD() end, 235)
    makeCheckbox(hud, L["OPT_HUD_LOCKED"], 18, -82, function() return ICN2DB.settings.hudLocked end, function(v) ICN2DB.settings.hudLocked = v; ICN2:LockHUD(v) end, 235)
    makeCheckbox(hud, L["OPT_MINIMAP_BUTTON"], 18, -112, function() return ICN2DB.settings.minimapButton end, function(v) ICN2DB.settings.minimapButton = v; ICN2:SetMinimapButtonShown(v) end, 235)
    makeSlider(hud, L["OPT_OPACITY"], 18, -190, 210, 0.1, 1.0, 0.05, function() return ICN2DB.settings.hudAlpha end, function(v) ICN2DB.settings.hudAlpha = v; local f = _G["ICN2HUDFrame"]; if f then f:SetAlpha(v) end end, 2)
    makeSlider(hud, L["OPT_SCALE"], 275, -190, 200, 0.5, 2.0, 0.1, function() return ICN2DB.settings.hudScale end, function(v) ICN2DB.settings.hudScale = v; local f = _G["ICN2HUDFrame"]; if f then f:SetScale(v) end end, 2)
    barLengthSlider = makeSlider(hud, L["OPT_BAR_LENGTH"], 18, -262, 220, 0.5, 1.5, 0.05, function() return ICN2DB.settings.hudBarScale or 1 end, function(v) ICN2DB.settings.hudBarScale = v; ICN2:ResizeBarLength() end, 2)
    local themeValues = function() local result = {}; for _, t in ipairs(ICN2.HUD_THEME_LIST or {}) do table.insert(result, { id = t.id, label = t.label }) end; return result end
    local themeText = function(raw) local id = ICN2DB.settings.barTheme or "smooth"; if raw then return id end; for _, t in ipairs(themeValues()) do if t.id == id then return t.label end end; return id end
    makeDropdown(hud, "ICN2ThemeDropdown", L["OPT_SEC_THEME"], 245, -48, 125, themeText, themeValues, function(item) ICN2:SetBarTheme(item.id); UpdateThemeDependencies() end)
    local palettes = function() local result = {}; for name in pairs(ICN2.Palettes or {}) do table.insert(result, { id = name, label = name:gsub("_", " ") }) end; table.sort(result, function(a,b) return a.label < b.label end); return result end
    local paletteText = function(raw) local id = ICN2DB.settings.colorPalette or "Default"; return raw and id or id:gsub("_", " ") end
    makeDropdown(hud, "ICN2PaletteDropdown", "Color Palette", 245, -96, 125, paletteText, palettes, function(item) ICN2DB.settings.colorPalette = item.id; ICN2:UpdateHUD() end)
    local labelModes = function() return { {id="none",label=L["LABEL_NONE"]}, {id="percentage",label=L["LABEL_PERCENTAGE"]}, {id="number",label=L["LABEL_NUMBER"]}, {id="both",label=L["LABEL_BOTH"]} } end
    local labelText = function(raw) local id = ICN2DB.settings.barLabelMode or "percentage"; if raw then return id end; for _, item in ipairs(labelModes()) do if item.id == id then return item.label end end end
    labelDropdown = makeDropdown(hud, "ICN2LabelDropdown", L["OPT_SEC_LABEL_MODE"], 245, -144, 125, labelText, labelModes, function(item) ICN2DB.settings.barLabelMode = item.id; ICN2:UpdateHUD() end)

    local immersion = makeCard(panelGeneral, L["OPT_SEC_IMMERSION"], -346, 112)
    makeCheckbox(immersion, L["OPT_FREEZE_OFFLINE"], 18, -52, function() return ICN2DB.settings.freezeOfflineNeeds end, function(v) ICN2DB.settings.freezeOfflineNeeds = v end)
    makeLabel(immersion, L["OPT_FOOD_AUTO"], 52, -82, "GameFontHighlightSmall", COLORS.muted, 480)

    local alerts = makeCard(panelGeneral, L["OPT_SEC_ALERTS"], -470, 350)
    makeCheckbox(alerts, L["OPT_ALERTS_ENABLED"], 18, -54, function() return ICN2DB.settings.alertsEnabled end, function(v) ICN2DB.settings.alertsEnabled = v; ICN2:UpdateAlerts() end, 220)
    makeCheckbox(alerts, L["OPT_ALERT_SOUND_ENABLED"], 18, -90, function() return ICN2DB.settings.alertSoundEnabled end, function(v) ICN2DB.settings.alertSoundEnabled = v end, 220)
    makeCheckbox(alerts, L["OPT_ALERT_DURING_COMBAT"], 18, -126, function() return ICN2DB.settings.alertDuringCombat end, function(v) ICN2DB.settings.alertDuringCombat = v end, 220)
    makeCheckbox(alerts, L["OPT_ALERT_HUNGER"], 275, -54, function() return ICN2DB.settings.alertHunger end, function(v) ICN2DB.settings.alertHunger = v; ICN2:UpdateAlerts() end, 220)
    makeCheckbox(alerts, L["OPT_ALERT_THIRST"], 275, -90, function() return ICN2DB.settings.alertThirst end, function(v) ICN2DB.settings.alertThirst = v; ICN2:UpdateAlerts() end, 220)
    makeCheckbox(alerts, L["OPT_ALERT_FATIGUE"], 275, -126, function() return ICN2DB.settings.alertFatigue end, function(v) ICN2DB.settings.alertFatigue = v; ICN2:UpdateAlerts() end, 220)
    makeSlider(alerts, L["OPT_ALERT_OPACITY"], 18, -176, 210, 0.03, 1.00, 0.01, function() return ICN2DB.settings.alertVisualOpacity end, function(v) ICN2DB.settings.alertVisualOpacity = v; ICN2:UpdateAlerts() end, 2)
    makeSlider(alerts, L["OPT_ALERT_INTERVAL"], 275, -176, 200, 60, 1800, 30, function() return ICN2DB.settings.alertReminderInterval end, function(v) ICN2DB.settings.alertReminderInterval = v end, 0)
    local soundValues = function() return { { id = "subtle", label = "Subtle" } } end
    local soundText = function(raw) return raw and (ICN2DB.settings.alertSound or "subtle") or "Subtle" end
    makeDropdown(alerts, "ICN2AlertSoundDropdown", L["OPT_ALERT_SOUND"], 18, -232, 125, soundText, soundValues, function(item) ICN2DB.settings.alertSound = item.id end)
    makeActionButton(alerts, L["BTN_PREVIEW_ALERT"], 139, -270, 128, function() ICN2:PreviewAlert() end)
    makeActionButton(alerts, L["BTN_TEST_SOUND"], 277, -270, 108, function() ICN2:TestAlertSound() end)
    makeLabel(alerts, L["DESC_ALERTS"], 18, -314, "GameFontDisableSmall", COLORS.muted, 480)

    local emotes = makeCard(panelGeneral, L["OPT_SEC_EMOTES"], -840, 164)
    makeCheckbox(emotes, L["OPT_EMOTES_ENABLED"], 18, -52, function() return ICN2DB.settings.emotesEnabled end, function(v) ICN2DB.settings.emotesEnabled = v end)
    makeCheckbox(emotes, L["OPT_AMBIENT_EMOTES"], 275, -52, function() return ICN2DB.settings.ambientEmotesEnabled ~= false end, function(v) ICN2DB.settings.ambientEmotesEnabled = v end)
    makeSlider(emotes, L["OPT_EMOTE_CHANCE"], 18, -94, 210, 0, 1, 0.05, function() return ICN2DB.settings.emoteChance end, function(v) ICN2DB.settings.emoteChance = v end, 2)
    makeSlider(emotes, L["OPT_EMOTE_INTERVAL"], 275, -94, 200, 30, 600, 10, function() return ICN2DB.settings.emoteMinInterval end, function(v) ICN2DB.settings.emoteMinInterval = v end, 0)

    local manual = makeCard(panelGeneral, L["OPT_SEC_MANUAL_RESTORE"], -1016, 202)
    makeActionButton(manual, L["BTN_EAT"], 18, -52, 108, function() ICN2:Eat(50) end); makeActionButton(manual, L["BTN_DRINK"], 136, -52, 108, function() ICN2:Drink(50) end); makeActionButton(manual, L["BTN_REST"], 254, -52, 108, function() ICN2:Rest(40) end); makeActionButton(manual, L["BTN_RESET"], 372, -52, 108, function() ICN2DB.hunger=ICN2:GetMaxValue("hunger"); ICN2DB.thirst=ICN2:GetMaxValue("thirst"); ICN2DB.fatigue=ICN2:GetMaxValue("fatigue"); ICN2:UpdateHUD() end)
    makeLabel(manual, L["OPT_SEC_MANUAL_DEPLETE"], 18, -102, "GameFontNormal", COLORS.gold)
    makeActionButton(manual, L["BTN_STARVE"], 18, -126, 108, function() ICN2DB.hunger=0; ICN2:UpdateHUD() end); makeActionButton(manual, L["BTN_DEHYDRATE"], 136, -126, 108, function() ICN2DB.thirst=0; ICN2:UpdateHUD() end); makeActionButton(manual, L["BTN_EXHAUST"], 254, -126, 108, function() ICN2DB.fatigue=0; ICN2:UpdateHUD() end)

    local decay = makeCard(panelDecay, L["OPT_SEC_DECAY_PRESET"], -4, 500)
    local presets = { "fast", "medium", "slow", "realistic", "custom" }
    presetBtns = {}
    for i, p in ipairs(presets) do
        local button = makeActionButton(decay, p:sub(1,1):upper()..p:sub(2), 18 + (i-1)*88, -52, 84, function() ICN2DB.settings.preset=p; for name,b in pairs(presetBtns) do b:SetAlpha(name==p and 1 or 0.55) end; refreshDecaySliders() end)
        presetBtns[p] = button
    end
    makeLabel(decay, string.format(L["DESC_DECAY_LONG"], ICN2.CUSTOM_DECAY_MULTIPLIER_MAX or 30), 18, -94, "GameFontHighlightSmall", COLORS.muted, 460)
    makeLabel(decay, L["OPT_SEC_BIAS"], 18, -178, "GameFontNormal", COLORS.gold)
    makeDecayBiasSlider(decay, "hunger", L["HUNGER"], -208); makeDecayBiasSlider(decay, "thirst", L["THIRST"], -278); makeDecayBiasSlider(decay, "fatigue", L["FATIGUE"], -348)
    refreshDecaySliders()

    optFrame:SetScript("OnShow", function() refreshDecaySliders(); for p,b in pairs(presetBtns) do b:SetAlpha(ICN2DB.settings.preset==p and 1 or 0.55) end end)
    selectOptionsTab(1)
    UpdateThemeDependencies()
end

function ICN2:ToggleOptions()
    if not optFrame then self:BuildOptions() end
    if optFrame:IsShown() then optFrame:Hide() else optFrame:Show() end
end
