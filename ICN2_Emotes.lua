-- =======================================================================================================================================
-- ICN2_Emotes.lua
-- Threshold-based automatic emotes and reaction system.
-- Handles automatic emotes when needs cross critical thresholds, and manual emotes for satisfaction events (eating, drinking, resting).
-- =======================================================================================================================================

ICN2 = ICN2 or {}

local lastEmoteTime = 0
local ambientElapsed = 0
local contextInitialized = false
local previousContext = {}
local AMBIENT_INTERVAL = 300

-- ── Random pick from a table ──────────────────────────────────────────────────
local function pick(t)
    return t[math.random(1, #t)]
end

-- ── Helper: get threshold tier ───────────────────────────────────────────────
-- Determines which threshold tier a need value falls into.
local function getTier(val)
    if val <= ICN2.THRESHOLDS.critical then return "critical"
    elseif val <= ICN2.THRESHOLDS.low   then return "low"
    else return "ok" end
end

-- ── Fire a single emote command ───────────────────────────────────────────────
local function fireEmote(emoteCmd)
    if not ICN2DB.settings.emotesEnabled then return end
    -- Re-check here as well as when scheduling. A delayed reaction may cross
    -- into combat after it was queued.
    if InCombatLockdown() or (ICN2.State and ICN2.State.inCombat) then return end

    local token = emoteCmd:upper():sub(2)
    DoEmote(token)
end

local function scheduleEmote(list, delay, chance, ambient)
    if not ICN2DB.settings.emotesEnabled then return false end
    if ambient and ICN2DB.settings.ambientEmotesEnabled == false then return false end
    if InCombatLockdown() or (ICN2.State and ICN2.State.inCombat) then return false end
    if type(list) ~= "table" or #list == 0 then return false end

    local now = GetTime()
    if (now - lastEmoteTime) < ICN2DB.settings.emoteMinInterval then return false end
    if chance and math.random() > chance then return false end

    lastEmoteTime = now
    C_Timer.After(delay or 0.5, function()
        fireEmote(pick(list))
    end)
    return true
end

-- ── Trigger a satisfied emote externally (on eat/drink/rest) ─────────────────
function ICN2:TriggerEmote(category, subKey)
    local group = ICN2.EMOTES[category]
    if not group then return end

    local list = subKey and group[subKey] or group
    -- Small delay so it fires after the eat/drink animation starts.
    scheduleEmote(list, 0.5)
end

-- ── Check for threshold crossings and trigger emotes ─────────────────────────
function ICN2:CheckEmotes(oldHunger, oldThirst, oldFatigue)
    if not ICN2DB.settings.emotesEnabled then return end
    if InCombatLockdown() or (ICN2.State and ICN2.State.inCombat) then return end

    local fired = false

    local oldTH = getTier(oldHunger)
    local newTH = getTier(ICN2:GetNeedPercent("hunger"))
    if oldTH ~= newTH and newTH ~= "ok" then
        local list = ICN2.EMOTES.hungry[newTH]
        if list then
            fired = scheduleEmote(list, 0, ICN2DB.settings.emoteChance)
        end
    elseif oldTH ~= "ok" and newTH == "ok" then
        fired = scheduleEmote(ICN2.EMOTES.recovered.hunger, 0, ICN2DB.settings.emoteChance)
    end

    if not fired then
        local oldTT = getTier(oldThirst)
        local newTT = getTier(ICN2:GetNeedPercent("thirst"))
        if oldTT ~= newTT and newTT ~= "ok" then
            local list = ICN2.EMOTES.thirsty[newTT]
            if list then
                fired = scheduleEmote(list, 0, ICN2DB.settings.emoteChance)
            end
        elseif oldTT ~= "ok" and newTT == "ok" then
            fired = scheduleEmote(ICN2.EMOTES.recovered.thirst, 0, ICN2DB.settings.emoteChance)
        end
    end

    if not fired then
        local oldTF = getTier(oldFatigue)
        local newTF = getTier(ICN2:GetNeedPercent("fatigue"))
        if oldTF ~= newTF and newTF ~= "ok" then
            local list = ICN2.EMOTES.tired[newTF]
            if list then
                fired = scheduleEmote(list, 0, ICN2DB.settings.emoteChance)
            end
        elseif oldTF ~= "ok" and newTF == "ok" then
            fired = scheduleEmote(ICN2.EMOTES.recovered.fatigue, 0, ICN2DB.settings.emoteChance)
        end
    end
end

-- ── Context and ambient reactions ───────────────────────────────────────────
-- Context reactions happen once when a meaningful state begins. Ambient
-- reactions are deliberately sparse and only occur while the player is safe.
function ICN2:CheckContextEmotes()
    if not ICN2DB.settings.emotesEnabled then return end

    local s = ICN2.State
    if not s then return end

    local contexts = {
        sitting  = s.isSitting,
        resting  = s.isResting and not s.isSitting,
        campfire = s.nearCampfire,
        housing  = s.inHousing and not s.nearCampfire,
        swimming = s.isSwimming,
    }

    -- Keep the baseline synchronized during combat so leaving combat does not
    -- create a false "just entered" reaction for every active context.
    if s.inCombat or InCombatLockdown() then
        previousContext = contexts
        contextInitialized = true
        ambientElapsed = 0
        return
    end

    if not contextInitialized then
        previousContext = contexts
        contextInitialized = true
    else
        for name, active in pairs(contexts) do
            if active and not previousContext[name] then
                if scheduleEmote(ICN2.EMOTES.context[name], 0.7, 0.65) then break end
            end
        end
        previousContext = contexts
    end

    if ICN2DB.settings.ambientEmotesEnabled == false then return end
    ambientElapsed = ambientElapsed + 1
    if ambientElapsed < AMBIENT_INTERVAL then return end
    ambientElapsed = 0

    local list
    if s.isSitting then
        list = ICN2.EMOTES.ambient.sitting
    elseif s.isResting then
        list = ICN2.EMOTES.ambient.resting
    elseif ICN2:GetNeedPercent("fatigue") <= ICN2.THRESHOLDS.low then
        list = ICN2.EMOTES.ambient.tired
    elseif ICN2:GetNeedPercent("hunger") <= ICN2.THRESHOLDS.low then
        list = ICN2.EMOTES.ambient.hungry
    elseif ICN2:GetNeedPercent("thirst") <= ICN2.THRESHOLDS.low then
        list = ICN2.EMOTES.ambient.thirsty
    end
    scheduleEmote(list, 0.5, 0.55, true)
end
