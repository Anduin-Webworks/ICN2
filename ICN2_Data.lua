-- ============================================================
-- ICN2_Data.lua
-- Static tables: defaults, race/class modifiers, emotes
-- ============================================================

ICN2 = ICN2 or {}

local L = setmetatable({}, { __index = function(_, k)
    return ICN2.L and ICN2.L[k] or k
end })

-- Reset savedvariables.decayrates to new 2.0 logic
local CURRENT_VERSION = 320

function ICN2:RunMigrations()
    if not ICN2DB.settings then
        ICN2DB.settings = {}
    end

    if not ICN2DB.version or ICN2DB.version < 200 then
        ICN2DB.settings.decayRates = {}
        for k, v in pairs(ICN2.DEFAULTS.settings.decayRates) do
            ICN2DB.settings.decayRates[k] = v
        end

        ICN2DB.version = 200
        print("|cFFFF6600ICN2|r: " .. L["MSG_RATES_UPDATED"])
    end

    if not ICN2DB.version or ICN2DB.version < 300 then
        ICN2DB.settings.hudX = nil
        ICN2DB.settings.hudY = nil
        ICN2DB.settings.hudPosition = {
            point = "CENTER",
            relPoint = "CENTER",
            x = 0,
            y = 0,
        }

        ICN2DB.version = 300
        print("|cFFFF6600ICN2|r: HUD position reset for v3 layout.")
    end

    -- v3.0.1: ensure live saved decay rates match the current defaults.
    -- Older clients retained stale rates because existing SavedVariables
    -- were only filled when keys were missing.
    if not ICN2DB.version or ICN2DB.version < 301 then
        ICN2DB.settings.decayRates = {}
        for k, v in pairs(ICN2.DEFAULTS.settings.decayRates) do
            ICN2DB.settings.decayRates[k] = v
        end
        ICN2DB.version = CURRENT_VERSION
        print("|cFFFF6600ICN2|r: Decay rates loaded from current defaults.")
    end

    if not ICN2DB.version or ICN2DB.version < 310 then
        ICN2DB.version = CURRENT_VERSION
        print("|cFFFF6600ICN2|r: Critical warnings added in v3.1.0.")
    end

    if ICN2DB.settings.ambientEmotesEnabled == nil then
        ICN2DB.settings.ambientEmotesEnabled = true
    end

    if not ICN2DB.version or ICN2DB.version < 320 then
        ICN2DB.version = CURRENT_VERSION
        print("|cFFFF6600ICN2|r: Context-aware emotes added in v3.2.0.")
    end
end

-- ── Default SavedVariables structure ──────────────────────────────────────────
ICN2.DEFAULTS = {
    hunger  = 100.0, 
    thirst  = 100.0,
    fatigue = 100.0,
    lastLogout = nil,
    wellFedEligible = true,

    
    settings = {
        -- "fast" | "medium" | "slow" | "realistic" | "custom"
        preset = "medium",

        customDecayBias = {
            hunger  = 1,
            thirst  = 1,
            fatigue = 1,
        },
        customDecayBiasVersion = 2,

        -- Decay per real-time second at medium preset (multiplier = 1.0)
        -- Situational and race/class multipliers are applied on top of these base values.
        decayRates = {
            hunger  = 0.0255,
            thirst  = 0.0255,
            fatigue = 0.0138,
        },

        -- HUD
        hudEnabled    = true,
        hudLocked     = false,
        hudScale      = 1.0,
        hudAlpha      = 1.0,
        hudBarScale   = 1.0,
        hudPosition   = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
        hudX          = nil,
        hudY          = nil,

        -- Minimap launcher
        minimapButton = true,

        -- Offline decay
        freezeOfflineNeeds = false,

        -- Blocky bar display
        blockyBars = false,

        -- Emotes
        emotesEnabled    = true,
        ambientEmotesEnabled = true,
        emoteChance      = 0.3,  -- probability per threshold crossing (0-1)
        emoteMinInterval = 120,  -- minimum seconds between emotes

        -- Critical visual and sound cues
        alertsEnabled       = true,
        alertSoundEnabled   = true,
        alertVisualOpacity  = 0.12,
        alertReminderInterval = 600,
        alertDuringCombat   = false,
        alertSound          = "subtle",
        alertHunger         = true,
        alertThirst         = true,
        alertFatigue        = true,

        -- Color Palettes
        colorPalette = "Default",
        hunger  = {0.2, 0.8, 0.2},
        thirst  = {0.2, 0.5, 1.0},
        fatigue = {1.0, 0.85, 0.1}
    },

    -- LibDBIcon persists the launcher's angle and visibility here.
    minimap = { hide = false },
}

ICN2.Palettes = {
    Default = {
        hunger  = {0.2, 0.8, 0.2},
        thirst  = {0.2, 0.5, 1.0},
        fatigue = {1.0, 0.85, 0.1}
    },
    Colorblind_OkabeIto = {
        hunger  = {0.84, 0.37, 0.00},  -- Vermilion (High contrast to blue/yellow)
        thirst  = {0.34, 0.71, 0.91},  -- Sky Blue
        fatigue = {0.94, 0.89, 0.26}   -- Yellow
    }
}

-- ── Preset multipliers (applied to base decay) ────────────────────────────────
-- Multipliers for decay rates: higher values mean faster decay (needs deplete quicker).
ICN2.PRESETS = {
    fast      = 2.00,   -- doubled
    medium    = 1.00,   -- baseline
    slow      = 0.20,   -- 5× slower than medium
    realistic = 0.01,   -- 10× slower than medium
    custom    = 1.00
}

ICN2.CUSTOM_DECAY_MULTIPLIER_MAX = 20 * ICN2.PRESETS.medium

-- ── Situational decay multipliers ─────────────────────────────────────────────
-- These modify the decay rate based on the player's current activity.
ICN2.SITUATION_MODIFIERS = {
    swimming   = { hunger = 1.4, thirst = 1.5, fatigue = 1.8 },
    flying     = { hunger = 0.9, thirst = 1.1, fatigue = 0.6 },
    mounted    = { hunger = 0.8, thirst = 0.9, fatigue = 0.5 },
    -- Rested areas pause fatigue decay completely.  Fatigue recovery is
    -- applied separately by ICN2:_ApplyFatigueRecovery(), so sitting,
    -- eating/drinking, campfires, and housing can still restore fatigue.
    resting    = { hunger = 0.5, thirst = 0.6, fatigue = 0.0 },
    combat     = { hunger = 1.3, thirst = 1.2, fatigue = 1.5 },
    indoors    = { hunger = 1.0, thirst = 1.0, fatigue = 0.8 },
    instance   = { hunger = 1.2, thirst = 1.2, fatigue = 1.0 },
}

-- ── Race modifiers (multiplied on top of situation) ───────────────────────────
ICN2.RACE_MODIFIERS = {
    -- Horde
    ["Orc"]                 = { hunger = 0.95, thirst = 1.00, fatigue = 0.92 }, -- strong constitution, excellent endurance},
    ["Scourge"]             = { hunger = 0.30, thirst = 0.40, fatigue = 0.75 }, -- undead don't need food/water, but still get tired from body parts decaying
    ["Tauren"]              = { hunger = 1.08, thirst = 1.00, fatigue = 0.88 }, -- large body, great endurance: big appetite but slower fatigue
    ["Troll"]               = { hunger = 1.00, thirst = 1.08, fatigue = 1.00 }, -- regeneration balances tropical thirst, but active lifestyle causes more hunger and fatigue
    ["BloodElf"]            = { hunger = 1.00, thirst = 1.00, fatigue = 1.00 }, -- refined but unremarkable needs
    ["Goblin"]              = { hunger = 1.15, thirst = 1.15, fatigue = 1.12 }, -- hyperactive metabolism and high-stress lifestyle cause faster decay, but small frame means they burn through reserves quicker
    ["Nightborne"]          = { hunger = 1.22, thirst = 1.22, fatigue = 1.35 }, -- arcane realiance causes faster decay
    ["HighmountainTauren"]  = { hunger = 1.10, thirst = 1.00, fatigue = 0.85 }, -- mountain endurance, hearty appetite: slightly faster hunger, but slower fatigue
    ["MagharOrc"]           = { hunger = 0.90, thirst = 0.93, fatigue = 0.88 }, -- Draenor-hardened survivors: slower decay due to harsh upbringing
    ["Vulpera"]             = { hunger = 1.08, thirst = 0.60, fatigue = 1.02 }, -- Desert adaptation: amazing water conservation
    ["ZandalariTroll"]      = { hunger = 1.00, thirst = 1.00, fatigue = 0.93 }, -- Proud empire builders, balanced

    -- Alliance
    ["Human"]               = { hunger = 1.00, thirst = 1.00, fatigue = 1.00 }, -- baseline
    ["Dwarf"]               = { hunger = 1.05, thirst = 1.00, fatigue = 0.95 }, -- Hardy mountain folk: great stamina, moderate hunger
    ["NightElf"]            = { hunger = 0.90, thirst = 0.92, fatigue = 0.88 }, -- Efficient metabolism, excellent rest
    ["Gnome"]               = { hunger = 1.12, thirst = 1.12, fatigue = 1.10 }, -- Small frame = small reserves, fast burn
    ["Draenei"]             = { hunger = 0.88, thirst = 0.90, fatigue = 0.85 }, -- Light-sustained endurance
    ["Worgen"]              = { hunger = 1.15, thirst = 1.05, fatigue = 1.08 }, -- Cursed metabolism causes faster decay, but also more reserves
    ["VoidElf"]             = { hunger = 0.92, thirst = 0.93, fatigue = 0.90 }, -- Void-touched efficiency
    ["LightforgedDraenei"]  = { hunger = 0.85, thirst = 0.88, fatigue = 0.80 }, -- Light-sustained endurance, but relentless warriors
    ["DarkIronDwarf"]       = { hunger = 1.05, thirst = 1.02, fatigue = 0.93 }, -- Forge-hardened constitution, but still needs sustenance
    ["KulTiran"]            = { hunger = 1.03, thirst = 1.00, fatigue = 0.97 }, -- Seafaring resilience, but hard work takes its toll
    ["Mechagnome"]          = { hunger = 0.75, thirst = 0.70, fatigue = 0.78 }, -- cybernetic body requires less sustenance but still gets worn down

    -- Neutral
    ["Pandaren"]            = { hunger = 0.93, thirst = 0.93, fatigue = 0.88 }, -- Zen discipline, love of food balanced by efficiency
    ["Dracthyr"]            = { hunger = 0.85, thirst = 0.88, fatigue = 0.85 }, -- Draconic metabolism = efficient
    ["EarthenDwarf"]        = { hunger = 0.72, thirst = 0.68, fatigue = 0.75 }, -- Living stone: tiny reserves but slow drain
    ["Harronir"]            = { hunger = 1.05, thirst = 1.15, fatigue = 1.05 }, -- Forest spirits: hunger and thirst decay faster due to their active nature, but fatigue is moderate
}
-- ── Race max values (point pools) ─────────────────────────────────────────────
-- Defines how large each need's pool is per race. Larger pools mean the need takes longer to deplete in absolute game time
ICN2.RACE_MAX_VALUES = {
    
    -- Horde
    ["Orc"]                = { hunger = 108, thirst = 102, fatigue = 112 }, -- Strong constitution, excellent endurance
    ["Scourge"]            = { hunger = 75,  thirst = 75,  fatigue = 120 }, -- Undead: minimal food/water, decay causes fatigue
    ["Tauren"]             = { hunger = 125, thirst = 110, fatigue = 118 }, -- large body, great endurance
    ["Troll"]              = { hunger = 102, thirst = 108, fatigue = 100 }, -- Regeneration balances tropical thirst
    ["BloodElf"]           = { hunger = 92,  thirst = 95,  fatigue = 98  }, -- Refined but unremarkable needs 
    ["Goblin"]             = { hunger = 82,  thirst = 82,  fatigue = 88  }, -- Hyperactive metabolism, small reserves
    ["Nightborne"]         = { hunger = 85,  thirst = 85,  fatigue = 78  }, -- arcane realiance causes smaller pools
    ["HighmountainTauren"] = { hunger = 120, thirst = 108, fatigue = 122 }, -- Mountain endurance, hearty appetite
    ["MagharOrc"]          = { hunger = 112, thirst = 105, fatigue = 115 }, -- Draenor-hardened survivors
    ["Vulpera"]            = { hunger = 85,  thirst = 75,  fatigue = 95  }, -- desert-adapted: small but efficient
    ["ZandalariTroll"]     = { hunger = 105, thirst = 105, fatigue = 108 }, -- Proud empire builders, balanced
    
    -- Alliance
    ["Human"]              = { hunger = 100, thirst = 100, fatigue = 100 }, -- baseline, boring but relatable
    ["Dwarf"]              = { hunger = 110, thirst = 105, fatigue = 115 }, -- hearty constitution, but still gets tired from mining and drinking
    ["NightElf"]           = { hunger = 95,  thirst = 95,  fatigue = 110 }, -- efficient metabolism, but need more rest
    ["Gnome"]              = { hunger = 80,  thirst = 80,  fatigue = 85  }, -- small frame, small pools
    ["Draenei"]            = { hunger = 105, thirst = 100, fatigue = 110 }, -- Light-sustained endurance
    ["Worgen"]             = { hunger = 110, thirst = 100, fatigue = 105 }, -- Large appetite, decent reserves
    ["VoidElf"]            = { hunger = 92,  thirst = 95,  fatigue = 100 }, -- Void-touched efficiency
    ["LightforgedDraenei"] = { hunger = 95,  thirst = 92,  fatigue = 115 }, -- Light sustains them heavily
    ["DarkIronDwarf"]      = { hunger = 108, thirst = 102, fatigue = 110 }, -- Forge-hardened constitution
    ["KulTiran"]           = { hunger = 115, thirst = 105, fatigue = 108 }, -- Hearty sailors with reserves
    ["Mechagnome"]         = { hunger = 65,  thirst = 60,  fatigue = 85  }, -- Cybernetic efficiency, tiny reserves
    
    -- Neutral/Other
    ["Pandaren"]           = { hunger = 105, thirst = 100, fatigue = 105 }, -- Zen discipline, love of food balanced by efficiency
    ["Dracthyr"]           = { hunger = 98,  thirst = 95,  fatigue = 100 }, -- Draconic metabolism = efficient
    ["EarthenDwarf"]       = { hunger = 75,  thirst = 70,  fatigue = 90  }, -- Living stone: tiny reserves but slow drain
    ["Harronir"]           = { hunger = 95,  thirst = 95,  fatigue = 110 }, -- Forest spirits: moderate pools, but need more rest
}

-- ── Class modifiers ───────────────────────────────────────────────────────────
ICN2.CLASS_MODIFIERS = {
    ["WARRIOR"]     = { hunger = 1.15, thirst = 1.1,  fatigue = 1.1  }, -- heavy armor, constant exertion
    ["PALADIN"]     = { hunger = 1.0,  thirst = 1.0,  fatigue = 0.95 }, -- divine sustenance
    ["HUNTER"]      = { hunger = 0.9,  thirst = 0.95, fatigue = 0.9  }, -- used to the wild
    ["ROGUE"]       = { hunger = 1.0,  thirst = 1.0,  fatigue = 1.0  }, -- agile and efficient, but high-stress lifestyle
    ["PRIEST"]      = { hunger = 1.0,  thirst = 1.0,  fatigue = 0.85 }, -- spiritual focus helps reduce fatigue
    ["SHAMAN"]      = { hunger = 1.0,  thirst = 1.0,  fatigue = 1.0  }, -- balanced needs, but elemental attunement can be draining
    ["MAGE"]        = { hunger = 0.9,  thirst = 0.85, fatigue = 0.9  }, -- arcane knowledge helps conserve energy
    ["WARLOCK"]     = { hunger = 0.85, thirst = 1.0,  fatigue = 0.9  }, -- life tap sustains
    ["MONK"]        = { hunger = 0.9,  thirst = 0.9,  fatigue = 0.85 }, -- disciplined training and meditation
    ["DRUID"]       = { hunger = 0.9,  thirst = 0.95, fatigue = 0.9  }, -- used to the wild
    ["DEMONHUNTER"] = { hunger = 0.9,  thirst = 1.0,  fatigue = 0.9  }, -- soul feeding helps, but reckless playstyle increases needs
    ["DEATHKNIGHT"] = { hunger = 0.5,  thirst = 0.5,  fatigue = 0.5  }, -- undead, reduced needs
    ["EVOKER"]      = { hunger = 1.1,  thirst = 1.1,  fatigue = 1.1  }, -- draconic metabolism, but intense magic use can be draining
}

-- ── Emote tables by state ─────────────────────────────────────────────────────
-- Tables of emote commands triggered when needs reach certain thresholds or are satisfied.
ICN2.EMOTES = {
    hungry = {
        critical = { "/lick", "/drool", "/hungry" },
        low      = { "/lick", "/drool", "/moan" },
    },
    thirsty = {
        critical = { "/cough", "/thirsty", "/sigh" },
        low      = { "/cough", "/thirsty" },
    },
    tired = {
        critical = { "/yawn", "/sleep", "/sigh", "/tired" },
        low      = { "/yawn", "/sigh" },
    },
    satisfied = {
        hunger  = { "/burp", "/flex" },
        thirst  = { "/burp" },
        fatigue = { "/flex", "/smile" },
    },
    recovered = {
        hunger  = { "/sigh", "/smile" },
        thirst  = { "/sigh", "/smile" },
        fatigue = { "/sigh", "/relax" },
    },
    context = {
        sitting  = { "/relax", "/sigh", "/stretch" },
        resting  = { "/relax", "/smile", "/sigh" },
        campfire = { "/relax", "/smile" },
        housing  = { "/relax", "/smile" },
        swimming = { "/gasp", "/cough", "/sigh" },
    },
    ambient = {
        sitting  = { "/relax", "/sigh", "/stretch" },
        resting  = { "/relax", "/smile", "/sigh" },
        hungry   = { "/sniff", "/lick", "/sigh" },
        thirsty  = { "/cough", "/sigh" },
        tired    = { "/yawn", "/stretch", "/sigh" },
    },
}

-- ── Threshold levels (% remaining) ───────────────────────────────────────────
-- Thresholds are in percentages
ICN2.THRESHOLDS = {
    critical = 15,
    low      = 35,
    ok       = 100,
}

-- ── Need helpers ──────────────────────────────────────────────────────────────
-- Returns the max point value for a need given the player's race.
-- Falls back to 100 for any race not in RACE_MAX_VALUES.
function ICN2:GetMaxValue(need)
    local race = select(2, UnitRace("player"))
    local raceMax = ICN2.RACE_MAX_VALUES[race]
    if raceMax and raceMax[need] then return raceMax[need] end
    return 100
end

-- Returns the current need as a 0–100 percentage (used by HUD, emotes, thresholds).
function ICN2:GetNeedPercent(need)
    local current = ICN2DB and ICN2DB[need] or 0
    local maxVal  = ICN2:GetMaxValue(need)
    return (current / maxVal) * 100
end

-- ── Self-modifier curves (Phase 1 — non-linear decay) ─────────────────────────
ICN2.SELF_MODIFIER_CURVES = {
    hunger = {
        low_threshold  = 35,   -- matches ICN2.THRESHOLDS.low
        crit_threshold = 15,   -- matches ICN2.THRESHOLDS.critical
        low_mult       = 1.10, -- 10% faster between low and critical
        crit_mult      = 1.20, -- 20% faster at critical (starving panic)
    },
    thirst = {
        low_threshold  = 35,
        crit_threshold = 15,
        low_mult       = 1.15, -- thirst accelerates slightly more than hunger
        crit_mult      = 1.30, -- dehydration is acutely urgent
    },
    fatigue = {
        low_threshold  = 35,
        crit_threshold = 15,
        low_mult       = 1.20,
        crit_mult      = 1.40,
    },
}

-- ── Cross-need rules (Phase 2 — inter-need coupling) ──────────────────────────
ICN2.CROSS_NEED_RULES = {
    {
        source    = "hunger",
        target    = "fatigue",
        threshold = 35,
        mult      = 1.15,
        label     = "hungry→fatigue×1.15",
    },
    {
        source    = "hunger",
        target    = "fatigue",
        threshold = 15,
        mult      = 1.35,
        label     = "starving→fatigue×1.35",
    },
}

-- ── Armor Fatigue Decay ────────────────────────────────────────────────────
ICN2.ARMOR_FATIGUE = {
    PLATE  = 1.20, -- heaviest armor causes more fatigue
    MAIL   = 1.10, -- medium armor has a moderate effect
    LEATHER= 1.00, -- light armor has no additional fatigue
    CLOTH  = 0.90, -- cloth armor is comfortable and breathable. Default fallback.
}

-- ── Fatigue recovery rates (% per second) ────────────────────────────────────
-- Recovery is a flat rate when resting, modified by armor and situations. Higher values mean faster recovery.
ICN2.FATIGUE_RECOVERY = {
    slow = 100 / 600,   -- ~0.167 pts/s → 100 points in ~10 minutes
    fast = 100 / 300,   -- ~0.333 pts/s → 100 points in ~5 minutes
}

-- ── Aura patterns for campfire / cozy fire detection ─────────────────────────
-- Matched against buff names on the player.
ICN2.CAMPFIRE_PATTERNS = {
    "cozy fire",
    "campfire",
    "warmth of the fire",
    "bonfire",
}

-- ── Housing zone detection ────────────────────────────────────────────────────
ICN2.HOUSING_MAP_IDS = {
    [2736] = true, -- Housing neighborhood (Razorwind Shores)
    [3027] = true, -- Warband Housing neighborhood (Razorwind Shores)
    [2735] = true, -- Housing neighborhood (Founders Point)
    [3026] = true  -- Warband Housing neighborhood (Founders Point)
}
