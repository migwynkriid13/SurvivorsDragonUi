# SurvivorsDragonUi

- Keep the user updated whenever meaningful progress happens.
- Never run validation, tests, syntax checks, or game startups for this project. Packaging ZIPs and publishing releases are allowed when requested, but are not addon validation.
- Public addon name and install folder: `SurvivorsDragonUi`. Keep its TOC filename, addon-loaded match and runtime texture paths consistent.
- Keep installation instructions in the README's `## Install` section. Releases copy that section with `scripts/release_notes.py`, including manual placement in `benilla-config/AddOns/` and the game's Options → AddOns → Open AddOns Folder button. Keep the public README focused on SurvivorsDragonUi without naming other addons.
- The addon is distributed alone. No companion, client patch, alternate launcher or machine-specific runtime dependency.
- Keep all appearance and placement hardcoded, with DEFAULT font and no settings UI, profiles, saved variables or frame movers. Only `/sct on|off|default` are supported configuration commands; modes are session-only.
- Integrated chat starts from a visible raw-message baseline: fixed 520-by-340 glass-style window at bottom left (20, 230), DEFAULT font, always-visible tabs, selected native `ChatFrameN` at full opacity, native scrolling/history/hyperlinks and the shared vanilla `ChatFrameEditBox`. Subscribe the primary frame to all available vanilla message groups and preserve channel membership. Do not filter, abbreviate, rewrite URLs or animate messages. Do not replace native message rendering with captured Lua `AddMessage` calls: the client can write directly to native frames. Copy may read native history through `GetNumMessages`/`GetMessageInfo` when available; its hook fallback captures only Lua writes and cannot promise complete native history. Do not import Ace, profiles, movers or Wrath-only chat APIs.
- Preserve the seven-button action bar using native slots 1–6 and 12. No paging, extra bars or decorative end caps.
- Keep XP immediately below the abilities, matching the artwork width, with no numbers or hover text. Place the gold kills/gold/cache-cost bar directly underneath XP at the same width, using three equal sections with centered numbers and game icons.
- Keep a square minimap, one original-addon backpack, Character/Talents/Main Menu buttons, and original-addon health-only player/target frames filling the old health-and-resource area.
- Use the official 0.87.0+ API. Read phase before retained tables, native time rather than an independent clock, zone duration or native `AZS_RUN.fin`, and complete native schedules for markers. Never mutate native tables or invent missing state.
- Boss identity uses spawn `id` and `hp`/`hpm`; guardians appear only for `awake == true` or `awake == 1`. Require a received `AZS_UNITS_UPDATED` snapshot before hiding native encounter bars after reload.
- Replace only native `clock`, `bosses` and `tally` after their replacements are ready; restore captured visibility when data is unavailable or on world leave/logout.
- Client reload snapshot replay and native nameplate overlap controls remain client-side requirements. Do not substitute private snapshots or unsupported CVars.
- Preserve native V behavior and mode-aware `CombatDamage`. Independent SCT animations must survive deaths/plate reuse; show only icon and damage, with no duplicate enemy-name captions.
- Retain original license and attribution notices. The project owner confirmed permission to redistribute the upstream custom textures for this public package.
