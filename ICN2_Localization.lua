-- ============================================================
-- ICN2_Localization.lua
-- Comprehensive localization system with validation and fallback
-- ============================================================

local _, _ = ...

-- ══════════════════════════════════════════════════════════
-- SECTION 1 — Color Constants
-- ══════════════════════════════════════════════════════════
ICN2 = ICN2 or {}

ICN2.COLOR = {
    ADDON   = "|cFFFF6600",  -- Orange (ICN2 branding)
    HUNGER  = "|cFF00FF00",  -- Green
    THIRST  = "|cFF4499FF",  -- Blue
    FATIGUE = "|cFFFFDD00",  -- Yellow
    GRAY    = "|cFF888888",  -- Gray (help text)
    WHITE   = "|cFFFFFFFF",  -- White
    RED     = "|cFFFF4444",  -- Red (warnings, reset)
    YELLOW  = "|cFFFFCC00",  -- Bright yellow (highlights)
    ORANGE  = "|cFFFF9900",  -- Bright orange (warnings)
    RESET   = "|r",          -- Color reset
}

-- ══════════════════════════════════════════════════════════
-- SECTION 2 — Locale Fallback Chain
-- ══════════════════════════════════════════════════════════
local function getLocaleWithFallback()
    local locale = GetLocale()
    
    -- Spanish variants fall back to each other
    if locale == "esES" or locale == "esMX" then
        return "esES"  -- Use European Spanish as primary
    end
    
    return locale
end

local currentLocale = getLocaleWithFallback()

-- ══════════════════════════════════════════════════════════
-- SECTION 3 — Localization Table with Fallback
-- ══════════════════════════════════════════════════════════
local L = setmetatable({}, { 
    __index = function(t, k) 
        -- Return key if translation missing (graceful degradation)
        if type(k) == "string" then
            return k
        end
        return tostring(k)
    end 
})

ICN2.L = L

-- ══════════════════════════════════════════════════════════
-- SECTION 4 — Validation Layer
-- ══════════════════════════════════════════════════════════
function ICN2:GetLocalizedString(key, ...)
    if type(key) ~= "string" then
        return tostring(key)
    end
    
    local str = L[key]
    
    -- Handle string formatting if arguments provided
    if select("#", ...) > 0 then
        local success, result = pcall(string.format, str, ...)
        if success then
            return result
        else
            -- Fallback: return unformatted string if format fails
            return str
        end
    end
    
    return str
end

-- Shorthand alias
function ICN2:L(key, ...)
    return self:GetLocalizedString(key, ...)
end

-- ══════════════════════════════════════════════════════════
-- SECTION 5 — English (Default) Strings
-- ══════════════════════════════════════════════════════════

-- ── Core Needs ────────────────────────────────────────────
L["HUNGER"] = "Hunger"
L["THIRST"] = "Thirst"
L["FATIGUE"] = "Fatigue"

-- ── Addon Branding ────────────────────────────────────────
L["ADDON_NAME"] = "ICN2"
L["ADDON_TITLE"] = "Character Needs"
L["ADDON_VERSION"] = "v2.0.0"

-- ── HUD Elements ──────────────────────────────────────────
L["HUD_TITLE"] = "Character Needs"
L["HUD_TOOLTIP_TITLE"] = ICN2.COLOR.ADDON .. "ICN2 - Character Needs" .. ICN2.COLOR.RESET
L["HUD_TOOLTIP_DETAILS"] = ICN2.COLOR.GRAY .. "/icn2 details" .. ICN2.COLOR.RESET

-- ── Theme Names ───────────────────────────────────────────
L["THEME_SMOOTH"] = "Smooth"
L["THEME_BLOCKY"] = "Blocky"
L["THEME_FOLK"] = "Folk"
L["THEME_NECROMANCER"] = "Necromancer"
L["THEME_DASTARDLY"] = "Dastardly"
L["THEME_WIP"] = ICN2.COLOR.GRAY .. "(WIP)" .. ICN2.COLOR.RESET

-- ── Preset Names ──────────────────────────────────────────
L["PRESET_FAST"] = "Fast"
L["PRESET_MEDIUM"] = "Medium"
L["PRESET_SLOW"] = "Slow"
L["PRESET_REALISTIC"] = "Realistic"
L["PRESET_CUSTOM"] = "Custom"

-- ── Label Modes ───────────────────────────────────────────
L["LABEL_MODE_NONE"] = "None"
L["LABEL_MODE_PERCENTAGE"] = "Percentage"
L["LABEL_MODE_NUMBER"] = "Number"
L["LABEL_MODE_BOTH"] = "Both"

-- ── Tab Labels ────────────────────────────────────────────
L["TAB_GENERAL"] = "General"
L["TAB_DECAY"] = "Decay & rates"

-- ── General Tab Sections ──────────────────────────────────
L["SECTION_HUD"] = "HUD"
L["SECTION_THEME"] = "Theme:"
L["SECTION_LABELS"] = "Bar labels:"
L["SECTION_IMMERSION"] = "Immersion"
L["SECTION_EMOTES"] = "Emotes"
L["SECTION_MANUAL_RESTORE"] = "Manual restore"
L["SECTION_MANUAL_DEPLETE"] = "Manual deplete"

-- ── Options: HUD ──────────────────────────────────────────
L["OPT_HUD_ENABLED"] = "Enable HUD"
L["OPT_HUD_LOCK"] = "Lock HUD position"
L["OPT_OPACITY"] = "Opacity"
L["OPT_SCALE"] = "Scale"
L["OPT_BAR_LENGTH"] = "Bar length"

-- ── Options: Immersion ────────────────────────────────────
L["OPT_FREEZE_OFFLINE"] = "Freeze needs while offline"
L["OPT_FREEZE_OFFLINE_DESC"] = ICN2.COLOR.GRAY .. "(no offline decay)" .. ICN2.COLOR.RESET
L["OPT_FOOD_DRINK_AUTO"] = ICN2.COLOR.GRAY .. "Food/drink buffs are detected automatically." .. ICN2.COLOR.RESET

-- ── Options: Emotes ───────────────────────────────────────
L["OPT_EMOTES_ENABLED"] = "Enable automatic emotes"
L["OPT_EMOTE_CHANCE"] = "Emote chance"
L["OPT_EMOTE_INTERVAL"] = "Min interval (sec)"

-- ── Options: Decay Tab ────────────────────────────────────
L["OPT_DECAY_PRESET"] = "Decay preset"
L["OPT_DECAY_HELP_1"] = "Choose a preset for global decay speed, or " .. ICN2.COLOR.YELLOW .. "Custom" .. ICN2.COLOR.RESET .. " to tune each need."
L["OPT_DECAY_HELP_2"] = ICN2.COLOR.GRAY .. "Custom multiplier vs Medium (1×): " .. ICN2.COLOR.WHITE .. "0" .. ICN2.COLOR.RESET .. ICN2.COLOR.GRAY .. " = no passive decay; " .. ICN2.COLOR.WHITE .. "%d" .. ICN2.COLOR.RESET .. ICN2.COLOR.GRAY .. " = 10× Fast. Sliders are read-only unless Custom." .. ICN2.COLOR.RESET
L["OPT_PER_NEED_BIAS"] = "Per-need decay bias"

-- ── Decay Slider Labels ───────────────────────────────────
L["DECAY_SLIDER_FORMAT"] = "%s: %d  (×%.2f vs Medium base)"
L["DECAY_SLIDER_PRESET"] = ICN2.COLOR.GRAY .. "(preset)" .. ICN2.COLOR.RESET
L["DECAY_SLIDER_HUNGER"] = "Hunger"
L["DECAY_SLIDER_THIRST"] = "Thirst"
L["DECAY_SLIDER_FATIGUE"] = "Fatigue"

-- ── Button Labels ─────────────────────────────────────────
L["BTN_EAT"] = ICN2.COLOR.HUNGER .. "Eat" .. ICN2.COLOR.RESET
L["BTN_DRINK"] = ICN2.COLOR.THIRST .. "Drink" .. ICN2.COLOR.RESET
L["BTN_REST"] = ICN2.COLOR.FATIGUE .. "Rest" .. ICN2.COLOR.RESET
L["BTN_RESET"] = ICN2.COLOR.RED .. "Reset" .. ICN2.COLOR.RESET
L["BTN_STARVE"] = ICN2.COLOR.RED .. "Starve" .. ICN2.COLOR.RESET
L["BTN_DEHYDRATE"] = ICN2.COLOR.RED .. "Dehydrate" .. ICN2.COLOR.RESET
L["BTN_EXHAUST"] = ICN2.COLOR.RED .. "Exhaust" .. ICN2.COLOR.RESET

-- ── Messages ──────────────────────────────────────────────
L["MSG_LOADED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " loaded. Type " .. ICN2.COLOR.YELLOW .. "/icn2" .. ICN2.COLOR.RESET .. " for options."
L["MSG_RESET"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Needs reset to 100%."
L["MSG_NEEDS_MIGRATED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Needs migrated to point-based system."
L["MSG_RATES_UPDATED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. ": Rates updated to v2.0.0 defaults."

L["MSG_EAT"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " You eat something. Hunger restored."
L["MSG_DRINK"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " You drink something. Thirst restored."
L["MSG_REST"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " You rest. Fatigue restored."

L["MSG_STARVE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Hunger" .. ICN2.COLOR.RESET .. " set to 0%."
L["MSG_DEHYDRATE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Thirst" .. ICN2.COLOR.RESET .. " set to 0%."
L["MSG_EXHAUST"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.FATIGUE .. "Fatigue" .. ICN2.COLOR.RESET .. " set to 0%."

L["MSG_HUD_ENABLED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.HUNGER .. "enabled" .. ICN2.COLOR.RESET
L["MSG_HUD_DISABLED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.RED .. "disabled" .. ICN2.COLOR.RESET
L["MSG_HUD_LOCKED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.RED .. "locked" .. ICN2.COLOR.RESET
L["MSG_HUD_UNLOCKED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.HUNGER .. "unlocked" .. ICN2.COLOR.RESET

L["MSG_WELL_FED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Well Fed!" .. ICN2.COLOR.RESET .. " Hunger decay paused for %d min."

L["MSG_COMPLETION_BONUS"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " %s completion bonus! (+%.0f pts — %s tier)"

-- ── Status Messages ───────────────────────────────────────
L["MSG_STATUS"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Hunger: " .. ICN2.COLOR.HUNGER .. "%.1f%%" .. ICN2.COLOR.RESET .. "  Thirst: " .. ICN2.COLOR.THIRST .. "%.1f%%" .. ICN2.COLOR.RESET .. "  Fatigue: " .. ICN2.COLOR.FATIGUE .. "%.1f%%" .. ICN2.COLOR.RESET

-- ── Details Output ────────────────────────────────────────
L["DETAILS_TITLE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.YELLOW .. "Details" .. ICN2.COLOR.RESET .. " — %s"
L["DETAILS_SEPARATOR"] = ICN2.COLOR.GRAY .. "--------------------------------" .. ICN2.COLOR.RESET
L["DETAILS_CUSTOM"] = "Custom — H×%.2f  T×%.2f  F×%.2f"
L["DETAILS_PRESET"] = "%s (global ×%.2f — slider display %d on 0–%d scale)"
L["DETAILS_HUNGER_LINE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Hunger" .. ICN2.COLOR.RESET .. "  %.1f%%  (%.1f / %d pts)  net %+.4f pts/s"
L["DETAILS_THIRST_LINE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Thirst" .. ICN2.COLOR.RESET .. "  %.1f%%  (%.1f / %d pts)  net %+.4f pts/s"
L["DETAILS_FATIGUE_LINE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.FATIGUE .. "Fatigue" .. ICN2.COLOR.RESET .. " %.1f%%  (%.1f / %d pts)  net %+.4f pts/s  (recovery %+.4f pts/s [%s])"
L["DETAILS_MODIFIERS"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.GRAY .. "Active modifiers:" .. ICN2.COLOR.RESET
L["DETAILS_NONE"] = "  " .. ICN2.COLOR.GRAY .. "None (walking/idle outdoors)" .. ICN2.COLOR.RESET
L["DETAILS_ARMOR"] = "  " .. ICN2.COLOR.GRAY .. "Armor:%s (F×%.2f)" .. ICN2.COLOR.RESET
L["DETAILS_FATIGUE_RECOVERY"] = "  " .. ICN2.COLOR.GRAY .. "Fatigue recovery: %s — sources: %s" .. ICN2.COLOR.RESET
L["DETAILS_CROSS_NEED"] = "  " .. ICN2.COLOR.ORANGE .. "Cross-need: %s" .. ICN2.COLOR.RESET
L["DETAILS_EATING"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Currently eating" .. ICN2.COLOR.RESET .. "  (tier: %s)"
L["DETAILS_DRINKING"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Currently drinking" .. ICN2.COLOR.RESET .. " (tier: %s)"
L["DETAILS_WELL_FED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Well Fed" .. ICN2.COLOR.RESET .. " — hunger decay paused (%ds remaining)"
L["DETAILS_INSTANCE"] = ICN2.COLOR.ORANGE .. "Instance" .. ICN2.COLOR.RESET .. " (H×%.2f T×%.2f F×%.2f) — aura scanning disabled"

-- ── Situation Modifiers ───────────────────────────────────
L["SITUATION_RESTING"] = "Resting (H×%.2f T×%.2f F×%.2f)"
L["SITUATION_MOUNTED"] = "Mounted (H×%.2f T×%.2f F×%.2f)"
L["SITUATION_FLYING"] = "Flying (H×%.2f T×%.2f F×%.2f)"
L["SITUATION_SWIMMING"] = "Swimming (H×%.2f T×%.2f F×%.2f)"
L["SITUATION_COMBAT"] = "Combat (H×%.2f T×%.2f F×%.2f)"
L["SITUATION_INDOORS"] = "Indoors (H×%.2f T×%.2f F×%.2f)"
L["SITUATION_RACE"] = "Race:%s (H×%.2f T×%.2f F×%.2f)"
L["SITUATION_CLASS"] = "Class:%s (H×%.2f T×%.2f F×%.2f)"

-- ── Slash Command Help ────────────────────────────────────
L["SLASH_HELP"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Commands: " .. ICN2.COLOR.YELLOW .. "/icn2" .. ICN2.COLOR.RESET .. " [show|eat|drink|rest|reset|starve|dehydrate|exhaust|status|details|hud|lock]"

-- ══════════════════════════════════════════════════════════
-- SECTION 6 — Portuguese (ptBR)
-- ══════════════════════════════════════════════════════════
if currentLocale == "ptBR" then
    -- ── Core Needs ────────────────────────────────────────
    L["HUNGER"] = "Fome"
    L["THIRST"] = "Sede"
    L["FATIGUE"] = "Fadiga"
    
    -- ── Addon Branding ────────────────────────────────────
    L["ADDON_TITLE"] = "Necessidades do Personagem"
    
    -- ── HUD Elements ──────────────────────────────────────
    L["HUD_TITLE"] = "Necessidades do Personagem"
    L["HUD_TOOLTIP_TITLE"] = ICN2.COLOR.ADDON .. "ICN2 - Necessidades do Personagem" .. ICN2.COLOR.RESET
    
    -- ── Theme Names ───────────────────────────────────────
    L["THEME_SMOOTH"] = "Suave"
    L["THEME_BLOCKY"] = "Blocado"
    L["THEME_FOLK"] = "Folclórico"
    L["THEME_NECROMANCER"] = "Necromante"
    L["THEME_DASTARDLY"] = "Vilão"
    
    -- ── Preset Names ──────────────────────────────────────
    L["PRESET_FAST"] = "Rápido"
    L["PRESET_MEDIUM"] = "Médio"
    L["PRESET_SLOW"] = "Lento"
    L["PRESET_REALISTIC"] = "Realista"
    L["PRESET_CUSTOM"] = "Personalizado"
    
    -- ── Label Modes ───────────────────────────────────────
    L["LABEL_MODE_NONE"] = "Nenhum"
    L["LABEL_MODE_PERCENTAGE"] = "Porcentagem"
    L["LABEL_MODE_NUMBER"] = "Número"
    L["LABEL_MODE_BOTH"] = "Ambos"
    
    -- ── Tab Labels ────────────────────────────────────────
    L["TAB_GENERAL"] = "Geral"
    L["TAB_DECAY"] = "Decaimento e taxas"
    
    -- ── General Tab Sections ──────────────────────────────
    L["SECTION_LABELS"] = "Rótulos da barra:"
    L["SECTION_IMMERSION"] = "Imersão"
    L["SECTION_EMOTES"] = "Emotes"
    L["SECTION_MANUAL_RESTORE"] = "Restauração manual"
    L["SECTION_MANUAL_DEPLETE"] = "Depleção manual"
    
    -- ── Options: HUD ──────────────────────────────────────
    L["OPT_HUD_ENABLED"] = "Habilitar HUD"
    L["OPT_HUD_LOCK"] = "Travar posição do HUD"
    L["OPT_OPACITY"] = "Opacidade"
    L["OPT_SCALE"] = "Escala"
    L["OPT_BAR_LENGTH"] = "Comprimento da barra"
    
    -- ── Options: Immersion ────────────────────────────────
    L["OPT_FREEZE_OFFLINE"] = "Congelar necessidades offline"
    L["OPT_FREEZE_OFFLINE_DESC"] = ICN2.COLOR.GRAY .. "(sem decaimento offline)" .. ICN2.COLOR.RESET
    L["OPT_FOOD_DRINK_AUTO"] = ICN2.COLOR.GRAY .. "Buffs de comida/bebida são detectados automaticamente." .. ICN2.COLOR.RESET
    
    -- ── Options: Emotes ───────────────────────────────────
    L["OPT_EMOTES_ENABLED"] = "Habilitar emotes automáticos"
    L["OPT_EMOTE_CHANCE"] = "Chance de emote"
    L["OPT_EMOTE_INTERVAL"] = "Intervalo mínimo (seg)"
    
    -- ── Options: Decay Tab ────────────────────────────────
    L["OPT_DECAY_PRESET"] = "Predefinição de decaimento"
    L["OPT_DECAY_HELP_1"] = "Escolha uma predefinição para velocidade de decaimento global, ou " .. ICN2.COLOR.YELLOW .. "Personalizado" .. ICN2.COLOR.RESET .. " para ajustar cada necessidade."
    L["OPT_DECAY_HELP_2"] = ICN2.COLOR.GRAY .. "Multiplicador personalizado vs Médio (1×): " .. ICN2.COLOR.WHITE .. "0" .. ICN2.COLOR.RESET .. ICN2.COLOR.GRAY .. " = sem decaimento passivo; " .. ICN2.COLOR.WHITE .. "%d" .. ICN2.COLOR.RESET .. ICN2.COLOR.GRAY .. " = 10× Rápido. Controles somente-leitura exceto em Personalizado." .. ICN2.COLOR.RESET
    L["OPT_PER_NEED_BIAS"] = "Viés de decaimento por necessidade"
    
    -- ── Decay Slider Labels ───────────────────────────────
    L["DECAY_SLIDER_PRESET"] = ICN2.COLOR.GRAY .. "(predefinição)" .. ICN2.COLOR.RESET
    
    -- ── Button Labels ─────────────────────────────────────
    L["BTN_EAT"] = ICN2.COLOR.HUNGER .. "Comer" .. ICN2.COLOR.RESET
    L["BTN_DRINK"] = ICN2.COLOR.THIRST .. "Beber" .. ICN2.COLOR.RESET
    L["BTN_REST"] = ICN2.COLOR.FATIGUE .. "Descansar" .. ICN2.COLOR.RESET
    L["BTN_RESET"] = ICN2.COLOR.RED .. "Resetar" .. ICN2.COLOR.RESET
    L["BTN_STARVE"] = ICN2.COLOR.RED .. "Morrer de fome" .. ICN2.COLOR.RESET
    L["BTN_DEHYDRATE"] = ICN2.COLOR.RED .. "Desidratar" .. ICN2.COLOR.RESET
    L["BTN_EXHAUST"] = ICN2.COLOR.RED .. "Exaurir" .. ICN2.COLOR.RESET
    
    -- ── Messages ──────────────────────────────────────────
    L["MSG_LOADED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " carregado. Digite " .. ICN2.COLOR.YELLOW .. "/icn2" .. ICN2.COLOR.RESET .. " para opções."
    L["MSG_RESET"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Necessidades restauradas para 100%."
    L["MSG_NEEDS_MIGRATED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Necessidades migradas para sistema baseado em pontos."
    L["MSG_RATES_UPDATED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. ": Taxas atualizadas para padrões v2.0.0."
    
    L["MSG_EAT"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Você comeu algo. Fome restaurada."
    L["MSG_DRINK"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Você bebeu algo. Sede restaurada."
    L["MSG_REST"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Você descansou. Fadiga restaurada."
    
    L["MSG_STARVE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Fome" .. ICN2.COLOR.RESET .. " definida para 0%."
    L["MSG_DEHYDRATE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Sede" .. ICN2.COLOR.RESET .. " definida para 0%."
    L["MSG_EXHAUST"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.FATIGUE .. "Fadiga" .. ICN2.COLOR.RESET .. " definida para 0%."
    
    L["MSG_HUD_ENABLED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.HUNGER .. "habilitado" .. ICN2.COLOR.RESET
    L["MSG_HUD_DISABLED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.RED .. "desabilitado" .. ICN2.COLOR.RESET
    L["MSG_HUD_LOCKED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.RED .. "travado" .. ICN2.COLOR.RESET
    L["MSG_HUD_UNLOCKED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.HUNGER .. "destravado" .. ICN2.COLOR.RESET
    
    L["MSG_WELL_FED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Bem Alimentado!" .. ICN2.COLOR.RESET .. " Decaimento de fome pausado por %d min."
    
    -- ── Details Output ────────────────────────────────────
    L["DETAILS_TITLE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.YELLOW .. "Detalhes" .. ICN2.COLOR.RESET .. " — %s"
    L["DETAILS_MODIFIERS"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.GRAY .. "Modificadores ativos:" .. ICN2.COLOR.RESET
    L["DETAILS_NONE"] = "  " .. ICN2.COLOR.GRAY .. "Nenhum (caminhando/parado ao ar livre)" .. ICN2.COLOR.RESET
    L["DETAILS_EATING"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Comendo atualmente" .. ICN2.COLOR.RESET .. "  (nível: %s)"
    L["DETAILS_DRINKING"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Bebendo atualmente" .. ICN2.COLOR.RESET .. " (nível: %s)"
    L["DETAILS_WELL_FED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Bem Alimentado" .. ICN2.COLOR.RESET .. " — decaimento de fome pausado (%ds restantes)"
    
    -- ── Situation Modifiers ───────────────────────────────
    L["SITUATION_RESTING"] = "Descansando (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_MOUNTED"] = "Montado (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_FLYING"] = "Voando (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_SWIMMING"] = "Nadando (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_COMBAT"] = "Combate (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_INDOORS"] = "Dentro de casa (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_RACE"] = "Raça:%s (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_CLASS"] = "Classe:%s (H×%.2f T×%.2f F×%.2f)"
    
    -- ── Slash Command Help ────────────────────────────────
    L["SLASH_HELP"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Comandos: " .. ICN2.COLOR.YELLOW .. "/icn2" .. ICN2.COLOR.RESET .. " [show|eat|drink|rest|reset|starve|dehydrate|exhaust|status|details|hud|lock]"
end

-- ══════════════════════════════════════════════════════════
-- SECTION 7 — Spanish (esES, esMX)
-- ══════════════════════════════════════════════════════════
if currentLocale == "esES" then
    -- ── Core Needs ────────────────────────────────────────
    L["HUNGER"] = "Hambre"
    L["THIRST"] = "Sed"
    L["FATIGUE"] = "Fatiga"
    
    -- ── Addon Branding ────────────────────────────────────
    L["ADDON_TITLE"] = "Necesidades del Personaje"
    
    -- ── HUD Elements ──────────────────────────────────────
    L["HUD_TITLE"] = "Necesidades del Personaje"
    L["HUD_TOOLTIP_TITLE"] = ICN2.COLOR.ADDON .. "ICN2 - Necesidades del Personaje" .. ICN2.COLOR.RESET
    
    -- ── Theme Names ───────────────────────────────────────
    L["THEME_SMOOTH"] = "Suave"
    L["THEME_BLOCKY"] = "Bloques"
    L["THEME_FOLK"] = "Folclórico"
    L["THEME_NECROMANCER"] = "Nigromante"
    L["THEME_DASTARDLY"] = "Malvado"
    
    -- ── Preset Names ──────────────────────────────────────
    L["PRESET_FAST"] = "Rápido"
    L["PRESET_MEDIUM"] = "Medio"
    L["PRESET_SLOW"] = "Lento"
    L["PRESET_REALISTIC"] = "Realista"
    L["PRESET_CUSTOM"] = "Personalizado"
    
    -- ── Label Modes ───────────────────────────────────────
    L["LABEL_MODE_NONE"] = "Ninguno"
    L["LABEL_MODE_PERCENTAGE"] = "Porcentaje"
    L["LABEL_MODE_NUMBER"] = "Número"
    L["LABEL_MODE_BOTH"] = "Ambos"
    
    -- ── Tab Labels ────────────────────────────────────────
    L["TAB_GENERAL"] = "General"
    L["TAB_DECAY"] = "Desgaste y tasas"
    
    -- ── General Tab Sections ──────────────────────────────
    L["SECTION_LABELS"] = "Etiquetas de barra:"
    L["SECTION_IMMERSION"] = "Inmersión"
    L["SECTION_EMOTES"] = "Emotes"
    L["SECTION_MANUAL_RESTORE"] = "Restauración manual"
    L["SECTION_MANUAL_DEPLETE"] = "Agotamiento manual"
    
    -- ── Options: HUD ──────────────────────────────────────
    L["OPT_HUD_ENABLED"] = "Activar HUD"
    L["OPT_HUD_LOCK"] = "Bloquear posición del HUD"
    L["OPT_OPACITY"] = "Opacidad"
    L["OPT_SCALE"] = "Escala"
    L["OPT_BAR_LENGTH"] = "Longitud de barra"
    
    -- ── Options: Immersion ────────────────────────────────
    L["OPT_FREEZE_OFFLINE"] = "Congelar necesidades sin conexión"
    L["OPT_FREEZE_OFFLINE_DESC"] = ICN2.COLOR.GRAY .. "(sin desgaste sin conexión)" .. ICN2.COLOR.RESET
    L["OPT_FOOD_DRINK_AUTO"] = ICN2.COLOR.GRAY .. "Los buffs de comida/bebida se detectan automáticamente." .. ICN2.COLOR.RESET
    
    -- ── Options: Emotes ───────────────────────────────────
    L["OPT_EMOTES_ENABLED"] = "Activar emotes automáticos"
    L["OPT_EMOTE_CHANCE"] = "Probabilidad de emote"
    L["OPT_EMOTE_INTERVAL"] = "Intervalo mínimo (seg)"
    
    -- ── Options: Decay Tab ────────────────────────────────
    L["OPT_DECAY_PRESET"] = "Preajuste de desgaste"
    L["OPT_DECAY_HELP_1"] = "Elige un preajuste para velocidad de desgaste global, o " .. ICN2.COLOR.YELLOW .. "Personalizado" .. ICN2.COLOR.RESET .. " para ajustar cada necesidad."
    L["OPT_DECAY_HELP_2"] = ICN2.COLOR.GRAY .. "Multiplicador personalizado vs Medio (1×): " .. ICN2.COLOR.WHITE .. "0" .. ICN2.COLOR.RESET .. ICN2.COLOR.GRAY .. " = sin desgaste pasivo; " .. ICN2.COLOR.WHITE .. "%d" .. ICN2.COLOR.RESET .. ICN2.COLOR.GRAY .. " = 10× Rápido. Controles solo lectura excepto en Personalizado." .. ICN2.COLOR.RESET
    L["OPT_PER_NEED_BIAS"] = "Sesgo de desgaste por necesidad"
    
    -- ── Decay Slider Labels ───────────────────────────────
    L["DECAY_SLIDER_PRESET"] = ICN2.COLOR.GRAY .. "(preajuste)" .. ICN2.COLOR.RESET
    
    -- ── Button Labels ─────────────────────────────────────
    L["BTN_EAT"] = ICN2.COLOR.HUNGER .. "Comer" .. ICN2.COLOR.RESET
    L["BTN_DRINK"] = ICN2.COLOR.THIRST .. "Beber" .. ICN2.COLOR.RESET
    L["BTN_REST"] = ICN2.COLOR.FATIGUE .. "Descansar" .. ICN2.COLOR.RESET
    L["BTN_RESET"] = ICN2.COLOR.RED .. "Restablecer" .. ICN2.COLOR.RESET
    L["BTN_STARVE"] = ICN2.COLOR.RED .. "Hambruna" .. ICN2.COLOR.RESET
    L["BTN_DEHYDRATE"] = ICN2.COLOR.RED .. "Deshidratar" .. ICN2.COLOR.RESET
    L["BTN_EXHAUST"] = ICN2.COLOR.RED .. "Agotar" .. ICN2.COLOR.RESET
    
    -- ── Messages ──────────────────────────────────────────
    L["MSG_LOADED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " cargado. Escribe " .. ICN2.COLOR.YELLOW .. "/icn2" .. ICN2.COLOR.RESET .. " para opciones."
    L["MSG_RESET"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Necesidades restablecidas al 100%."
    L["MSG_NEEDS_MIGRATED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Necesidades migradas al sistema basado en puntos."
    L["MSG_RATES_UPDATED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. ": Tasas actualizadas a valores predeterminados v2.0.0."
    
    L["MSG_EAT"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Comes algo. Hambre restaurado."
    L["MSG_DRINK"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Bebes algo. Sed restaurada."
    L["MSG_REST"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Descansas. Fatiga restaurada."
    
    L["MSG_STARVE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Hambre" .. ICN2.COLOR.RESET .. " establecido en 0%."
    L["MSG_DEHYDRATE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Sed" .. ICN2.COLOR.RESET .. " establecido en 0%."
    L["MSG_EXHAUST"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.FATIGUE .. "Fatiga" .. ICN2.COLOR.RESET .. " establecido en 0%."
    
    L["MSG_HUD_ENABLED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.HUNGER .. "activado" .. ICN2.COLOR.RESET
    L["MSG_HUD_DISABLED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.RED .. "desactivado" .. ICN2.COLOR.RESET
    L["MSG_HUD_LOCKED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.RED .. "bloqueado" .. ICN2.COLOR.RESET
    L["MSG_HUD_UNLOCKED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.HUNGER .. "desbloqueado" .. ICN2.COLOR.RESET
    
    L["MSG_WELL_FED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "¡Bien Alimentado!" .. ICN2.COLOR.RESET .. " Desgaste de hambre pausado por %d min."
    
    -- ── Details Output ────────────────────────────────────
    L["DETAILS_TITLE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.YELLOW .. "Detalles" .. ICN2.COLOR.RESET .. " — %s"
    L["DETAILS_MODIFIERS"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.GRAY .. "Modificadores activos:" .. ICN2.COLOR.RESET
    L["DETAILS_NONE"] = "  " .. ICN2.COLOR.GRAY .. "Ninguno (caminando/inactivo al aire libre)" .. ICN2.COLOR.RESET
    L["DETAILS_EATING"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Comiendo actualmente" .. ICN2.COLOR.RESET .. "  (nivel: %s)"
    L["DETAILS_DRINKING"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Bebiendo actualmente" .. ICN2.COLOR.RESET .. " (nivel: %s)"
    L["DETAILS_WELL_FED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Bien Alimentado" .. ICN2.COLOR.RESET .. " — desgaste de hambre pausado (%ds restantes)"
    
    -- ── Situation Modifiers ───────────────────────────────
    L["SITUATION_RESTING"] = "Descansando (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_MOUNTED"] = "Montado (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_FLYING"] = "Volando (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_SWIMMING"] = "Nadando (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_COMBAT"] = "Combate (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_INDOORS"] = "Interior (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_RACE"] = "Raza:%s (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_CLASS"] = "Clase:%s (H×%.2f T×%.2f F×%.2f)"
    
    -- ── Slash Command Help ────────────────────────────────
    L["SLASH_HELP"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Comandos: " .. ICN2.COLOR.YELLOW .. "/icn2" .. ICN2.COLOR.RESET .. " [show|eat|drink|rest|reset|starve|dehydrate|exhaust|status|details|hud|lock]"
end

-- ══════════════════════════════════════════════════════════
-- SECTION 8 — French (frFR)
-- ══════════════════════════════════════════════════════════
if currentLocale == "frFR" then
    -- ── Core Needs ────────────────────────────────────────
    L["HUNGER"] = "Faim"
    L["THIRST"] = "Soif"
    L["FATIGUE"] = "Fatigue"
    
    -- ── Addon Branding ────────────────────────────────────
    L["ADDON_TITLE"] = "Besoins du Personnage"
    
    -- ── HUD Elements ──────────────────────────────────────
    L["HUD_TITLE"] = "Besoins du Personnage"
    L["HUD_TOOLTIP_TITLE"] = ICN2.COLOR.ADDON .. "ICN2 - Besoins du Personnage" .. ICN2.COLOR.RESET
    
    -- ── Theme Names ───────────────────────────────────────
    L["THEME_SMOOTH"] = "Lisse"
    L["THEME_BLOCKY"] = "Blocs"
    L["THEME_FOLK"] = "Folklorique"
    L["THEME_NECROMANCER"] = "Nécromancien"
    L["THEME_DASTARDLY"] = "Vilain"
    
    -- ── Preset Names ──────────────────────────────────────
    L["PRESET_FAST"] = "Rapide"
    L["PRESET_MEDIUM"] = "Moyen"
    L["PRESET_SLOW"] = "Lent"
    L["PRESET_REALISTIC"] = "Réaliste"
    L["PRESET_CUSTOM"] = "Personnalisé"
    
    -- ── Label Modes ───────────────────────────────────────
    L["LABEL_MODE_NONE"] = "Aucun"
    L["LABEL_MODE_PERCENTAGE"] = "Pourcentage"
    L["LABEL_MODE_NUMBER"] = "Nombre"
    L["LABEL_MODE_BOTH"] = "Les deux"
    
    -- ── Tab Labels ────────────────────────────────────────
    L["TAB_GENERAL"] = "Général"
    L["TAB_DECAY"] = "Décroissance et taux"
    
    -- ── General Tab Sections ──────────────────────────────
    L["SECTION_LABELS"] = "Étiquettes de barre :"
    L["SECTION_IMMERSION"] = "Immersion"
    L["SECTION_EMOTES"] = "Émotes"
    L["SECTION_MANUAL_RESTORE"] = "Restauration manuelle"
    L["SECTION_MANUAL_DEPLETE"] = "Épuisement manuel"
    
    -- ── Options: HUD ──────────────────────────────────────
    L["OPT_HUD_ENABLED"] = "Activer le HUD"
    L["OPT_HUD_LOCK"] = "Verrouiller la position du HUD"
    L["OPT_OPACITY"] = "Opacité"
    L["OPT_SCALE"] = "Échelle"
    L["OPT_BAR_LENGTH"] = "Longueur de barre"
    
    -- ── Options: Immersion ────────────────────────────────
    L["OPT_FREEZE_OFFLINE"] = "Geler les besoins hors ligne"
    L["OPT_FREEZE_OFFLINE_DESC"] = ICN2.COLOR.GRAY .. "(pas de décroissance hors ligne)" .. ICN2.COLOR.RESET
    L["OPT_FOOD_DRINK_AUTO"] = ICN2.COLOR.GRAY .. "Les buffs de nourriture/boisson sont détectés automatiquement." .. ICN2.COLOR.RESET
    
    -- ── Options: Emotes ───────────────────────────────────
    L["OPT_EMOTES_ENABLED"] = "Activer les émotes automatiques"
    L["OPT_EMOTE_CHANCE"] = "Probabilité d'émote"
    L["OPT_EMOTE_INTERVAL"] = "Intervalle minimum (sec)"
    
    -- ── Options: Decay Tab ────────────────────────────────
    L["OPT_DECAY_PRESET"] = "Préréglage de décroissance"
    L["OPT_DECAY_HELP_1"] = "Choisissez un préréglage pour la vitesse de décroissance globale, ou " .. ICN2.COLOR.YELLOW .. "Personnalisé" .. ICN2.COLOR.RESET .. " pour ajuster chaque besoin."
    L["OPT_DECAY_HELP_2"] = ICN2.COLOR.GRAY .. "Multiplicateur personnalisé vs Moyen (1×) : " .. ICN2.COLOR.WHITE .. "0" .. ICN2.COLOR.RESET .. ICN2.COLOR.GRAY .. " = pas de décroissance passive ; " .. ICN2.COLOR.WHITE .. "%d" .. ICN2.COLOR.RESET .. ICN2.COLOR.GRAY .. " = 10× Rapide. Contrôles en lecture seule sauf en Personnalisé." .. ICN2.COLOR.RESET
    L["OPT_PER_NEED_BIAS"] = "Biais de décroissance par besoin"
    
    -- ── Decay Slider Labels ───────────────────────────────
    L["DECAY_SLIDER_PRESET"] = ICN2.COLOR.GRAY .. "(préréglage)" .. ICN2.COLOR.RESET
    
    -- ── Button Labels ─────────────────────────────────────
    L["BTN_EAT"] = ICN2.COLOR.HUNGER .. "Manger" .. ICN2.COLOR.RESET
    L["BTN_DRINK"] = ICN2.COLOR.THIRST .. "Boire" .. ICN2.COLOR.RESET
    L["BTN_REST"] = ICN2.COLOR.FATIGUE .. "Reposer" .. ICN2.COLOR.RESET
    L["BTN_RESET"] = ICN2.COLOR.RED .. "Réinitialiser" .. ICN2.COLOR.RESET
    L["BTN_STARVE"] = ICN2.COLOR.RED .. "Affamer" .. ICN2.COLOR.RESET
    L["BTN_DEHYDRATE"] = ICN2.COLOR.RED .. "Déshydrater" .. ICN2.COLOR.RESET
    L["BTN_EXHAUST"] = ICN2.COLOR.RED .. "Épuiser" .. ICN2.COLOR.RESET
    
    -- ── Messages ──────────────────────────────────────────
    L["MSG_LOADED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " chargé. Tapez " .. ICN2.COLOR.YELLOW .. "/icn2" .. ICN2.COLOR.RESET .. " pour les options."
    L["MSG_RESET"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Besoins rétablis à 100 %."
    L["MSG_NEEDS_MIGRATED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Besoins migrés vers le système basé sur des points."
    L["MSG_RATES_UPDATED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " : Taux mis à jour vers les valeurs par défaut v2.0.0."
    
    L["MSG_EAT"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Vous mangez quelque chose. Faim restaurée."
    L["MSG_DRINK"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Vous buvez quelque chose. Soif restaurée."
    L["MSG_REST"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Vous vous reposez. Fatigue restaurée."
    
    L["MSG_STARVE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Faim" .. ICN2.COLOR.RESET .. " défini à 0 %."
    L["MSG_DEHYDRATE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Soif" .. ICN2.COLOR.RESET .. " défini à 0 %."
    L["MSG_EXHAUST"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.FATIGUE .. "Fatigue" .. ICN2.COLOR.RESET .. " défini à 0 %."
    
    L["MSG_HUD_ENABLED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.HUNGER .. "activé" .. ICN2.COLOR.RESET
    L["MSG_HUD_DISABLED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.RED .. "désactivé" .. ICN2.COLOR.RESET
    L["MSG_HUD_LOCKED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.RED .. "verrouillé" .. ICN2.COLOR.RESET
    L["MSG_HUD_UNLOCKED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.HUNGER .. "déverrouillé" .. ICN2.COLOR.RESET
    
    L["MSG_WELL_FED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Bien Nourri !" .. ICN2.COLOR.RESET .. " Décroissance de la faim en pause pendant %d min."
    
    -- ── Details Output ────────────────────────────────────
    L["DETAILS_TITLE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.YELLOW .. "Détails" .. ICN2.COLOR.RESET .. " — %s"
    L["DETAILS_MODIFIERS"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.GRAY .. "Modificateurs actifs :" .. ICN2.COLOR.RESET
    L["DETAILS_NONE"] = "  " .. ICN2.COLOR.GRAY .. "Aucun (marche/inactif en extérieur)" .. ICN2.COLOR.RESET
    L["DETAILS_EATING"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Actuellement en train de manger" .. ICN2.COLOR.RESET .. "  (niveau : %s)"
    L["DETAILS_DRINKING"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Actuellement en train de boire" .. ICN2.COLOR.RESET .. " (niveau : %s)"
    L["DETAILS_WELL_FED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Bien Nourri" .. ICN2.COLOR.RESET .. " — décroissance de la faim en pause (%ds restantes)"
    
    -- ── Situation Modifiers ───────────────────────────────
    L["SITUATION_RESTING"] = "Au repos (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_MOUNTED"] = "Monté (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_FLYING"] = "En vol (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_SWIMMING"] = "Nage (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_COMBAT"] = "Combat (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_INDOORS"] = "Intérieur (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_RACE"] = "Race :%s (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_CLASS"] = "Classe :%s (H×%.2f T×%.2f F×%.2f)"
    
    -- ── Slash Command Help ────────────────────────────────
    L["SLASH_HELP"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Commandes : " .. ICN2.COLOR.YELLOW .. "/icn2" .. ICN2.COLOR.RESET .. " [show|eat|drink|rest|reset|starve|dehydrate|exhaust|status|details|hud|lock]"
end

-- ══════════════════════════════════════════════════════════
-- SECTION 9 — German (deDE)
-- ══════════════════════════════════════════════════════════
-- Translator notes:
-- - Preserve all color codes (|cFFxxxxxx and |r)
-- - Keep format specifiers (%s, %d, %.2f) in the same order
-- - Theme names can be translated except for proper nouns
-- - "WIP" = Work In Progress (can be translated as "in Arbeit", "en curso", etc.)
if currentLocale == "deDE" then
    -- ── Core Needs ────────────────────────────────────────
    L["HUNGER"] = "Hunger"
    L["THIRST"] = "Durst"
    L["FATIGUE"] = "Erschöpfung"
    
    -- ── Addon Branding ────────────────────────────────────
    L["ADDON_TITLE"] = "Charakterbedürfnisse"
    
    -- ── HUD Elements ──────────────────────────────────────
    L["HUD_TITLE"] = "Charakterbedürfnisse"
    L["HUD_TOOLTIP_TITLE"] = ICN2.COLOR.ADDON .. "ICN2 - Charakterbedürfnisse" .. ICN2.COLOR.RESET
    
    -- ── Theme Names ───────────────────────────────────────
    L["THEME_SMOOTH"] = "Glatt"
    L["THEME_BLOCKY"] = "Blockartig"
    L["THEME_FOLK"] = "Folkloristisch"
    L["THEME_NECROMANCER"] = "Nekromant"
    L["THEME_DASTARDLY"] = "Schurke"
    
    -- ── Preset Names ──────────────────────────────────────
    L["PRESET_FAST"] = "Schnell"
    L["PRESET_MEDIUM"] = "Mittel"
    L["PRESET_SLOW"] = "Langsam"
    L["PRESET_REALISTIC"] = "Realistisch"
    L["PRESET_CUSTOM"] = "Benutzerdefiniert"
    
    -- ── Label Modes ───────────────────────────────────────
    L["LABEL_MODE_NONE"] = "Keine"
    L["LABEL_MODE_PERCENTAGE"] = "Prozentsatz"
    L["LABEL_MODE_NUMBER"] = "Zahl"
    L["LABEL_MODE_BOTH"] = "Beides"
    
    -- ── Tab Labels ────────────────────────────────────────
    L["TAB_GENERAL"] = "Allgemein"
    L["TAB_DECAY"] = "Verfall und Raten"
    
    -- ── General Tab Sections ──────────────────────────────
    L["SECTION_LABELS"] = "Leistenbeschriftungen:"
    L["SECTION_IMMERSION"] = "Immersion"
    L["SECTION_EMOTES"] = "Emotes"
    L["SECTION_MANUAL_RESTORE"] = "Manuelle Wiederherstellung"
    L["SECTION_MANUAL_DEPLETE"] = "Manuelle Erschöpfung"
    
    -- ── Options: HUD ──────────────────────────────────────
    L["OPT_HUD_ENABLED"] = "HUD aktivieren"
    L["OPT_HUD_LOCK"] = "HUD-Position sperren"
    L["OPT_OPACITY"] = "Deckkraft"
    L["OPT_SCALE"] = "Skalierung"
    L["OPT_BAR_LENGTH"] = "Leistenlänge"
    
    -- ── Options: Immersion ────────────────────────────────
    L["OPT_FREEZE_OFFLINE"] = "Bedürfnisse offline einfrieren"
    L["OPT_FREEZE_OFFLINE_DESC"] = ICN2.COLOR.GRAY .. "(kein Offline-Verfall)" .. ICN2.COLOR.RESET
    L["OPT_FOOD_DRINK_AUTO"] = ICN2.COLOR.GRAY .. "Nahrungs-/Getränkebuffs werden automatisch erkannt." .. ICN2.COLOR.RESET
    
    -- ── Options: Emotes ───────────────────────────────────
    L["OPT_EMOTES_ENABLED"] = "Automatische Emotes aktivieren"
    L["OPT_EMOTE_CHANCE"] = "Emote-Wahrscheinlichkeit"
    L["OPT_EMOTE_INTERVAL"] = "Mindestintervall (Sek)"
    
    -- ── Options: Decay Tab ────────────────────────────────
    L["OPT_DECAY_PRESET"] = "Verfallsvorgabe"
    L["OPT_DECAY_HELP_1"] = "Wähle eine Vorgabe für globale Verfallgeschwindigkeit oder " .. ICN2.COLOR.YELLOW .. "Benutzerdefiniert" .. ICN2.COLOR.RESET .. " für individuelle Anpassung."
    L["OPT_DECAY_HELP_2"] = ICN2.COLOR.GRAY .. "Benutzerdefinierter Multiplikator vs Mittel (1×): " .. ICN2.COLOR.WHITE .. "0" .. ICN2.COLOR.RESET .. ICN2.COLOR.GRAY .. " = kein passiver Verfall; " .. ICN2.COLOR.WHITE .. "%d" .. ICN2.COLOR.RESET .. ICN2.COLOR.GRAY .. " = 10× Schnell. Regler schreibgeschützt außer bei Benutzerdefiniert." .. ICN2.COLOR.RESET
    L["OPT_PER_NEED_BIAS"] = "Verfallverzerrung pro Bedürfnis"
    
    -- ── Decay Slider Labels ───────────────────────────────
    L["DECAY_SLIDER_PRESET"] = ICN2.COLOR.GRAY .. "(Vorgabe)" .. ICN2.COLOR.RESET
    
    -- ── Button Labels ─────────────────────────────────────
    L["BTN_EAT"] = ICN2.COLOR.HUNGER .. "Essen" .. ICN2.COLOR.RESET
    L["BTN_DRINK"] = ICN2.COLOR.THIRST .. "Trinken" .. ICN2.COLOR.RESET
    L["BTN_REST"] = ICN2.COLOR.FATIGUE .. "Ruhen" .. ICN2.COLOR.RESET
    L["BTN_RESET"] = ICN2.COLOR.RED .. "Zurücksetzen" .. ICN2.COLOR.RESET
    L["BTN_STARVE"] = ICN2.COLOR.RED .. "Verhungern" .. ICN2.COLOR.RESET
    L["BTN_DEHYDRATE"] = ICN2.COLOR.RED .. "Austrocknen" .. ICN2.COLOR.RESET
    L["BTN_EXHAUST"] = ICN2.COLOR.RED .. "Erschöpfen" .. ICN2.COLOR.RESET
    
    -- ── Messages ──────────────────────────────────────────
    L["MSG_LOADED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " geladen. Gib " .. ICN2.COLOR.YELLOW .. "/icn2" .. ICN2.COLOR.RESET .. " für Optionen ein."
    L["MSG_RESET"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Bedürfnisse auf 100 % zurückgesetzt."
    L["MSG_NEEDS_MIGRATED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Bedürfnisse zu punktebasiertem System migriert."
    L["MSG_RATES_UPDATED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. ": Raten auf v2.0.0-Standardwerte aktualisiert."
    
    L["MSG_EAT"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Du isst etwas. Hunger wiederhergestellt."
    L["MSG_DRINK"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Du trinkst etwas. Durst wiederhergestellt."
    L["MSG_REST"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Du ruhst dich aus. Erschöpfung wiederhergestellt."
    
    L["MSG_STARVE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Hunger" .. ICN2.COLOR.RESET .. " auf 0 % gesetzt."
    L["MSG_DEHYDRATE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Durst" .. ICN2.COLOR.RESET .. " auf 0 % gesetzt."
    L["MSG_EXHAUST"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.FATIGUE .. "Erschöpfung" .. ICN2.COLOR.RESET .. " auf 0 % gesetzt."
    
    L["MSG_HUD_ENABLED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.HUNGER .. "aktiviert" .. ICN2.COLOR.RESET
    L["MSG_HUD_DISABLED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.RED .. "deaktiviert" .. ICN2.COLOR.RESET
    L["MSG_HUD_LOCKED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.RED .. "gesperrt" .. ICN2.COLOR.RESET
    L["MSG_HUD_UNLOCKED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " HUD " .. ICN2.COLOR.HUNGER .. "entsperrt" .. ICN2.COLOR.RESET
    
    L["MSG_WELL_FED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Gut Genährt!" .. ICN2.COLOR.RESET .. " Hungerverfall pausiert für %d Min."
    
    -- ── Details Output ────────────────────────────────────
    L["DETAILS_TITLE"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.YELLOW .. "Details" .. ICN2.COLOR.RESET .. " — %s"
    L["DETAILS_MODIFIERS"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.GRAY .. "Aktive Modifikatoren:" .. ICN2.COLOR.RESET
    L["DETAILS_NONE"] = "  " .. ICN2.COLOR.GRAY .. "Keine (Gehen/Untätig im Freien)" .. ICN2.COLOR.RESET
    L["DETAILS_EATING"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Derzeit am Essen" .. ICN2.COLOR.RESET .. "  (Stufe: %s)"
    L["DETAILS_DRINKING"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.THIRST .. "Derzeit am Trinken" .. ICN2.COLOR.RESET .. " (Stufe: %s)"
    L["DETAILS_WELL_FED"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " " .. ICN2.COLOR.HUNGER .. "Gut Genährt" .. ICN2.COLOR.RESET .. " — Hungerverfall pausiert (%ds verbleibend)"
    
    -- ── Situation Modifiers ───────────────────────────────
    L["SITUATION_RESTING"] = "Ausruhen (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_MOUNTED"] = "Beritten (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_FLYING"] = "Fliegend (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_SWIMMING"] = "Schwimmend (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_COMBAT"] = "Kampf (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_INDOORS"] = "Innenraum (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_RACE"] = "Rasse:%s (H×%.2f T×%.2f F×%.2f)"
    L["SITUATION_CLASS"] = "Klasse:%s (H×%.2f T×%.2f F×%.2f)"
    
    -- ── Slash Command Help ────────────────────────────────
    L["SLASH_HELP"] = ICN2.COLOR.ADDON .. "ICN2" .. ICN2.COLOR.RESET .. " Befehle: " .. ICN2.COLOR.YELLOW .. "/icn2" .. ICN2.COLOR.RESET .. " [show|eat|drink|rest|reset|starve|dehydrate|exhaust|status|details|hud|lock]"
end
