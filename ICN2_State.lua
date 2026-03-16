-- ============================================================
-- ICN2_State.lua
-- World-sensing module. Its only job is answering:
-- "What is the player currently doing?"
--
-- ICN2.State is the single source of truth for all condition
-- flags. Every field is a plain fact about the player — no
-- gameplay math lives here.
--
-- The rate engine in Core reads ICN2.State but never writes it.
-- OnEvent in Core writes inCombat directly via ICN2.State.
-- Everything else is updated by ICN2:UpdateState() each tick.
--
-- Load order: after ICN2_Data.lua, before ICN2_Core.lua.
-- ============================================================

ICN2 = ICN2 or {}

-- ── State table ───────────────────────────────────────────────────────────────
-- All fields default to their safest / most conservative value.
-- inCombat is the only field written by an event rather than UpdateState(),
-- because PLAYER_REGEN_DISABLED/ENABLED fire instantly and we want zero lag.
ICN2.State = {
    inCombat    = false,  -- written by Core OnEvent (PLAYER_REGEN_*)
    isSwimming  = false,  -- IsSubmerged()
    isSitting   = false,  -- aura-based: "Restful" buff from /sit, /sleep, /kneel
    isResting   = false,  -- IsResting() — inn, city, garrison, etc.
    isFlying    = false,  -- IsFlying()
    isMounted   = false,  -- IsMounted()
    isIndoors   = false,  -- IsIndoors()
    nearCampfire = false, -- player has a Cozy Fire / campfire buff
    inHousing   = false,  -- player is in a housing zone/plot
}

-- ── Why GetUnitStandState for sitting? ───────────────────────────────────────
-- UnitIsSitting("player") was removed in Retail 12.0 (TWW pre-patch).
-- The aura-based approach ("Restful" buff) proved unreliable in testing —
-- the buff does not consistently appear on /sit in outdoor zones.
-- GetUnitStandState("player") returns a numeric stance:
--   0 = standing, 1 = sitting, 2 = laying down, 3 = kneeling
-- Values > 0 mean the player is not standing = effectively sitting/resting.
local STAND_STATE_STANDING = 0

-- ── UpdateState ───────────────────────────────────────────────────────────────
function ICN2:UpdateState()
    local s = ICN2.State

    -- inCombat is NOT set here — it's set immediately by PLAYER_REGEN_* events
    -- in Core for zero-latency response. We just leave it as-is.

    s.isSwimming = (IsSubmerged and IsSubmerged()) and true or false
    s.isResting  = IsResting()  and true or false
    s.isFlying   = IsFlying()   and true or false
    s.isMounted  = IsMounted()  and true or false
    s.isIndoors  = IsIndoors()  and true or false

    -- ── Aura-based detection (sitting + campfire) ─────────────────────────────
    -- Combat clears sitting/campfire — you can't do those while fighting.
    -- inHousing is intentionally NOT cleared on combat; the zone is unchanged.
    if s.inCombat then
        s.isSitting    = false
        s.nearCampfire = false
        return
    end

    -- ── Sitting detection ─────────────────────────────────────────────────────
    -- GetUnitStandState returns 0 for standing, >0 for sit/lay/kneel.
    local standState = GetUnitStandState and GetUnitStandState("player") or STAND_STATE_STANDING
    s.isSitting = standState ~= STAND_STATE_STANDING

    -- ── Campfire detection ────────────────────────────────────────────────────
    local campfireFound = false
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        local lower = aura.name and string.lower(aura.name) or ""
        for _, p in ipairs(ICN2.CAMPFIRE_PATTERNS) do
            if lower:find(p, 1, true) then campfireFound = true; break end
        end
        if campfireFound then break end
        i = i + 1
    end
    s.nearCampfire = campfireFound

    -- Housing: campfire buff is the primary signal. Map ID is a belt-and-suspenders fallback.
    local mapID = C_Map.GetBestMapForUnit("player")
    s.inHousing = campfireFound or (mapID ~= nil and ICN2.HOUSING_MAP_IDS[mapID] == true)
end
