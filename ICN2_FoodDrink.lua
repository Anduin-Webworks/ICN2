-- ============================================================
-- ICN2_FoodDrink.lua  (v1.4.1)
-- Hooks WoW's native food/drink buff events via UNIT_AURA.
--
-- Food/drink tier system:
--   SIMPLE  — eating/drinking aura with no secondary spell effect
--             (no Well Fed or similar buff accompanying it)
--             Restores 30% over the buff duration, +10% on full session.
--
--   COMPLEX — eating/drinking aura WITH a secondary spell effect
--             (Well Fed, or any stat buff that appears simultaneously)
--             Restores 40% over the buff duration, +15% on full session.
--
--   FEAST   — like COMPLEX but feeds multiple people; detected by
--             checking if the eating aura's name contains known feast
--             keywords. Restores 60% over the duration, +20% on full
--             session for BOTH hunger AND thirst simultaneously.
--
-- Tier detection (v1.4.1 FIXED):
--   The old approach scanned ALL player buffs for long-duration secondary
--   effects, which caused false positives when unrelated buffs (flasks,
--   guild perks, zone auras) were active.
--
--   The NEW approach uses timing correlation: complex food applies both
--   the eating buff and the stat buff nearly simultaneously (within ~0.1-0.5s).
--   We track when stat buffs appear, and only classify food as "complex" if
--   a stat buff appeared within the last 1 second. This eliminates false
--   positives from pre-existing unrelated buffs.
--
-- Well Fed rework:
--   Well Fed no longer restores hunger/thirst directly. Instead, when
--   the aura is applied, it pauses hunger decay for WELLFED_PAUSE_SECS.
--   ICN2._wellFedPauseExpiry (public) is read by calculateCurrentRates()
--   in Core to suppress hunger decay while active.
--
-- How it works:
--   1. UNIT_AURA fires when food/drink buffs appear or disappear.
--   2. We track when stat buffs appear (recentSecondaryBuffs table).
--   3. On food/drink buff appear: check if stat buff appeared recently.
--   4. Tier is resolved once at buff-appear time and cached in state.
--   5. On buff expire naturally (>=85% duration elapsed): full bonus.
--   6. On buff cancelled early: proportional fraction of the trickle %.
--   7. Well Fed: sets _wellFedPauseExpiry, suppressing hunger decay.
-- ============================================================

ICN2 = ICN2 or {}

-- ── Constants ─────────────────────────────────────────────────────────────────
-- Trickle: % restored per second during the buff (spread over duration).
-- Bonus:   % restored on natural completion (full session).
local TIER = {
    simple  = { trickle = 30.0, bonus = 10.0 },
    complex = { trickle = 40.0, bonus = 15.0 },
    feast   = { trickle = 60.0, bonus = 20.0 },  -- applies to both hunger AND thirst
}

-- How long Well Fed pauses hunger decay (seconds).
local WELLFED_PAUSE_SECS = 300  -- 5 minutes

-- ── Public state (read by Core) ───────────────────────────────────────────────
-- Expiry timestamp from GetTime(). 0 = not active.
ICN2._wellFedPauseExpiry = 0

-- ── Internal state ────────────────────────────────────────────────────────────
-- tier: "simple" | "complex" | "feast" | nil
local foodState  = { active = false, startTime = nil, duration = nil, tier = nil }
local drinkState = { active = false, startTime = nil, duration = nil, tier = nil }

-- Track when secondary buffs appeared to correlate with food/drink timing
local recentSecondaryBuffs = {}  -- [auraInstanceID] = appearTime

-- ── Aura name patterns (lowercase, plain string match) ────────────────────────
local FOOD_AURA_PATTERNS   = { "food", "refreshment", "eating" }
local DRINK_AURA_PATTERNS  = { "drink", "drinking", "hydration" }
local DRINK_EXTRA_PATTERNS = { "conjured water", "mana tea", "morning glory" }
local WELLFED_PATTERNS     = { "well fed" }

-- Feast detection — checked against the food aura name itself.
-- Feasts in WoW typically have "feast", "banquet", or "spread" in the name.
local FEAST_NAME_PATTERNS  = { "feast", "banquet", "spread", "bountiful" }

-- Patterns that indicate a stat buff from food (complex tier).
-- These are buff names that food items apply as secondary effects.
local STAT_BUFF_PATTERNS = {
    "well fed",
    "versatility",    -- food stat buffs
    "haste",
    "critical strike",
    "mastery",
    "stamina",
    "strength",
    "agility",
    "intellect",
    "primary stat",
    "nourished",
    "feast",          -- feast buffs
    "banquet",
}

-- Patterns that indicate a secondary spell effect (complex tier).
-- These are buff names that appear alongside food/drink auras.
-- We deliberately exclude the food/drink aura names themselves and
-- common short-duration cosmetic auras.
local SECONDARY_EXCLUDE_PATTERNS = {
    "food", "drink", "eating", "drinking", "refreshment",
    "hydration", "conjured water", "mana tea", "morning glory",
    "recently fed", "recently bitten",  -- combat/racial auras, not food buffs
}

-- ── Aura scanner ─────────────────────────────────────────────────────────────
local function scanAuras(unit)
    local results = {}
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        results[i] = aura
        i = i + 1
    end
    return results
end

local function matchesAny(name, patterns)
    if not name then return false end
    local lower = string.lower(name)
    for _, p in ipairs(patterns) do
        if lower:find(p, 1, true) then return true end
    end
    return false
end

local function findAura(patterns, extraPatterns)
    local auras = scanAuras("player")
    for _, aura in ipairs(auras) do
        if matchesAny(aura.name, patterns) then return aura end
        if extraPatterns and matchesAny(aura.name, extraPatterns) then return aura end
    end
    return nil
end

-- ── Tier detection ────────────────────────────────────────────────────────────
-- Called once when a food/drink aura first appears.
-- Returns "feast", "complex", or "simple".
--
-- NEW APPROACH (v1.4.1):
--   Instead of checking ALL player buffs (which causes false positives from
--   unrelated long-duration buffs like flasks, guild perks, zone auras), we
--   check if a stat buff appeared RECENTLY (within last 1 second).
--
--   This works because complex food applies both buffs nearly simultaneously:
--     1. The eating/drinking aura (appears first, triggers UNIT_AURA)
--     2. The stat buff (Well Fed, etc.) appears within ~0.1-0.5 seconds
--
--   By checking timing correlation instead of just buff coexistence, we avoid
--   false positives from pre-existing unrelated buffs.
--
-- Logic:
--   1. If the food aura name matches feast keywords → FEAST
--   2. If any stat buff appeared within last 1 second → COMPLEX
--   3. Otherwise → SIMPLE
--
local function detectFoodTier(foodAura)
    -- Step 1: feast check on the food buff name itself
    if matchesAny(foodAura.name, FEAST_NAME_PATTERNS) then
        return "feast"
    end

    -- Step 2: check if a stat buff appeared recently (within last 1 second)
    local now = GetTime()
    local auras = scanAuras("player")
    
    for _, aura in ipairs(auras) do
        -- Skip the food aura itself
        if aura.auraInstanceID ~= foodAura.auraInstanceID then
            -- Check if this is a stat buff
            if matchesAny(aura.name, STAT_BUFF_PATTERNS) then
                -- Check timing: did this buff appear recently?
                local buffAppearTime = recentSecondaryBuffs[aura.auraInstanceID]
                if buffAppearTime and (now - buffAppearTime) <= 1.0 then
                    -- Stat buff appeared within 1 second of food buff → complex food
                    return "complex"
                end
            end
        end
    end

    return "simple"
end

-- Drink tier mirrors food tier but feasts always give both,
-- so drink inherits the food tier when a feast is active.
local function detectDrinkTier(drinkAura)
    -- Feasts cover both needs — if food is already a feast, drink is too.
    if foodState.active and foodState.tier == "feast" then
        return "feast"
    end

    -- Check for recently appeared stat buff same as food
    local now = GetTime()
    local auras = scanAuras("player")
    
    for _, aura in ipairs(auras) do
        if aura.auraInstanceID ~= drinkAura.auraInstanceID then
            if matchesAny(aura.name, STAT_BUFF_PATTERNS) then
                local buffAppearTime = recentSecondaryBuffs[aura.auraInstanceID]
                if buffAppearTime and (now - buffAppearTime) <= 1.0 then
                    return "complex"
                end
            end
        end
    end

    return "simple"
end

-- ── Apply restoration on buff end ─────────────────────────────────────────────
-- full = true  → natural expiry (full bonus applies)
-- full = false → early cancel (proportional trickle fraction only)
local function applyRestore(state, need, full)
    if not state.startTime or not state.tier then return end

    local elapsed  = GetTime() - state.startTime
    local duration = state.duration or 30
    local fraction = math.min(1.0, elapsed / math.max(1, duration))
    local tierData = TIER[state.tier] or TIER.simple

    -- Trickle is already applied per-second via calculateCurrentRates(),
    -- so on buff end we only grant the completion bonus (if natural).
    -- For early cancels, we grant nothing extra — the per-second trickle
    -- already credited the proportional amount during the session.
    local bonusAmount = full and tierData.bonus or 0

    if need == "hunger" or (state.tier == "feast" and need == "hunger") then
        ICN2DB.hunger = math.min(100, ICN2DB.hunger + bonusAmount)
        if bonusAmount > 0 then ICN2:TriggerEmote("satisfied", "hunger") end
    end
    if need == "thirst" or (state.tier == "feast" and need == "thirst") then
        ICN2DB.thirst = math.min(100, ICN2DB.thirst + bonusAmount)
        if bonusAmount > 0 then ICN2:TriggerEmote("satisfied", "thirst") end
    end

    ICN2:UpdateHUD()

    if full and bonusAmount > 0 then
        local needStr = (need == "hunger") and "|cFF00FF00Hunger|r" or "|cFF4499FFThirst|r"
        if state.tier == "feast" then needStr = "|cFF00FF00Hunger|r & |cFF4499FFThirst|r" end
        print(string.format("|cFFFF6600ICN2|r %s bonus! (+%.0f%% — %s)",
            needStr, bonusAmount, state.tier))
    end
end

-- ── Main aura scan — called on every UNIT_AURA for player ─────────────────────
function ICN2:OnUnitAura()
    if UnitAffectingCombat("player") then return end

    local now = GetTime()

    -- ── Track stat buff appearances for tier detection ───────────────────────
    -- Clean up old tracking data (older than 2 seconds)
    for id, appearTime in pairs(recentSecondaryBuffs) do
        if (now - appearTime) > 2.0 then
            recentSecondaryBuffs[id] = nil
        end
    end
    
    -- Record when stat buffs appear
    local auras = scanAuras("player")
    for _, aura in ipairs(auras) do
        if matchesAny(aura.name, STAT_BUFF_PATTERNS) then
            local id = aura.auraInstanceID
            if not recentSecondaryBuffs[id] then
                recentSecondaryBuffs[id] = now
            end
        end
    end

    -- ── Food ──────────────────────────────────────────────────────────────────
    local foodAura = findAura(FOOD_AURA_PATTERNS)
    if foodAura then
        if not foodState.active then
            foodState.active    = true
            foodState.startTime = now
            foodState.duration  = foodAura.duration or 30
            foodState.tier      = detectFoodTier(foodAura)
            
            -- Debug: print detected tier
            if foodState.tier then
                print(string.format("|cFFFF6600ICN2|r Food tier: |cFF00FF00%s|r", foodState.tier))
            end
        end
    else
        if foodState.active then
            local elapsed = now - (foodState.startTime or now)
            local natural = elapsed >= (foodState.duration or 30) * 0.85
            applyRestore(foodState, "hunger", natural)
            foodState.active    = false
            foodState.startTime = nil
            foodState.duration  = nil
            foodState.tier      = nil
        end
    end

    -- ── Well Fed ──────────────────────────────────────────────────────────────
    -- Well Fed no longer restores needs directly.
    -- Instead it pauses hunger decay for WELLFED_PAUSE_SECS.
    -- The pause is tracked via ICN2._wellFedPauseExpiry (read in Core).
    local wellFedAura = findAura(WELLFED_PATTERNS)
    if wellFedAura then
        local id = wellFedAura.auraInstanceID or 0
        if id ~= ICN2._lastWellFedInstanceID then
            ICN2._lastWellFedInstanceID = id
            local expiry = now + WELLFED_PAUSE_SECS
            ICN2._wellFedPauseExpiry = expiry
            print(string.format(
                "|cFFFF6600ICN2|r |cFF00FF00Well Fed!|r Hunger decay paused for %d min.",
                math.floor(WELLFED_PAUSE_SECS / 60)))
        end
    else
        ICN2._lastWellFedInstanceID = nil
        -- Note: we do NOT clear _wellFedPauseExpiry here — the pause
        -- continues until the timer expires even if the aura drops early.
    end

    -- ── Drink ─────────────────────────────────────────────────────────────────
    local drinkAura = findAura(DRINK_AURA_PATTERNS, DRINK_EXTRA_PATTERNS)
    if drinkAura then
        if not drinkState.active then
            drinkState.active    = true
            drinkState.startTime = now
            drinkState.duration  = drinkAura.duration or 30
            drinkState.tier      = detectDrinkTier(drinkAura)
            
            -- Debug: print detected tier
            if drinkState.tier then
                print(string.format("|cFFFF6600ICN2|r Drink tier: |cFF4499FF%s|r", drinkState.tier))
            end
        end
    else
        if drinkState.active then
            local elapsed = now - (drinkState.startTime or now)
            local natural = elapsed >= (drinkState.duration or 30) * 0.85
            applyRestore(drinkState, "thirst", natural)
            drinkState.active    = false
            drinkState.startTime = nil
            drinkState.duration  = nil
            drinkState.tier      = nil
        end
    end
end

-- ── Combat break hook ─────────────────────────────────────────────────────────
function ICN2:OnCombatBreakFoodDrink()
end

-- ── Trickle tick stub ─────────────────────────────────────────────────────────
function ICN2:FoodDrinkTick()
end

-- ── Status queries ────────────────────────────────────────────────────────────
function ICN2:IsEating()         return foodState.active              end
function ICN2:IsDrinking()       return drinkState.active             end
function ICN2:GetFoodTier()      return foodState.tier or "simple"    end
function ICN2:GetDrinkTier()     return drinkState.tier or "simple"   end
function ICN2:GetFoodDuration()  return foodState.duration            end
function ICN2:GetDrinkDuration() return drinkState.duration           end
