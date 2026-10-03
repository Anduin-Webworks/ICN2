# ICN2 — Immersive Character Needs 2

ICN2 adds three survival-style needs to your *World of Warcraft* character:

- Hunger
- Thirst
- Fatigue

It is designed for roleplay and immersion. Your needs change naturally as you travel, fight, swim, fly, rest, eat, drink, and spend time in the world.

## Quick start

After installing ICN2, the HUD appears automatically. Use it to see your current needs at a glance.

Type `/icn2` to open the options menu. From there you can choose a theme, adjust the HUD, select a decay pace, and configure emotes.

If the minimap button is enabled, it provides the same shortcuts:

- Left-click: open the options menu
- Right-click: toggle the HUD
- Ctrl+left-click: open the debug window

The minimap button is enabled by default and can be hidden from the General options tab.

## How the needs work

Needs normally decay over real time. The current situation changes the rate, so the pace is not identical everywhere.

- Combat increases the pressure on your needs.
- Swimming, flying, and mounted travel use their own movement modifiers.
- Rested areas reduce Hunger and Thirst decay and pause Fatigue decay. A rested area alone does not restore Fatigue.
- Sitting, eating or drinking, campfires, and housing can restore Fatigue.
- Sitting in a rested area, or using a campfire or housing while rested, provides faster Fatigue recovery.
- Entering combat, moving, jumping, casting, mounting, or standing ends the sitting state.
- A Well Fed effect can temporarily pause Hunger decay.
- Race, class, armor, and empty needs can affect the final rate.

At the Medium preset, the base pace is approximately 46 Hunger/Thirst points and 25 Fatigue points per 30 minutes before situational modifiers are applied. Each race has its own maximum need pools, so the displayed percentage is the most useful comparison between characters.

## Choosing a decay pace

The Decay & rates tab offers five presets:

- Fast — needs fall quickly.
- Medium — the default balanced pace.
- Slow — needs fall more gradually.
- Realistic — very slow decay for long roleplay sessions.
- Custom — set an independent decay bias for Hunger, Thirst, and Fatigue.

Custom bias `0` means that need has no passive decay. Recovery effects can still apply.

## HUD and appearance

The General tab lets you:

- Enable or disable the HUD.
- Lock or unlock its position.
- Choose a HUD theme.
- Choose a color palette, including the colorblind-friendly Okabe-Ito palette.
- Select labels: None, Percentage, Number, or Both.
- Adjust opacity, scale, and bar length where supported by the selected theme.
- Show or hide the minimap button.

Available themes include Colorful, Minimalist Vertical, Minimalist Horizontal, Smooth, Blocky, Folk, Necromancer, Dastardly, and Vanguard. Some themes intentionally use icons or vertical depletion instead of regular horizontal bars.

## Automatic emotes

ICN2 can perform layered, context-aware emotes when a need reaches a low or critical threshold, after successful recovery actions, and when safe world contexts begin.

- Need reactions occur when Hunger, Thirst, or Fatigue enters a low or critical tier.
- Recovery reactions can occur when a need returns to a healthy level.
- Context reactions can occur when sitting, resting, using a campfire, entering housing, or beginning to swim.
- Sparse ambient reactions can occur while sitting, resting, or dealing with a low need. They are controlled separately.
- All emotes are suppressed during combat, including reactions that were delayed before combat began.

You can disable automatic emotes, disable ambient reactions, or adjust the chance and minimum interval in the General tab. The system remains deliberately infrequent to avoid interrupting roleplay or gameplay.

## Critical warnings and cues

When Hunger, Thirst, or Fatigue reaches the critical threshold (15% or less), ICN2 can provide a quiet reminder so you do not miss the need while focused on other gameplay.

- A need-specific warning asset appears along the top of the screen.
- Each critical cue pulses three times, growing for one second and shrinking for one second.
- The warning uses the need's color and stays away from the center of the screen.
- A subtle sound plays when entering the critical tier.
- Sound reminders repeat only after the configured interval, rather than on every update.
- Warnings can be enabled independently for Hunger, Thirst, and Fatigue.
- Visual opacity, sound, combat behavior, and reminder interval are configurable.

The feature is enabled by default with conservative settings. Open `/icn2`, then use **Critical warnings & cues** to preview the visual warning or test the sound. Cues are designed to support immersion and can be disabled independently from automatic emotes.

## Commands

All commands begin with `/icn2`.

| Command | What it does |
|---|---|
| `/icn2` or `/icn2 show` | Open the options menu |
| `/icn2 status` | Print current Hunger, Thirst, and Fatigue percentages |
| `/icn2 details` | Show a readable status report with situation, rates, recovery, and effects |
| `/icn2 debug` | Open the technical diagnostic window |
| `/icn2 hud` | Toggle the HUD |
| `/icn2 lock` | Toggle HUD position locking |
| `/icn2 reset` | Restore all needs to full |
| `/icn2 eat` | Restore 50 Hunger |
| `/icn2 drink` | Restore 50 Thirst |
| `/icn2 rest` | Restore 40 Fatigue |
| `/icn2 starve` | Set Hunger to zero |
| `/icn2 dehydrate` | Set Thirst to zero |
| `/icn2 exhaust` | Set Fatigue to zero |

The restore and deplete commands are useful for testing or for roleplay situations where you want to set a specific state manually.

## Installation

1. Download ICN2 from [CurseForge](https://www.curseforge.com/wow/addons/immersive-character-needs-2).
2. Extract the `ICN2` folder into `World of Warcraft/_retail_/Interface/AddOns`.
3. Restart WoW and enable **Immersive Character Needs 2** in the AddOns menu.

## Compatibility

ICN2 is developed and tested for the modern Retail client. Classic Era, Season of Discovery, and Cataclysm Classic are not officially supported or maintained.

The addon stores character data in the `ICN2DB` saved variable. Existing saved data is migrated when required, including updates to the current default decay rates.

## Known issue

Some legacy Drink items do not apply the standard Drink aura and may not restore Thirst automatically. As a workaround, use the settings menu or `/icn2 drink`.

## Source and credits

[ICN2 source code on GitHub](https://github.com/Anduin-Webworks/ICN2)

Developed by **Oswaldovzki** at Anduin Webworks. Licensed under Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International.
