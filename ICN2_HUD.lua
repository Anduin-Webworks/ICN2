-- ============================================================
-- ICN2_HUD.lua
-- On-screen HUD: hunger, thirst, fatigue.
-- Draggable, scalable.
-- ============================================================

ICN2 = ICN2 or {}

local L = setmetatable({}, { __index = function(_, k)
    return ICN2.L and ICN2.L[k] or k
end })

-- ── Module state ──────────────────────────────────────────────────────────────
local hudFrame
local headerFrame
local contentFrame
local chrome = {}
local bars   = {}
local headerBtns = {}

-- ── Pixel Snapping ──────────────────────────────────────────────
local function PixelSnap(value)
    local uiHeight = UIParent:GetHeight()
    if not uiHeight or uiHeight == 0 then return value end
    local px = 768 / uiHeight
    return px * math.floor((value / px) + 0.5)
end

-- ── System Constants (Logic Only) ─────────────────────────────────────────────
local NEED_KEYS = { "hunger", "thirst", "fatigue" }
local ASSETS_PATH = "Interface\\AddOns\\ICN2\\assets\\"

local IND_FASTER_UP   =  0.278
local IND_FAST_UP     =  0.167
local IND_FAST_DOWN   = -0.050
local IND_FASTER_DOWN = -0.100
local STABLE_EPSILON  =  0.002

local PULSE_PERIOD = 2.0
local PULSE_MIN    = 0.25
local PULSE_MAX    = 1.0

-- ── Deep Merge Engine ─────────────────────────────────────────────────────────
local function MergeTheme(base, override)
    local result = {}
    for k, v in pairs(base) do
        if type(v) == "table" and type(override[k]) == "table" then
            result[k] = MergeTheme(v, override[k])
        else
            -- If user explicitly overrides (even with false or ""), use it.
            if override[k] ~= nil then
                result[k] = override[k]
            else
                result[k] = v
            end
        end
    end
    for k, v in pairs(override or {}) do
        if result[k] == nil then
            result[k] = v
        end
    end
    return result
end

-- ═══ SECTION 1 — The Master Blueprint (THEME_BASE) ════════════════════════════
ICN2.THEME_BASE = {
    layout = {
        -- Visibility Flags
        showChrome = true,
        showHeader = true,
        showIcons  = true,
        showBars   = true,
        showGlyphs = true,
        orientation = "vertical", -- "vertical" or "horizontal"

        -- Global Spacing
        chromePad    = 6,
        headerHeight = 26,
        barGap       = 8,

        -- Element Dimensions
        barWidth      = 200,
        barHeight     = 20,
        iconSize      = 20,
        indicatorW    = 30,
        glyphSize     = 16,          -- NEW: Indicator/glyph texture size
        glyphPad      = 2,           -- NEW: Padding around glyph
        barOrientation = "HORIZONTAL",
        barReverseFill = false,
        barFillAlpha   = 1.0,
        showDepletionOverlay = false,
        showOverlayLabels = false,
        overlayTopLeft  = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 0, y = 0 },
        overlayTopRight = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = 0, y = 0 },

        -- Blocky Mode Settings
        numBlocks   = 10,
        blockGap    = 2,

        -- Row Anchors (relative to their parent frame)
        iconAnchor  = { point = "LEFT", relPoint = "LEFT", x = 0, y = 0 },
        barAnchor   = { point = "LEFT", relPoint = "LEFT", x = 30, y = 0 },
        glyphAnchor = { point = "RIGHT", relPoint = "RIGHT", x = -2, y = 0 },

        -- Header Buttons
        headerBtnAnchor = { point = "RIGHT", relPoint = "RIGHT", x = -6, y = -4 },
        headerTitleAnchor = { point = "LEFT", relPoint = "LEFT", x = 12, y = 0 },
        headerBtnSize   = 24,
        headerBtnGap    = 4,

        -- Labels & Fonts
        labelLeftAnchor  = { point = "LEFT", relPoint = "LEFT", x = 3, y = 0 },
        labelRightAnchor = { point = "RIGHT", relPoint = "RIGHT", x = -3, y = 0 },
        fontFace         = "Fonts\\FRIZQT__.TTF",
        fontSize         = 10,
        fontFlags        = "OUTLINE",
    },

    assets = {
        -- Bar Fill Textures (primary texture for smooth bars)
        barBg       = { 0.12, 0.12, 0.12, 0.9 },  -- NEW: Default bar background color
        barOverlay  = nil,                         -- NEW: Optional overlay texture
        barFills = {
            hunger  = ASSETS_PATH .. "icn2_fill_hunger_bar.png",
            thirst  = ASSETS_PATH .. "icn2_fill_thirst_bar.png",
            fatigue = ASSETS_PATH .. "icn2_fill_fatigue_bar.png",
        },

        -- Block Texture (for blocky mode)
        blockTex = "Interface\\Buttons\\WHITE8X8",

        -- Row & Background Elements
        rowBG       = nil,  -- Row background (spans icon + bar)
        glyphBG     = nil,  -- Glyph/indicator background

        -- Need Icons
        icons = {
            hunger  = ASSETS_PATH .. "icn2_hunger_chicken.png",
            thirst  = ASSETS_PATH .. "icn2_thirst.png",
            fatigue = ASSETS_PATH .. "icn2_fatigue.png",
        },

        -- Status Indicators (NEW: Complete set in THEME_BASE for all themes to inherit)
        indicators = {
            stable = ASSETS_PATH .. "icn2_paused.png",
            up1    = ASSETS_PATH .. "icn2_up_1.png",
            up2    = ASSETS_PATH .. "icn2_up_2.png",
            up3    = ASSETS_PATH .. "icn2_up_3.png",
            down1  = ASSETS_PATH .. "icn2_down_1.png",
            down2  = ASSETS_PATH .. "icn2_down_2.png",
            down3  = ASSETS_PATH .. "icn2_down_3.png",
        },

        -- Header Buttons
        headerBtns = {
            btn1 = ASSETS_PATH .. "icn2_details.png",
            btn2 = ASSETS_PATH .. "icn2_settings.png",
            btn3 = ASSETS_PATH .. "icn2_quick-rest.png",
        }
    },

    chrome = {
        bgCenter      = { 0.05, 0.05, 0.05, 0.88 },
        cornerTL      = nil, cornerTR = nil,
        cornerBL      = nil, cornerBR = nil,
        edgeTop       = nil, edgeBottom = nil,
        edgeLeft      = nil, edgeRight  = nil,
        titleStrip    = nil,
        cornerSize    = 8,
        edgeThickness = 4,
    },

    colors = {
        hunger  = { 0.2, 0.9, 0.2 },
        thirst  = { 0.2, 0.5, 1.0 },
        fatigue = { 1.0, 0.85, 0.1 },
    }
}

-- ═══ SECTION 2 — Custom Themes ════════════════════════════════════════════════
ICN2.HUD_THEMES = {
    colorful = {
        id    = "colorful",
        label = "Colorful (Default)",
        mode  = "smooth",
        layout = {
            barFillAlpha = 1.0,
            iconAnchor  = { point = "LEFT", relPoint = "LEFT", x = 3, y = 0 },
            barAnchor   = { point = "LEFT", relPoint = "LEFT", x = 33, y = 0 },
            glyphAnchor = { point = "RIGHT", relPoint = "RIGHT", x = 3, y = 0 },
            headerBtnAnchor = { point = "RIGHT", relPoint = "RIGHT", x = -20, y = 0 },
            headerTitleAnchor = { point = "LEFT", relPoint = "LEFT", x = 5, y = 0 },
            headerBtnSize   = 16,
            headerBtnGap    = 3,
        },

        chrome = {
            bgCenter      = { 0.03, 0.03, 0.03, 0.65 },
            cornerSize    = 6,
            edgeThickness = 2,
        },
        assets = {
            barBg = { 0.0, 0.0, 0.0, 0.0 },
            barFills = {
                hunger  = ASSETS_PATH .. "icn2_fill_hunger_bar.png",
                thirst  = ASSETS_PATH .. "icn2_fill_thirst_bar.png",
                fatigue = ASSETS_PATH .. "icn2_fill_fatigue_bar.png",
            },
        },
    },

    smooth = {
        id    = "smooth",
        label = "Smooth",
        mode  = "smooth",
        layout = {
            barFillAlpha = 0.65,
            iconAnchor  = { point = "LEFT", relPoint = "LEFT", x = 3, y = 0 },
            barAnchor   = { point = "LEFT", relPoint = "LEFT", x = 33, y = 0 },
            glyphAnchor = { point = "RIGHT", relPoint = "RIGHT", x = 3, y = 0 },
            headerBtnAnchor = { point = "RIGHT", relPoint = "RIGHT", x = -20, y = 0 },
            headerTitleAnchor = { point = "LEFT", relPoint = "LEFT", x = 5, y = 0 },
            headerBtnSize   = 16,
            headerBtnGap    = 3,
            iconSize   = 16,
            barHeight  = 16,
            glyphSize  = 14,
        },
        chrome = {
            bgCenter   = { 0.0, 0.0, 0.0, 0.6 },
        },
        assets = {
            barBg = { 0.1, 0.1, 0.1, 0.85 },
            barFills = {
                hunger  = "Interface\\Buttons\\WHITE8X8",
                thirst  = "Interface\\Buttons\\WHITE8X8",
                fatigue = "Interface\\Buttons\\WHITE8X8",
            },
        },
    },

    blocky = {
        id    = "blocky",
        label = "Blocky",
        mode  = "blocky",
        layout = {
            barFillAlpha = 0.95,
            glyphSize = 14,
            headerBtnAnchor = { point = "RIGHT", relPoint = "RIGHT", x = -20, y = 0 },
            headerTitleAnchor = { point = "LEFT", relPoint = "LEFT", x = 5, y = 0 },
            headerBtnSize   = 16,
            headerBtnGap    = 3,
        },
    },

    vanguard = {
        id    = "vanguard",
        label = "Vanguard (Modern)",
        mode  = "smooth",
        layout = {
            barFillAlpha = 0.65,
            showHeader = false,
            iconSize   = PixelSnap(28),
            barWidth   = PixelSnap(180),
            barHeight  = PixelSnap(14),
            glyphSize  = PixelSnap(18),
            iconAnchor = { point = "LEFT", relPoint = "LEFT", x = PixelSnap(12), y = 0 },
            barAnchor  = { point = "LEFT", relPoint = "LEFT", x = PixelSnap(48), y = 0 },
            glyphAnchor= { point = "RIGHT", relPoint = "RIGHT", x = PixelSnap(-12), y = 0 },
            cornerSize = PixelSnap(12), edgeThickness = PixelSnap(12),
        },
        chrome = {
            bgCenter   = { 0.05, 0.05, 0.06, 0.85 },
        },
        assets = {
            barBg = { 0.08, 0.08, 0.08, 0.9 },
            barFills = {
                hunger  = "Interface\\Buttons\\WHITE8X8",
                thirst  = "Interface\\Buttons\\WHITE8X8",
                fatigue = "Interface\\Buttons\\WHITE8X8",
            },
        },
        colors = {
            hunger  = { 0.8, 0.5, 0.2 },
            thirst  = { 0.3, 0.6, 0.9 },
            fatigue = { 0.6, 0.4, 0.8 },
        },
    },

    minimalistV = {
        id    = "minimalistV",
        label = "Minimalist (Vertical)",
        mode  = "minimalist",
        layout = {
            showChrome = false, showHeader = false, showBars = false, showGlyphs = true,
            orientation = "vertical",
            fixedScale  = 2.0,
            barOrientation = "VERTICAL",
            barReverseFill = false,
            barFillAlpha = 0.40,
            showDepletionOverlay = true,
            showOverlayLabels = true,
            overlayTopLeft  = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 0, y = 0 },
            overlayTopRight = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = 0, y = 0 },
            iconSize    = 32,
            barWidth    = 32,
            barHeight   = 32,
            barGap      = 8,
            glyphSize   = 12,
            glyphPad    = 4,
            iconAnchor  = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
            glyphAnchor = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -1, y = 1 },
            labelLeftAnchor  = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 1, y = -1 },
            labelRightAnchor = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 1, y = 1 },
            fontFace = "Fonts\\ARIALN.ttf", fontSize = 10,
        },
        assets = {
            barFills = {
                hunger = "Interface\\Buttons\\WHITE8X8",
                thirst = "Interface\\Buttons\\WHITE8X8",
                fatigue = "Interface\\Buttons\\WHITE8X8",
            },
        },
    },

    minimalistH = {
        id    = "minimalistH",
        label = "Minimalist (Horizontal)",
        mode  = "minimalist",
        layout = {
            showChrome = false, showHeader = false, showBars = false, showGlyphs = true,
            orientation = "horizontal",
            fixedScale  = 2.0,
            barOrientation = "HORIZONTAL",
            barReverseFill = false,
            barFillAlpha = 0.40,
            showDepletionOverlay = true,
            showOverlayLabels = true,
            overlayTopLeft  = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 0, y = 0 },
            overlayTopRight = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = 0, y = 0 },
            iconSize    = 32,
            barWidth    = 32,
            barHeight   = 32,
            barGap      = 8,
            glyphSize   = 12,
            glyphPad    = 4,
            iconAnchor  = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
            glyphAnchor = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -1, y = 1 },
            labelLeftAnchor  = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 1, y = -1 },
            labelRightAnchor = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 1, y = 1 },
            fontFace = "Fonts\\ARIALN.ttf", fontSize = 10,
        },
        assets = {
            barFills = {
                hunger = "Interface\\Buttons\\WHITE8X8",
                thirst = "Interface\\Buttons\\WHITE8X8",
                fatigue = "Interface\\Buttons\\WHITE8X8",
            },
        },
    }
}

ICN2.HUD_THEME_LIST = {
    ICN2.HUD_THEMES.colorful,
    ICN2.HUD_THEMES.smooth,
    ICN2.HUD_THEMES.blocky,
    -- ICN2.HUD_THEMES.vanguard,
    ICN2.HUD_THEMES.minimalistV,
    ICN2.HUD_THEMES.minimalistH,
}

local function getTheme(themeId)
    local id = themeId or (ICN2DB and ICN2DB.settings and ICN2DB.settings.barTheme) or "colorful"
    local custom = ICN2.HUD_THEMES[id] or ICN2.HUD_THEMES.colorful
    return MergeTheme(ICN2.THEME_BASE, custom)
end

-- ══ SECTION 3 — Helper Functions ═══════════════════════════════════════════════
local function shouldPulse(assetPath, theme)
    return assetPath ~= theme.assets.indicators.stable
end

local function getSelectedPalette()
    local paletteId = ICN2DB and ICN2DB.settings and ICN2DB.settings.colorPalette or "Default"
    return ICN2.Palettes and ICN2.Palettes[paletteId]
end

local function getNeedColor(key, val, theme)
    if theme.id == "colorful" and val > ICN2.THRESHOLDS.critical then
        return 1, 1, 1
    end

    if val <= ICN2.THRESHOLDS.critical then return 0.9, 0.1, 0.1
    elseif val <= ICN2.THRESHOLDS.low  then return 0.9, 0.6, 0.1
    else
        local paletteId = ICN2DB and ICN2DB.settings and ICN2DB.settings.colorPalette or "Default"
        local palette = (paletteId ~= "Default") and getSelectedPalette() or nil
        local fc = palette and palette[key]
        if fc then return fc[1], fc[2], fc[3] end

        local tc = theme.colors and theme.colors[key]
        if tc then return tc[1], tc[2], tc[3] end

        return 1, 1, 1
    end
end

local function getIndicatorAsset(needKey, rate, theme)
    local ind = theme.assets.indicators
    if needKey == "fatigue" then
        local thresholds = ICN2.FATIGUE_RATE_THRESHOLDS or {}
        local stable = thresholds.stable or STABLE_EPSILON
        local medium = thresholds.medium or IND_FAST_UP
        local high = thresholds.high or IND_FASTER_UP
        if math.abs(rate) <= stable then return ind.stable, 1, 1, 1
        elseif rate >= high then return ind.up3, 1, 1, 1
        elseif rate >= medium then return ind.up2, 1, 1, 1
        elseif rate > 0 then return ind.up1, 1, 1, 1
        elseif rate <= IND_FASTER_DOWN then return ind.down3, 1, 1, 1
        elseif rate <= IND_FAST_DOWN then return ind.down2, 1, 1, 1
        else return ind.down1, 1, 1, 1 end
    end
    if math.abs(rate) <= STABLE_EPSILON then return ind.stable, 1, 1, 1
    elseif rate >= IND_FASTER_UP        then return ind.up3,   1, 1, 1
    elseif rate >= IND_FAST_UP          then return ind.up2,   1, 1, 1
    elseif rate >  0                    then return ind.up1,   1, 1, 1
    elseif rate <= IND_FASTER_DOWN      then return ind.down3, 1, 1, 1
    elseif rate <= IND_FAST_DOWN        then return ind.down2, 1, 1, 1
    else                                     return ind.down1, 1, 1, 1
    end
end

local function applyTexSlot(tex, value)
    if not tex then return end
    if value == nil or value == false or value == "" then
        tex:Hide()
    elseif type(value) == "string" then
        if string.find(value, "\\") then
            tex:SetTexture(value)
        else
            tex:SetAtlas(value, true)
        end
        tex:Show()
    elseif type(value) == "table" then
        tex:SetColorTexture(value[1], value[2], value[3], value[4] or 1)
        tex:Show()
    end
end

-- ══  SECTION 4 — Build HUD (Creation ONLY)  ════════════════════════════════════
function ICN2:BuildHUD()
    local s = ICN2DB.settings

    -- Root frame
    hudFrame = CreateFrame("Frame", "ICN2HUDFrame", UIParent)
    hudFrame:SetFrameStrata("MEDIUM")
    hudFrame:SetClampedToScreen(true)
    hudFrame:SetPoint("CENTER", UIParent, "CENTER", s.hudX or 200, s.hudY or -250)
    hudFrame:EnableMouse(true)
    hudFrame:SetMovable(true)
    hudFrame:RegisterForDrag("LeftButton")
    hudFrame:SetScript("OnDragStart", function(self) if not ICN2DB.settings.hudLocked then self:StartMoving() end end)
    hudFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint()
        ICN2DB.settings.hudX = x
        ICN2DB.settings.hudY = y
    end)
    hudFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(string.format(L["TOOLTIP_HUNGER"],  ICN2:GetNeedPercent("hunger")),  0.2, 0.8, 0.2)
        GameTooltip:AddLine(string.format(L["TOOLTIP_THIRST"],  ICN2:GetNeedPercent("thirst")),  0.2, 0.5, 1.0)
        GameTooltip:AddLine(string.format(L["TOOLTIP_FATIGUE"], ICN2:GetNeedPercent("fatigue")), 1.0, 0.85, 0.1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["TOOLTIP_HINT"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    hudFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Chrome slots
    chrome.bgCenter = hudFrame:CreateTexture(nil, "BACKGROUND")
    for _, slot in ipairs({ "cornerTL", "cornerTR", "cornerBL", "cornerBR", "edgeTop", "edgeBottom", "edgeLeft", "edgeRight", "titleStrip" }) do
        chrome[slot] = hudFrame:CreateTexture(nil, "BORDER")
    end
    chrome.titleStrip:SetDrawLayer("ARTWORK")

    -- Header
    headerFrame = CreateFrame("Frame", nil, hudFrame)
    headerFrame.title = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerFrame.title:SetText(L["HUD_TITLE"])

    for i = 1, 3 do
        local btn
        if i == 3 then
            btn = CreateFrame("Button", nil, headerFrame, "SecureActionButtonTemplate")
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("spell", 1231411)
            btn:SetAttribute("useOnKeyDown", false)
            btn:RegisterForClicks("AnyUp", "AnyDown")
        else
            btn = CreateFrame("Button", nil, headerFrame)
        end

        btn.tex = btn:CreateTexture(nil, "ARTWORK")
        btn.tex:SetAllPoints()
        headerBtns[i] = btn
    end

    headerBtns[1]:SetScript("OnClick", function() ICN2:PrintDetails() end)
    headerBtns[2]:SetScript("OnClick", function() ICN2:ToggleOptions() end)

    -- Content
    contentFrame = CreateFrame("Frame", nil, hudFrame)

    for _, key in ipairs(NEED_KEYS) do
        local rowFrame = CreateFrame("Frame", "ICN2Row_" .. key, contentFrame)
        local icon = rowFrame:CreateTexture(nil, "ARTWORK")
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local rowBG = rowFrame:CreateTexture(nil, "BACKGROUND")

        local barFrame = CreateFrame("Frame", "ICN2BarFrame_" .. key, rowFrame)

        local barBG = barFrame:CreateTexture(nil, "BACKGROUND")
        barBG:SetAllPoints()

        local barFill = CreateFrame("StatusBar", "ICN2BarFill_" .. key, barFrame)
        barFill:SetAllPoints()
        barFill:SetMinMaxValues(0, 100)
        barFill:SetValue(100)

        local barLabelLeft = barFill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local barLabelRight = barFill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

        local barOverlay = barFrame:CreateTexture(nil, "OVERLAY")
        barOverlay:SetAllPoints()

        -- Keep the glyph in its own higher-level frame so it renders above
        -- barFrame, whose child textures otherwise cover rowFrame textures.
        local glyphFrame = CreateFrame("Frame", nil, rowFrame)
        glyphFrame:SetAllPoints(rowFrame)
        glyphFrame:SetFrameLevel(rowFrame:GetFrameLevel() + 10)
        local glyphTex = glyphFrame:CreateTexture(nil, "OVERLAY")
        local indBG = rowFrame:CreateTexture(nil, "BACKGROUND")
        indBG:SetPoint("CENTER", glyphTex, "CENTER", 0, 0)
        indBG:SetSize(32, 32)

        local pulseFrame = CreateFrame("Frame", nil, rowFrame)
        local pulseElapsed = 0
        local pulseRunning = false
        pulseFrame:SetScript("OnUpdate", function(_, dt)
            if not pulseRunning then return end
            pulseElapsed = pulseElapsed + dt
            local t = (pulseElapsed % PULSE_PERIOD) / PULSE_PERIOD
            local a = PULSE_MIN + (PULSE_MAX - PULSE_MIN) * (0.5 + 0.5 * math.sin(t * math.pi * 2 - math.pi / 2))
            glyphTex:SetAlpha(a)
        end)

        -- RowBG depends on Icon and BarFrame, so we'll link them structurally here
        rowBG:SetPoint("TOPLEFT", icon, "TOPLEFT", -4, 4)
        rowBG:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", 4, -4)

        bars[key] = {
            rowFrame      = rowFrame,
            rowBG         = rowBG,
            icon          = icon,
            barFrame      = barFrame,
            barBG         = barBG,
            barFill       = barFill,
            barOverlay    = barOverlay,
            barLabelLeft  = barLabelLeft,
            barLabelRight = barLabelRight,
            blocks        = {}, -- Generated dynamically in Apply
            glyphTex      = glyphTex,
            indBG         = indBG,
            setPulse      = function(active)
                pulseRunning = active
                if not active then
                    pulseElapsed = 0
                    glyphTex:SetAlpha(1.0)
                end
            end,
        }
    end

    hudFrame:SetAlpha(s.hudAlpha or 1.0)
    hudFrame:SetScale(s.hudScale or 1.0)

    if not s.barTheme then s.barTheme = "colorful" end
    ICN2:ApplyHUDTheme(s.barTheme)
    if not s.hudEnabled then hudFrame:Hide() end
end

-- ═══ SECTION 5 — Theme Engine (Layout & Styling) ══════════════════════════════
function ICN2:ApplyHUDTheme(themeId)
    if not hudFrame then return end

    local theme = getTheme(themeId)
    ICN2DB.settings.barTheme = theme.id
    ICN2DB.settings.blockyBars = (theme.mode == "blocky")

    local layout = theme.layout
    local settings = ICN2DB.settings or {}
    local barScale = ICN2DB.settings.hudBarScale or 1.0
    local barWidth = math.floor(layout.barWidth * barScale)
    local isMinimalist = (theme.mode == "minimalist")

    -- Size HUD Frame mathematically based on theme flags
    local contentW = layout.iconSize + 4 + barWidth + layout.indicatorW
    if isMinimalist then contentW = layout.iconSize end

    local frameW = contentW + layout.chromePad * 2 + 8
    if layout.orientation == "horizontal" then
        frameW = (#NEED_KEYS * contentW) + layout.chromePad * 2
    end

    local frameH = (#NEED_KEYS * layout.barHeight) + ((#NEED_KEYS - 1) * layout.barGap) + layout.chromePad * 2
    if layout.orientation == "horizontal" then
        frameH = layout.barHeight + layout.chromePad * 2
    end
    if layout.showHeader then frameH = frameH + layout.headerHeight end

    hudFrame:SetSize(frameW, frameH)
    hudFrame:SetScale(layout.fixedScale or settings.hudScale or 1.0)

    -- Apply Chrome
    if layout.showChrome then
        local c = theme.chrome
        applyTexSlot(chrome.bgCenter, c.bgCenter)
        chrome.bgCenter:SetAllPoints()

        local cs = c.cornerSize
        chrome.cornerTL:SetSize(cs, cs); chrome.cornerTL:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 0, 0)
        chrome.cornerTR:SetSize(cs, cs); chrome.cornerTR:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", 0, 0)
        chrome.cornerBL:SetSize(cs, cs); chrome.cornerBL:SetPoint("BOTTOMLEFT", hudFrame, "BOTTOMLEFT", 0, 0)
        chrome.cornerBR:SetSize(cs, cs); chrome.cornerBR:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", 0, 0)
        applyTexSlot(chrome.cornerTL, c.cornerTL); applyTexSlot(chrome.cornerTR, c.cornerTR)
        applyTexSlot(chrome.cornerBL, c.cornerBL); applyTexSlot(chrome.cornerBR, c.cornerBR)

        local et = c.edgeThickness
        chrome.edgeTop:SetHeight(et); chrome.edgeTop:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 0, 0); chrome.edgeTop:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", 0, 0)
        chrome.edgeBottom:SetHeight(et); chrome.edgeBottom:SetPoint("BOTTOMLEFT", hudFrame, "BOTTOMLEFT", 0, 0); chrome.edgeBottom:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", 0, 0)
        chrome.edgeLeft:SetWidth(et); chrome.edgeLeft:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 0, 0); chrome.edgeLeft:SetPoint("BOTTOMLEFT", hudFrame, "BOTTOMLEFT", 0, 0)
        chrome.edgeRight:SetWidth(et); chrome.edgeRight:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", 0, 0); chrome.edgeRight:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", 0, 0)
        applyTexSlot(chrome.edgeTop, c.edgeTop); applyTexSlot(chrome.edgeBottom, c.edgeBottom)
        applyTexSlot(chrome.edgeLeft, c.edgeLeft); applyTexSlot(chrome.edgeRight, c.edgeRight)

        chrome.titleStrip:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 0, 0)
        chrome.titleStrip:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", 0, 0)
        chrome.titleStrip:SetHeight(layout.headerHeight)
        applyTexSlot(chrome.titleStrip, c.titleStrip)
    else
        for _, tex in pairs(chrome) do tex:Hide() end
    end

    -- Header Alignment
    if layout.showHeader then
        headerFrame:Show()
        headerFrame:SetHeight(layout.headerHeight)
        local cp = math.max(layout.chromePad, theme.chrome.edgeThickness + 2)
        headerFrame:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", cp, -cp)
        headerFrame:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", -cp, -cp)

        local titleAnchor = layout.headerTitleAnchor or { point = "LEFT", relPoint = "LEFT", x = 12, y = 0 }
        headerFrame.title:ClearAllPoints()
        headerFrame.title:SetPoint(titleAnchor.point, headerFrame, titleAnchor.relPoint, titleAnchor.x, titleAnchor.y)

        local hAnchor = layout.headerBtnAnchor
        headerBtns[2]:SetSize(layout.headerBtnSize, layout.headerBtnSize)
        headerBtns[2]:ClearAllPoints()
        headerBtns[2]:SetPoint(hAnchor.point, headerFrame, hAnchor.relPoint, hAnchor.x, hAnchor.y)
        applyTexSlot(headerBtns[2].tex, theme.assets.headerBtns.btn2)

        headerBtns[1]:SetSize(layout.headerBtnSize, layout.headerBtnSize)
        headerBtns[1]:ClearAllPoints()
        headerBtns[1]:SetPoint("RIGHT", headerBtns[2], "LEFT", -layout.headerBtnGap, 0)
        applyTexSlot(headerBtns[1].tex, theme.assets.headerBtns.btn1)

        headerBtns[3]:SetSize(layout.headerBtnSize, layout.headerBtnSize)
        headerBtns[3]:ClearAllPoints()
        headerBtns[3]:SetPoint("LEFT", headerBtns[2], "RIGHT", layout.headerBtnGap, 0)
        applyTexSlot(headerBtns[3].tex, theme.assets.headerBtns.btn3)

        contentFrame:ClearAllPoints()
        contentFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
    else
        headerFrame:Hide()
        contentFrame:ClearAllPoints()
        local cp = math.max(layout.chromePad, theme.chrome.edgeThickness + 2)
        contentFrame:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", cp, -cp)
    end

    -- Size contentFrame to contain all rows
    local contentFrameW, contentFrameH
    if layout.orientation == "horizontal" then
        contentFrameW = (#NEED_KEYS * contentW) + ((#NEED_KEYS - 1) * layout.barGap)
        contentFrameH = layout.barHeight
    else
        contentFrameW = contentW
        contentFrameH = (#NEED_KEYS * layout.barHeight) + ((#NEED_KEYS - 1) * layout.barGap)
    end
    contentFrame:SetSize(contentFrameW, contentFrameH)

    -- Apply Rows
    for i, key in ipairs(NEED_KEYS) do
        local data = bars[key]
        if data then
            local rowX = (layout.orientation == "horizontal") and ((i - 1) * (contentW + layout.barGap)) or 0
            local rowY = (layout.orientation == "horizontal") and 0 or -((i - 1) * (layout.barHeight + layout.barGap))

            data.rowFrame:SetSize(contentW, layout.barHeight)
            data.rowFrame:ClearAllPoints()
            data.rowFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", rowX, rowY)

            -- Icon
            if layout.showIcons then
                data.icon:Show()
                data.icon:SetSize(layout.iconSize, layout.iconSize)
                data.icon:ClearAllPoints()
                data.icon:SetPoint(layout.iconAnchor.point, data.rowFrame, layout.iconAnchor.relPoint, layout.iconAnchor.x, layout.iconAnchor.y)
                data.icon:SetTexture(theme.assets.icons[key])
            else
                data.icon:Hide()
            end

            -- Backgrounds
            if theme.assets.rowBG then applyTexSlot(data.rowBG, theme.assets.rowBG) else data.rowBG:Hide() end
            if theme.assets.glyphBG then applyTexSlot(data.indBG, theme.assets.glyphBG) else data.indBG:Hide() end

            -- Bar Framework
            if layout.showBars or isMinimalist then
                data.barFrame:Show()
                data.barFrame:SetSize(isMinimalist and layout.iconSize or barWidth, isMinimalist and layout.iconSize or layout.barHeight)
                data.barFrame:ClearAllPoints()
                if isMinimalist then
                    data.barFrame:SetPoint("CENTER", data.rowFrame, "CENTER", 0, 0)
                else
                    data.barFrame:SetPoint(layout.barAnchor.point, data.rowFrame, layout.barAnchor.relPoint, layout.barAnchor.x, layout.barAnchor.y)
                end

                applyTexSlot(data.barBG, theme.assets.barBg)
                data.barBG:SetAllPoints()

                if layout.showDepletionOverlay and theme.assets.barOverlay then
                    applyTexSlot(data.barOverlay, theme.assets.barOverlay)
                    data.barOverlay:ClearAllPoints()
                    data.barOverlay:SetPoint(layout.overlayTopLeft.point, data.barFrame, layout.overlayTopLeft.relPoint, layout.overlayTopLeft.x, layout.overlayTopLeft.y)
                    data.barOverlay:SetPoint(layout.overlayTopRight.point, data.barFrame, layout.overlayTopRight.relPoint, layout.overlayTopRight.x, layout.overlayTopRight.y)
                elseif theme.assets.barOverlay then applyTexSlot(data.barOverlay, theme.assets.barOverlay) else data.barOverlay:Hide() end

                local fillTex = theme.assets.barFills and theme.assets.barFills[key]
                data.barFill:SetStatusBarTexture(fillTex)
                if layout.barOrientation then
                    data.barFill:SetOrientation(layout.barOrientation)
                end
                if layout.barReverseFill ~= nil then
                    data.barFill:SetReverseFill(layout.barReverseFill)
                end
                if layout.showDepletionOverlay then
                    data.barBG:Hide()
                end

                -- Fonts
                data.barLabelLeft:SetFont(layout.fontFace, layout.fontSize, layout.fontFlags)
                data.barLabelRight:SetFont(layout.fontFace, layout.fontSize, layout.fontFlags)
                data.barLabelLeft:ClearAllPoints()
                data.barLabelRight:ClearAllPoints()
                data.barLabelLeft:SetPoint(layout.labelLeftAnchor.point, data.barFrame, layout.labelLeftAnchor.relPoint, layout.labelLeftAnchor.x, layout.labelLeftAnchor.y)
                data.barLabelRight:SetPoint(layout.labelRightAnchor.point, data.barFrame, layout.labelRightAnchor.relPoint, layout.labelRightAnchor.x, layout.labelRightAnchor.y)

                -- Blocky Engine Generation
                if theme.mode == "blocky" then
                    data.barFill:Hide()
                    data.barBG:Hide()
                    local blockW = (barWidth - (layout.blockGap * (layout.numBlocks - 1))) / layout.numBlocks

                    for b = 1, layout.numBlocks do
                        if not data.blocks[b] then
                            local t = data.barFrame:CreateTexture(nil, "OVERLAY")
                            data.blocks[b] = { fill = t }
                        end
                        data.blocks[b].fill:SetSize(blockW, layout.barHeight)
                        data.blocks[b].fill:ClearAllPoints()
                        data.blocks[b].fill:SetPoint("LEFT", data.barFrame, "LEFT", (b - 1) * (blockW + layout.blockGap), 0)
                        data.blocks[b].fill:SetTexture(theme.assets.blockTex)
                        data.blocks[b].fill:Show()
                    end
                    -- Hide excess blocks if theme switched from high count to low count
                    for b = layout.numBlocks + 1, #data.blocks do
                        data.blocks[b].fill:Hide()
                    end
                else
                    data.barFill:Show()
                    data.barBG:Show()
                    for _, b in ipairs(data.blocks) do b.fill:Hide() end
                end
            else
                data.barFrame:Hide()
            end

            if layout.showOverlayLabels then
                data.barLabelLeft:SetFont(layout.fontFace, layout.fontSize, layout.fontFlags)
                data.barLabelRight:SetFont(layout.fontFace, layout.fontSize, layout.fontFlags)
                data.barLabelLeft:ClearAllPoints()
                data.barLabelRight:ClearAllPoints()
                data.barLabelLeft:SetPoint(layout.labelLeftAnchor.point, data.rowFrame, layout.labelLeftAnchor.relPoint, layout.labelLeftAnchor.x, layout.labelLeftAnchor.y)
                data.barLabelRight:SetPoint(layout.labelRightAnchor.point, data.rowFrame, layout.labelRightAnchor.relPoint, layout.labelRightAnchor.x, layout.labelRightAnchor.y)
            end

            -- Indicators
            if layout.showGlyphs then
                data.glyphTex:Show()
                data.glyphTex:SetSize(layout.glyphSize, layout.glyphSize)
                data.glyphTex:ClearAllPoints()
                data.glyphTex:SetPoint(layout.glyphAnchor.point, data.rowFrame, layout.glyphAnchor.relPoint, layout.glyphAnchor.x, layout.glyphAnchor.y)
            else
                data.glyphTex:Hide()
            end
        end
    end
end

-- ── Public Entry & Resize ──────────────────────────────────────────────────────
function ICN2:SetBarTheme(themeId)
    ICN2:ApplyHUDTheme(themeId)
    ICN2:UpdateHUD()
end

function ICN2:ResizeBarLength()
    if hudFrame then ICN2:ApplyHUDTheme(ICN2DB.settings.barTheme) end
end

function ICN2:LockHUD(locked)
    if hudFrame then hudFrame:EnableMouse(not locked) end
end

-- ══  SECTION 7 — Update Loop  ══════════════════════════════════════════════════
function ICN2:UpdateHUD()
    if not hudFrame then return end
    local inCombat = (InCombatLockdown and InCombatLockdown()) and true or false

    if not ICN2DB.settings.hudEnabled then
        if not inCombat then hudFrame:Hide() end
        -- If we're in combat, avoid calling protected methods; defer until combat ends
        if inCombat then ICN2._hudPendingShow = false end
        return
    end

    -- Only call :Show() when not in combat to avoid ADDON_ACTION_BLOCKED errors.
    if inCombat then
        ICN2._hudPendingShow = true
        return
    else
        ICN2._hudPendingShow = nil
        hudFrame:Show()
    end

    local theme = getTheme()
    local values = { hunger = ICN2:GetNeedPercent("hunger"), thirst = ICN2:GetNeedPercent("thirst"), fatigue = ICN2:GetNeedPercent("fatigue") }
    local rates = ICN2:GetCurrentRates()
    if ICN2._ApplyTimedManualRecoveryPreview then
        ICN2:_ApplyTimedManualRecoveryPreview(rates)
    end
    local labelMode = ICN2DB.settings.barLabelMode or "percentage"

    for _, key in ipairs(NEED_KEYS) do
        local data = bars[key]
        if data then
            local val = values[key] or 0
            local r, g, b = getNeedColor(key, val, theme)

            if theme.mode == "blocky" then
                local filled = (val >= 100) and theme.layout.numBlocks or math.floor(val / (100 / theme.layout.numBlocks))
                for idx = 1, theme.layout.numBlocks do
                    local bf = data.blocks[idx]
                    -- A theme change can trigger UpdateHUD between the old
                    -- layout being hidden and the new block textures being
                    -- created. Build any missing block defensively here.
                    if not bf then
                        local blockW = (data.barFrame:GetWidth() - (theme.layout.blockGap * (theme.layout.numBlocks - 1))) / theme.layout.numBlocks
                        local blockTex = data.barFrame:CreateTexture(nil, "OVERLAY")
                        bf = { fill = blockTex }
                        data.blocks[idx] = bf
                        blockTex:SetSize(blockW, theme.layout.barHeight)
                        blockTex:SetPoint("LEFT", data.barFrame, "LEFT", (idx - 1) * (blockW + theme.layout.blockGap), 0)
                        blockTex:SetTexture(theme.assets.blockTex)
                    end
                    if idx <= filled then
                        bf.fill:SetVertexColor(r, g, b, 0.95)
                        bf.fill:Show()
                    else
                        bf.fill:Hide()
                    end
                end
            else
                data.barFill:SetValue(val)
                data.barFill:SetStatusBarColor(r, g, b, theme.layout.barFillAlpha)

                local current = ICN2DB[key] or 0
                local maxVal  = ICN2:GetMaxValue(key)
                local pctText = string.format("%.0f%%", val)
                local numText = string.format("%.0f/%.0f", current, maxVal)

                if theme.layout.showDepletionOverlay then
                    -- The dark overlay represents the missing portion and always
                    -- retracts from the top down over the icon-sized bar.
                    local missingHeight = data.barFrame:GetHeight() * (1 - (val / 100))
                    data.barOverlay:SetHeight(math.max(0, missingHeight))
                    data.barOverlay:Show()
                    if labelMode == "none" then
                        data.barLabelLeft:Hide()
                        data.barLabelRight:Hide()
                    elseif labelMode == "percentage" then
                        data.barLabelLeft:Hide()
                        data.barLabelRight:SetText(pctText)
                        data.barLabelRight:Show()
                    elseif labelMode == "number" then
                        data.barLabelLeft:SetText(numText)
                        data.barLabelLeft:Show()
                        data.barLabelRight:Hide()
                    elseif labelMode == "both" then
                        data.barLabelLeft:SetText(numText)
                        data.barLabelRight:SetText(pctText)
                        data.barLabelLeft:Show()
                        data.barLabelRight:Show()
                    end
                elseif labelMode == "none" or not theme.layout.showBars then
                    data.barLabelLeft:Hide()
                    data.barLabelRight:Hide()
                elseif labelMode == "percentage" then
                    data.barLabelLeft:Hide()
                    data.barLabelRight:SetText(pctText)
                    data.barLabelRight:Show()
                elseif labelMode == "number" then
                    data.barLabelLeft:Hide()
                    data.barLabelRight:SetText(numText)
                    data.barLabelRight:Show()
                elseif labelMode == "both" then
                    data.barLabelLeft:SetText(numText)
                    data.barLabelLeft:Show()
                    data.barLabelRight:SetText(pctText)
                    data.barLabelRight:Show()
                end
            end

            local assetPath, ir, ig, ib = getIndicatorAsset(key, rates[key] or 0, theme)
            data.glyphTex:SetTexture(assetPath)
            data.glyphTex:SetVertexColor(ir, ig, ib)
            data.setPulse(shouldPulse(assetPath, theme))
        end
    end
end
