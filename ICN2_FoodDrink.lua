-- ============================================================
-- Hooks WoW's native food/drink buff events via UNIT_AURA.
-- Food/drink tier system
-- ──────────────────────────────────────────────────────────────
-- Tier is detected once when the eating/drinking buff first
-- appears, by scanning the player's bags for a food/drink item
-- and inspecting its on-use spell description via:
--
--   GetItemSpell(itemLink)  → spellName, spellID
--   GetSpellDescription(spellID) → desc   (global; C_Spell.GetSpellDescription DNE in TWW 12.0)
--
-- If desc contains "well fed" (case-insensitive), the item grants a secondary stat buff → COMPLEX tier.
-- If the eating aura name contains feast keywords → FEAST tier.
-- Otherwise → SIMPLE tier.
--
-- Tiers:
--   SIMPLE  — 30% trickle over duration + 10% completion bonus
--   COMPLEX — 40% trickle over duration + 15% completion bonus
--   FEAST   — 60% trickle over duration + 20% completion bonus
--             (applies to BOTH hunger and thirst simultaneously)
--
-- The per-second trickle is applied in Core's _ApplyFoodDrinkRecovery.
-- The completion bonus is a lump-sum applied here on natural expiry.
--
-- Well Fed rework
-- ──────────────────────────────────────────────────────────────
-- Well Fed no longer restores hunger/thirst directly.
-- When the aura applies, it pauses hunger decay for 5 minutes
-- by setting ICN2._wellFedPauseExpiry, read by Core's
-- _ApplyWellFedPause modifier.
-- ============================================================

ICN2 = ICN2 or {}

-- ── Constants ─────────────────────────────────────────────────────────────────
local TIER_DATA = {
    simple  = { trickle = 30.0, bonus = 10.0 },
    complex = { trickle = 40.0, bonus = 15.0 },
    feast   = { trickle = 60.0, bonus = 20.0 },
}

local WELLFED_PAUSE_SECS = 300  -- 5 minutes

-- ── Public state (read by Core) ───────────────────────────────────────────────
ICN2._wellFedPauseExpiry = 0    -- GetTime() timestamp; 0 = not active

-- ── Internal state ────────────────────────────────────────────────────────────
local foodState  = { active = false, startTime = nil, duration = nil, tier = nil }
local drinkState = { active = false, startTime = nil, duration = nil, tier = nil }

-- ── Aura name patterns ────────────────────────────────────────────────────────
local FOOD_AURA_PATTERNS   = { "food", "refreshment", "eating" }
local DRINK_AURA_PATTERNS  = { "drink", "drinking", "hydration" }
local DRINK_EXTRA_PATTERNS = { "conjured water", "mana tea", "morning glory" }
local WELLFED_PATTERNS     = { "well fed" }
local FEAST_NAME_PATTERNS  = { "feast", "banquet", "spread", "bountiful" }

-- ── Aura helpers ──────────────────────────────────────────────────────────────
local function matchesAny(name, patterns) -- case-insensitive substring match
    if not name then return false end
    local lower = string.lower(name)
    for _, p in ipairs(patterns) do
        if lower:find(p, 1, true) then return true end
    end
    return false
end

local function findAura(patterns, extraPatterns) -- returns the first matching aura, or nil if not found
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        if matchesAny(aura.name, patterns) then return aura end
        if extraPatterns and matchesAny(aura.name, extraPatterns) then return aura end
        i = i + 1
    end
    return nil
end

-- ── Tier detection ────────────────────────────────────────────────────────────
-- Called once when the eating/drinking buff first appears.
-- Scans the player's bags for a food/drink item and checks its tooltip
-- for "Well Fed" to determine if it's complex tier.
--
-- TWW 12.0 API notes:
--   C_Container.GetContainerNumSlots / GetContainerItemLink — correct calls.
--   GetContainerItemLink global was removed in Dragonflight.
--   C_TooltipInfo.GetItemByID returns tooltip lines including secondary effects.
--
-- Returns "feast" | "complex" | "simple".
local function detectTierFromBags(isFeast)
    if isFeast then return "feast" end

    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    -- Use C_TooltipInfo to read tooltip lines, which includes
                    -- secondary effects like "Well Fed" that GetSpellDescription
                    -- may not return reliably for food items.
                    local itemID = C_Item.GetItemIDByGUID and
                        select(1, strsplit(":", itemLink:match("|Hitem:([%d:]+)|"))) or nil
                    if not itemID then
                        -- Fallback: parse item ID directly from link
                        itemID = tonumber(itemLink:match("|Hitem:(%d+):"))
                    end
                    if itemID then
                        local tooltipData = C_TooltipInfo and C_TooltipInfo.GetItemByID(tonumber(itemID))
                        if tooltipData and tooltipData.lines then
                            for _, line in ipairs(tooltipData.lines) do
                                local text = line.leftText or ""
                                if text:lower():find("well fed", 1, true) then
                                    return "complex"
                                end
                            end
                        else
                            -- C_TooltipInfo unavailable; fall back to GetSpellDescription
                            local _, spellID = GetItemSpell(itemLink)
                            if spellID then
                                local desc = GetSpellDescription and GetSpellDescription(spellID) or ""
                                if desc:lower():find("well fed", 1, true) then
                                    return "complex"
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return "simple"
end

local function detectFoodTier(foodAura)
    local isFeast = matchesAny(foodAura.name, FEAST_NAME_PATTERNS)
    return detectTierFromBags(isFeast)
end

local function detectDrinkTier() -- Feasts cover both needs; if food is already feast, drink inherits it.
    if foodState.active and foodState.tier == "feast" then return "feast" end
    return detectTierFromBags(false)
end

-- ── Apply completion bonus ─────────────────────────────
local function applyBonus(state, need, natural) -- On natural completion we add a lump-sum bonus. Interrupted sessions get nothing.
    if not state.tier or not natural then return end

    local data   = TIER_DATA[state.tier] or TIER_DATA.simple
    local bonus  = data.bonus
    local isFeast = state.tier == "feast"

    if need == "hunger" or isFeast then
        ICN2DB.hunger = math.min(100, ICN2DB.hunger + bonus)
        ICN2:TriggerEmote("satisfied", "hunger")
    end
    if need == "thirst" or isFeast then
        ICN2DB.thirst = math.min(100, ICN2DB.thirst + bonus)
        ICN2:TriggerEmote("satisfied", "thirst")
    end

    ICN2:UpdateHUD()

    local needStr = (need == "hunger") and "|cFF00FF00Hunger|r" or "|cFF4499FFThirst|r"
    if isFeast then needStr = "|cFF00FF00Hunger|r & |cFF4499FFThirst|r" end
    print(string.format("|cFFFF6600ICN2|r %s completion bonus! (+%.0f%% — %s tier)",
        needStr, bonus, state.tier))
end

-- ── Main aura scan ────────────────────────────────────────────────────────────
function ICN2:OnUnitAura() -- Fires on UNIT_AURA, which is more reliable than the native food/drink buff events that can be missed if the buff applies and expires while the player is in combat.
    if UnitAffectingCombat("player") then return end

    local now = GetTime()

    -- ── Food ──────────────────────────────────────────────────────────────────
    local foodAura = findAura(FOOD_AURA_PATTERNS)
    if foodAura then
        if not foodState.active then
            foodState.active    = true
            foodState.startTime = now
            foodState.duration  = foodAura.duration or 30
            foodState.tier      = detectFoodTier(foodAura)
        end
    else
        if foodState.active then
            local elapsed = now - (foodState.startTime or now)
            local natural = elapsed >= (foodState.duration or 30) * 0.85
            applyBonus(foodState, "hunger", natural)
            foodState.active    = false
            foodState.startTime = nil
            foodState.duration  = nil
            foodState.tier      = nil
        end
    end

    -- ── Well Fed ──────────────────────────────────────────────────────────────
    local wellFedAura = findAura(WELLFED_PATTERNS)
    if wellFedAura then
        local id = wellFedAura.auraInstanceID or 0
        if id ~= ICN2._lastWellFedInstanceID then
            ICN2._lastWellFedInstanceID = id
            ICN2._wellFedPauseExpiry    = now + WELLFED_PAUSE_SECS
            print(string.format(
                "|cFFFF6600ICN2|r |cFF00FF00Well Fed!|r Hunger decay paused for %d min.",
                math.floor(WELLFED_PAUSE_SECS / 60)))
        end
    else
        ICN2._lastWellFedInstanceID = nil
        -- Do NOT clear _wellFedPauseExpiry here — the pause runs its full
        -- 5 minutes even if the aura drops before the timer expires.
    end

    -- ── Drink ─────────────────────────────────────────────────────────────────
    local drinkAura = findAura(DRINK_AURA_PATTERNS, DRINK_EXTRA_PATTERNS)
    if drinkAura then
        if not drinkState.active then
            drinkState.active    = true
            drinkState.startTime = now
            drinkState.duration  = drinkAura.duration or 30
            drinkState.tier      = detectDrinkTier()
        end
    else
        if drinkState.active then
            local elapsed = now - (drinkState.startTime or now)
            local natural = elapsed >= (drinkState.duration or 30) * 0.85
            applyBonus(drinkState, "thirst", natural)
            drinkState.active    = false
            drinkState.startTime = nil
            drinkState.duration  = nil
            drinkState.tier      = nil
        end
    end
end

-- ── Stubs ─────────────────────────────────────────────────────────────────────
function ICN2:OnCombatBreakFoodDrink() end
function ICN2:FoodDrinkTick()          end

-- ── Status queries (read by Core rate engine) ─────────────────────────────────
function ICN2:IsEating()         return foodState.active            end -- Active = has the food buff aura; not necessarily still eating (could be in the post-eating buff phase)
function ICN2:IsDrinking()       return drinkState.active           end -- Active = has the drink buff aura; not necessarily still drinking (could be in the post-drinking buff phase)
function ICN2:GetFoodTier()      return foodState.tier or "simple"  end -- If active, tier is set to "simple", "complex", or "feast". If not active, tier is nil, but we return "simple" as a default for simplicity in Core's rate calculations.
function ICN2:GetDrinkTier()     return drinkState.tier or "simple" end -- Same logic as GetFoodTier.
function ICN2:GetFoodDuration()  return foodState.duration          end -- If active, duration is the total duration of the food buff. If not active, duration is nil.
function ICN2:GetDrinkDuration() return drinkState.duration         end -- Same logic as GetFoodDuration.
