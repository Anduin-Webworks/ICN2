# ICN2 CHANGELOG

## v3.2.0

### Layered context-aware emotes

- Added recovery reactions when a low or critical need returns to a healthy level.
- Added context reactions for sitting, resting, campfires, housing, and swimming.
- Added sparse ambient reactions for safe, out-of-combat moments.
- Added an independent option to disable ambient reactions while retaining need and recovery emotes.
- Emotes are blocked during combat both when scheduled and immediately before firing.

## v3.1.2

- Fixed a bug causing the decay indicator not to be shown.

## v3.1.1

- Fixed a `ipairs()` bug caused when entering combat. Again.

## v3.1.0

### Critical warnings and cues

- Added optional, low-opacity screen-edge warnings when Hunger, Thirst, or Fatigue enters the critical tier.
- Reworked the warning presentation to use separate top-screen assets for Hunger, Thirst, and Fatigue, with three 2-second pulses: one second growing and one second shrinking.
- Added a subtle sound cue when a need becomes critical.
- Added reminder cooldowns so sound cues do not repeat every engine tick.
- Added independent per-need warning toggles for Hunger, Thirst, and Fatigue.
- Added configurable visual opacity, reminder interval, sound enablement, and combat behavior.
- Added visual and sound preview controls to the options menu.
- Added alert state, cooldown, and suppression information to `/icn2 debug`.
- Added saved-variable migration support for the new 3.1.0 settings.
- Updated the player guide with practical warning and cue behavior.

## v3.0.1

- Fixed a `ipairs()` bug caused when entering combat
- Fixed an issue with the width of the new Options Menu

## v3.0.0

- Reworked the Options window with a scalable two-pane layout and scrollable content.
- Grouped settings into clear HUD, immersion, emotes, manual controls, and decay cards.
- Improved spacing, readability, navigation, and control hit areas while preserving all existing options.

## Known Issues

- Certain legacy Drink items do not apply the "Drink" aura and therefore fail to restore "Thirst".
- This behavior has been reported to Blizzard; it is unclear whether it is intended.
- Workaround: Manually replenish the "Thirst" state via the ICN2 settings menu.

## v2.9.0

- Added an optional LDB-compatible minimap button using the ICN2 logo. 
 - Left-click opens options.
 - Right-click toggles the HUD
 - Ctrl+left-click opens debug.
- README Update
 - Quick start and minimap controls
 - Hunger, Thirst, and Fatigue behavior
 - Resting, sitting, recovery, and Well Fed effects
 - Decay presets and Custom mode
 - HUD themes and settings
 - Automatic emotes
 - Complete slash-command reference
 - Installation, compatibility, and known issues

## v2.8.3

### Hotfixes

- Removed the temporary chat messages printed when the player sits or stands.
- Sitting in a rested area now triggers fast-tier fatigue recovery.
- Rested areas without a recovery trigger continue to pause fatigue decay.

## v2.8.2

### Details and Debug improvements

- `/icn2 details` now shows:
  - Current situation in plain language
  - Preset name
  - Current percentage and points
  - Decay/recovery speed in points per minute
  - Estimated time until empty
  - Paused decay when applicable
  - Simple effects summary
  - Recovery, eating, drinking, and Well Fed status
- `/icn2 debug` has now been updated with current v2.8 code changes.

## v2.8.1

### Base Decay rate fix

- Added a migration version 301.
- decayRates now load from current defaults once during login/reload.
- Existing stale values such as 0.055560 will be replaced with the current medium defaults:Hunger/thirst: 0.0255 | - Fatigue: 0.0138
- After migration, manual changes to decayRates will persist normally.
- Migration now actually runs during database initialization.

### Debug improvements

- Reports inInstance.
- Correctly shows instance as the active situation.
- Uses the same priority logic as the rate engine.
- Includes the missing spell-recovery pipeline stage.
- Updated pipeline numbering and fatigue recovery text.

## v2.8.0

### Resting and Sitting

- Added reliable sitting detection for the sit/stand keybind and built-in `/sit` and `/stand` commands.
- Sitting now contributes to slow fatigue recovery and is exposed through `ICN2.State.isSitting`.
- Sitting state is cleared when the player moves, jumps, casts, enters combat, mounts, or stands.
- Rested areas now pause fatigue decay completely instead of recovering fatigue by themselves.
- Fatigue recovery still occurs when the player is sitting, eating or drinking, near a campfire, or inside housing.
- Rested areas combined with campfires or housing provide fast recovery; rested areas alone produce a net fatigue rate of zero.

## v2.7.0

### HUD and Theme Engine

- Refined the theme engine so each theme controls its own textures, colors,
  opacity, fill direction, overlays, labels, positions, and sizing.
- Restored the Colorful theme's custom bar textures while keeping translucent
  solid fills for the other themes.
- Improved the Minimalist Vertical and Horizontal themes with icon-sized
  top-to-bottom depletion overlays, configurable labels, 200% scale, and
  visible status glyphs.
- Fixed theme-switch initialization issues, missing Blocky bar textures, and
  glyph layering above the bars.
- Enabled the label mode option for Minimalist themes, including None,
  Percentage, Number, and Both.

## v2.6.0

### Localization Updates

- Updated some stgs with new/improved information
- Added more translations to other languages (PT-BR, ES-MXrin, FR-FR, DE-DE)

## v2.5.0

### HUD Updates

- Adjusted available themes.
- Set "Clean" as the new default.
- Added a minimalist theme that displays only icons.
- Improved the "Colorful" and "Smooth" themes.
- Enhanced the "Blocky" theme.
- Updated .toc to v2.5.0.

### New Functionality

- Added a third button to the header:
  - This is a quick rest button.
  - It restores 15% of each need over 10 seconds.

## v2.4.0

### Themes Engine Refactor

- Implemented a completely new system for rendering themes.
  - Primarily backend logic.

### UI Updates

- Introduced a new default theme called "Colorful".
  - Added new icons for Needs.
  - Created new textures for bars.
- Made minor HUD changes.

## v2.3.0

### Food Quality

- Food and Drink now restore more points based on quality:
  - Common (white): 30 points
  - Uncommon (green): 40 points
  - Rare (blue and higher): 60 points

### UI Updates

- Refactored UI rendering code for better maintainability and future support.
- Updated state icons for improved clarity.
- Adjusted recovery and decay indicator thresholds.
- Moved all images to a dedicated "assets" folder.
- Fixed issues with the "Blocky" theme.
- Tuned default values for Fast and Realistic settings.
- Increased decay in instanced content by 10%.
- Increased Hunger recovery from Cannibalize to 60 points.

## v2.2.1

### TOC

- Updated .toc version to support 12.0.7.

## v2.2.0

### Accessibility

- Added preliminary support for future accessibility options, including colorblind modes.

## v2.1.0

### Localization

- Localized UI and chat messages.
- Added combat guard to prevent aura scanning in unsafe contexts.
- Expanded localization coverage and replaced remaining hardcoded strings.
- Standardized color codes, improved fallback behavior, and broadened string coverage.

### Aura Scanning

- Added a persistent aura cache with delta-based updates, reducing redundant scans and improving performance.

## v2.0.0

### Core Refactor

- Major cleanup and behavior changes across core modules.
- Bumped .toc version to 2.0.0.
- Added data migration to reset decayRates for new logic.
- Adjusted default presets and values.
- Introduced "instance" mode (neutral modifiers, short-circuit aura scanning/display).
- Improved situation label handling.
- Tweaked race/class modifiers and RACE_MAX_VALUES for better balance.

### Food/Drink

- Simplified tier math and adjusted tier values.
- Improved aura/item detection (nil guards, tooltip API, container/class/subclass checks).
- Prevented aura scanning in instances/combat.
- Implemented wellFedEligible handling and robust Well Fed pause consumption.

### Emotes

- Prevented emotes in combat.
- Enforced minimum intervals and chance checks.
- Minor cleanup.

### Debug/UI

- Enlarged and polished debug window (sizes, fonts).
- Improved serializer and pretty-printing.
- Streamlined snapshot pipeline and refresh/select controls.
- Updated debug version tag.

### Miscellaneous

- Various formatting and comment tweaks.
- Added VSCode Lua diagnostics/globals.
- Reorganized CHANGELOG with new v1.8.x entries.

## v1.8.1

### Well Fed Eligibility

- Added a `wellFedEligible` flag to prevent the Well Fed hunger pause from reapplying across UI reloads/portals.
- ICN2_Data.lua: introduced `defaults.wellFedEligible`.
- ICN2_FoodDrink.lua: documented rework, persisted `wellFedEligible` in ICN2DB, set it true when eating starts, and consumed it when the Well Fed pause is applied (checked alongside `auraInstanceID`).
- Minor comment and formatting tweaks.
- Updated .toc to v1.8.1.

## v1.8.0

### Fixed-Point Values & Localization

- Converted hunger/thirst/fatigue recovery and bonuses from percentage-based to fixed-point values, ensuring all races gain the same absolute points.
- Updated food/drink trickle, feast behavior, manual Eat/Drink/Rest defaults, and fatigue recovery logic to use points/sec semantics.
- Improved item detection for food/drink (container item IDs, class/subclass filtering, tooltip API).
- Adjusted completion bonus math and printouts.
- Added ICN2_Localization.lua (English + ptBR), laying groundwork for future language support.
- Fixed race name typo (Harronir).
- Simplified race lookup in GetMaxValue.
- Updated .toc to v1.8.0.

## v1.7.1

### Race Modifiers & Max Pools

- Updated and normalized ICN2.RACE_MODIFIERS values and comments, adjusting hunger/thirst/fatigue modifiers for better balance.
- Introduced consolidated ICN2.RACE_MAX_VALUES table with per-race point pools, including neutral/other races (Pandaren, Dracthyr, Earthen Dwarf, Haranir).
- Removed duplicate RACE_MAX_VALUES block and cleaned up explanatory comments.
- Updated .toc to v1.7.1.
