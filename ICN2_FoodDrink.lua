-- =====================================================================================
-- ICN2_FoodDrink.lua
-- Tracks food and drink buffs, detects their tiers, and applies completion bonuses.
-- Uses aura scanning for reliable detection of buffs that apply/expire during combat.
-- Also keeps a short-lived memory of the last consumed food/drink item so item
-- quality can be used as a fast-path hint before the aura logic runs.
-- =====================================================================================

ICN2 = ICN2 or {}

-- Item APIs are namespaced on newer Retail/PTR builds.  Keep one compatibility
-- alias so item hints remain optional and never prevent this module from loading.
local getItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local getItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant

local L = setmetatable({}, { __index = function(_, k)
    return ICN2.L and ICN2.L[k] or k
end })

-- ── Constants ─────────────────────────────────────────────────────────────────
-- Tier data defines the recovery rates and completion bonuses for each food/drink tier
local TIER_DATA = {
    simple  = { trickle = 30.0, bonus = 10.0 },  -- Simple items: 30 points over duration + 10 point bonus
    complex = { trickle = 40.0, bonus = 20.0 },  -- Complex items: 40 points over duration + 20 point bonus
    feast   = { trickle = 60.0, bonus = 40.0 },  -- Feasts: 60 points over duration + 40 point bonus, applies to both hunger and thirst
}

local WELLFED_PAUSE_SECS = 300
local CONSUMABLE_HINT_TTL = 2.0

-- ── Public state (read by Core) ───────────────────────────────────────────────
ICN2._wellFedPauseExpiry = 0    -- GetTime() timestamp when well-fed pause expires; 0 = not active

-- ── Internal state ────────────────────────────────────────────────────────────
-- Tracks current food and drink consumption states
local foodState  = { active = false, startTime = nil, duration = nil, tier = nil }
local drinkState = { active = false, startTime = nil, duration = nil, tier = nil }

ICN2._recentConsumableUse = {
    tier       = nil,
    quality    = nil,
    itemRef    = nil,
    expiresAt  = 0,
}

-- ── Aura name patterns ────────────────────────────────────────────────────────
local FOOD_AURA_PATTERNS   = { "food", "refreshment", "eating" }
local DRINK_AURA_PATTERNS  = { "^drink", "^drinking", "hydration" }
local DRINK_EXTRA_PATTERNS = { "conjured water", "mana tea", "morning glory" }
local WELLFED_PATTERNS     = { "well fed" }
local FEAST_NAME_PATTERNS  = { "feast", "banquet", "spread", "bountiful" }

-- ── Aura helpers ──────────────────────────────────────────────────────────────
local function matchesAny(name, patterns)
    if not name or not patterns then return false end

    local success, lower = pcall(string.lower, name)
    if not success then
        return false
    end
    
    for _, p in ipairs(patterns) do
        if p:sub(1,1) == "^" then
            local pat = p:sub(2)
            if lower:sub(1, #pat) == pat then return true end
        else
            if lower:find(p, 1, true) then return true end
        end
    end
    return false
end

local function qualityToTierHint(quality)
    quality = tonumber(quality)
    if not quality then return nil end

    -- Conservative mapping:
    --   common -> no hint, let aura/bag logic decide
    --   uncommon -> complex
    --   rare+ -> feast
    if quality == 2 then
        return "complex"
    elseif quality >= 3 then
        return "feast"
    end
    return nil
end

local function isFoodDrinkItem(itemRef)
    if not itemRef then return false end

    local itemID = tonumber(itemRef)
    if not itemID and type(itemRef) == "string" then
        if type(getItemInfoInstant) == "function" then
            itemID = getItemInfoInstant(itemRef)
        end
    end
    if not itemID and type(itemRef) == "string" and type(getItemInfo) == "function" then
        local _, _, _, _, _, _, _, classID, subClassID = getItemInfo(itemRef)
        return classID == 0 and subClassID == 5
    end
    if not itemID then return false end

    if type(getItemInfoInstant) ~= "function" then return false end
    local _, _, _, _, _, classID, subClassID = getItemInfoInstant(itemID)
    return classID == 0 and subClassID == 5
end

local function cacheRecentConsumableUse(itemRef, itemQuality)
    if not itemRef then return end
    if not isFoodDrinkItem(itemRef) then return end

    local quality = itemQuality
    if quality == nil then
        if type(getItemInfo) == "function" then
            quality = select(3, getItemInfo(itemRef))
        end
    end
    local tier = qualityToTierHint(quality)
    if not tier then return end

    ICN2._recentConsumableUse.tier      = tier
    ICN2._recentConsumableUse.quality   = quality
    ICN2._recentConsumableUse.itemRef   = itemRef
    ICN2._recentConsumableUse.expiresAt = GetTime() + CONSUMABLE_HINT_TTL
end

local function cacheRecentConsumableUseFromBag(bag, slot)
    if not C_Container or not C_Container.GetContainerItemInfo then return end

    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then return end

    local itemID = info.itemID or (C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot))
    if not itemID then return end

    cacheRecentConsumableUse(itemID, info.quality)
end

local function consumeRecentConsumableTier()
    local hint = ICN2._recentConsumableUse
    if not hint or not hint.tier then return nil end

    if hint.expiresAt and GetTime() > hint.expiresAt then
        hint.tier      = nil
        hint.quality   = nil
        hint.itemRef   = nil
        hint.expiresAt = 0
        return nil
    end

    local tier = hint.tier
    hint.tier      = nil
    hint.quality   = nil
    hint.itemRef   = nil
    hint.expiresAt = 0
    return tier
end

-- ── Persistent aura cache ─────────────────────────────────────────────────────
-- Maps auraInstanceID → auraData for all current HELPFUL buffs on the player.
-- Built once on login, then patched on each UNIT_AURA event using updateInfo deltas.
-- A nil updateInfo is a full-refresh signal — we rebuild from scratch.
-- State.lua reads this cache for campfire/sitting detection instead of ForEachAura.
ICN2._auraCache = {}
ICN2._auraAccessBlocked = false
ICN2._auraAccessBlockedReason = nil

local function isSecretAuraError(err)
    if not err or type(err) ~= "string" then return false end
    local lower = err:lower()
    return lower:find("secret", 1, true) ~= nil
        or lower:find("forbidden", 1, true) ~= nil
        or lower:find("tainted", 1, true) ~= nil
end

local function safeGetAuraDataByIndex(unit, index, filter)
    if not C_UnitAuras or type(C_UnitAuras.GetAuraDataByIndex) ~= "function" then
        return nil, false
    end

    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
    if not ok then
        if isSecretAuraError(aura) then
            return nil, true
        end
        return nil, false
    end

    return aura, false
end

local function safeGetAuraDataByAuraInstanceID(unit, id)
    if not C_UnitAuras or type(C_UnitAuras.GetAuraDataByAuraInstanceID) ~= "function" then
        return nil, false
    end

    local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, id)
    if not ok then
        if isSecretAuraError(aura) then
            return nil, true
        end
        return nil, false
    end

    return aura, false
end

local function setAuraAccessBlocked(reason)
    ICN2._auraAccessBlocked = true
    ICN2._auraAccessBlockedReason = reason or "secret"
    ICN2._auraCache = {}
end

local function clearAuraAccessBlocked()
    ICN2._auraAccessBlocked = false
    ICN2._auraAccessBlockedReason = nil
end

local function rebuildAuraCache()
    clearAuraAccessBlocked()

    local cache = {}
    local i = 1
    while true do
        local aura, blocked = safeGetAuraDataByIndex("player", i, "HELPFUL")
        if blocked then
            setAuraAccessBlocked("secret")
            return
        end
        if not aura then break end
        if aura.auraInstanceID then
            cache[aura.auraInstanceID] = aura
        end
        i = i + 1
    end
    ICN2._auraCache = cache
end

-- WoW can expose UNIT_AURA delta fields as protected/secret values.  Calling
-- ipairs() on one raises an error instead of simply returning no entries, so
-- probe the iterator call before entering any generic-for loop.
local function safeIpairs(value)
    local ok, iterator, state, index = pcall(ipairs, value)
    if not ok then
        setAuraAccessBlocked("secret")
        return nil
    end
    return iterator, state, index
end

local function patchAuraCache(updateInfo)
    local cache = ICN2._auraCache

    if updateInfo.addedAuras then
        local iterator, state, index = safeIpairs(updateInfo.addedAuras)
        if not iterator then return end
        for _, aura in iterator, state, index do
            if aura.auraInstanceID then
                local fresh, blocked = safeGetAuraDataByAuraInstanceID("player", aura.auraInstanceID)
                if blocked then
                    setAuraAccessBlocked("secret")
                    return
                end
                cache[aura.auraInstanceID] = fresh or aura
            end
        end
    end

    if updateInfo.updatedAuraInstanceIDs then
        local iterator, state, index = safeIpairs(updateInfo.updatedAuraInstanceIDs)
        if not iterator then return end
        for _, id in iterator, state, index do
            local fresh, blocked = safeGetAuraDataByAuraInstanceID("player", id)
            if blocked then
                setAuraAccessBlocked("secret")
                return
            end
            if fresh then
                cache[id] = fresh
            else
                cache[id] = nil
            end
        end
    end

    if updateInfo.removedAuraInstanceIDs then
        local iterator, state, index = safeIpairs(updateInfo.removedAuraInstanceIDs)
        if not iterator then return end
        for _, id in iterator, state, index do
            cache[id] = nil
        end
    end

    clearAuraAccessBlocked()
end

-- Searches the cache for the first aura matching any pattern set.
-- Returns the auraData table or nil.
local function findAuraInCache(patterns, extraPatterns)
    for _, aura in pairs(ICN2._auraCache) do
        if matchesAny(aura.name, patterns) then return aura end
        if extraPatterns and matchesAny(aura.name, extraPatterns) then return aura end
    end
    return nil
end

function ICN2:InitAuraCache()
    rebuildAuraCache()
end

-- ── Tier detection ────────────────────────────────────────────────────────────
-- Detects food tier by prioritizing the short-lived consumable hint, then falling
-- back to aura duration heuristics. Duration is used because standard food/drink
-- auras are typically ~20s while higher-tier consumables often last 25-30s.
local function detectFoodTier(foodAura)
    local recentTier = consumeRecentConsumableTier()
    if recentTier then return recentTier end

    if foodAura and matchesAny(foodAura.name, FEAST_NAME_PATTERNS) then
        return "feast"
    end

    if foodAura and foodAura.duration and foodAura.duration >= 25 then
        return "complex"
    end

    return "simple"
end

-- Detects drink tier, inheriting feast status from food if applicable.
local function detectDrinkTier(drinkAura)
    local recentTier = consumeRecentConsumableTier()
    if recentTier then return recentTier end

    if foodState.active and foodState.tier == "feast" then
        return "feast"
    end

    if drinkAura and drinkAura.duration and drinkAura.duration >= 25 then
        return "complex"
    end

    return "simple"
end

-- ── Apply completion bonus ─────────────────────────────────
local function applyBonus(state, need, natural)
    if not state.tier or not natural then return end

    local data   = TIER_DATA[state.tier] or TIER_DATA.simple
    local bonus  = data.bonus
    local isFeast = state.tier == "feast"

    if need == "hunger" or isFeast then
        local maxH = ICN2:GetMaxValue("hunger")
        ICN2DB.hunger = math.min(maxH, ICN2DB.hunger + bonus)
        ICN2:TriggerEmote("satisfied", "hunger")
    end
    if need == "thirst" or isFeast then
        local maxT = ICN2:GetMaxValue("thirst")
        ICN2DB.thirst = math.min(maxT, ICN2DB.thirst + bonus)
        ICN2:TriggerEmote("satisfied", "thirst")
    end

    ICN2:UpdateHUD()

    local needStr
    if isFeast then
        needStr = L["FOOD_BONUS_BOTH"]
    elseif need == "hunger" then
        needStr = L["FOOD_BONUS_HUNGER"]
    else
        needStr = L["FOOD_BONUS_THIRST"]
    end
    print(string.format("|cFFFF6600ICN2|r " .. L["FOOD_BONUS_MSG"], needStr, bonus, state.tier))
end

-- ── Main aura handler ────────────────────────────────────────────────────────
-- Entry point called by Core's UNIT_AURA event with the raw updateInfo payload.
function ICN2:OnUnitAura(updateInfo)
    -- UNIT_AURA's delta fields can be secret tables while the player is in
    -- combat.  Do not even inspect them here; ipairs() would reject those
    -- protected values before the cache maintenance can inspect them.
    if (ICN2.State and ICN2.State.inCombat) or UnitAffectingCombat("player") then
        return
    end

    -- ── Step 1: maintain the cache ────────────────────────────────────────────
    if not updateInfo then
        rebuildAuraCache()
    else
        patchAuraCache(updateInfo)
    end

    if ICN2._auraAccessBlocked then return end
    if ICN2.State and ICN2.State.inInstance then return end

    local now = GetTime()

    -- ── Race Identity Interceptor Hook ────────────────────────────────────
    if ICN2DB and ICN2DB.settings and ICN2DB.settings.raceIdentityEnabled and ICN2.RaceModifiers then
        local _, playerRace = UnitRace("player")
        if ICN2.RaceModifiers[playerRace] and type(ICN2.RaceModifiers[playerRace].HandleConsumables) == "function" then
            local handled = ICN2.RaceModifiers[playerRace]:HandleConsumables(ICN2._auraCache, now, foodState, drinkState)
            if handled then return end
        end
    end

    -- ── Food aura handling ─────────────────────────────────────────────────────
    local foodAura = findAuraInCache(FOOD_AURA_PATTERNS)
    if foodAura then
        if not foodState.active then
            foodState.active    = true
            foodState.startTime = now
            foodState.duration  = foodAura.duration or 30
            foodState.tier      = detectFoodTier(foodAura)
            ICN2DB.wellFedEligible = true
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

    -- ── Well Fed aura handling  ────────────────────────────────────────────────
    local wellFedAura = findAuraInCache(WELLFED_PATTERNS)
    if wellFedAura then
        local id = wellFedAura.auraInstanceID or 0
        if id ~= ICN2._lastWellFedInstanceID and ICN2DB.wellFedEligible then
            ICN2._lastWellFedInstanceID = id
            ICN2._wellFedPauseExpiry    = now + WELLFED_PAUSE_SECS
            ICN2DB.wellFedEligible      = false

            print(string.format(
                "|cFFFF6600ICN2|r " .. L["WELLFED_MSG"],
                math.floor(WELLFED_PAUSE_SECS / 60)))
        end
    else
        ICN2._lastWellFedInstanceID = nil
    end

    -- ── Drink aura handling ───────────────────────────────────────────────────
    local drinkAura = findAuraInCache(DRINK_AURA_PATTERNS, DRINK_EXTRA_PATTERNS)
    if drinkAura then
        if not drinkState.active then
            drinkState.active    = true
            drinkState.startTime = now
            drinkState.duration  = drinkAura.duration or 30
            drinkState.tier      = detectDrinkTier(drinkAura)
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

local function installConsumableHooks()
    if ICN2._consumableHooksInstalled then return end

    -- Blizzard has moved/removed several item-use entry points between PTR
    -- builds.  hooksecurefunc() raises when its target does not exist; because
    -- this file is loaded before Core, one failed hook used to abort the whole
    -- module and leave IsEating/FoodDrinkTick undefined.  Treat these hooks as
    -- optional integrations so the aura path remains available.
    local function tryHook(target, method, callback)
        if type(hooksecurefunc) ~= "function" then return false end
        if method then
            if not target or type(target[method]) ~= "function" then return false end
        elseif type(_G[target]) ~= "function" then
            return false
        end

        local ok = pcall(function()
            if method then
                hooksecurefunc(target, method, callback)
            else
                hooksecurefunc(target, callback)
            end
        end)
        return ok
    end

    tryHook(C_Container, "UseContainerItem", function(bag, slot)
        cacheRecentConsumableUseFromBag(bag, slot)
    end)

    tryHook("UseAction", nil, function(slot)
        if type(GetActionInfo) ~= "function" then return end
        local actionType, id = GetActionInfo(slot)
        if actionType == "item" and id then
            cacheRecentConsumableUse(id, type(getItemInfo) == "function" and select(3, getItemInfo(id)) or nil)
        end
    end)

    tryHook("UseItemByName", nil, function(itemRef)
        cacheRecentConsumableUse(itemRef)
    end)

    ICN2._consumableHooksInstalled = true
end

installConsumableHooks()

-- ── Stubs ─────────────────────────────────────────────────────────────────────
-- Rebuild after combat because aura deltas were intentionally ignored while
-- their updateInfo fields were protected/secret.
function ICN2:OnCombatBreakFoodDrink()
    self:OnUnitAura(nil)
end
function ICN2:FoodDrinkTick()          end

-- ── Status queries (read by Core rate engine) ─────────────────────────────────
-- Functions that provide current food/drink state information to the core rate calculation engine

function ICN2:IsEating()
    return foodState.active
end

function ICN2:IsDrinking()
    return drinkState.active
end

function ICN2:GetFoodTier()
    return foodState.tier or "simple"
end

function ICN2:GetDrinkTier()
    return drinkState.tier or "simple"
end

function ICN2:GetFoodDuration()
    return foodState.duration
end

function ICN2:GetDrinkDuration()
    return drinkState.duration
end
