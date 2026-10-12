-- ============================================================================
-- ICN2_Alerts.lua
-- Quiet visual and sound cues for needs entering the critical tier.
-- ============================================================================

ICN2 = ICN2 or {}

local NEEDS = { "hunger", "thirst", "fatigue" }
local COLORS = {
    hunger  = { 0.85, 0.16, 0.10 },
    thirst  = { 0.16, 0.42, 0.95 },
    fatigue = { 0.95, 0.70, 0.12 },
}
local CUE_TEXTURES = {
    hunger  = "Interface\\AddOns\\ICN2\\assets\\icn2_hunger_cue.png",
    thirst  = "Interface\\AddOns\\ICN2\\assets\\icn2_thirst_cue.png",
    fatigue = "Interface\\AddOns\\ICN2\\assets\\icn2_fatigue_cue.png",
}
local SOUND_KITS = {
    hunger  = 28939,
    thirst  = 28939,
    fatigue = 28939,
}
local PULSE_COUNT = 3
local PULSE_GROW_SECONDS = 1.0
local PULSE_SHRINK_SECONDS = 1.0

local alertFrame
local cueSlots = {}

local function inCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function setting(name, fallback)
    local settings = ICN2DB and ICN2DB.settings
    local value = settings and settings[name]
    if value == nil then return fallback end
    return value
end

local function isNeedEnabled(need)
    return setting("alert" .. need:sub(1, 1):upper() .. need:sub(2), true)
end

local function getTier(value)
    if value <= ICN2.THRESHOLDS.critical then return "critical" end
    if value <= ICN2.THRESHOLDS.low then return "low" end
    return "ok"
end

local function currentValues() -- Returns a table of the current need values as percentages (0-100).
    return {
        hunger = ICN2:GetNeedPercent("hunger"),
        thirst = ICN2:GetNeedPercent("thirst"),
        fatigue = ICN2:GetNeedPercent("fatigue"),
    }
end

local function chooseCritical(values)
    local chosen, chosenValue
    for _, need in ipairs(NEEDS) do
        if isNeedEnabled(need) and getTier(values[need]) == "critical" then
            if not chosenValue or values[need] < chosenValue then
                chosen, chosenValue = need, values[need]
            end
        end
    end
    return chosen, chosenValue
end

local function setCueTexture(need)
    local slot = cueSlots[need]
    if not slot or not slot.texture then return end
    slot.texture:SetTexture(CUE_TEXTURES[need] or CUE_TEXTURES.hunger)
end

local function getVisualOpacity()
    return math.max(0, math.min(1.0, tonumber(setting("alertVisualOpacity", 0.12)) or 0.12))
end

local function hideOverlay()
    for _, slot in pairs(cueSlots) do
        slot.active = false
        if slot.pulse then slot.pulse:Stop() end
        slot.pulseRunning = false
        slot:Hide()
        slot:SetAlpha(0)
    end
end

local function showCue(need)
    local slot = cueSlots[need]
    if not slot or not setting("alertsEnabled", true) then return end

    setCueTexture(need)
    slot.active = true
    if slot.pulse then slot.pulse:Stop() end
    slot.pulseCount = 0
    slot.pulseRunning = true
    slot:SetAlpha(0)
    slot:Show()
    slot.pulseGrow:SetToAlpha(getVisualOpacity())
    slot.pulseShrink:SetFromAlpha(getVisualOpacity())
    slot.pulse:Play()
end

local function hideCue(need)
    local slot = cueSlots[need]
    if not slot then return end
    slot.active = false
    slot.pulseRunning = false
    if slot.pulse then slot.pulse:Stop() end
    if not slot:IsShown() then return end
    slot:Hide()
    slot:SetAlpha(0)
end

local function playSound(need, force)
    if not force and not setting("alertSoundEnabled", true) then
        ICN2._alertSoundResult = "disabled"
        return false
    end

    local soundKit = SOUND_KITS[need] or SOUND_KITS.fatigue
    ICN2._alertSoundKit = soundKit
    if soundKit and PlaySound then
        local willPlay = PlaySound(soundKit, "SFX", true)
        ICN2._alertSoundResult = willPlay and "accepted" or "rejected_by_client"
        return willPlay and true or false
    end
    ICN2._alertSoundResult = "api_unavailable"
    return false
end

function ICN2:InitAlerts()
    if alertFrame then return end

    alertFrame = CreateFrame("Frame", "ICN2AlertOverlay", UIParent)
    alertFrame:SetAllPoints(UIParent)
    alertFrame:SetFrameStrata("BACKGROUND")
    alertFrame:SetFrameLevel(0)

    local slotOrder = { "hunger", "thirst", "fatigue" }
    for index, need in ipairs(slotOrder) do
        local slot = CreateFrame("Frame", "ICN2Alert" .. need:sub(1, 1):upper() .. need:sub(2), alertFrame)
        local screenWidth = math.max(1, UIParent:GetWidth())
        slot:SetPoint("TOP", alertFrame, "TOP", (index - 2) * (screenWidth / 3), 0)
        slot:SetWidth(screenWidth / 3)
        slot:SetHeight(math.min(220, math.max(1, screenWidth / 9)))
        slot:SetFrameLevel(1)
        slot:Hide()
        slot:SetAlpha(0)

        local texture = slot:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints(slot)
        texture:SetTexCoord(0, 1, 0, 1)
        slot.texture = texture

        local pulse = slot:CreateAnimationGroup()
        local pulseGrow = pulse:CreateAnimation("Alpha")
        pulseGrow:SetOrder(1)
        pulseGrow:SetFromAlpha(0)
        pulseGrow:SetDuration(PULSE_GROW_SECONDS)
        local pulseShrink = pulse:CreateAnimation("Alpha")
        pulseShrink:SetOrder(2)
        pulseShrink:SetToAlpha(0)
        pulseShrink:SetDuration(PULSE_SHRINK_SECONDS)
        pulse:SetScript("OnFinished", function()
            if not slot.active or not slot.pulseRunning then return end
            slot.pulseCount = slot.pulseCount + 1
            if slot.pulseCount < PULSE_COUNT then
                slot.pulseGrow:SetToAlpha(getVisualOpacity())
                slot.pulseShrink:SetFromAlpha(getVisualOpacity())
                slot.pulse:Play()
            else
                slot.pulseRunning = false
                slot:Hide()
                slot:SetAlpha(0)
            end
        end)
        slot.pulse = pulse
        slot.pulseGrow, slot.pulseShrink = pulseGrow, pulseShrink
        cueSlots[need] = slot
    end

    alertFrame:SetScript("OnSizeChanged", function(_, width)
        local height = math.min(220, math.max(1, width / 9))
        for index, need in ipairs(slotOrder) do
            local slot = cueSlots[need]
            slot:SetWidth(width / 3)
            slot:ClearAllPoints()
            slot:SetPoint("TOP", alertFrame, "TOP", (index - 2) * (width / 3), 0)
            slot:SetHeight(height)
        end
    end)

    self._alertTiers = {}
    self._alertLastCue = {}
    self._alertLastSoundAt = nil
    self._alertCurrentNeed = nil
    self._alertCurrentValue = nil
end

function ICN2:UpdateAlerts(suppressSound)
    if not alertFrame then return end

    local values = currentValues()
    local now = GetTime()
    local criticalEntered

    for _, need in ipairs(NEEDS) do
        local tier = getTier(values[need])
        local previous = self._alertTiers[need]
        self._alertTiers[need] = tier
        if isNeedEnabled(need) and tier == "critical" and previous ~= "critical" then
            criticalEntered = criticalEntered or need
        end
    end

    local need, value = chooseCritical(values)
    self._alertCurrentNeed, self._alertCurrentValue = need, value
    local combatSuppressed = inCombat() and not setting("alertDuringCombat", false)

    if setting("alertsEnabled", true) and not combatSuppressed then
        for _, visualNeed in ipairs(NEEDS) do
            local isCritical = isNeedEnabled(visualNeed) and getTier(values[visualNeed]) == "critical"
            local slot = cueSlots[visualNeed]
            if isCritical then
                if not slot.active then showCue(visualNeed) end
            elseif slot.active then
                hideCue(visualNeed)
            end
        end
    elseif not setting("alertsEnabled", true) then
        hideOverlay()
    else
        for _, visualNeed in ipairs(NEEDS) do hideCue(visualNeed) end
    end

    if not need or not setting("alertSoundEnabled", true) or suppressSound then return end
    if inCombat() and not setting("alertDuringCombat", false) then return end

    local lastCue = self._alertLastCue[need] or 0
    local interval = math.max(30, tonumber(setting("alertReminderInterval", 600)) or 600)
    local lastAnySound = self._alertLastSoundAt
    local anySoundReady = not lastAnySound or (now - lastAnySound >= interval)
    if anySoundReady and (criticalEntered or (now - lastCue >= interval)) then
        -- Record the attempt regardless of PlaySound's return value.  On some
        -- Retail/PTR clients PlaySound() can return nil even when it starts
        -- playback; only recording successful returns would replay the cue on
        -- every UpdateAlerts call.
        self._alertLastCue[need] = now
        self._alertLastSoundAt = now
        playSound(need)
    end
end

function ICN2:PreviewAlert()
    if not alertFrame then self:InitAlerts() end
    showCue("hunger")
end

function ICN2:TestAlertSound()
    playSound("hunger", true)
end

function ICN2:GetAlertDebugState()
    local tiers, cooldowns = {}, {}
    local now = GetTime()
    local visualShown = false
    for _, need in ipairs(NEEDS) do
        tiers[need] = self._alertTiers and self._alertTiers[need] or "unknown"
        local last = self._alertLastCue and self._alertLastCue[need] or 0
        cooldowns[need] = math.max(0, (tonumber(setting("alertReminderInterval", 600)) or 600) - (now - last))
        if cueSlots[need] and cueSlots[need]:IsShown() then visualShown = true end
    end
    return {
        enabled = setting("alertsEnabled", true),
        sound_enabled = setting("alertSoundEnabled", true),
        during_combat = setting("alertDuringCombat", false),
        current_need = self._alertCurrentNeed,
        current_value = self._alertCurrentValue,
        tiers = tiers,
        reminder_cooldown_seconds = cooldowns,
        visual_shown = visualShown,
        last_sound_kit = self._alertSoundKit,
        last_sound_result = self._alertSoundResult or "not_attempted",
    }
end
