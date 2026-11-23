# Stats HUD

Enable **Stats → Show stats** in `/sdui`. The window defaults off. Its title,
section headings, font size (default 13), row spacing, five sections and individual stats use
the existing display draft, Confirm/Cancel, profiles and both full resets.
The **Stats** Layout group owns movement, proportional scale, width and hiding.
No SavedVariable is added. The eleven sidebar categories use a 42-unit pitch
to retain clearance above the footer and below the sidebar controls.

The community contribution supplies the stat catalog and native-value formats.
Only that feature is integrated: the package's older core, settings and other
module copies do not replace the current owners. Gold, including its stat
modifier, kills and cache cost have no Stats row, control, reader or footer.

## Appearance

The open HUD follows the existing Guardian tracker: the same Quest Tracker
header at 204 rendered units wide, gold section captions and stat names, white
right-aligned values, and a transparent body. Sections use left-aligned titles
and the header artwork's own fading gold rule at 80% opacity. Each section
reuses the exact top-line pixels, drawn as a three-physical-pixel strip including
its shaded edges, rather than a tinted solid bar.
There is no enclosing frame, colored category
chrome, solid body fill or animation. Normal and Performance Mode share this
static presentation. The header uses the selected silver-and-gold
character/equipment icon, with its original transparent shading.

The root defaults to scale 0.85, with its top-right corner 224 UIParent units
left of the screen's right edge and 200 below its top. It does not move other
HUD groups. Width is adjustable from 180 to 600 frame units; corner scale and
confirmed positions remain independent. Rows grow only with the selected and
available fields. Translated captions and values are measured when text, font,
width or scale changes; unsuccessful font/metric work remains retryable.

A local static preview is retained in the Git-ignored
`docs/designs/stats-window/` design directory. It composes the existing artwork
at twice the default rendered size, using illustrative values and an
approximate font. It is not a game capture or evidence of native glyph rendering.
The follow-up `stats-dividers-preview.png` illustrates the selected gold-rule
crop. `stats-icon-options.png` shows ten inspected candidates in the same
header; the user selected option 1, the character/equipment icon.
Exact files, crops and immutable source links are in that directory's `ARTWORK.md`
and `icon-candidates.json`. None of these study assets enters the runtime payload.

## Data and lifecycle

`modules/ui/stats.lua` reads phase before retained tables. Ordinary display
requires `playing` or `paused`, a published finite `AZS_RUN_UPDATED`, finite
native run time and an available `AZS_STATS` table. The current native scalar
values alone supply the rows; missing/nonfinite fields are omitted. Settings
editing can show `--` placeholders, without invented stats or native writes.
Choice screens temporarily hide the HUD; ended/inactive phases retire it.

Damage, area, speed and experience use their supplied multipliers minus one;
haste displays the supplied cooldown reduction. Fractional chances and critical
multiplier values are displayed as percentages. Regeneration, heal per kill,
counts and pickup range retain their separate formats. `common.yards` supplies
the localized range unit. There is no combat parsing, rate estimation, saved
run history or native HUD/CVar takeover.

Only enabled, Layout-permitted, in-world Stats subscribes to `CHAT_MSG_ADDON`.
`AZS`, `AZSZONE` and `AZSRUN` publications coalesce a read onto the next frame;
the event frame never reads a partially parsed packet. Changed scalar values
are detected even when a provider reuses its table. A settled controller
detaches OnUpdate; only unresolved visible fonts/artwork/metrics retain a
half-second retry. Settings, locale, Layout resize and world recovery request
the same deferred refresh.

World leave/logout, observed zone publications and native-clock regressions
retire the accepted table. A retired reference needs a later stats publication
before reuse; fresh replacement tables can recover normally. The base API
provides no stats receipt timestamp or guaranteed complete run identity, so
unobserved boundaries and missing native reload replay remain client limits.
Hiding or disabling detaches the reader and publication subscription. On return,
the view reads current native values rather than replaying hidden changes.
Disabled mode clears copied scalar/format caches; only bounded continuity
references remain until the world/boundary cleanup.

## Artwork and source evidence

One lossless icon texture is added to the runtime payload; no font is added.
The header reuses
`guardians/Header.blp` and `Header_2.blp`: 512×128 half-sheets with the existing
`(1,0)-(281,70)` source region, ordinary blending and 0.8 alpha. The shared
helper assembles these into the original 560×70 Quest Tracker proportions.
Section rules sample `(1,5)-(281,10)` from each half-sheet: together these
preserve the full 560×5 top rule, including both fading ends. In the original
QuestTracker atlas this is `(11,252)-(571,257)`. Only the length stretches;
the crop excludes the header's body and lower scrollwork. The existing strip
helper retains two pooled texture regions per section and retries unsuccessful
bindings through the same visible-presentation reader.
The selected icon uses `stats/CharacterEquipment.blp`, a transparent 64×64
canvas containing the original 33×35 equipment-tab crop. UVs select
`(15,14)-(48,49)`; drawing at `24 * 33 / 35` by 24 frame units preserves the
source proportions and centers the image in the existing icon slot. Ordinary
BLEND retains the silver/gold colors and dark shading. The single region,
lazy preparation, successful-binding cache and visible-art retry remain unchanged.
Pixel, build and ownership records are in
[Guardian tracker artwork](../third_party/GuardianTracker-ARTWORK.md) and
[Stats icon artwork](../third_party/Stats-ARTWORK.md). The minimap's separate
Dragonflight glyph remains owned by its existing module and notice.

The 2026-11-23 asset search checked current
[DragonUI source/notices](https://github.com/NeticSoul/DragonUI/blob/407dd0069f2b853388483e9e7e169198abf4c6d0/DragonUI/THIRD_PARTY_NOTICES.md),
Blizzard's published
[Dragonflight HUD treatment](https://news.blizzard.com/en-us/article/23841481/world-of-warcraft-dragonflight-hud-and-ui-revamp)
and the current
[native metal-frame assembly](https://github.com/Gethe/wow-ui-source/blob/ab5cb850a3f65e742959e379c4689353a2f4549f/Interface/AddOns/Blizzard_SharedXML/Mainline/NineSliceLayouts.lua#L43).
The selected HUD uses the already-bundled Quest Tracker artwork, whose exact
pinned file, crop and Blizzard ownership are recorded in its existing notice.
Current mirror code and branch names do not change that artwork's origin or
establish older-client atlas/API support.

The standalone module is listed in the TOC and shared runtime manifest.
`ui_stats_spec.lua` supplies CI-only production-owner scenarios; no local tests,
standalone checks or addon/game execution were performed. Native appearance and
publication/reload timing remain unverified in the packaged client.
