# Rendering and update costs

The October 2026 performance work removes repeated presentation writes while
retaining native data, pause-aware timing, saved preferences and artwork.
It adds no gameplay clock, setting, SavedVariable or native client dependency.

## Mandatory rule for all drawing and assets

Drawing performance is a project requirement for every frame and artwork change,
including new features. Review two separate costs: recurring Lua/native work
and what stays visible in the renderer every frame. A cached updater can still
leave hundreds of expensive texture regions drawing continuously.

- Prefer one cached native image when its appearance matches the request.
  Pet and meter circles use named `SetPortraitToTexture` images, with the gold
  rim separate. Bind only on icon changes; scale inheritance needs no rebinding.
- Pool and lazily allocate view elements and reuse existing atlases. A
  compatibility fallback allocates only when needed and reflows only on actual
  scale changes. Successful bindings are cached. Remember native-path failures
  until the icon/retirement changes, while failed fallback assignments retry.
- Skip unchanged text, fonts, tint, alpha, visibility, anchors, dimensions and
  UV writes. Reuse measurements only while text, fonts, owning-frame effective
  scale and relevant widths match; unavailable glyph metrics remain retryable.
- Native-owned widgets require actual-state comparisons after native updates.
  A cache must not hide native anchor/color/style resets. Read effective scale
  from the owning frame, since FontStrings lack that method in this client.
- Hidden groups skip cosmetic work while retaining required snapshots, native
  timing, HUD ownership and expiry/queue retirement. Stop idle animation and
  redundant polling through the existing event/dirty/controller lifecycle.
- Preserve requested artwork, source pixels/alpha, filtering, crop boundaries,
  layers, overdraw that belongs to authored effects, geometry and input. The
  StatusBar owns its UV writes. Keep jewelry's fourteen exact strips and the
  character window's three authored equipment-quality rim passes. Do not substitute the pet
  native circle for jewelry's magnified crop or merge bands without parity.
- Preserve animation equations and required cadence. Active input, final
  cooldown sampling, model-paint readiness and native geometry repair are
  deliberate exceptions to idle throttling. Do not invent a gameplay clock,
  drop combat events, truncate diagnostics or cap native rosters to save work.
- Record visible/allocated regions and material/UV-clamp implications separately
  from CPU calls. Source counts and reference models are not live draw-call,
  GPU-memory, pixel-parity or FPS measurements. No local tests, standalone
  validation, addon execution or game launch is authorized for this audit.

## Lossless palette packing — 2026-10-27

Forty-eight prepared BLPs now use exact indexed RGB plus separate alpha instead
of Raw3. All decoded pixels, including RGB under zero alpha, canvas dimensions,
mips, UVs, layers and draw-region counts are preserved. The existing six DXT5
images remain byte-identical; no lossy recompression is introduced. Preparation
uses the same BLP path for native and browser clients and adds no runtime code,
texture, updater or package member. See [client compatibility](CLIENT-COMPATIBILITY.md#exact-lossless-palettes--2026-10-27)
for decoder evidence, byte-comparison results and the format rule.

The 108 runtime textures drop from 25.55 to 22.34 MiB on disk, saving 3.21 MiB.
The complete runtime ZIP drops from 2.013 to 1.980 MiB: only 32.8 KiB, because
DEFLATE already compresses the original pixels well. These are data-only file
measurements. The reference UI renderer expands palette files into RGBA, so
this change makes no GPU-memory, draw-call or FPS improvement claim. Native and
browser rendering have not been executed locally.

## Layout hiding audit — 2026-10-27

The independent custom run-timer and boss-bar enable switches are stronger
than Layout hiding: off clears the corresponding custom view, skips its
clock/schedule or encounter/debuff getter and presentation work, and restores
the native HUD setting to on. Shared phase/boundary observation, independent
tally/guardian work and failed native-preference restoration remain necessary.
These switches reuse the current reader without adding an updater; see
[RUN-TIMER.md](RUN-TIMER.md).

All 24 Layout groups were traced in the installed addon checkout. Layout uses
native `Hide`, so the group and its descendants leave visible rendering. Hiding
does not unload pooled regions or unregister the game's own event handlers.
The fixes below stop addon presentation work that previously continued in
separate controllers or native hooks. They add no artwork, setting, saved state
or updater.

`layout.IsHidden(key)` reads the current draft/confirmed policy, including a
saved flag before lazy registration. `layout.ListenVisibility` publishes policy
transitions through the existing layout application. Pure view controllers can
therefore detach even when their conditional root was already hidden. Actual
`IsVisible` guards also account for hidden ancestors; requested Show state is
kept separately so normal native state can resume on showing.

| Layout key          | Hidden presentation and retained work                                                                                                                                                                                                                                                                                                                                          |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `playerFrame`       | Custom health/level/color hooks, resource painting, portrait copy binding and cosmetic animations skip hidden work. Native unit events/values and secondary-resource phase retirement remain; Show refreshes current presentation.                                                                                                                                             |
| `targetFrame`       | Custom values, classification artwork and aura-anchor repairs defer until visible. Native target/death/aura state stays owned by the game; Show forces current styling and aura layout.                                                                                                                                                                                        |
| `partyFrames`       | Custom labels/colors skip invisible rows and refresh on Show. Native roster, unit values and shared edit bounds remain.                                                                                                                                                                                                                                                        |
| `buffs`             | Hiding clears custom timer rows/hovers and stops cosmetic ticking. Native packets may request one deferred phase/receipt check, without hidden timer getters or painting. Icon/font/anchor repair resumes on Show. Hidden edit entry may count slots for handle bounds. Native buffs/enchants remain native.                                                                   |
| `actionBar`         | Native buttons remain native. Custom cooldown numbers skip hidden getter/paint work; range polling detaches, existing indicators/fades clear, and hidden buttons allocate no indicator. Attached XP/jewelry/tally follow this owner.                                                                                                                                           |
| `runTimer`          | Hidden fill, caption, markers, foam and sparkle writes stop. Native clock/schedule validation and HUD ownership use the existing ten-Hz poll or deferred publication; visible clock effects retain frame cadence. HUD release paints cleanup once while failed native restorations can retry.                                                                                  |
| `bossBars`          | Hidden health/debuff text, icon allocation, timing getters and reflow stop. Existing hovers/debuff rows clear once on Hide. Native encounter validation, row retirement and takeover remain, including a valid empty boss list; Show requests fresh rows.                                                                                                                      |
| `runTally`          | Hidden counter formatting/measurement and glow preparation stop. Native counter validation/takeover and attachment metadata remain; Show requests fresh presentation.                                                                                                                                                                                                          |
| `xpBar`             | Native XP/level events still coalesce the latest tuple. Hidden gain animation stops and detaches, final private bar writes defer, and requested visibility changes only on transitions. Show restores the latest fraction and schedules a fresh instant read.                                                                                                                  |
| `jewelryBar`        | Its existing polling controller detaches behind the active hidden Layout owner. Hidden inventory/cooldown reads, icon composition and cosmetic cooldown painting stop; visible recovery retries metadata. Attachment changes and world cleanup remain. Exact fourteen-strip sampling is unchanged.                                                                             |
| `minimap`           | Clock painting stops with its hidden parent. The glyph launcher stops its active drag and clears its hover; square-edge button projection/reflow stops until shown. Custom pins skip hidden styling/projection/facing work, while required native guardian-flag ownership/restoration continues at the existing lifecycle poll. The independent visible world map still works. |
| `cacheWaypoint`     | Hidden guide interpolation, distance formatting, arrow rotation and facing samples stop. Native destination acceptance/selection, world cleanup and independently visible map pins remain.                                                                                                                                                                                     |
| `guardianWaypoint`  | Same visibility boundary as cache guidance; accepted lairs still feed the guardian data foundation independently of this HUD's visibility.                                                                                                                                                                                                                                     |
| `guardianTracker`   | Layout-hidden policy detaches its pure view controller before roster copying, measurements or row painting. The separate guardian foundation continues accepting native state. Show uses a fresh snapshot.                                                                                                                                                                     |
| `damageMeter`       | Layout-hidden mode validates newly published native data without copying view rows or sampling displayed rates, retaining phase retirement and takeover checks. Showing rebuilds from the getter. Feature-off remains stricter: no meter subscription, collection, getters or idle updater, apart from a pending native-preference restoration.                                |
| `petFrames`         | Hidden/static groups skip timer sampling and all row/icon painting. New native roster receipts, phase retirement and changed edit bounds remain. Show refreshes current timing through the existing controller. The separate native primary pet retains its native ownership.                                                                                                  |
| `revive`            | Hidden progress/identity state stays current without glyph measurement, text/bar/cross/spark writes or cosmetic animation. Show requests a fresh deferred read. Existing native-HUD release while Layout-hidden remains; no revive time is invented.                                                                                                                           |
| `levelUp`           | Hidden class icon, count formatting/measurement, content alignment and pulse painting stop. Native stored-level validity/takeover remains. Hidden editor bounds still measure the active-language panel; Show refreshes current data.                                                                                                                                          |
| `lootNotifications` | Hidden labels/icons/colors, alpha animation and card reflow defer. Original lifetimes, bounded exact-reference metadata retries and queue retirement continue, so expired cards cannot reappear. Show expires old cards before painting.                                                                                                                                       |
| `banners`           | Hidden labels/colors, alpha animation and reflow defer. Native registration, preference ownership, delivery deduplication, queue promotion and original expiry cadence remain. Show retires expired rows before painting current notices.                                                                                                                                      |
| `chat`              | Its cosmetic updater inherits native hiding; native hooks skip hidden font/geometry/indicator work. Show repairs native presentation. Native messages, level/stat batching, history, opt-in capture and the separately parented command input remain available.                                                                                                                |
| `copyWindow`        | No idle updater. Opening while Layout-hidden only establishes the lazy edit owner/requested visibility; it skips archive-page preparation and invisible focus. Existing close cleanup and capture policy remain.                                                                                                                                                               |
| `menu`              | No idle updater or hidden decorative controller. Game-owned commands/window actions keep their existing behavior.                                                                                                                                                                                                                                                              |
| `tooltip`           | Hide clears the current native hover immediately. Hidden ancestry prevents positioning/styling updates; no subject is forced visible on Show. Native content/owner and separate private readers stay native.                                                                                                                                                                   |

The shared grid, handles and numeric/editor bounds remain active while editing,
including for hidden elements: they are the controls needed to show them again.
Native primary-pet, target-of-target and portrait callbacks retain their existing
ownership; addon presentation uses actual visibility, and native model copies
are released while hidden. No native event subscriptions or gameplay mechanisms
are disabled to obtain a cosmetic saving.

Verification is manual source/diff review plus pinned StyLua/Prettier formatting.
No local tests, standalone validation, addon/game execution or FPS measurement
was performed. Live input, drawing parity, native restoration and Show/Hide
behavior still require an authorized in-game check.

## Recovered Git history

The 2026-10-26 audit fetched the complete available branch history into the
installed addon checkout and reviewed the performance commits below alongside
current owning code. Some commits are historical feature-branch sources of
squashed/integrated changes, so their hashes alone do not establish current
ancestry. Current behavior is checked in the actual module. Earlier experiments
must not be silently promoted to shipped optimizations.

| Historical commit                                                  | Drawing/update lesson retained                                                                                                                                                                                                                                                                 |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cc75e6e`, integrated work in PR #17 (`25ad81e`)                   | Parse SCT before expensive plate work; coalesce discovery within event batches while retaining independent per-frame discovery, native placement and Lua 5.0 queue sizes. Dirty icon scans stay globally throttled.                                                                            |
| `c2a7c98`                                                          | Pet icons moved from per-physical-pixel strip composition to one named native circular image per group. Cache roster receipts, text and settings; skip timer reads for hidden/static/permanent groups. Keep lazy strips only as compatibility fallback.                                        |
| `d1025bf`                                                          | Shared unchanged text/font guards; receipt-based run schedules and waypoint copies; changed-only nameplate styling; reusable guardian views; exact unit-event routing; completed player fades; hidden cosmetic suppression; retained full chat archive without repeated whole-history copying. |
| `005687c`                                                          | Restore the original fourteen jewelry bands. A visually tempting central-band merge could change cropped-UV filtering at fractional scales. Appearance parity takes precedence over a smaller region count.                                                                                    |
| `c9aadcb`                                                          | Group equal jewelry textures without changing their icon windows; assemble fixed timer backgrounds exactly; keep eight skull-glow copies but replace repeated clear/reanchor work with anchored geometric frames. Material/UV-clamp state and global ordering matter.                          |
| `633a6f2`                                                          | Unchanged jewelry layout stays put and idle cooldowns skip paint traversal. Keep five-Hz native equipment/cooldown retries and active cosmetic cadence.                                                                                                                                        |
| `a8bce4b`, `6bbde53`                                               | Alternative jewelry alias/repeat/subdivision proposals remain investigations. Exact rational identities and CPU float models do not establish identical rendered pixels or a net performance gain. Five distinct jewelry icons remain unresolved.                                              |
| `aef95e3`                                                          | Revive stops completed fade writes; Level Up caches text bounds and requested visibility; class resources rebind changed styles with failed attempts retryable; loot caches icons/colors/placement; native primary-pet styling compares actual state after native resets.                      |
| `5912dfd`                                                          | Character updates coalesce into one deferred callback, stop while hidden, reuse text/row/header measurements and repair actual native geometry. Quality-rim passes compare current RGB/visibility instead of hide/repaint cycles.                                                              |
| `3d3583c`                                                          | Layout/grid/coordinate idle sampling uses ten Hz, immediate invalidation and per-frame active input. Reuse target bounds and candidate/latch records, skip unchanged searches/writes, and force a final cursor/modifier/target sample.                                                         |
| `0366880`, `4fb3036`, `9a0580e` and later local micro-menu removal | Retire unused runtime artwork and modules rather than keeping hidden decorative systems. Package/load savings are distinct from measured drawing savings. Required native suppression and keyboard access remain.                                                                              |

Later history also matters: `db84500` replaced the whole-session Copy field
with bounded UTF-8-safe pages, and `7ebee3e` made diagnostic capture opt-in.
The current implementation follows those later changes, rather than restoring
the earlier full-field presentation from `d1025bf`. See
[CLEANERCHAT-PORT.md](CLEANERCHAT-PORT.md) for the native-history boundary.

## Current frame coverage

The audit covers the following drawing/update owners, including their native
ownership and cleanup boundaries. Existing authored animation and native work
remain in place; this is not a claim that every remaining cost is eliminated.

| Frame group                                             | Owners and preserved performance boundary                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Pet summons and native primary pet                      | `modules/unit/pets.lua`, `modules/unit/mini.lua`: native cached circles, receipt/roster reuse, visible timer reads and actual native-state repair.                                                                                                                                                                                                                                                                                         |
| Equipped jewelry                                        | `modules/ui/jewelry.lua`: original fourteen-strip UVs, grouped texture order, unchanged layout, idle cooldown gating and metadata retries.                                                                                                                                                                                                                                                                                                 |
| Run/boss/tally, guardian tracker                        | `modules/ui/run.lua`, `modules/ui/guardians.lua`, `modules/ui/guardian_tracker.lua`: receipt-based schedules/copies, pooled rows, hidden cosmetic guards, fixed pill backgrounds, retained marker/foam/glow equations and edge-to-edge bezel joins.                                                                                                                                                                                        |
| Player/target/party, resources and portraits            | `modules/unit/player.lua`, `target.lua`, `mini.lua`, `resources.lua`, `portraits.lua`, `core/widgets.lua`: shared styling, completed fades, changed styles, exact native-unit routing, native health and model-paint evidence.                                                                                                                                                                                                             |
| Character and equipment                                 | `modules/ui/character.lua`: coalesced deferred work, measurement/discovery caches, actual native anchor repair and the three authored quality-rim passes.                                                                                                                                                                                                                                                                                  |
| Revive, stored levels, loot and banners                 | `modules/ui/revive.lua`, `levels.lua`, `loot_view.lua`, `banners.lua`: passive pools, changed-only presentation, requested visibility, bounded view queues and required hidden lifetime/ownership cleanup.                                                                                                                                                                                                                                 |
| Action bar, range and XP                                | `modules/bars/bars.lua`, `range.lua`, `modules/xprep/xprep.lua`: shared controllers, event-driven work, transition-only range fades, final cooldown sampling and pending-only XP animation.                                                                                                                                                                                                                                                |
| Minimap, guides and map markers                         | `modules/map/map.lua`, `buttons.lua`, `navigation.lua`, `waypoints.lua`: reusable accepted snapshots/pins and native direction/position sampling; skip unchanged clock labels and button anchors. The transparent glyph adds one texture, no idle polling or extra hover region; its pointer updater exists only while dragging. Square-edge adaptation runs on foreign placement calls or map/show/load events. See `MINIMAP-BUTTONS.md`. |
| SCT and nameplates                                      | `modules/nameplates/sct.lua`, `style.lua`: event-batch discovery plus independent frame discovery, preserved matching/animation, cached metadata and unchanged native styling.                                                                                                                                                                                                                                                             |
| Layout/editor, tooltips, chat, Copy, menu and inspector | `core/layout.lua`, `editor.lua`, `tooltips.lua`, `fstack.lua`, `modules/chat/*`, `modules/menu/menu.lua`: bounded edit sampling, passive/pool reuse, owner/scale-aware hover work, native chat/fades, retained opt-in diagnostics and hidden inspector shutdown.                                                                                                                                                                           |
| Meter and general warning overlay                       | `modules/ui/meter.lua`, `modules/ui/ui.lua`: native circles, one-Hz native rate display with five-Hz data observation, visibility/change guards, transition-only warning visibility and preserved gradient animation.                                                                                                                                                                                                                      |

Native aura/timer rows (`modules/unit/auras.lua`) retain changed-slot reflow,
hidden timer shutdown and required repair of native buff/enchant anchors.
Damage-loss artwork (`modules/unit/cut.lua`) installs its animation callback
only for active fades and removes it when the fading pool is empty. These
native repair and authored fade paths must not be removed as idle work.
Bag, cast-bar and micro-menu suppression have no replacement artwork or
decorative updater; their game-owned window/keyboard behavior stays intact.

## Meter drawing audit — 2026-10-26

The custom meter now defaults off through `meterEnabled`. Off hides/clears the
view, releases its native HUD preference and detaches its existing OnUpdate;
no meter/phase getters, icon work or drawing run. Off also unsubscribes from native
addon messages, clears receipt flags, copied snapshots, sampled rates and displayed
row/header values, and requires a fresh publication when enabled again. It collects
no private off-period history and writes no damage log. World lifecycle cleanup
stays registered. A pending native HUD restore may retry through the same controller
with CVar observation until its captured preference is released. The initial readiness row and any previously grown pools remain
allocated for reuse, with no visible drawing cost. Live enable/disable, profiles,
Confirm/Cancel/discard and both resets share the existing display lifecycle.

The meter's normal circular path uses six native icon regions plus six existing
ring regions. With its header, row backgrounds and fills, the full six-row view
has 25 authored texture regions, excluding text, native internal regions,
tooltips and other HUD owners. The configurable one-to-ten row limit defaults
to six; a fully populated native view has `1 + 4n` authored texture regions,
so ten rows use 41. One seeded row checks renderer readiness; additional rows
are allocated only when requested visible sources need them. Shrinking the
view retires surplus rows immediately and retains the pool for reuse.
No strip pool is allocated on the native path.

Meter DPS, icons and both header fields default on; ability damage, percentage
and ranks default off. Turning **Ability icons** off
clears pooled icon bindings, hides icons/rims and skips icon resolution and binding
in subsequent paints, leaving `1 + 2n` authored texture regions in a populated
view (13 at six rows, 21 at ten). Pools remain allocated for reuse. Disabled
row values do not trigger formatting when their native values change. Column
widths and the icon gutter reflow only for effective option changes; header
text is cached by its visible values, view, language and options revision.
These are source-level cost controls, without a measured FPS claim.

The compatibility path is deliberately more expensive: at effective scale one,
each 26-unit icon uses 24 nonempty strips. Six such rows have 163 visible
authored texture regions and 169 allocated regions including their six hidden
named portraits. These are construction counts, not measured material batches
or GPU draw calls. For a freshly populated ten-row fallback view the equivalent
counts are 271 visible / 281 allocated at scale one. Retained pools can have
additional hidden regions after reducing the count or scale. Different scales
change the lazy fallback pool. Keep the
native cached image as the preferred path; do not treat updater caching alone
as a fix for strip-composition cost.

The audit found and corrected local meter gaps:

- Valid native data and HUD ownership continue while Layout hides the meter,
  but hidden rows skip formatting, tooltip repaint, icon lookup/binding and bar
  painting. Visibility requests occur only on transitions; clearing is idempotent.
- A hovered tooltip reuses unchanged source/value/mode/language/scale content.
  It no longer clears, reparents and rebuilds the same lines every five-Hz poll,
  or steals a tooltip that another native owner has taken or hidden.
- Row labels/numbers avoid unchanged formatting; bar, color and icon bindings
  retain their existing guards. Native circle failures are remembered like the
  pet renderer; failed fallback texture assignments still retry.
- The minimap clock skips identical minute text on its existing five-second
  timer, and the low-health overlay skips repeated Show/Hide calls while keeping
  its authored gradient animation and timing.

All audit edits are made directly in the installed Git checkout and remain
unstaged, uncommitted and unpushed. Local work used source/history review and
pinned formatting only; no addon/client execution, local test or standalone
validation was run. Live appearance, FPS, draw calls and GPU-memory behavior
remain unverified.

## Side resizing, row viewports and text size — 2026-10-27

Six Layout groups add twenty editor-only center-edge marks: two horizontal for run timer, boss health, Revive, meter, Chat and guardians, plus two vertical for the four row views. Each is one existing native solid texture under the hidden shared handle, with no asset or additional controller. The two obsolete settings sliders and their four thumb/track textures are removed. **Show grid** uses one existing-style lazy editor checkbox; off hides the complete grid and guide parent and skips grid geometry sampling. Shift alignment still uses the existing active-drag calculations.

Width lives in shared Layout geometry. Meter and guardian roots default to 240 and allow 120–960 without scaling row height, icons or fonts. Cached natural tracker text widths compress its columns safely; native health end caps retain their 50-unit combined span. Meter geometry caches width, font size, icon gutter and numeric-column count. Failed font changes remain retryable. Hidden/off views accept required edit bounds while deferring row/header/font/icon presentation. Meter resizing never enables native reads or packet intake while off.

Row handles update normalized display drafts. DPS retains 1–10 rows; boss/guardian capacity defaults to the existing automatic full list, with explicit 1–40-slot viewports and session-only scroll offsets. Native snapshots remain complete. Only viewport rows are painted; retired rows clear health, debuffs and hovers before pooling. Boss debuffs preserve their icon dimensions and reanchor only when their width-derived column count changes. Chat keeps its existing native dimension and content ownership.

Run timer width reflows the existing 27 flow textures and 28 red glints without additional regions. Flow speed, temporal phases, pulse equations, opacity and cadence remain unchanged; spatial spacing, span, foam clipping and scheduled skull positions use the actual fill width. Native health/status-bar UV ownership and artwork crops are preserved. Wider visible fills cover more pixels; these source-level changes do not establish equal GPU cost or FPS. Revive invalidates its spark/cross geometry on width changes, retaining the existing animation lifecycle.

All resizing uses the existing editor controller, unchanged-pointer guards and final release sample. Root height changes from row/debuff reflow also invalidate the active opposite-edge calculation. Grid preference, row counts, widths and font size retain shared Confirm/Cancel/discard/profile/reset behavior, without a new SavedVariable or idle updater. Local work was limited to source inspection and pinned formatting; appearance, animation, input and renderer performance remain unverified.

## Unit health width handles — 2026-10-27

Player, target and party add six editor-only one-texture side marks. Their anchor can use the native health bar or existing multi-row edit region independently of the Layout owner's dimensions. Width remains in the existing Layout record and uses existing resize/editor/Show/unit-event paths, with no asset, SavedVariable or new updater. Portrait/model dimensions, health heights, animation timing and native values remain unchanged; the existing Cut-Out size callback reflows retained loss fractions.

Large-frame width reflows its shared health span and metal end position. Native StatusBar UVs remain untouched. Each large top/bottom artwork region becomes a fixed cap plus a straight span: two additional allocated/visible regions per large frame. Party's full resource-mode sheet becomes three pieces (one previously), and each health-only top/bottom span splits at the fixed outer cap, raising that variant from thirteen to fifteen pieces. Both party variants are allocated during the existing four-row setup, adding four allocated regions per row; only the selected variant has nonzero alpha, adding two visible regions per active row. Across player, target and four party rows this is twenty extra allocated artwork regions, up to twelve extra visible artwork regions, plus six editor-only marks. Four passive party anchors replace their old single-texture anchors; they have no updater or input.

The extra pieces preserve portrait/cap proportions during horizontal extension and use the same source pixel regions without added effects or alpha overlap. Changed widths update the affected sizes/anchors; unchanged state skips them, and actual large-bar/divider anchors are compared before repair. Width changes reuse successful texture bindings. Hidden large frames defer their reflow until visible or required editor entry; inactive party rows update only required root/border bounds and defer caption/texture work until Show or editing. Ordinary unit events make only the existing visibility checks and small width/state comparisons before any reflow. Party resource-mode changes and width changes share one owner, so later native value events or preview changes cannot restore the old health span.

Source/diff inspection and pinned formatting cover the geometry and shared save/discard paths. This is an explicit source-level drawing-cost increase for independent width, not measured FPS, GPU cost or pixel parity. No local tests, standalone validation or addon/game execution were run; packaged-client appearance and input remain unverified.

## Combat-text editor availability — 2026-10-27

The Combat text mode selector and status description stay outside one passive settings parent. When effective SCT mode is Off or Game settings, that parent uses the existing 0.45 alpha and every control below it disables mouse input: incoming/self text, damage icons, size buttons, class colors and all filter checkboxes. Headings, separators, labels and values inherit the same dimming. Custom restores the parent to full alpha and reenables its controls. All existing preference values are preserved, including the native incoming/self choice; availability itself writes no gameplay/native setting.

The shared editor availability helper now serves this group and the existing replacement-display dependents. It skips alpha/input writes when enabled state is unchanged. The existing SCT settings listener supplies the effective draft mode, including preview, profile loads, external mode changes, Confirm and discard. The lazy settings dialog adds one passive frame, zero texture regions, no animation, updater, game event, asset or SavedVariable. Source/diff inspection and pinned formatting only; local tests, standalone validation and addon/game execution were not run. Runtime appearance and interaction remain unverified.

## Guardian Show dead control — 2026-10-27

The tracker's minus/plus header button, four native state-texture slots, tooltip
handlers and optional glyph-alignment branch are removed. The existing minimap
zoom controls retain their artwork and styling. A standard shared-editor checkbox
owns the default-on `guardianShowDead` display choice, with normal preview,
Confirm/Cancel/discard, profiles and reset handling. The title reclaims the old
button space without another frame, texture or font.

Changes coalesce into the existing visible tenth-second view refresh. Off
compacts only the presented rows to native `asleep` / `awake` entries and clears
retired health fills. Hidden views skip the refresh and retain a pending current
choice for showing again. The complete accepted roster, health joins, native
countdowns and independent guidance retain their existing ownership. No new
updater, game event, asset or SavedVariable is added. These are source-level
drawing/lifecycle observations, without measured FPS or in-game input proof.

## Source-icon language coverage — 2026-10-27

The shared SCT/meter icon resolver now receives generated exact-name aliases
for all fourteen game languages, extending the former Czech-only data path.
The generated data contains 5,667 non-identity alias groups; English has an
empty table. This adds resident Lua tables/strings at load time. Each lookup
still reads only the selected language and its candidate list through the
existing resolver; there is no per-hit catalog build or cross-language scan.

No renderer, frame, texture, material, UV, alpha, animation or binding path
changes. Native circles, fallback pools and gold rims keep their existing
region counts and binding caches. Disabled/hidden meters and disabled icons
still skip resolution. No updater, event, setting, asset or saved state is
added. These are source-level cost observations, without an FPS/GPU claim or
local execution. Alias provenance and remaining limits are in
[LOCALIZATION.md](LOCALIZATION.md#source-icon-languages--2026-10-27).

## Pet re-audit — 2026-10-26

Rechecking `c2a7c98` against the current owner found two remaining gaps in the
compatibility path and hidden presentation. The strip fallback previously
remembered an icon even when a texture assignment failed. A static group could
then retain an incomplete icon until its icon or scale changed. It now caches
only successful strip assignments and retries failures through the existing
tenth-second controller, without repeating successful bindings or native
portrait failures. Incomplete icons stay hidden until all required strips load.
Scale changes keep successful bindings and reflow only the clip geometry.

Hidden groups still accept native roster publications and keep shared edit
bounds current, but no longer create or paint rows for those publications.
An OnShow invalidation requests the next existing controller tick, so unhiding
repaints the accepted data and resumes native timer sampling when needed.
Retirement clears successful strip bindings and the native-failure cache.
No asset, setting, SavedVariable, gameplay clock or updater is added, and the
34-unit circle, 39-unit rim, exact UVs and native data ownership are preserved.
These changes were reviewed from source and formatted locally; appearance,
failure recovery and performance remain unverified in the running client.

## What changes

- Text and DEFAULT font helpers compare current widget values before writing.
  Localized labels retain their original source caption for language changes.
- Nameplate styling skips unchanged native suppression, health, names and raid
  icon writes. Live SCT discovery, position sampling and hit matching keep their
  original cadence.
- Run schedules are validated and copied per received native publication rather
  than per rendered frame. Receipt generations, run boundaries and the one-use
  reload handoff remain authoritative.
- Hidden timer groups keep throttled native clock observation and HUD preference ownership
  but skip cosmetic animation, label and marker geometry work. Visible effects
  use the existing textures, equations and update cadence. Reappearing groups
  catch up from current native data.
- Boss and guardian rows update changed content and reflow changed geometry.
  Guardian views may reuse their own copied snapshot; private accepted lairs are
  never returned to callers. Native remaining time and spawn-matched health
  continue to be read through their existing APIs.
- Waypoint snapshots reuse accepted copies between receipts. Live position,
  bearing and facing sampling remain unchanged; identical pin positions and
  arrow UVs are not resent.
- Small unit frames route unit-specific events through the exact token and
  native unit aliases. Ownership, world and target transitions refresh the
  complete group. Native colors are compared directly so later native writes
  are still repaired.
- Player pulses retain frame-by-frame native state detection and their original
  fades, then stop alpha writes after reaching zero. Resource polling stops
  outside the world. Cooldown sampling preserves its final positive-time zero
  window while avoiding identical text, color and visibility writes.
- Jewelry hover cards retain native retries and only repeat layout when their
  text, owner or effective scale changes.

## Jewelry rendering

Jewelry keeps its existing magnified icon crop and stepped circular outline:
14 regions per populated icon, or 70 across five populated slots. Even merging
the geometrically identical central strips could change sampling at their
shared seam on clients that clamp cropped UVs per quad, so their original
partition remains unchanged. Icon regions now share one artwork owner, ordered
by exact texture path, then strip, then slot. Equal images with the same UV
window are adjacent for native batching. Their slot-relative anchors, dimensions,
crop and order within each icon stay the same. The icons cannot overlap: their
32-unit canvases have at least 43 units between centers, including while detached.
Cooldowns and gold rims retain their original layers above the icons.

The base renderer additionally sorts equal-texture quads using an unstable
native-style sort. For an isolated batch of two equal icons, that sort leaves
16 material runs instead of the original 28; five equal icons leave 16 instead
of 70. Different images and unrelated artwork in the same native layer can
alter that permutation, so this is a conditional batching improvement rather
than a fixed draw-count guarantee. Five different icons still need 70 regions.
Native action-button normal/pushed artwork can share this layer; their icon
images use BACKGROUND. The isolated examples therefore do not predict the live
combined batch's draw count.
The Actions reference model reports equipment/rank combinations without running
addon Lua; these are source-model results, not measured GPU counters. Failed
texture assignments retain that slot's last successful artwork; recycling never
borrows another slot's old pixels.

The first Actions run evaluated 541 five-slot equality/rank cases: 421 improved
and 120 were unchanged in isolation. Three fixed peer scenarios had no modeled
regression. In the fourth, seven later peers sharing the first jewelry texture,
418 improved, 120 were unchanged and three increased by up to three runs. The
model therefore demonstrates useful reductions without proving an improvement
for every possible shared-layer composition.

The native portrait conversion used by pet frames is not interchangeable here.
The reviewed client masks portrait pixels before applying texture coordinates;
the jewelry crop would enlarge that circle, and the partially transparent gold
rim does not fully conceal the difference. No approximate native-circle
replacement or prepared item images are included. Grouping preserves the native
texture paths, including future or unknown valid paths, without an icon catalog.

### Five different icons

The remaining unique-image drawing cost is unresolved. The supplied executable
stores `uv_clamp` as one material uniform at `0x5fb2f29`, applies that clamp at
`0x5fb339e`, and samples the image at `0x5fb3442`. Each of the fourteen original
bands has a different half-texel sampling window. The existing one-quad-per-band
implementation therefore retains seventy texture/window states for five
distinct images. This is a bound on that implementation, not proof that every
addon-only approach requires seventy states.

Further read-only inspection found an addon-accessible repeat-mode route that
could replace sampling clamps with subdivided geometry. It could use five
material groups and 630 regions, or a partial version could use 35 groups and
210 regions. The packaged client supports the required repeat-mode loading.
Exact rendered output, overlap ordering and net performance are not established;
neither candidate is enabled. See
[the follow-up investigation](JEWELRY-RENDERING-INVESTIGATION.md) for the concrete
construction, evidence and remaining questions. The five-different-icons request
remains unresolved; this PR does not present these candidates as a shipped fix.

The follow-up nevertheless removes redundant work for every equipment
combination: unrelated display previews retain unchanged row anchors and edit
bounds, and inactive cooldowns skip their thirty-Hz paint traversal. Native
equipment/cooldown retries remain at five Hz, and active cooldown painting keeps
its original cadence and final clearing pass. These are update/layout savings,
separate from the unresolved drawing cost.

## Timer rendering

Fixed run and boss-health pills use one assembled background region in place of
three. Each base pill therefore uses five regions instead of seven. The original
left and right caps are copied unchanged around the horizontally uniform black
center. Their joins have the same constant texels on both sides, so removing the
two internal UV clamps preserves bilinear samples. The variable-width tally
keeps its original three-piece background. Borders, fills and geometry are
unchanged; the new image is prepared by `scripts/prepare_timer_background.py`.

Each active scheduled skull retains eight glow copies in the same creation and
draw order. Their centers are permanently anchored to two empty geometric
frames: cardinal copies follow edge centers and diagonal copies follow corners.
Four dimension writes replace sixteen clear/reanchor calls per animated frame;
the eight original texture-alpha writes remain. This reduces that loop from 24
to 12 native methods per active marker per frame. The original trigonometry,
alpha values, textures, timing and cadence remain. Blue flow and foam also skip
identical size and UV writes, while position and animation continue normally.

The timer's cosmetic layers now use 72 allocated textures,
with at most 43 blue flow/foam pieces or 29 red sparkle/glow pieces visible at
once, plus the base pill and schedule markers. Active boss markers retain their
eight glow copies. Their drawing cost remains alongside the reductions above.
A finite baked animation cannot preserve these independently phased effects at
every native time and layout scale, so no animation frames are substituted.

## Renderer evidence

Read-only inspection of the supplied Windows executable found native
`UiQuadBatch` / `UiQuadMaterial` type names at byte offset 99,712,445 and the
cropped-UV shader's `uv_clamp` input at 100,347,689. The inspected executable's
SHA-256 is `e069bf3152f8d8f7160d66388907fc181c733bd170aa150d3b7ff7adf251e048`.
The shader starts near 100,342,970 and identifies `shaders/ui_quad.wgsl`.

The public native-base
[UI renderer](https://github.com/samwhosung/benilla/blob/main/crates/benilla-app/src/ui_pass.rs)
groups contiguous quads with the same texture and material, including their UV
clamp. The native-base
[layer ordering](https://github.com/samwhosung/benilla/blob/main/crates/benilla-ui/src/order.rs)
and
[texture sort](https://github.com/samwhosung/benilla/blob/main/crates/benilla-ui/src/script/layer_batch.rs)
can further permute equal-texture quads across all owners sharing a flat
stratum, level and layer. Owner creation order alone cannot guarantee a batch.
Its
[extraction code](https://github.com/samwhosung/benilla/blob/main/crates/benilla-app/src/ui_script/extract/mod.rs)
defines cropped half-texel clamps. These sources explain the proposed batching
and the reason to retain every jewelry strip boundary. They do not establish
the complete packaged renderer's identity or a measured performance result.

## Shared addon identity

The release package and local installation both use the `SurvivorsDragonUi`
folder and `SurvivorsDragonUi.toc`. The shared asset root and load-event name
use the same identity. Local work is edited directly in the installed Git checkout without identity translation or a separate worktree/sync step.
The action bar, range indicator, XP bar, minimap and window skins obtain their
texture subfolders through `DFRL:GetInfoOrCons("tex")`, as the newer modules do.
GitHub Actions enforces the single shared root across runtime Lua sources.

## Full chat history

Diagnostic capture is opt-in and off by default. While enabled, the session
archive retains original ordering, duplicate-delivery rules and literal markup
without a retention cap. Completed chunks are joined once; appending does not
recopy earlier history. Disabling capture unregisters collectors, clears the
archive and invalidates open snapshots; normal chat and live loot/banner intake
keep working without diagnostic collection.

Copy displays at most six KiB of archive text per UTF-8-safe page, plus compact
banner status. Its archive boundary is fixed when opened, and native history
is read through bounded client pages. Resizing measures only the current page
and then clears the hidden measurement text. The full export API remains
available, but the dialog does not build or measure a whole-session string.
There is no saved archive; memory necessarily grows while enabled capture
retains more text. See [CLEANERCHAT-PORT.md](CLEANERCHAT-PORT.md).

## Verification limits

Checks run only in GitHub Actions: version gating, formatting, Lua static
analysis, fractional timer-artwork sampling, a native-base batching reference
model and runtime-manifest validation. The extra checks read TGA pixels and model
ordering only; they do not execute addon Lua or client code.
Pinned StyLua and Prettier formatting is allowed locally. No local tests,
syntax checks, addon execution or game launches are part of this work.
PR checks do not build an addon ZIP. Current local implementation is edited
directly in the installed Git checkout, with the same folder, TOC and loader
identity as the release.

The source review covers unchanged values, reused rows, malformed reload
handoffs, native unit aliases, receipt boundaries, hidden-to-visible transitions
and failed texture assignment retries. Static checks do not establish in-game
pixel parity, an FPS improvement or resolution of the separate world-entry
stall and GPU out-of-memory reports. Those require new user-recorded captures.
