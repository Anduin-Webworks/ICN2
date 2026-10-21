-- ============================================================
-- ICN2_State.lua
-- World-sensing module. Its only job is answering: "What is the player currently doing?"
--
-- ICN2.State is the single source of truth for all condition flags. Every field is a plain fact about the player
-- No gameplay math lives here.
-- ============================================================

ICN2 = ICN2 or {}

-- ── State table ───────────────────────────────────────────────────────────────
-- All fields default to their safest / most conservative value.
-- inCombat is the only field written by an event rather than UpdateState().
ICN2.State = {
    inCombat    = false, -- set by PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED events for zero-latency response
    isSwimming  = false, -- IsSubmerged()
    isSitting   = false, -- set by sit/stand hooks; cleared by movement/action events
    isResting   = false, -- IsResting() — inn, city, garrison, etc.
    isFlying    = false, -- IsFlying()
    isMounted   = false, -- IsMounted()
    isIndoors   = false, -- IsIndoors()
    nearCampfire = false,-- player has a Cozy Fire / campfire buff
    inHouse     = false, -- player is inside a house interior
    inNeighborhood = false, -- player is outdoors on a housing neighborhood map
    housingDetectionSource = "none", -- API or legacy map fallback used for housing
    housingMapID = nil, -- current UI map ID, exposed for diagnostics
    inInstance  = false, -- IsInInstance() — dungeon, raid, BG, arena (aura scanning disabled)
}

-- Sitting is not represented reliably by a player aura.  It is therefore an
-- input/event-driven state rather than something reconstructed during the
-- normal state scan below.
function ICN2:SetSitting(value)
    local newValue = value and true or false
    if ICN2.State.isSitting ~= newValue then
        ICN2.State.isSitting = newValue
    end
end

function ICN2:ClearSitting()
    self:SetSitting(false)
end

-- Install these after PLAYER_LOGIN.  Some of the protected Blizzard action
-- functions are not guaranteed to be available while addon files are loading.
-- The guard also prevents duplicate hooks after an addon reload/init path.
function ICN2:InitSittingHooks()
    if self._sittingHooksInitialized then return end
    self._sittingHooksInitialized = true

    -- Keyboard sit/stand action.  This is a toggle, so mirror the toggle.
    if type(SitStandOrDescendStart) == "function" then
        hooksecurefunc("SitStandOrDescendStart", function()
            ICN2:SetSitting(not ICN2.State.isSitting)
        end)
    end

    -- Built-in /sit and /stand commands are emotes, not addon slash commands.
    if type(DoEmote) == "function" then
        hooksecurefunc("DoEmote", function(emote)
            emote = string.upper(tostring(emote))
            if emote == "SIT" then
                ICN2:SetSitting(true)
            elseif emote == "STAND" then
                ICN2:SetSitting(false)
            end
        end)
    end

    -- Retail clients may route built-in slash emotes through the C namespace
    -- instead of the legacy DoEmote() function.
    if C_ChatInfo and type(C_ChatInfo.PerformEmote) == "function" then
        hooksecurefunc(C_ChatInfo, "PerformEmote", function(emote)
            emote = string.upper(tostring(emote))
            if emote == "SIT" then
                ICN2:SetSitting(true)
            elseif emote == "STAND" then
                ICN2:SetSitting(false)
            end
        end)
    end

    -- On some clients the built-in slash handlers are created after the
    -- addon files load and do not route through DoEmote in an observable way.
    -- Hook the handlers directly when they are available after login.
    if SlashCmdList then
        if type(SlashCmdList.SIT) == "function" then
            hooksecurefunc(SlashCmdList, "SIT", function()
                ICN2:SetSitting(true)
            end)
        end
        if type(SlashCmdList.STAND) == "function" then
            hooksecurefunc(SlashCmdList, "STAND", function()
                ICN2:SetSitting(false)
            end)
        end
    end
end

-- ── Housing detection ────────────────────────────────────────────────────────
-- Housing is deliberately independent from aura scanning.  Campfires and
-- housing are separate facts and must never populate the same state flag.
local function queryHousingAPI(method)
    if not C_Housing or type(C_Housing[method]) ~= "function" then
        return nil
    end

    local ok, result = pcall(C_Housing[method])
    if not ok then return nil end
    return result and true or false
end

local function getPlayerMapID()
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" then
        return nil
    end

    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    return ok and mapID or nil
end

local function detectHousing()
    local mapID = getPlayerMapID()
    local apiHouse = queryHousingAPI("IsInsideHouse")
    local apiNeighborhood = queryHousingAPI("IsOnNeighborhoodMap")

    if apiHouse ~= nil or apiNeighborhood ~= nil then
        local inHouse = apiHouse == true
        local inNeighborhood = apiNeighborhood
        local source
        if inNeighborhood == nil then
            inNeighborhood = mapID ~= nil and ICN2.HOUSING_MAP_IDS[mapID] == true
            source = "C_Housing.IsInsideHouse+map_fallback"
        elseif apiHouse ~= nil then
            source = "C_Housing"
        else
            source = "C_Housing.IsOnNeighborhoodMap"
        end
        inNeighborhood = inNeighborhood == true and not inHouse
        return inHouse, inNeighborhood, source, mapID
    end

    -- Compatibility fallback for builds without the Retail housing API.  The
    -- legacy map list can identify a neighborhood but cannot identify a house
    -- interior, so it conservatively maps only to the neighborhood state.
    local inNeighborhood = mapID ~= nil and ICN2.HOUSING_MAP_IDS[mapID] == true
    return false, inNeighborhood, "map_fallback", mapID
end

-- ── UpdateState ───────────────────────────────────────────────────────────────
function ICN2:UpdateState()
    local s = ICN2.State

    s.isSwimming = (IsSubmerged and IsSubmerged()) and true or false
    s.isResting  = IsResting()  and true or false
    s.isFlying   = IsFlying()   and true or false
    s.isMounted  = IsMounted()  and true or false
    s.isIndoors  = IsIndoors()  and true or false

    -- ── Instance detection ────────────────────────────────────────────────────

    local inInst, instType = IsInInstance()
    s.inInstance = inInst and (instType == "party" or instType == "raid" 
                              or instType == "pvp" or instType == "arena")

    local inHouse, inNeighborhood, housingSource, housingMapID = detectHousing()
    s.inHouse = inHouse
    s.inNeighborhood = inNeighborhood
    s.housingDetectionSource = housingSource
    s.housingMapID = housingMapID

    -- ── Instance mode: skip aura scanning ─────────────────────────────────────
    if s.inInstance then
        s.nearCampfire = false
        s.inHouse      = false
        s.inNeighborhood = false
        s.housingDetectionSource = "instance_override"
        return
    end

    if ICN2._auraAccessBlocked then
        s.nearCampfire = false
        return
    end

    -- ── Aura-based detection ──────────────────────────────────────────────
    if s.inCombat or UnitAffectingCombat("player") then
        s.nearCampfire = false
        return
    end

    local campfireFound = false

    for _, aura in pairs(ICN2._auraCache or {}) do
        local ok, lower = pcall(function()
            return aura.name and string.lower(aura.name) or ""
        end)
        if ok then
            if not campfireFound then
                for _, p in ipairs(ICN2.CAMPFIRE_PATTERNS) do
                    if lower:find(p, 1, true) then campfireFound = true; break end
                end
            end
        end
        if campfireFound then break end
    end

    s.nearCampfire = campfireFound
end
