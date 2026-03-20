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

local SIT_AURA_PATTERNS = { "restful", "resting", "sitting" }

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
    -- Two guards before the scan:
    --   1. s.inCombat  — set by PLAYER_REGEN_DISABLED event (zero latency)
    --   2. UnitAffectingCombat — covers the rare window where encounter auras
    --      arrive via UNIT_AURA before PLAYER_REGEN_DISABLED fires. Boss/combat
    --      auras in that window have tainted secret names; calling string.lower()
    --      on them throws "attempt to perform string conversion on a secret string".
    -- inHousing is intentionally NOT cleared on combat; the zone is unchanged.
    if s.inCombat or UnitAffectingCombat("player") then
        s.isSitting    = false
        s.nearCampfire = false
        return
    end

    local sitFound      = false
    local campfireFound = false
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end

        -- pcall guards against any remaining tainted aura names that slip
        -- past the combat check (e.g. from a previous frame's residual state).
        local ok, lower = pcall(function()
            return aura.name and string.lower(aura.name) or ""
        end)
        if not ok then
            -- Name is tainted (secret string). Skip this aura safely.
            i = i + 1
        else
            if not sitFound then
                for _, p in ipairs(SIT_AURA_PATTERNS) do
                    if lower:find(p, 1, true) then sitFound = true; break end
                end
            end
            if not campfireFound then
                for _, p in ipairs(ICN2.CAMPFIRE_PATTERNS) do
                    if lower:find(p, 1, true) then campfireFound = true; break end
                end
            end
            if sitFound and campfireFound then break end
            i = i + 1
        end
    end

    s.isSitting    = sitFound
    s.nearCampfire = campfireFound

    -- Housing: campfire buff is the primary signal. Map ID is a belt-and-suspenders fallback.
    local mapID = C_Map.GetBestMapForUnit("player")
    s.inHousing = campfireFound or (mapID ~= nil and ICN2.HOUSING_MAP_IDS[mapID] == true)
end