# Rendering and update costs

The October 2026 performance work removes repeated presentation writes while
retaining native data, pause-aware timing, saved preferences and artwork.
It adds no gameplay clock or native client dependency. Display choices use the
existing saved display table; the optional minimap clock below defaults off.

Pet and meter image textures share `T.NewCircularIcon` for native circular
binding and the lazy physical-pixel strip fallback. Each view keeps its original
icon/rim dimensions, strip-density minimum, metadata and hidden lifecycle. This
consolidation adds no frame, region, asset or updater; successful bindings remain
cached and failed fallback texture assignments remain retryable. Shared HUD
ownership and encounter validation likewise retain the existing controller
cadences and separate receipt/retirement gates. Performance Mode and normal-mode
presentation keep the same behavior.

## Mandatory rule for all drawing and assets

Drawing performance is a project requirement for every frame and artwork change,
including new features. Review two separate costs: recurring Lua/native work
and what stays visible in the renderer every frame. A cached updater can still
leave hundreds of expensive texture regions drawing continuously.

- Every new or changed feature with applicable addon-owned cosmetic animation
  must include a Performance Mode equivalent in the same change. Reuse the
  existing default-off `performanceMode` display choice and shared listeners,
  preview, Confirm, discard, profiles and resets. Prefer useful static or
  instant presentation; actually hide optional decorative regions and skip
  their animation math, writes and cosmetic workers. Avoid preparing unused
  animation artwork while the static path is selected; reuse any prepared pool.
  Mode/visibility/world transitions must clear or settle active and queued
  effects, reject late animation callbacks and avoid replaying expired effects
  when normal presentation returns. Preserve individual saved choices, native
  information, timing, ownership, input, readiness retries and notification
  expiry. Native gameplay effects, active dragging and required navigation
  projection retain their own ownership. Add no separate performance setting,
  SavedVariable or idle updater. Record the static behavior and source-level
  costs in the owning developer docs, with meaningful CI-only lifecycle coverage
  where appropriate; local tests and addon/game execution remain unauthorized.
- SCT keeps its selected Over enemies, MSBT or Diablo IV animation
  in Performance Mode. Only grouping changes: sum same-attack damage in
  300 ms while enabled, with the original 75 ms exact-amount duplicate
  suppression otherwise. Do not add a static override or
  retire its active hits just because Performance Mode changes.
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
  The user-requested run-progress exception uses whole native run-second steps
  for the fill and its decorative clipping edge; temporal effect cadence stays
  unchanged. See the one-second progress entry below.
- Record visible/allocated regions and material/UV-clamp implications separately
  from CPU calls. Source counts and reference models are not live draw-call,
  GPU-memory, pixel-parity or FPS measurements. No local tests, standalone
  validation, addon execution or game launch is authorized for this audit.

## Diablo IV combat text — 2026-10-30

The optional Diablo IV style reuses the enemy-origin path, controller and hit
pool: no combat frame, region, asset, event or updater is added. Its 1.1-second
burst/hold/fade replaces the selected label's animation only. Formatting and
random size/scatter are chosen once; live anchors, scale and alpha retain their
changed-only writes and empty lists remain idle. Performance Mode preserves the
animation with the existing 300 ms same-attack sums. It never restarts active
labels on a Performance Mode transition.

Matched Diablo labels reuse the existing per-frame native origin projection,
so camera/mob movement changes the base point beneath their independent motion.
Only unanimous nonnil group origins are retained. Each following label performs
constant-time cached-field reads, with no extra native geometry read, lookup,
scan or updater. Retirement or stale projection permanently detaches at the
last usable point; pool/world cleanup clears the reference. Mixed and unknown
groups retain the fixed centroid. Camera compensation after native retirement
has no supported world-projection source. CI-only plate/queue cases cover these
boundaries in both grouping modes; they were not run locally.

The shared style selector replaces the MSBT checkbox on the lazy Combat page.
Net settings cost is two button frames, eight texture regions and three labels;
none draw while that page is closed. Original per-hit allocations, metadata
ownership and native tracking remain shared. See [DIABLO-SCT.md](DIABLO-SCT.md)
for the video study, tuning, migration and CI-only evidence limits. Source
review and pinned formatting do not establish native appearance or FPS.

## Static Heroic numerals — 2026-10-29

The Bildad marker lazily adds one texture to the existing live timer overlay
on first visible Heroic use, with no frame or animation pool. Normal allocates no numeral texture. Each
32-by-16 unit region samples one transparent cell from the same 512-by-256
lossless BLP atlas, with a baked dark outline and a tier-specific vertex tint.
The TGA is an authoring source only; no font is installed or shipped. Source
and licensing are in [HeroicNumerals-ARTWORK.md](../third_party/HeroicNumerals-ARTWORK.md).

Rank/UV/tint and binding caches skip unchanged native writes. Position follows
the actual fill width and received run duration, using the one-minute point
with cap protection for narrow bars. Layout resizing reanchors the already
accepted rank without another gameplay read. Lazy bindings retry on the
existing ten-Hz/deferred sample; no per-frame numeral update is added.

Live acceptance shares the affix view's numeric-rank, publication-stamp,
receipt and retirement gates while remaining independent of affix artwork or
visibility. Hiding and run/world/zone/reload retirement clear the active rank
and hide its existing texture; later valid use reuses its successful binding.
Hidden overlays skip allocation, geometry and tint work. Performance Mode
retains the exact static marker with no animation work in either mode. There
is no added event, updater, setting or SavedVariable.

CI-only source-extracted mocks cover rank acceptance and retirement, I–X
selection, hidden lazy allocation, unchanged-write suppression, width changes,
binding failures/retry and the static Performance Mode path. These are source
contracts, not live appearance or GPU measurements. Local tests, standalone
validation and addon/game execution were not run.

## Heroic run timer

The timer selects one of six cosmetic palettes from accepted `AZS_ZONE.heroic`
metadata: blue for Normal, then the authored Heroic I–V progression toward red.
Higher ranks use V's palette while the separate I–X marker retains the exact
received level. Unknown/invalid ranks use the blue fallback without a numeral.
The existing caption reader returns its accepted `AZS_RUN.endl` mode to the
same clock pass. Only that flag selects Endless; passing the native duration
never changes the palette or mode. `AZS_GetRunTime` and the native duration own
regular whole-second fill values. Endless holds full progress without altering
native time, counters, schedule or gameplay tables.

There is one timer and one lazy, reusable cosmetic pool. Performance Mode and
empty regular progress allocate no decoration. First visible normal-mode
progress prepares 44 regions: 27 flow textures, 16 foam pieces and one glow.
Rank-dependent glints grow lazily to 0, 2, 5, 10, 18 or 28 regions, retaining
the prepared maximum for reuse. The upper bound is 72 cosmetic textures, plus
one lazy numeral texture for a supported Heroic rank; no new frame, asset,
event, updater, option or SavedVariable is added by rank/mode selection.

Rank changes recolor stable scattered stream/foam positions rather than splitting
or overlaying the native fill. Unchanged tier colors, base fill, sizes,
UVs and settled visibility skip native writes. Width changes reflow the existing
stream spacing/span; glints and glow track the actual filled width. Native
whole-second progress dirties this geometry once per changed sample. Pool
retirement hides active pieces, and later accepted state reuses their artwork.

Endless retains its tier palette and changes one existing nine-texture stream
lane into moving glitter points. The remaining eighteen broad streaks preserve
their original movement. Each point shares one sine sample between its pulse
and vertical motion, adding one alpha write per visible point. Existing glints
pulse 20% faster with squared peaks and alpha from `0.28 * 0.85` to `0.85`.
Regular glints retain the authored cubic pulse. All cosmetic animation uses
the same thirty-Hz cap through the existing visible HUD reader.

The twelve existing foam flecks spread across Endless's full fill. They swell
through most of its height, with final alpha from `0.04 * 1.4 = 0.056` to
`(0.04 + 0.28) * 1.4 = 0.448`; the four brighter crest pieces stay at the end.
This pass shares one native height read. Regular flecks retain their original
edge placement and equations. Spark artwork keeps ADD blending so its source
black backing contributes no color. Broader foam covers more pixels, and glitter
adds timed alpha writes: a bounded reused pool does not establish equal GPU/CPU
cost or FPS.

Performance Mode keeps the same static tier fill, numeral, captions and native
marker information. It hides prepared effects immediately and skips all cosmetic
painting and UI-time samples; unused pools remain unallocated. Mode exit, showing
and accepted rank/Endless changes resume from current native state, without
replaying old particles. Hidden views skip presentation; run/zone/world retirement,
disabling and reload clear active information through the existing lifecycle.

CI-only source-extracted contracts cover API mode handoff, rank acceptance and
retirement, invalid input, all tier palettes, higher-rank fallback, bounded/lazy
allocation, width/progress changes, full Endless rendering, glitter/foam opacity,
throttle, cleanup/reuse and Performance Mode. Source review and pinned formatting
are not in-game appearance, BLP decoding, live API delivery or FPS proof. Local
tests, standalone validation and addon/game execution were not run.

## Settings navigation — 2026-10-29

Default-off `bossShowHealthPercentage` and `guardianShowHealthPercentage` choices
reuse the existing white health labels. On appends a whole percentage, or shows
it alone when both numeric values are hidden. The shared formatter validates and
clamps full native values before current/maximum hiding or abbreviation. Off
skips ratio work and clears optional raw-pair cache fields; on reuses the latest
raw pair and rounded percentage, including when changing health rounds to the
same caption. Changed-only text writes and hidden-view guards remain intact.
Guardian percentage-only labels use the existing bounded measurement slots;
the optional longer caption receives its measured slot within the saved width,
without resizing the tracker or changing fonts/caps. Turning
all three text choices off skips health formatting/measurement and hides the
label while preserving the bar. There is no gameplay frame/region, asset, event,
updater, animation or SavedVariable. Normal and Performance Mode share this static
behavior. The two extra editor checkboxes use existing pooled static artwork.
CI-only fixtures cover defaults/transactions, independent visibility combinations,
full-number compatibility, zero/full/invalid health, rounded-cache reuse, hidden
recovery and unchanged native fill/loss state. They were not run locally.

The independent default-on `unitShortHealth`, `bossShortHealth` and
`guardianShortHealth` display choices use existing settings rows and transactions.
Off formats full whole-number health in the shared formatter; on retains K/M/B/T.
Native health, percentages, fills, input, fonts and selected geometry remain
unchanged in normal and Performance Mode. Latest-value label caches include the
format choice. Hidden unit/encounter views retain their existing early exits;
the guardian option invalidates only its bounded measurement slots and defers
remeasurement to the existing visible controller. Boss rows read health choices
once per visible pass. No event, updater, gameplay frame/region, asset or
SavedVariable is added. The three pooled editor checkboxes use existing static
artwork and stay hidden with their categories. CI-only health/guardian fixtures
cover full K/M/B/T values, cache transitions, defaults/normalization/transactions,
native fill preservation, unchanged writes and hidden recovery; no local tests
or addon/game execution were run.

`/sdui` uses the already-bundled plain Dragonflight metal frame, gold choices and
shared transaction.
Nine category buttons replace twenty; Damage meter has its own sidebar entry. Related controls share one native
ScrollFrame rather than thirteen separate option-page ScrollFrames. The editor
shell is prepared only on its first opening and reused. Each section retains
its original control owner. Its wrappers, heading and actual controls are built
only when that category is selected, then retained. Unvisited categories allocate
no native pages or controls; Profiles and the timer's font chooser are separately
deferred to their category/button. The hidden shell is completed before showing
the requested category, including direct Profiles entry. There is no background
preloading. There is no search input, query state, category
content title or repeated section title matching the sidebar category.
See [SETTINGS.md](SETTINGS.md).

Category changes perform bounded work over twenty section records. Settled
navigation returns before presentation writes. Scroll offsets remain
session-only. The sidebar uses its existing 232-unit maximum without measuring
all category captions. Footer and selected-page sizing use only the active
language, with successful ruler measurements cached by source caption,
language/font/size/flags/width/owning-frame effective scale. Missing metrics remain
retryable. This removes the previous first-click sweep of all fourteen catalogs
and construction/measurement of 71 generic settings (65 toggles and six numeric
controls). Those generic settings alone account for 308 texture regions and 160
FontStrings; they now allocate only on their owning category's visit. These are
source counts, not measured native load time or GPU costs. Hidden categories use
real ancestor hiding. Compact toggle rows
measure their active-language caption on opening, category selection and
language changes; successful unchanged geometry skips writes. Single-line
captions use 16 units and wrapped captions 28, followed by a three-unit gap and
32-unit description. Row heights are 64/76, replacing the previous 88. Paired
columns use their larger row height. Multi-option sections now pair numeric
steps as well as toggles; numeric titles use the same three-unit help gap and
72/84-unit rows with a separate 40-unit description area. Explicit enable
switches, mode selectors and single-option sections retain full-width rows.
The shared row layout reuses the existing controls, captions and separators,
adding no frame, drawing region or artwork. It flushes incomplete pairs before
full-width controls and includes the last odd row in the scroll extent.
Hidden categories defer later remeasurement;
missing metrics stay retryable. There is no new OnUpdate, event, animation,
idle worker. The separate retail-moving changes below add their two preferences
in the existing display table. Normal and Performance Mode share the static editor.

The first Layout refresh also limits new handle/grip preparation to two eligible
groups per render frame through the existing controller. Remaining groups set
the existing editor dirty flag so preparation continues on the next frame,
without waiting for the normal ten-Hz settled cadence. Closing, leaving Layout,
Cancel/world cleanup or moving-mode transitions stop inappropriate preparation;
reopening reuses completed groups and prepares only still-needed artwork. No
queue, worker, event, frame, asset or saved preference is added for scheduling.
The grid is updated after the selected editor page sets its overlay policy, so
direct entry to a non-Layout category does not prepare an unnecessary grid.

The full settings window enables HUD edit overlays only for Layout. Changing to
another category finishes active input, actually hides all handle/grip parents,
grid and snap-guide owner, and suspends their edit-bound sampling. The shared
draft and pending numeric input remain intact; returning to Layout restores the
existing pools. `/sdui lock` explicitly enables these overlays. This avoids drawing
every HUD selection while the user changes Combat, Profiles or other settings.

The coordinate form no longer installs its own OnUpdate. Visible, unfocused,
clean numeric fields reuse the existing ten-Hz Layout sample. Hidden form
listeners return before reading geometry. The existing viewport watcher still
checks client UI scale/size and resolves pending Layout placement while settings
are closed; it does no settled handle/grid/control painting in that state, and
returns immediately outside the world. Necessary live geometry tracking remains
bounded; this is not a claim that every addon controller stops when settings close.

The existing full editor now has the native name `SurvivorsDragonUiSettings` and
one `UISpecialFrames` registration. Its hide hook cancels the shared transaction
only while full editing is active, preserving mode switches and Confirm's saved
values. Numeric/profile Escape routes call the same Cancel owner; invalid text
cannot keep the full window open. The minimap click uses `layout.ToggleEdit`.
Its existing minimap-group edit callback raises the existing launcher above the
selection overlay and restores its current minimap strata/level on exit, skipping
unchanged native assignments. These event-driven changes add no frame, drawing
region, asset, keyboard-capture worker, event, updater, setting or saved state.

Display/SCT settings listeners defer hidden windows and unselected pages before
value formatting and drawing. Page Show catches up from current settings through
the existing listeners. Hidden Profiles also defers listing/sorting and row
painting until its existing Show callback. Dependency input/alpha and checkbox states skip unchanged
writes. Live run-caption updates first check that the lazy sample clock exists;
an open shell does not imply a prepared timer page. The font sample checks its
page, since its source FontString is deliberately hidden behind the rendered
parts; hidden categories do no sample font assignment,
measurement or painting. Visible samples cache face/size/outline/shadow/language,
retaining scale/readiness checks through the existing clock owner. No new updater
or gameplay preference is added. Failed native sample font assignments do not
advance the style cache and remain retryable. Locale binding and transaction cleanup retain
their necessary event-driven work; no idle settings animation is introduced.

Drawing and allocation are distinct from navigation work. Eleven fewer category
buttons remove eleven sets of twelve directly authored textures and two frames
per button. After every category has been visited, the navigator adds fifteen
one-texture subsection dividers/heading labels, twenty passive wrappers and one
shared scroll child. These are allocated on demand; first opening does not create
that complete set. The five sections
named identically to their sidebar category allocate no heading or divider.
Native scrollbar-template regions are not counted in those authored-texture
figures. Only selected sections are shown; closing hides the editor's complete
drawing tree. No GPU, FPS, draw-call or live appearance measurement is claimed.

Description-free checkbox captions use a centered LEFT anchor and middle text
alignment, so changing row heights does not separate text from its checkbox.
Performance Mode retains its wrapped caption box; Black shadow and Attach affixes
use the same 28-unit row. Subsection titles center within their existing width.
These anchor/justification changes add no frame or drawing region.

Layout's existing Hide frame/Show grid controls share one measured row, with no
new controls. Mode/language/Show transitions update widths and the existing
caption/description/divider bounds only when changed. The moving popup reuses the
same form, expands Hide frame when Show grid is hidden, and fits translated row
height through its existing clamped placement. No input or idle updater is added.

Each Layout/profile input now uses one inset fill and four thin neutral native
WHITE8X8 edges instead of the old fill and eight ornamental border pieces: five
regions rather than nine per input. The five fields remove twenty regions once
prepared. Anchors inherit resizing without a script; normal and Performance Mode
share the static skin. The unreferenced border BLP and its manifest entry are
removed, and the historical design producer uses retained metal artwork. This
is a source-level cost change, not measured GPU/FPS or retail pixel parity.

Shared action buttons now use three face textures and one native hover texture,
plus their existing caption. This replaces eleven textures (inset fill, eight
border pieces, selected fill and hover) and removes the extra caption frame per
button. Four textures and one caption belong to one native button. The shared
512-by-512 `editor/button.blp` keeps exact source RGBA pixels; the retained TGA is
an authoring input. Gold/grey normal, pressed and disabled states share this one
sheet. No per-state region pool, idle updater or animation is added.

Face UVs, cap dimensions, highlight locking, caption color and press offset skip
unchanged writes. Hover/press, native enable/disable calls, selected-choice changes
and explicit width/height changes are the only refresh sources. Hiding clears
input/hover state, while subsequent hidden changes defer painting until Show.
Normal and Performance Mode use the same static artwork. The CI-only editor
fixture covers press/leave/hide recovery, native disabled values, retained click
callbacks, selected choices, narrow/resized caps and unchanged/hidden work. It is
not run locally and establishes no native rendering or FPS result.

The CI-only editor fixture loads the production factory with explicit native
scrollbar and glyph-width boundaries. It checks category/heading visibility,
absence of a search input, original section ownership, retained state, scroll
offsets, reopen, stable allocation, compact/wrapped spacing, metric retry and
hidden/unchanged work. It was not run locally. The user's supplied screenshots
showed the former duplicated titles and excessive spacing; the correction has
not been launched or visually verified in the game.

## Retail-style moving view — 2026-10-29

The `/sdui lock` manager and selected-frame popup are lazy, static pools. They
share the existing controller, layout geometry, display draft and Confirm/Cancel
transaction. The same numeric form is reparented between the popup and full
settings; inputs, validation and pending geometry are not duplicated. Full-editor
corner/side grips prepare only when that mode first needs them and actually hide
and stop input in moving mode. Selection, focus, drag completion, mode changes,
manager close and world/logout/reload cleanup retire their input correctly.
Normal and Performance Mode use the same non-animated presentation.

Numeric-form transfers explicitly restore effective visibility and align existing
child frame levels above the new parent. The bounded child walk runs only during
form preparation or an explicit selection/mode transfer; unchanged layers skip
writes. Returning to settings lowers the same controls to that parent's layer.
This adds no frame, region, animation, event, updater, asset or saved state in
either mode. CI-only mocks model legacy reparenting's root-only level changes
and hidden visibility, without claiming live rendering verification.

Each edit handle now has nine authored selection regions, using real retail
blue/gold pixels and changed-only state UVs. Selection and snap bounds share a
16-unit minimum, so the fixed corners do not produce reversed edge spans on a
thin native strip; this does not resize the native HUD owner. The former outline used a native
backdrop plus twenty-four corner-mark textures and any side marks. No live
rendering/driver count is inferred from those source allocations. All handle
artwork is hidden outside editing. The new selection sheet is 256 by 64, with
lossless BLP encoding and a retained TGA/preparation receipt. The main/popup
panels reuse character/Chrome.blp rather than copying another sheet; the unused
old header asset is removed. Eight simple category rows each use two choice
textures instead of the former twelve textures and caption frame. The main
panel has eight border pieces and a fill, with no extra header texture.

The manager adds one panel, two toggles, a native slider and standard action
buttons. The selected-frame popup adds one panel and close button around the
existing numeric form. Their eight-piece borders retain native proportions;
only straight edges stretch. Native scrollbar/slider/backdrop internals and text
glyphs are not included in authored-region counts. The grid reuses its texture
pool and rebuilds only for viewport, scale, spacing or mode changes. Moving mode
supports 8–128 UI-unit spacing, default 32; finer spacing deliberately increases
visible grid lines while editing. Retired surplus lines hide and remain pooled.

Magnetism runs only on changed drag samples or refreshed target geometry, with
fresh final-release input. The existing ten-Hz target/bounds sampling is retained;
active pointer response keeps frame cadence. Candidate/results reuse the drag’s
bounded target records and one result pool. Two preview lines use one lazy,
mouse-transparent owner independent of the visible grid, so hiding the grid does
not suppress frame/screen snapping. Cleanup hides their actual regions. No new
OnUpdate, event, gameplay read, clock, history, SavedVariable or native preference
owner is added. `layoutSnapEnabled`/`layoutGridSpacing` use the existing display
normalizer, preview, Confirm/Cancel, profiles and resets.

CI-only fixtures load production magnetism, selection art and Layout/Display
against explicit native boundaries. They cover physical capture distances, grid
independence, corner/axis priority, pool reuse, manager/form focus, one-/ten-unit
nudging with numeric/native-chat focus ownership, free drag/release snapping, invalid input, Save/Cancel, mode switching,
retired handles and world cleanup. They were authored but not run locally. The
static preview and source review do not establish exact live retail parity,
draw calls, FPS, GPU time or native input behavior. Compatibility boundaries
and immutable source evidence are in [LAYOUT-HANDLES.md](LAYOUT-HANDLES.md).

## Target-of-target seams and name placement — 2026-10-29

The compact target-of-target reuses the prepared large health fill for both its
native StatusBar and existing loss texture. Native StatusBar UV ownership stays
intact. An eight-unit span beneath the portrait curve and a half-unit underlap
cover the reported joins; compensating label/name anchors keep the original
text column fixed. The background follows the same rectangle. Portraitless mode
removes the portrait span and compensates the existing closed border.

The clean party health-only crop set replaces the compact view's four strips
with fifteen, adding eleven allocated/visible texture regions in portrait mode.
They share the existing pet sheet, meet edge to edge and retain half-texel-safe
one-row tips, without overlapping shaded border alpha. The pool is built once
and reused; portraitless mode actually hides all fifteen strips and shows its
unchanged eight-piece closed border. No frame, FontString, asset, event, updater,
setting or SavedVariable is added. The unused shaded compact fill BLP is removed,
while its original TGA and native pet artwork are preserved.

The existing visible native refresh and display listener own the geometry.
Unchanged choices skip anchors, dimensions and visibility writes. Hidden previews
defer until the existing Show/value path; hidden native refreshes skip custom
name and health reads. The existing loss animation keeps its original normal-mode
fade and Performance Mode retirement. Static name/border/fill geometry is the
same in either mode. CI-only mocks cover those boundaries and pool reuse; local
work uses source/asset review and pinned formatting. These region counts and
bounded extra fill overdraw do not establish draw calls, GPU/FPS improvement or
live visual parity.

## Projection reuse and metadata preparation — 2026-10-28

The two changes in this pass share one commit. They reduce duplicate native
projection calls and spread optional spellbook preparation over existing frame
callbacks, while preserving current positions, native gameplay data and the
icons used to identify duplicate combat text.

### Waypoint projection cache

Player position and heading still update at the existing frame cadence. Only a
successful destination projection can be reused, and only within one synchronous
`navigation.WithSample` callback. Equal accepted world-coordinate tuples share a
result even when the HUD and a minimap pin hold different point records. Missing,
zero, failed or uncertain projections remain retryable. Calls outside a shared
sample keep their original fresh-read behavior.

The cache is limited to the currently accepted destination rosters supplied by
`navigation.SetPoints`; roster changes and navigation retirement release prior
entries. Its coordinate index and records are reused so a settled frame does
not allocate a new table per pin. Context, getter and map-selection changes
invalidate reuse, and the existing map-recovery path invalidates the sample
when it changes selection. No map movement or full-map listener is added.

The boundary is deliberately synchronous. Public benilla's
[`GetWorldLocMapPosition`](https://github.com/samwhosung/benilla/blob/cdebda36fb4c611ad0a8c35ddc45bf53e4ff1c60/crates/benilla-ui/src/script/worldmap.rs#L884-L911)
uses the selected continent/zone/direct-area and a host projector. The projector
can be replaced without changing the Lua function or exposing a revision.
Map-name equality therefore does not prove that a successful result can survive
into the next game frame. This implementation does not retain cross-frame
projection answers or introduce a periodic stale-result window.

For a destination consumed **k** times in a shared callback, successful native
projection calls fall from **k** to **one**. Distinct destinations still need
fresh projections each callback. Frame motion, interpolation, map browsing,
instance/world-coordinate fallback, minimap zoom, timers and native flag
ownership keep their existing behavior. This is a duplicate-call reduction,
not a lower projection or drawing rate.

### Chunked spellbook preparation

The existing SCT controller prepares native spellbook metadata in small chunks
rather than scanning the complete book from settings/mode readiness. Normal
preparation performs at most **four work steps per rendered callback**: a tab
header, a spell-name/texture pair or a final shape-validation step. It therefore
visits at most four spell slots; empty tabs cannot create an unbounded loop. It uses
one provisional generation and publishes only a completed result; partial data
cannot become authoritative for icon priority or exact duplicate grouping.
Native book/language/world changes and getter changes cancel stale preparation.
Incomplete warm metadata remains private and retries after one second. Optional
read failures back off without interrupting active text or queued-hit delivery.

An actual SCT or meter consumer still needs an authoritative current result.
If preparation has not produced a usable complete generation, that call discards
unfinished work and performs the existing fresh synchronous traversal. It does
not hold a hit, extend the grouping window, choose a weaker icon while warming
or shorten any animation. The fallback is necessary: this change does **not**
claim a strict four-slot bound for every possible icon lookup.

Preparation runs only through the existing eligible SCT controller. Custom SCT
also resolves icons with visual damage icons off because the resolved icon is
part of duplicate identity. Game/Off and hidden MSBT do no background preparation;
a visible meter can still resolve through the shared on-demand path. Completed
work becomes idle, and missing native metadata retains the existing bounded
retry behavior. No new updater, event, SavedVariable, learned registry, gameplay
history, drawing region or asset is added.

CI-only production mocks cover repeated projections, equal-coordinate records,
map/getter/roster/pass changes, failure/readiness recovery and fresh player
movement. Resolver mocks cover four-slot preparation, atomic publication,
invalidation, missing metadata, first-use completion and unchanged hit/icon
identity. They are authored for GitHub Actions and were not run locally. Local
work uses source review and pinned formatting only; no local tests, standalone
validation, addon/game execution or runtime probes ran. No FPS, CPU-time,
draw-call or visual-parity measurement is claimed.

## Optional Performance Mode — 2026-10-28

The checkbox above **Layout** uses normalized default-false `performanceMode`
in the existing display table. Missing and invalid values and both full resets
leave it off. Preview, Confirm, Cancel, world/logout/reload discard and profiles
use the shared display transaction. Individual effect, portrait and cooldown
choices are retained. The sidebar bounds translated category widths and reserves a wrapping row for
this caption above the category buttons.

| Owner                       | While Performance Mode is on                                                                                                                                                                                                                                                                                                                                                                 |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Chat                        | Keep native expiry at its original deadline with zero fade duration, so messages disappear instantly; scrolling back still holds lines. Snap reveal opacity and message-slide geometry, and clear active reveal/slide state. Native messages, history, links and input remain current.                                                                                                       |
| SCT                         | Sum same-attack outgoing damage within a fixed 300 ms window; normal mode keeps 75 ms exact-amount duplicate suppression. Preserve original per-hit matching, critical/source separation, motion, fade, full lifetime and the selected enemy/MSBT style.                                                                                                                                     |
| Unit frames                 | Hide player absorbs and player/target/target-of-target damage trails, reset trail baselines, and use the existing 2D still portraits. Party has no custom loss overlay. Hide combat/rest rim glows; keep a static resting symbol and a static low-health warning at the current health-derived strength.                                                                                     |
| Resources                   | Skip absorb snapshot/field work when Class resources is also off; keep native phase/receipt retirement and selected resource values.                                                                                                                                                                                                                                                         |
| Run timer                   | Keep native whole-second progress and current labels, static tier fill and informative skull/check markers. Skip flow, foam, sparkle, red-glint and skull-halo animation. The decorative pool grows lazily from 44 to at most 72 textures only if normal mode needs it, then retained for reuse. Required native phase, ownership, schedule and encounter work keeps its existing lifecycle. |
| Boss bars                   | Keep native fill and health text instant. Hide the Crimson echo loss strip, clear its baseline and active state, and skip effect time/geometry work. Rows first used in this mode do not prepare a loss texture.                                                                                                                                                                             |
| Cache tally                 | Refresh kills and gold numbers once every five UI seconds. Keep cache cost at its normal cadence. Clear the affordable-cache gold halo, rays and sparkles and detach its animation worker.                                                                                                                                                                                                   |
| XP                          | Snap the fill to received XP, clear gain/spark artwork and detach completed effect work. Existing deferred native reads remain.                                                                                                                                                                                                                                                              |
| Abilities and stored levels | Clear cooldown-number overlays and detach their timing worker. Suppress the seven native ability-ready flashes while retaining unfinished cooldown swipes. Hide level-button glow/highlight layers and detach the pulse worker; retain its static gold artwork, count and click behavior.                                                                                                    |
| Notifications and revive    | Loot cards and banners stay opaque until their original expiry; hidden notices still retire. Revive displays received fill/percentage directly without smoothing, fade, spark or pulsing crosses, using its existing ten-Hz state reader.                                                                                                                                                    |
| Action range                | Keep the current out-of-range warning static and remove any active native fade on a mode transition.                                                                                                                                                                                                                                                                                         |

Changing the mode clears or settles currently active effects immediately. Turning
it off restores the saved individual choices from current native state, without
replaying old XP or damage-loss effects. Hidden presentation stays deferred;
notification expiry, data gates, native HUD ownership and cleanup stay active.
Navigation direction, custom combat-text travel, meaningful native cooldown
swipes and jewelry cooldown progress retain their functional motion. This mode
does not change native gameplay values, incoming combat feedback or game effects.

Ability-ready suppression wraps only the seven existing cooldown Models'
`OnUpdateModel` handlers, using their native timing fields to hide at completion
before the finishing sequence starts. The original callbacks own every
unfinished swipe and all normal-mode behavior. The existing display listener
clears a flash already running on mode entry and caches the selected mode;
mode exit leaves retired flashes hidden until the next native timer rearms.
This remains independent of the retained Cooldown numbers choice. There are at
most seven wrappers and one existing-Model list, with no new frame, region,
asset, event, polling or updater. Native timer setup, animation-finished handling
and input remain unchanged. Unfinished native drawing stays present; hidden
completion Models skip their finishing animation. These are source-level
costs, not measured GPU/FPS results. See [ability cooldowns](ABILITY-COOLDOWNS.md)
for pinned native sources and CI-only coverage.

SCT caches the selected grouping window through the existing display listener.
Each new identified damage group receives its fixed inclusive deadline from
the first hit; joining hits never extend it. Performance Mode sums amounts for
the same identified attack: `20 + 100` displays `120`, and `100 + 100` displays
`200`. Normal mode retains exact-amount duplicate suppression, so those cases
remain separate `20`/`100` labels or one unchanged `100` respectively. Source,
pet, damage type, school, critical status and resolved icon remain separate
identity fields in both modes. Misses, aura notices and unidentified attacks
gain no new hold. The original 80 ms per-hit settling and
160 ms enemy-position fallback gates remain, so 300 ms limits admission rather
than total display latency. Both enemy and MSBT-style SCT use the selected
window; native incoming text remains independent.

An actual window change closes intake on every queued group and clears its
bucket index, while retaining all pending hits and active text. Existing
matching/settling finishes those groups without mixing new arrivals across
mode changes. Each group retains its creation mode's total or duplicate value.
Preview, Cancel, profiles and resets restore the selected window
through the shared lifecycle. Active animation and normal-mode equations are
unchanged; no per-hit setting lookup, frame, region, asset, event, updater or
SavedVariable is added. The total lives only on the existing pending group and
is passed to the renderer as an optional value override; original hit amounts,
color samples and loss consumption are untouched. A stored bucket key keeps
cleanup independent of the changing total, including when a newer group owns
the same attack. Unrepresentable numeric totals split into separate groups
instead of painting infinity. No per-hit display-copy table is allocated.
More same-attack arrivals can share a label, but visible
region savings depend on the hit stream; this is not measured FPS/GPU evidence.

Only the kills/gold number presentation uses the five-second cadence. The initial
valid display paints immediately, then changing packets, styles and widths
cannot refresh those numbers early. Cache cost, native phase/data validation,
HUD ownership and the shared reader keep their existing cadence. One unsaved
last-paint timestamp uses `GetTime()` for display scheduling only; it never
supplies gameplay time or counters. Between due samples, kills/gold skip number
formatting and text assignment, while the existing fit helper can refit the
retained text after a width/style change or retry missing metrics.

Actual Performance Mode transitions, tally retirement and existing zone/new-run
or native-clock rollback boundaries reset that presentation timestamp. Routine
attachment/style Hide/Show cycles do not reset it. Hidden tallies perform no
number formatting, text updates or cadence-clock read; required native data
validation and HUD ownership remain active. Elapsed hidden time naturally makes
the next visible sample due after five seconds. Disabling Performance Mode
restores current numbers through the next normal refresh, including preview,
Cancel, profiles and resets. There is no new event, updater, region, asset,
setting or SavedVariable. CI-only extracted production cases cover the exact
five-second boundary, unaffected normal/cache-cost refresh, mode changes,
hidden recovery, refitting and retirement; they are not local execution or
measured FPS evidence.

The new editor control uses one standard button, four existing editor textures
and one caption. No gameplay frame, drawing region, texture file, event, updater
or SavedVariable is added. Existing effect pools stay allocated after use for
reuse; suppressed textures are actually hidden, rather than left at zero alpha.
Static fills, borders, text, jewelry strips and other retained artwork still
have a persistent drawing cost. Skipped animation callbacks and hidden regions
are source-level evidence only; this work does not establish FPS/GPU gains or
live appearance. Local work uses source review and pinned formatting; mocked
coverage is authored for CI only and has not been run locally.

## Boss health loss — 2026-10-28

The selected **04 Crimson echo** adds at most one lazily prepared FillWhite
texture per pooled boss-bar row, including guardian rows in this view. Each
existing base pill retains its five regions; one extra region and its material/
UV state are visible only during an active normal-mode loss trail. The strip
uses the existing plain overlay's BACKGROUND layer, above the native health fill
and beneath bezel/text artwork. It covers only the recently lost section.
The preview's 0.74 brightness is baked into its crimson tint with opaque vertex
alpha, so native fill underneath cannot brighten one section and make it look
like a second trail. No backing region, mask, extra pass or native fill/UV
override is added.
Retired and completed effects are actually hidden, while their texture remains
available for reuse. Performance Mode prepares nothing and draws no loss strip.

Actual native fill and labels update immediately. A cosmetic 950 ms eased edge
uses one bounded trail per row, with rapid decreases coalesced from its current
edge. The existing HUD reader visits only active trails; idle effects return
before clock, geometry and paint work. Binding/tint/UV setup is cached, failed
bindings remain retryable during active effects, and geometry/visibility writes
skip unchanged values. Active geometry uses the existing `T.GetLocalSize`
helper's local edge extents, avoiding the client's already-scaled raw width for
this anchor-sized StatusBar. Those edge reads occur only for active loss strips;
idle, hidden and Performance Mode paths retain their early exits. Width and
UI/group scale changes keep the loss strip against the actual health boundary,
without another updater or an effect pool proportional to hit count.

Hide, retirement/reuse, identity/name/maximum changes, healing, reload and actual
Performance Mode changes clear effects and comparison baselines. Show and mode
exit accept current health without hidden-time replay. Existing run/world and
custom-view cleanup retain native health, debuffs and HUD ownership. The
production helper and its real row lifecycle have authored CI-only mocks; no
local tests or addon/game execution ran. Region counts and source review do not
establish live draw calls, GPU cost, FPS or visual parity. See
[RUN-TIMER.md](RUN-TIMER.md#boss-health-loss).

## Remaining frame work — 2026-10-28

A second pass reviews every frame path and the interval-gated controllers listed
in the cadence inventory. All fixes from this pass, including the requested
minimap clock option, belong to one commit. The reductions below supersede the
corresponding retained-work descriptions from the preceding pass. They do not
lower authored animation cadence or replace native gameplay time.

| Path                        | Before this pass                                                                                       | After this pass                                                                                                                                                                                                                                                                                                                                   |
| --------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Minimap local clock         | A visible frame callback and one date read every five seconds                                          | **Off by default**, with no clock callback or date reads. `/sdui` → Minimap → **Show clock** enables the original five-second reader only while visible. Off centers the existing zone button/text in the top panel; on restores its original left position beside the clock.                                                                     |
| SCT origin retirement       | Walk the complete live/recent catalog every frame                                                      | Skip that walk until the earliest real retirement is strictly older than the original 0.65 seconds, then stable-compact and retain the next deadline. Shown-plate sampling, matching, every original hit and active text motion retain frame cadence.                                                                                             |
| Nameplate raid-icon copying | Two native source texture reads per refresh and two UV reads when copying                              | One texture and one UV sample, retaining four/eight-coordinate forms, actual destination comparisons and retry.                                                                                                                                                                                                                                   |
| Final cooldown numbers      | All seven buttons reread every frame when any is in the positive final 200 ms                          | Only the **m** already-finishing buttons receive intervening frame reads. All seven retain an independent ten-Hz full pass and immediate cooldown/slot events. Store only final-window flags, never a private completion clock or cached native timing.                                                                                           |
| Boss skulls                 | Reconcile all historical marker slots and compute the pulse every frame, including when none is active | Reconcile on received state/native-limit changes. Only active marker references animate each frame. No marker time/cosine/pool traversal when none is active; unchanged alpha skips eight writes. Keep all eight glow copies and both cardinal/diagonal dimensions.                                                                               |
| Revive crosses              | Recompute all twelve clipping edges/positions and six pulse phases every active frame                  | Cache geometry until actual width or smoothed fill changes; calculate pulse only for crosses with visible parts. Visible pulse equations, frame smoothing/fade, native progress and cleanup remain.                                                                                                                                               |
| Loot cards                  | Traverse populated cards every frame, including a settled full-opacity hold                            | During a settled hold, wait until the existing fade, metadata-retry or expiry deadline before traversing cards. Sample root visibility once per callback, reuse one protected updater, and invalidate the wait on new cards/Show. Active fades keep frames; hidden cards still expire.                                                            |
| Player combat/rest rims     | Native eligibility and display reads every frame, even after inactive alpha reached zero               | Existing overlay frames observe combat/rest/world events plus Show/display recovery; eligibility reads happen on those transitions. Detach after the original inactive fade reaches zero. Active pulse and fade equations remain frame-driven; both rim variants must actually reach zero before detaching, including a failed round-alpha retry. |
| Settled Layout editor       | Viewport reads every frame while editing                                                               | Ten-Hz viewport/handle samples while settled; invalidation, initial/unresolved placement, active input and final release remain immediate/frame-driven. Carry accumulated elapsed into handle cadence.                                                                                                                                            |
| Active Layout input         | Repeated viewport samples in controller/cursor/move/resize/position helpers                            | Pass the current synchronous viewport tuple through the drag math. The base no-Shift move path uses one tuple instead of three while stationary or four while moving. Shift-snap candidates and centered-position reads share the tuple too. Final release samples current state afresh.                                                          |
| Waypoint HUD math           | Recompute bearing and settled angular interpolation every frame                                        | Recompute bearing only when its current native vector changes; completed interpolation reuses its current result while accepting the latest stamp. Native position/heading reads, projection, active interpolation, pause/regression handling and final samples retain cadence.                                                                   |
| Idle Chat native time       | `GetTime` every visible frame                                                                          | Read once per one-second geometry pass while settled, or lazily once per active animation/message-batching callback. Native alpha repair remains: its existing wrapper already compares actual alpha before a native write.                                                                                                                       |
| Shared tooltip owner        | Non-icon hovers can call native `IsOwned` once per registered/action/equipment icon each frame         | Verify a directly observed `SetOwner` owner once, then use Lua identity comparisons for registry lookup. Replaced or unobserved native owners retain the original discovery fallback. Cursor/visibility/scale/anchor checks remain frame-driven. Player styling shares one class-color sample instead of reading it twice.                        |
| Guardian health snapshots   | Read/validate native guardian health even with no living lair                                          | Defer that read until the first living lair; returning/empty-only snapshots do no health getter/list work. Living health remains current.                                                                                                                                                                                                         |
| Stored levels               | Out-of-world callback kept reaching the ten-Hz guard/update                                            | Detach on world leave/logout and rearm on entry; live ten-Hz native state and frame pulse remain.                                                                                                                                                                                                                                                 |
| Resources                   | Two player-visibility samples per native pass                                                          | One synchronous sample shared by data-read eligibility and presentation. Native events/ten-Hz fallback remain.                                                                                                                                                                                                                                    |

The minimap choice is normalized as default-false `minimapShowClock` in the
existing display table. Preview, Confirm-only saving, Cancel/world/logout/reload
discard, profiles and both full resets use the shared display lifecycle. No new
SavedVariable, gameplay clock, drawing region or asset is added. The caption and
hint have all fourteen source/runtime translations. Hiding or disabling the
clock clears only its owned hover and detaches its worker; Show with the option
on takes a fresh local-time sample.

Combat/rest event evidence comes from public benilla
[`field_watch.rs` at cdebda36](https://github.com/samwhosung/benilla/blob/cdebda36fb4c611ad0a8c35ddc45bf53e4ff1c60/crates/benilla-app/src/field_watch.rs#L808-L822)
for both combat edges and
[the resting edges](https://github.com/samwhosung/benilla/blob/cdebda36fb4c611ad0a8c35ddc45bf53e4ff1c60/crates/benilla-app/src/field_watch.rs#L935-L948).
The addon already uses the resting event. Public source is event-contract
evidence, not verification of the packaged executable's exact revision or live
performance.

### Reviewed paths that retain their cadence

- Visible run/boss readers retain raw native phase/time, rollback/boundary and
  HUD ownership checks every frame. The one-second fill and ten-Hz/deferred
  duration/schedule/encounter/debuff readers remain separate.
- Current waypoint/minimap position and heading projection remain frame-driven;
  guardian hover/timer checks remain ten Hz. The launcher samples only during
  active dragging, including a final release sample.
- Optional 3D portrait viewport/readiness and native model-paint handshakes remain
  frame-driven. They establish when the native model can replace its still image;
  native model animation is not controlled by addon polling.
- Active health-loss/XP effects and stored-level pulses retain their equations
  and frame cadence. Loss/XP callbacks already detach on completion. Chat keeps
  scroll/unread/native visibility repair; its native alpha setter was already
  guarded, so no second cache suppresses the required reveal animation.
- Native aura-anchor repair follows actual native callbacks. Icon traversal is
  already dirty-driven; active official timer and decimal hover reads stay ten
  Hz, with static/paused/hidden retirement.
- Timer flow/foam/red glints, cache affordability glow, jewelry cooldowns and
  banner fades remain capped at thirty Hz. Warning gradients and the resting
  flipbook remain twenty Hz only while active.
- Resources, pets, normal cooldowns, guardian tracker and encounter fallback reads
  remain ten Hz. Meter, jewelry metadata, loot service, banner readiness and
  tooltip styling remain five Hz; meter rates stay one Hz. Required phase,
  publication, native ownership and failed-read readiness work is retained.
- Jewelry cursor placement runs only for a visible hovered card. Its exact
  fourteen-strip icons, original rims and five-distinct-icon cost remain;
  this pass does not replace artwork or claim a smaller drawing budget.

CI-only production/extracted-source cases cover the new setting and lifecycle,
selective final cooldown sampling, strict SCT retirement, raid UV arity,
marker-state/halo transitions, loot hold and hidden expiry, Revive geometry,
player pulse events/failure recovery, Layout sample sharing/final release,
waypoint interpolation, lazy chat time and observed/replaced tooltip owners.
No local tests, standalone validation, addon/game execution or runtime probes
ran. Local evidence is source review and pinned formatting; active pixels still
render each game frame. These call/work reductions do not establish measured
CPU milliseconds, GPU draw calls, pixel parity, FPS gains or a resolved stutter.

## Cadence cleanup — 2026-10-28

The user requested a review of every frame-driven and periodic path, removing
unnecessary work without changing authored visuals or gameplay, with all fixes
from this pass in one commit. This supersedes the earlier one-finding-per-commit
instruction for this pass only. It does not authorize dropping combat hits,
guessing timers, weakening native ownership or changing animation equations.

Rates below describe Lua/native calls and presentation updates. Visible artwork
still participates in rendering every game frame. A per-frame callback follows
actual FPS rather than a fixed 60 Hz; interval gates can run less often under
load, and native events can request additional refreshes.

| Owner                     | Removed work and retained behavior                                                                                                                                                                                                                                                                                                                 |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Low-health warning        | Native player health/max-health and death/world events determine eligibility and current intensity. Healthy/dead/out-of-world states detach the updater instead of reading health twenty times per second. Only an active warning runs the original 50-ms pulse integration and four gradient writes; healing and retirement clear it immediately. |
| Layout                    | Settled gameplay samples viewport geometry at ten Hz instead of every rendered frame. Initial/unresolved placement, restoration, editing, drag/resize and final release samples retain frame/immediate behavior. Grid/handle/coordinate cadence and Shift alignment remain.                                                                        |
| Language discovery        | Successful discovery detaches its callback; existing world/zone events restart the original five-Hz readiness retry, and leave/logout detaches.                                                                                                                                                                                                    |
| Cooldown numbers          | Disabled, hidden and out-of-world states detach the existing callback. Show, display and world/native cooldown events rearm it. Enabled native timing retries remain at ten Hz, and the required final-200-ms seven-button frame sampling is unchanged.                                                                                            |
| Tooltip and target colors | Compare actual native colors before writing, after resolving the owning friendly/enemy target rule. Missing tooltip color getters keep the original write fallback. Native resets and failed assignments remain repairable. Hiding an already-hidden tooltip health bar skips the extra Hide.                                                      |
| Minimap clock             | Accumulated frame elapsed replaces a native GetTime call each frame. The existing five-second date check remains; Hide detaches and Show samples immediately. Unchanged minutes still skip text writes.                                                                                                                                            |
| Native aura layout        | Native enchant callbacks still repair actual BuffFrame/enchant anchors each time. Icon-slot traversal/reflow is dirty-driven by Show/Hide, received timer visibility, forced native positioning and editing. Forced geometry/font repair and hidden editor bounds remain.                                                                          |
| Received aura countdowns  | Cache each displayed ceil-rounded duration string, retain actual-text comparisons and failed-setter retries, and Show timer buttons only on transitions. Ten-Hz native timing and hovered decimal-duration tooltip updates remain.                                                                                                                 |
| Pet/summon/totem captions | Existing rows retain only their latest rounded countdown/count strings. Repeated tenth-second samples skip formatting/concatenation; hidden/missing/zero values and retirement remain distinct. Native feed validation, timing getters, roster counts and metadata/icon retries remain.                                                            |
| Run length and schedule   | Reuse duration/schedule validation within the existing ten-Hz/deferred-publication scope; phase changes, schedule/run boundaries and reload force fresh acceptance. Raw native run time, phase/rollback checks and native clock ownership retain frame cadence. Exact one-second fill progress and authored decoration remain.                     |
| Boss debuffs              | Remove per-frame getter/list/format traversal between normal refreshes. Existing ten-Hz/deferred-publication updates read current native remaining values; hovering performs a fresh native phase/effect read before opening and reflows changed height immediately. No countdown is extrapolated.                                                 |
| Guardian snapshots        | Sample native run time lazily once when the first returning lair needs it; no countdown-clock getter when none is returning. Native health and phase gates remain.                                                                                                                                                                                 |
| Guardian tracker          | Cache fallback unnamed-lair captions by received index/language, retaining actual label comparison and clearing on row retirement. Existing status/health caches and ten-Hz native snapshots remain.                                                                                                                                               |
| Stored levels             | Reuse the latest count string. An already-hidden native HUD needs one actual read instead of two; true visibility still uses setter/readback and retries. The original visible pulse remains per frame.                                                                                                                                            |
| SCT                       | Empty pending/group and active-text passes skip bookkeeping/compaction. Per-hit and frame native mode checks, required plate discovery, all matching, crit/refit/motion/fade and metadata readiness remain.                                                                                                                                        |
| Chat                      | A settled fade configuration/held state returns before repeated native visibility reads. Existing invalidation, selected-pane movement, native messages, geometry repair and failed-operation retries remain.                                                                                                                                      |

This pass adds no gameplay history, saved preference, drawing region or asset.
It reuses existing controllers; low-health eligibility adds native events to its
existing monitor. Source reductions are conditional call/work reductions, not
measured CPU milliseconds, GPU draw calls, FPS or proof that stutter is solved.

### Paths deliberately retained

Every path in the preceding cadence inventory was reviewed. The remaining work
has an active visual, native-data, ownership or readiness purpose:

| Area                                               | Cadence and reason retained                                                                                                                                                                                                                                                                                     |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SCT and backing nameplates                         | Render-frame discovery, shown origins, pending matching and active label motion/scale/fade. Enemy-only visibility hooks do not prove every native/friendly feed transition. Native CVar polling also catches unreported changes; weakening it could duplicate native/custom text. Empty work now exits earlier. |
| Waypoint HUD, minimap pins and legacy player arrow | Frame interpolation/projection uses current native position/heading. Shared synchronous sampling and changed-only anchors/UVs already avoid duplicate writes. The ten-Hz reader retains selection, receipt/phase retirement, flag ownership, hover tests and timer refreshes.                                   |
| Run timer and boss health                          | Visible readers retain frame phase/boundary/native-clock/ownership checks. Fill values use whole native seconds. Flow/foam/red glints remain capped at thirty Hz; active boss-skull halo geometry/alpha retain frame cadence. Encounter rows, counters and debuffs use ten-Hz/deferred native refreshes.        |
| Revive                                             | Ten-Hz receipt/phase/native ownership plus frame-driven active smoothing, fade, spark and six cross pulses. Caption/percentage/width caches from the prior pass remain.                                                                                                                                         |
| Stored levels/player effects                       | Ten-Hz stored-level validity/native ownership; visible level pulse and player combat/rest rim pulses retain frames. Resting flipbook remains twenty Hz. Completed inactive fades already stop writes.                                                                                                           |
| Optional 3D portraits                              | Frame/model-paint readiness preserves native camera/animation and still-image fallback. Removing the handshake could blank portraits on unsupported or not-yet-painted clients.                                                                                                                                 |
| Health-loss and XP effects                         | Frame updates exist only for active loss/gain/fade animation and detach on completion. Target health and XP reads are coalesced next-frame native/event work, not additional idle pollers.                                                                                                                      |
| Resources, absorbs and pets                        | Ten-Hz native phase/current values/readiness; power events and feed receipts can refresh earlier. Hidden views retain retirement while skipping presentation/timer-only reads. Unreported native changes and failed icon/style readiness still need fallback.                                                   |
| Native buffs/received timers                       | Native anchor repair follows native resets; timing uses the official getter at ten Hz while active. Hovered tooltips display tenths, so their required timing refresh stays. Paused/static/hidden timers already stop or defer work.                                                                            |
| Jewelry                                            | Five-Hz native equipment/cooldown and metadata readiness; active exact 64-cell cooldown painting at thirty Hz, cursor placement only while hovered. Fourteen-strip icon sampling and original rims remain.                                                                                                      |
| Loot                                               | Five-Hz service/readiness/native ownership and bounded queue delivery, populated frame fades/expiry, bounded five-Hz metadata retry. Hidden cards must expire and free capacity; empty cosmetic pools already detach.                                                                                           |
| Banners                                            | Five-Hz registration/ownership/readiness, next-frame pending native errors and original thirty-Hz fade/expiry/promotion. Settled disabled/faulted cleanup already detaches.                                                                                                                                     |
| Damage meter                                       | Five-Hz native publication/readiness/ownership and one-Hz rate presentation. Off detaches; hidden views skip rows/rates/icon work. Accepted counter processing already has publication caches.                                                                                                                  |
| Chat/tooltip/character                             | Visible chat slides/reveals and cursor tooltip placement need frames; chat geometry repair stays one Hz and tooltip styling five Hz. Character stats already coalesce to a next-frame flush only after relevant events while open. Capture/Copy remain opt-in/event/user driven.                                |
| Editing and diagnostics                            | Active Layout/minimap-launcher drag stays per frame with final sample. Settled editor/coordinates remain ten Hz; fstack stays five Hz only while explicitly enabled.                                                                                                                                            |
| Other modules/native work                          | Menu, font resolution, display/profile controls, static catalogs and bootstrap are event/initialization driven. Omitted cast/bag/micro frames remain suppressed. Native action swipes/usability, model animation, incoming combat text and range fade-manager animation retain their engine schedules.          |

Independent source reviews cover lifecycle, hidden recovery, native reset/color
ownership, getter failures, Lua 5.0 remembered queue sizes and new seam/mock
dependencies. CI-only production/extracted-source fixtures cover these changes;
none was executed locally. Only source review and pinned formatting ran locally.

## Movement stutter investigation — 2026-10-28

**Latest measured outcome:** the longer normal run still stutters and worsens
with encounter activity. Median logged mean/p95 windows rise from 22.29/42.34 ms
at native journal seconds 120–240 to 29.76/58.37 ms at 480–600; GPU UI remains
about 0.08 ms. These intervals precede the authorized macOS stack samples.
The earlier short complete-configuration capture showed partial early-run
recovery (17.62/25.49 ms versus 19.89/33.50 ms), which does not establish a
mid/late-run fix. Addon-disabled controls were 16.67/about 17–18 ms. The earlier
17.53 ms result was specifically with SCT Off. Individual changes remain
untimed, and the MSBT-only optimization is inactive in over-enemy style.

The user repeated four fresh runs in one client session, **OFF / ON / OFF / ON**,
with ten seconds standing still followed by twenty seconds circling after
loading settled. The installed Diagnostics journal, last written at 13:53:20
GMT, contains the complete recording at `t=1.2–243.0` (physical CSV lines
75959–76188). The file appends older recordings. These mode labels come from the
user's sequence; the CSV records neither addon enablement nor loaded revision.

Identify each first movement by at least 0.5 native coordinate units of
horizontal displacement. Use the preceding ten seconds for standing and the
following twenty seconds for movement, excluding loading and inactive-world
coordinates. Each standing interval contains nine logged windows and each
moving interval twenty. Results below are medians of the journal's one-second
`mean_ms` and `p95_ms` windows, not reconstructed frame-level percentiles.

| Run   | First movement (`t`) | Still mean (ms) | Moving mean (ms) | Moving window p95 (ms) |
| ----- | -------------------- | --------------- | ---------------- | ---------------------- |
| OFF 1 | 39.8                 | 16.67           | 16.67            | 17.89                  |
| ON 1  | 93.6                 | 16.69           | 19.13            | 30.52                  |
| OFF 2 | 155.8                | 16.67           | 16.67            | 17.27                  |
| ON 2  | 213.5                | 16.66           | 19.97            | 31.72                  |

This reproduces a movement/active-encounter slowdown in both addon-on runs.
Median moving `gpu_ui` stays about 0.08–0.09 ms in every run; median moving
whole-process `cpu_ms` is about 31 ms off and 39–41 ms on. This supports a
CPU-side investigation, including native UI work. The journal cannot isolate
Lua, native layout, world work or scheduling. Its CPU clocks are not wall frame
times, and residency counts are not draw calls. The earlier uncontrolled
`t=1.1–515.1` recording was inconclusive and is superseded by this comparison.

Movement coincides with `streamed` rising from one native entity to about eighty
in all four runs, so it also starts encounter/publication work. The final ON
tail stays slower after the player stops while those entities remain. Movement
is the observed activation boundary, not an established sole continuing cause.
Encounter populations and starting resident entity counts are still not exact
matches between runs.

The persisted configuration inspected after the capture selects Custom SCT,
default over-enemy style and V-off enemy plates; the meter is default-off. In
that configuration `UsesPlateOrigins` keeps the native backing nameplate feed
enabled despite hiding its pixels. The public engine's disabled-plate gate skips
native unit projection, sorting and overlap work; hiding drawing layers does
not skip that CPU path. SDUI also samples shown origins every frame. This is a
source-supported suspect, not per-subsystem timing or proof of the installed
engine's exact revision. The existing MSBT-style option releases that forced
feed with V off while preserving custom damage text, allowing a narrower user
comparison without changing native preferences or adding profiling hooks.
That comparison still retains the controller's per-frame child-count discovery
check and ordinary visible HUD work; it does not disable the whole module.

The subsequent user comparison, written at 14:08:39 GMT, records
`t=1.2–225.4` (CSV lines 76189–76397). Persisted settings confirm Custom SCT,
MSBT on, both native plate toggles off, meter off and damage icons off. The
preview/Confirm source path clears old SCT state and releases the backing plate
feed; no other SDUI module requests that feed. This comparison does not show a
clear improvement, weakening forced enemy tracking as a sufficient explanation.

The settings period is stationary. The last ten seconds before the first step
(`161.5–170.5`) have median logged mean/p95 windows of 16.72/19.26 ms. A first
step at `171.5` activates the encounter, followed by unchanged player and focus
coordinates from `175.5–203.4`; that active stationary stretch still has median
windows of 21.88/43.00 ms. Sustained circle-like changes occur only at
`204.4–221.3` (seventeen logged windows), with medians of 24.49/39.70 ms. Do not
label the first twenty or thirty seconds after the initial step as continuous
circling. Encounter populations grow beyond the earlier four-run windows, so
the trials do not establish a causal performance difference between SCT styles.
Recorded GPU UI time remains around 0.08 ms during the active portions.

The End Run boundary has only one non-exit window (`224.4`, mean 17.81 ms), with
streamed entities dropping to zero and resident entities falling from roughly
35,000 to 995. It cannot establish a settled post-run improvement or identify an
addon component; ending the run also removes native encounter/world work.
MSBT retains parsing, queues, text animation and crit-scale changes. An existing
Combat text **Off** comparison, with the other choices held fixed, can separate
that remaining custom SCT path from other active HUD/controller costs without
introducing runtime profiling hooks. The journal does not time individual
callbacks, and no specific cause or measured fix has been established.

The next user recording, written at 14:18:27 GMT, has Custom SCT **Off**, MSBT
retained and both native plate toggles off (`t=1.7–93.6`, CSV lines 76398–76485).
It contains a clear first movement at `44.0`, circling through `66.2` and a
stationary active encounter at `67.2–92.5`. Using the same preceding-ten and
following-twenty-second rule gives median logged mean/p95 windows of
16.67/17.35 ms before movement and 19.80/35.82 ms during movement. The subsequent
stationary encounter has medians of 18.32/28.87 ms. Moving whole-process CPU has
a median of 38.97 ms and GPU UI remains about 0.08 ms. Resident entity/material
counts resemble the earlier full-addon-OFF cases, strengthening the residual
SDUI work lead without proving exact scene equivalence.

Custom SCT parsing, animated text and forced enemy tracking are therefore not
necessary to reproduce this slowdown. Their individual costs remain unmeasured;
do not attribute the current issue to crit scaling from these trials. The next
prepared comparison changes only `customRunTimer` to false, retaining SCT Off
and the other display choices. The existing native clock handoff separates the
custom timer's animation/caption/controller work from the remaining addon.

The timer-off comparison, written at 14:24:57 GMT, keeps SCT Off and the other
choices fixed while setting `customRunTimer=false` (`t=1.1–77.2`, CSV lines
76486–76560). First movement is `33.7`, continuous circles extend through `64.0`
and stationary active-encounter samples cover `65.0–75.1`. In the first twenty
moving windows, median logged mean/p95 improves from 19.80/35.82 ms with the
timer on to 16.68/17.39 ms with it off. Mean window time improves from 20.38 to
17.13 ms, and median whole-process CPU from 38.97 to 29.34 ms. Post-movement
median mean/p95 windows are 16.70/18.55 ms. GPU UI remains about 0.08 ms. Native
entity medians are slightly higher in the timer-off moving interval, not lower.

This is strong localization to the custom timer path, returning near the
full-addon-OFF frame windows in one comparison. It is not a repeated causal
proof of any particular Lua call or renderer mechanism. The timer switch also
changes native clock ownership and reader cadence, so attribution must retain
those boundaries rather than naming the foam alone.

The inspected public renderer has two relevant CPU mechanisms:

- Cropped UV bounds participate in the material identity. Each previously
  unseen four-float clamp key allocates material state; the cache clears above
  256 keys. Timer foam/ripples and the native StatusBar's smooth fill crop change
  those bounds while advancing. See the
  [material key and cache](https://github.com/samwhosung/benilla/blob/cb949ba1a51011061667a078ed7812ab954ce4a4/crates/benilla-app/src/ui_pass.rs#L1004-L1093).
- Changing crop or dimensions defeats the retained translation shortcut and
  rewrites mesh attributes. The source explicitly notes that modifying one UI
  mesh activates asset-change probes across world `Mesh3d` rows. See the
  [mesh rewrite path](https://github.com/samwhosung/benilla/blob/cb949ba1a51011061667a078ed7812ab954ce4a4/crates/benilla-app/src/ui_pass.rs#L1131-L1183).

These are plausible explanations for CPU-side cost with low recorded GPU UI
time, not measured attribution in the packaged client. The journal's resident
entity count is not a `Mesh3d` row count. Its `mats` column counts world-model
materials, not these UI clamp-cache entries; its large cross-run change does
not measure UI material churn. The packaged renderer revision remains unknown.

An exact-asset escape was inspected and rejected: both shipped 256-by-16 fills
vary horizontally on every row. Decoded runtime BLP pixels match the retained
TGAs, so a one-column replacement would remove authored detail. No replacement
asset was prepared. Eight-corner UVs, repeat flags and native clipping have no
verified equivalent escape from these material/mesh paths. Do not change
sampling, cadence, native StatusBar UV ownership or independent effects to
claim an addon-side fix. Narrowing UI material/mesh invalidation is an engine
lead; it does not establish a shippable fix for this installed client.

After that recording, the two bounded timer source changes below were applied
locally and source-reviewed, without running the CI-only mocks. The next
prepared comparison reenables the custom timer while disabling its existing
Regular/Endless word, current, maximum and boss-countdown caption options. SCT
remains Off. This retains the fill, foam, marker animation, native values and
cadence while removing timer glyph presentation. It is a diagnostic settings
change; neither those source changes nor the animated-artwork attribution has
a subsequent measured result yet.

The resulting captions-off recording, written at 14:50:00 GMT, spans
`t=1.1–93.9` (CSV lines 76561–76651). It confirms timer On, SCT Off and all
caption components disabled. Movement starts at `40.2` and continues through
`72.6`, followed by stationary active-encounter samples at `73.6–92.9`. In the
first twenty moving windows, median mean/p95 is 17.73/25.44 ms and median
whole-process CPU 33.73 ms. This is partial recovery against the earlier
captions-on result (19.80/35.82 ms, CPU 38.97 ms), but remains above timer Off
(16.68/17.39 ms, CPU 29.34 ms). Entity counts closely match timer Off and GPU UI
stays about 0.08 ms. Post-movement median mean/p95 is 17.47/23.31 ms.

This comparison also introduces the two bounded timer source changes, so it
cannot assign the improvement to hiding captions alone or quantify either
source fix separately. The missing run-time text is intentional in this trial.
The prepared follow-up restores the original Regular/Endless caption choices
with the same updated code, timer On and SCT Off; no further runtime edits are
introduced between those two captures.

The user's subsequent text-restored attempt exposed a regression in that local
caption-cache change: the formatting table reused `runClock.caption`, which
already holds the optional font-localization caption. Non-default font setup
therefore passed a table to `string.find` at `ApplyFont`, interrupting custom
timer setup/update and leaving the native clock and missing custom boss markers.
That attempt is invalid as a custom-timer performance comparison. Post-change
comparisons remain provisional until the complete custom view is verified;
they do not establish a successful optimization.

The formatting state now uses independent `runClock.captionCache`; the original
string/nil `caption` metadata stays exclusively with font setup. The CI-only
fixture now extracts the actual `NewClockLabel` constructor, checks both font
captions survive formatting, and exercises Skurri styling after cache creation.
Source review and pinned formatting were completed; no local test or game run
was performed. Custom timer/captions remain enabled for a visual recovery check
before collecting another performance comparison.

After the field-collision repair, the user explicitly confirmed that the custom
timer, time text and boss markers were restored with no Lua errors. The valid
recording written at 15:02:15 GMT spans `t=1.3–86.0` (CSV lines 76733–76814).
The preceding `t=1.2–83.9` attempt (lines 76652–76732) is the failed display
capture and is excluded. The captions-off capture also remains unsuitable for
attributing either optimization independently.

In the valid restored-view run, first movement is `40.0` and circling continues
through `72.3`, followed by stationary samples at `73.3–84.4`. The same first
twenty-window comparison has median mean/p95 of 17.53/24.44 ms and median
whole-process CPU 34.09 ms. This improves against the earlier valid timer-on
result of 19.80/35.82 ms and CPU 38.97 ms, while retaining a gap from timer Off
at 16.68/17.39 ms and CPU 29.34 ms. Pre-movement median mean is 16.67 ms and
post-movement 17.72 ms. Entity counts are comparable; GPU UI remains about
0.08 ms. This supports partial recovery with the combined local changes, not
individual component timing or elimination of the reported stutter.

The diagnostic settings are then retired: the original Custom SCT mode and
over-enemy style are restored, with the custom timer and its original caption
choices enabled. Native enemy/friendly plate preferences remain off and the
meter remains at its original disabled value. No new runtime edits separate the
restored-timer capture from the pending complete-configuration observation.
The complete configuration has not yet been measured with these changes.

The complete-configuration recording written at 15:12:56 GMT spans
`t=1.1–84.1` (CSV lines 76815–76895), with Custom SCT, over-enemy style and the
custom timer/captions enabled. First movement is `46.2`, circling continues
through `68.8`, and stationary encounter samples cover `69.8–82.0`. The first
twenty moving windows have median mean/p95 of 19.89/33.50 ms and whole-process
CPU 39.23 ms. Those results remain in the initial full-addon-ON range
(19.13–19.97 ms, p95 30.52–31.72 ms), rather than returning to full-addon-OFF
(16.67 ms, p95 17.27–17.89 ms). Post-movement median mean remains 18.20 ms.
This is not a successful normal-configuration stutter fix.

Entity and world-material counts closely match the first full-addon-OFF run,
while recorded GPU UI stays about 0.08 ms. The short native Mac trials support
continued CPU/native-work investigation. They do not cover browser execution,
late-run populations or an enabled damage meter, and they cannot attribute the
cost of SCT independently from native backing-plate work.

### Released-addon and browser reports

The user separately relayed browser mid/late-run stutter as mobs/damage grow,
and reports from two PC players that the game is smoother without the addon.
The verified latest public release at this point is
[3.2.57](https://github.com/migwynkriid13/SurvivorsDragonUi/releases/tag/build-b70cbf444e7ade2aaed7d1faf415fbe0746df021),
published at 12:14:01 UTC and pinned to
`b70cbf444e7ade2aaed7d1faf415fbe0746df021`. It does not contain the original
performance PR or these local follow-ups. The local caption-cache regression
therefore cannot explain those released-addon reports. These are qualitative
reports, not instrumented browser or late-run measurements.

Source inspection at that release identifies retained-pool plate scanning,
per-hit all-origin matching, distinct-name spellbook rebuilding, uncached final
source resolution, parser descriptors and recurring complete meter processing.
The original performance branch already reduces several of those paths; the
additional indexed matching, stable retirement and stream queue work below
address further source-level scaling. Icon resolution can still be required
with icons hidden because exact duplicate identity includes its received art.
Ambiguity still considers every eligible same-name candidate.

An enabled meter processes complete source lists independently of its one-to-ten
visible rows. Its rolling history already uses bounded separate time/value
arrays and lossless flat-interval compression; 604 pairs per series is a
worst-case capacity for changing counters, not an unchanged-plateau leak. The
default-off meter detaches collection and cannot explain this default-off
capture. Neither native portraits nor the SCT pool are established lifetime
leaks: portrait images are path-cached and text pools track peak concurrency,
with retired labels cleared and hidden.

The inspected native and browser forks also share a world-size-dependent CPU
path through Bevy 0.18.1. Updating an existing animated UI mesh queues a
[modified asset event](https://github.com/bevyengine/bevy/blob/v0.18.1/crates/bevy_asset/src/assets.rs#L382-L390).
If any mesh changed, even a 2D UI mesh, Bevy's
[3D mesh change tracker](https://github.com/bevyengine/bevy/blob/v0.18.1/crates/bevy_mesh/src/components.rs#L127-L145)
probes every `Mesh3d` handle. Both inspected forks retain this path without a
browser guard. This establishes a plausible coupling between animated UI and
larger world populations, not its measured contribution or the deployed
clients' exact engine revisions. Browser event-loop differences alone do not
prove an additional browser-specific defect.

### Short capture after additional scaling changes

The next completed recording, written at 15:45:23 GMT, spans `t=1.1–83.1`
(CSV lines 76896–76975). The user explicitly confirmed that outgoing custom
damage text, the custom timer/text and boss markers all worked without Lua
errors. Saved settings retain Custom SCT, over-enemy style, custom timer and
captions enabled; the meter remains off.

Movement starts at `22.5`. The first twenty moving windows have median
mean/p95 of 17.62/25.49 ms and whole-process CPU 34.96 ms, compared with
19.89/33.50 ms and CPU 39.23 ms in the preceding complete-configuration trial.
Counted entity medians are higher, not lower, and GPU UI remains about 0.08 ms.
This supports partial early-run recovery with the additional origin lookup and
retirement changes, without assigning a per-function saving or eliminating the
gap from addon Off. The MSBT-only change cannot explain this trial's result.

Only two settled samples precede movement; a forced ten-second pre-window
would include loading spikes. The final stationary tail has five samples and
the entire recording includes only about one minute after first movement.
It does not establish the requested mid/late-run behavior. A subsequent
recording began appending during analysis; its incomplete loading/menu rows
are excluded from the completed trial above. No further runtime or settings
edits separate those recordings.

For the next user-requested longer run, the saved setup was inspected with the
game closed: Custom SCT in over-enemy style, damage icons on, custom timer and
original captions on, custom boss bars on, meter off, visible enemy/friendly
plates off and FPS journaling on. These values already matched the chosen
setup, so no redundant preference writes were needed. Damage icons differ from
the earlier icon-off controls; this is a longer workload observation, not a
directly matched icon-off performance comparison. No runtime source changes
were made while preparing it.

### Longer normal run and macOS sampling

Two short intervening recordings span CSV lines 76976–76987 (`t=1.3–16.2`)
and 76988–77027 (`t=1.1–44.6`). The longer recording starts at physical line
77028, `t=1.1`; the read-only snapshot at 16:18:22 GMT extends through line
78240, `t=1241.9`. Do not combine these launches into one time coordinate.
The user reported pronounced stutter during the longer run. This is the
icon-enabled normal configuration described above, with the meter off.

| Native journal seconds | Windows | Median mean (ms) | Median window p95 (ms) | Median whole-process CPU (ms) | Median GPU UI (ms) | Median streamed entities |
| ---------------------- | ------- | ---------------- | ---------------------- | ----------------------------- | ------------------ | ------------------------ |
| 120–240                | 118     | 22.29            | 42.34                  | 42.98                         | 0.08               | 105                      |
| 240–360                | 118     | 25.88            | 48.42                  | 49.75                         | 0.08               | 118                      |
| 360–480                | 117     | 28.25            | 53.92                  | 54.59                         | 0.08               | 135                      |
| 480–600                | 117     | 29.76            | 58.37                  | 56.97                         | 0.08               | 153                      |

These fixed intervals exclude startup and precede both stack samples. They
show worsening in this run alongside increased native streamed populations;
they do not separate addon work from native combat/world work or establish
SCT, cooldowns or icons as the cause. Median total GPU time stays about
1.00–1.05 ms. CPU-side preparation and frame pacing remain the stronger lead,
without ruling out work outside the recorded GPU spans. Resident entity
counts are not enemy counts or `Mesh3d` row counts.

The user explicitly authorized five seconds of read-only OS stack sampling.
Two five-second samples of the running game were taken at 16:08:16 and
16:13:43 GMT, with 10 ms and 20 ms intervals respectively. The second retried
the first oversized output with in-memory reduction. Both sent the report to
`/dev/stdout`; no report file or runtime Lua hook was created. The host reports
Wine 11.13 running the Windows executable through x86-64 Rosetta translation.
The game main-thread frames are predominantly unnamed Rosetta JIT/unknown
addresses, so these samples do not attribute cost to Lua, cooldowns, SCT or a
specific renderer function. Recursive Wine dispatcher counts are not usable
subsystem CPU percentages. Sampling can perturb frame pacing; later spikes
must not be presented as an uncontaminated before/after measurement.

The user declined temporary callback timing probes. Investigation therefore
remains source-only apart from the completed OS samples and read-only journal
inspection. No timing command, saved diagnostic state or background updater
was added.

### One-second run progress — user-requested cadence change

The progress StatusBar now writes whole native run seconds instead of a new
fractional value every rendered frame. At a steady 60 FPS this reduces normal
advancing fill-value writes from about 60 per second to one, without changing
the reader or inventing a gameplay clock. Native pauses stop the sampled native
coordinate. Initial/current-state recovery, native time corrections and
duration changes remain immediate; a reached limit uses its exact native value,
including fractional maxima. Hidden views still skip fill painting.

The same stepped value bounds the existing flow and foam so their fill edge
cannot continue crawling between one-second steps. Their temporal phase and
30-Hz cap remain, as do the original caption, schedule and marker inputs.
Moving textures, foam, glows and the native renderer's persistent drawing costs
remain; this does not make the whole timer render only once per second.
The source reduction is not a measured FPS or stutter result. Local work uses
source review and pinned formatting, with coverage authored for CI only.

### Other source follow-ups

The following changes remove specific avoidable work:

- Moving minimap pins replace their existing CENTER anchor directly, removing
  one ClearAllPoints call per moved pin. The legacy player-arrow overlay
  separates size from heading changes: a fixed-size turn skips two size writes
  and ClearAllPoints, while size-only changes skip unchanged rotation UVs.
  Settled overlay visibility also skips writes. Positions, rotation equations,
  update cadence and native model ownership remain unchanged.
- Minimap size is shared lazily across pin, hover and legacy-arrow work within
  each existing synchronous callback. Invalid or insufficient bounds remain
  retryable in that callback; later callbacks sample afresh. This avoids repeated
  native geometry reads after pin writes, which can otherwise drain pending
  native layout work on the inspected engine. Settled native flag suppression
  uses its first actual false read and retains readback after setter calls.
  CI-only native-boundary mocks cover size sharing and readiness recovery.
- Each cooldown-number overlay retains only its latest rounded caption value,
  unit, language and text. Unchanged display buckets skip localization and string
  joining while all seven native timing reads, immediate event passes and the
  required final-200-ms frame cadence remain. Actual text/color/visibility
  comparisons still repair native changes and retry failed setters. The existing
  hide/disable/world cleanup clears these seven bounded caption caches; no
  cooldown start, duration or remaining-time history is retained. CI-only
  production-controller mocks cover reuse, same-value unit changes, language,
  setter failure and the exact positive final-zero threshold. This does not
  reduce native-swipe work or establish measured stutter recovery.
- Range-indicator passes sample target existence/hostility lazily once across
  visible buttons and read each button's visibility once. Seven visible buttons
  therefore use at most one UnitExists and one UnitCanAttack call instead of
  seven each, while their seven independent IsActionInRange results remain.
  The two scalar results live only within that synchronous pass; later events
  and ten-Hz ticks read fresh state. Hidden buttons retain cleanup and skip
  artwork allocation and target/range reads. CI-only production mocks cover
  missing/friendly/hostile transitions, independent ranges and hidden recovery.
- Native chat panes retain their subscriptions, messages, unread tracking and
  level/stat intake. Only selected visible chat activity starts the existing
  0.35-second slide. Deselected panes expire any outstanding slide deadline
  without animated anchors; selected slides retain their final settled sample.
  Selection, native-event and one-second geometry repair remain available.
- Target changes retain synchronous nameplate refresh and target-aura
  invalidation, but use count-based incremental discovery. An unchanged native
  child count skips full WorldFrame enumeration and recursive V/filter remasking.
  Newly appended native slots remain discoverable immediately; OnShow, mode and
  world transitions retain required forced checks. A CI-only production mock
  covers unchanged and newly allocated rosters; it was not run locally.
- Matching indexes references to the existing live/recent origins by exact
  received name. Uncached hits visit only their matching-name array, preserving
  relative creation order, centroid arithmetic, health-loss consumption,
  ambiguity and the original timing rules. Identical-name packs still inspect
  every eligible candidate; no hit, origin or lifetime is capped.
- Within one pending-hit matching pass, identical queries can reuse the same
  unresolved result, exact origin or ambiguous centroid. The key compares the
  exact received target name, kind, amount and fallback eligibility at the same
  sampled time. Any effective health-loss consumption invalidates prior results;
  every matched original hit still calls UseLoss. Only the latest tuple per name
  occupies one of at most 64 reusable records, and overflow uses the unchanged
  resolver. References clear before presentation, between passes and on display
  retirement. This bounds the optimization's scratch space without capping
  combat intake, names, origins or text. Repeated unchanged ambiguous queries
  can share one candidate traversal; distinct queries and changing loss evidence
  retain their required scans. No measured saving is established yet.
- Recent-origin retirement stable-compacts the master array and each affected
  name array once. This avoids repeated survivor shifts during mixed bulk
  expiry, preserving relative order, Lua 5.0 remembered lengths and the strict
  greater-than-0.65-second boundary. The index adds references, not duplicate
  origin records or additional gameplay history, and clears on the existing
  style/mode/world lifecycle.
- MSBT arrivals increment their existing duplicate group directly and retain
  the maximum member receipt. The original subtraction-based 80 ms age gate
  and inclusive intake window (75 ms normally, 300 ms in Performance Mode)
  determine emission, including out-of-order
  receipts and floating-point boundaries. Stream mode no longer allocates or
  revisits a pending record for each original hit. Every original color sample
  and icon identity still runs; first-hit values/style and default over-enemy
  matching/fallback remain. This has no subsequent live performance result.
- Normal-hit color keys concatenate their original four string fields and
  separators directly, avoiding one temporary four-entry table per qualifying
  original hit. Every original sample still enters the same eight-sample color
  history in receipt order, including visually collapsed duplicates. Parser,
  history and default pending records still allocate; this is not an
  allocation-free SCT path.
- Shared local-size reads call GetWidth/GetHeight only when their corresponding
  edge extent is unresolved. Resolved rectangles skip two unnecessary native
  geometry reads, retaining independent fallback for either axis.
- Blue foam shares one current authored bar-height sample across its sixteen
  pieces per existing paint pass. This removes fifteen duplicate native calls
  without changing clipping, UVs or temporal equations. The inspected getter
  reads an authored height directly; this is not avoided layout resolution.
- Timer captions retain rounded native inputs separately from the final two
  display strings. One bounded cache follows mode, effective options and
  language; unchanged displayed values reuse formatting and disabled components
  skip it. Previews rebuild immediately from retained inputs. Per-frame scale
  checks and unavailable-font-metric retries remain in the existing presentation
  helper. Retirement invalidates active data once, retaining settled empty state
  on repeated clears. CI-only extracted-production mocks cover both timer
  changes; neither reduction establishes a measured fix for the timer slowdown.
- Revive retains one latest subject/direction and language caption, plus its
  latest displayed percentage string. Hidden presentation defers caption
  formatting; visible unchanged captions/percentages skip localization and
  string construction while actual text comparisons and failed-write retries
  remain. Clear invalidates the bounded caches. The native progress source,
  smoothing and percentage-step equations, fade and cross pulses are unchanged.
- A revive animation callback shares one current root-width sample between
  dirty fill/spark painting and its existing cross loop, removing one duplicate
  native width read on dirty frames. Standalone paints read current width.
- Guardian tracker rows cache their latest received key/status, rounded native
  respawn second, language and status text. Unchanged tenth-second samples skip
  clock/status formatting without changing native time or static captions.
  Health presentation, row retirement, visibility, language and relevant options
  invalidate the cache; actual text comparisons retain retries and restoration.
  Boss and guardian health fills and health-caption caches already skip
  unchanged work. These views do not allocate the timer's foam/flow effects;
  the shared native rendering costs of changing fills remain unresolved.

These edits reduce source-level work without adding regions, events, updaters,
assets or saved state. Pinned formatting and source review do not establish a
stutter fix; no local tests, standalone validation or addon/game execution were
performed. No before/after measurement of these edits is established.

## Full performance follow-up — 2026-10-28

### Inactive unit borders

Party resource and health-only borders now use real Hide/Show transitions for
their inactive strips. With resources on, fifteen health-only strips per shown
party row leave extraction instead of remaining shown at zero alpha; resources
off hides the three-piece alternative. The replaced native party sheet is also
hidden. Player/target portraitless borders, target-of-target strips and the
player's alternative pointed rim use the same actual visibility boundary.
Original pixels, crops, geometry and pools remain unchanged.

This separates visually transparent regions from renderer-submitted regions:
the inspected public engine extracts zero-alpha textures, whereas hidden regions
are excluded. CI-only extracted production transitions assert hiding, restoration
and unchanged-state idling. No local tests, addon execution or measured GPU/FPS
result is claimed; the packaged renderer's exact revision remains unverified.

### Native nameplate layers

Supported native plate and health-bar owners now disable their own drawing
layers instead of making source regions transparent. Native region shown bits,
names, health, raid-icon metadata and input remain available; the custom child
keeps its own enabled layers. One captured layer state serves permanent skin
suppression and temporary recursive V/filter masking, so unmasking cannot expose
the native art. World/logout/reload retirement restores the captured bits.
Clients without owner-layer support retain the former alpha fallback.

This removes submitted native texture regions on the inspected engine path,
without changing custom art or allocation. CI-only production nameplate mocks
cover data/shown-state retention, V transitions, prior disabled bits and cleanup.
The source does not establish packaged-client drawing or measured FPS.

### Encounter tooltip content

Hovered encounter debuffs cache the displayed name, stack count, dispel caption,
permanence, rounded remaining/duration, language and effective scale. Native
debuff timing still updates at the original cadence; unchanged tooltip content
skips SetText/AddLine/Show and their native clear/rebuild/size work. Cursor and
shared placement continue independently. Re-entry rebuilds after native SetOwner;
hidden or foreign-owned tooltips are never replayed. One bounded record per
pooled icon adds no region, event, updater or saved data. CI-only extracted
production coverage asserts these transitions without renderer measurements.

### Shared frame navigation reads

The existing waypoint frame/display callbacks share one lazy synchronous native
sample for phase, zone/map context, player position, metric, aspect and heading.
Both guides and every minimap pin retain per-frame projection and the original
interpolation equations. Separate calls outside that callback stay fresh; the
next callback retries unavailable data. Read-only map browsing, calibration,
native run-coordinate/stamp fallbacks and hidden guards remain authoritative.
One reused scalar record adds no updater, region or gameplay history. Protected
sample cleanup also releases the record after a native/widget error. CI-only
coverage checks repeated consumers, new-frame movement, map ownership, failures
and retirement. This is native-call reduction, not a changed drawing budget.

### Stable shared tooltip owners

Shared tooltip placement first checks its last accepted icon with native IsOwned.
An unchanged owner skips action/equipment/registered-icon traversals; a mismatch
uses the original discovery order. Clear/Hide retires the cached owner, while
foreign owners and native resets remain observable. Cursor motion, current
visibility, scale and anchor checks still run at their existing cadence. CI-only
placement assertions cover the single-owner check and replaced-owner fallback.
No new registry, event, region or drawing pass is introduced.

### Shared spellbook generations

SCT and meter source resolution share one lazy complete spellbook scan after an
existing spell/world/language invalidation. Different non-book names use that
same result instead of each rebuilding the book before catalog lookup. Incomplete
native slot metadata retries at most once per second through actual consumers;
missing APIs and failed scans remain retryable. Off/hidden consumers add no scan.
The source priority, ambiguity, original grouping identity and icon pools remain
unchanged. CI-only controller coverage includes meter-only lookup while SCT is
off, several missing names, delayed artwork readiness and world retirement.

### Loot backpressure

Loot resolves native/catalog item metadata only after its existing three-card
view accepts capacity. A full pool retains the original queued head without
repeated copying or item queries every fifth second. Accepted cards still retain
their existing bounded metadata retries, expiry and pool reuse. Resolution now
also occurs inside the protected delivery call. CI-only lifecycle coverage checks
three occupied cards, unchanged queued work and the first delivery after expiry.
No drawing, intake identity or queue-limit behavior changes.

### Guardian respawn guidance

Optional **Guide to next respawn** selects the earliest known respawn only while
every accepted lair is empty. The existing acceptance pass compares native
non-negative `left` values once per publication, retains equal-time selections
and caches one point reference. Navigation calibration reuses the accepted empty-lair coordinate
copies. It adds no countdown clock, health read, per-refresh ranking scan or
gameplay history. The default-off choice caches only a boolean through the shared
display listener. Toggling reselects from accepted data immediately, with no new
packet, timer sampling or roster copy. Living publications take priority, while
hidden/off presentation and run/world retirement keep the existing lifecycle.
Defeated minimap pins remain independently controlled.
Normal and Performance Mode use the same existing icon, text and required
navigation arrow; this adds no gameplay frame, region, asset, event, updater or
SavedVariable. One boolean lives in the existing display table; the Map &
navigation page lazily adds one standard Button, four texture regions and two
FontStrings, using existing editor artwork. At rest the unchecked control draws
two textures and its two text regions; checkmark and hover can show the other
two textures. The page hides all of them when closed. While awaiting a respawn,
the existing Guardian HUD can draw its two textures and two text regions; no
additional gameplay regions are allocated. This required guidance stays visible
in Performance Mode with the same static icon and native navigation updates.
Its value is retained while it is dimmed/mouse-disabled with Guardian guidance
off; hidden settings skip its presentation work. CI-only full-controller cases
cover default/invalid choices, preview/save/discard/profiles/reset, timer ordering,
ties, due/unknown values, living priority, hidden/off recovery and retirement;
they were not run locally and do not establish rendered behavior or FPS.

### Rounded waypoint labels

The fallen-ally extension adds one shared 190-by-46 HUD frame, two texture
regions (the bound-once Winged Soul icon and existing direction arrow) and two
font strings. Its static icon is identical in Performance Mode; it adds no
cosmetic animation, event, controller, updater or SavedVariable. The existing
ten-Hz/deferred waypoint refresh checks at most four native party slots, skipping
all party reads while its guidance is disabled. Live map records reuse one
bounded array and up to four point tables; retirement clears entries without
persisting locations. Missing geometry does not guess a location.

Each eligible member can lazily allocate one existing pooled minimap pin frame
and one static texture, at most four active/pooled pins for this tracker. There
are no party respawn labels, checkmarks, hover handlers or world overlays. The
shared per-frame projection/arrow path uses the latest native sample and retains
changed-only label/placement writes. CI-only production mocks cover roster and
display transitions, stationary work, location loss and pin reuse. These are
source/fixture claims, not measured rendering or FPS improvements.

The waypoint HUDs no longer allocate or draw their decorative bottom stripes.
Removing the shared `FloatingRail` helper and its construction call removes one
`WHITE8X8` texture region per guide, two across Cache and Guardian. This is a
source-level region reduction, with no measured GPU or FPS result.

Each guide caches only its latest rounded yard value, language and formatted
caption. Per-frame interpolation and rotation stay unchanged; stationary values
skip translated formatting and its temporary field table. Actual text comparison
still repairs native resets or failed assignments. Missing distances retain
their translated On map caption, zero remains a valid value, and retirement
clears the record. CI-only extracted coverage asserts these boundaries.

### Shown nameplate sampling

The historical native-plate registry still owns discovery and reuse hooks, but
the per-frame refresh walks a separate shown set maintained by those same native
Show/Hide callbacks. Hidden peak-pool entries no longer incur recurring shown
checks or retirement lookups. Forced discovery resynchronizes existing entries
on recovery. Live discovery/projection cadence, recent retired origins and
lethal-hit matching remain unchanged; no native roster is capped or discarded.
CI-only production fixtures assert hidden-pool idling and reuse on Show.

### Settled disabled banners

Disabled, faulted or unsupported banners detach their existing update callback
after native restoration and handler unregistration settle. Pending cleanup
retains its existing fifth-second retry; failed unregistration remains pending,
and native dispatch still defers handler-list mutation. Existing settings,
world, CVar and run/zone receipt callbacks restore readiness checks without a
new event or updater. Enabled views keep their original polling, expiry and
cosmetic cadence, including hidden notice retirement. CI-only production
coverage checks enable/disable, failed cleanup retries and dispatch failure.

### Meter publication work

The visible meter distinguishes accepted counter publications from changing
native rates. Getter identity, returned source, native stamp, total and a
monotonic receipt generation invalidate counter validation/copying, including
same-table/same-stamp deliveries. Official getters and five-Hz native-time
observations remain active; one-Hz row/header rate updates remain independent.
Session comparison and immutable name/order/class/share copying skip settled
publications. The bounded rolling ring still samples cached counters, preserving
pauses, interpolation, warmup, gaps and regressions. Reset, language/off/world
retirement and empty-publication gates retain their existing ownership.

This independently applies FieldKit's separation of publication and rate work,
with the installed native parser's list-replacement/stamp contract and our
stronger receipt gates. CI-only production fixtures cover invalid/replaced
sources, same-stamp receipts, native changing rates and all reset/retirement
boundaries. No native gameplay table is changed and no drawing region is removed.

### Shared plate samples

One reusable lazy scratch tuple within each synchronous plate refresh now feeds
the filter, skin and SCT matching. Names, reaction colors, health range and value
are read only as required, avoiding duplicate native calls for the same pass.
Names-only/MSBT paths retain their health-read skips; filtered skins still defer
their cosmetic reads. The next refresh and native reuse callbacks sample afresh,
and retirement clears scratch data. CI-only fixtures assert single reads and the
disabled paths. Native health, matching cadence and all artwork stay unchanged.

### Lazy Layout handles

Group registration keeps required geometry, visibility wrappers and editor
availability, while deferring its handle, label, four corner grips and optional
side grips until the first eligible edit refresh. Each ordinary handle's 24
corner textures and five buttons therefore stay unallocated for groups never
edited. Prepared handles remain pooled for later edits. This is a startup/resident
allocation reduction, not a gameplay draw-count reduction or a saving after all
handles have been used.

Unprepared groups remain safe through Confirm/Cancel/reset/world cleanup; hidden
groups stay selectable and conditional groups use the existing eligibility rule.
Partial native preparation stays hidden, publishes no handle and does not
reallocate every tick. CI-only full Layout mocks cover first preparation, reuse,
late registration, drafts, cleanup and allocation failure. Authored grip geometry
and input remain unchanged, with no runtime test hook or additional controller.

### Combat parser descriptors

Fixed native capture-field descriptors allocate once at source load. Their
pet-source prefix form prepares lazily once per descriptor, instead of copying
the same fields for every attempted combat pattern. Successful events retain
their own independent captures/results and original localized pattern, school,
amount and ownership validation. CI-only production parsing checks player/pet,
melee/periodic and foreign-source cases without shared-result aliasing.

### XP fade geometry

The existing gain/spark renderer caches its owned anchors, widths, crop and alpha
independently. A stationary final fade now changes only its two alpha values;
actual width/progress changes retain the original gain bounds and clipped spark.
Show/Hide comparisons preserve pooled reuse and the final clearing pass. Timing,
easing, native XP reads, source images, layers and region count stay unchanged.
CI-only extracted production coverage checks fades, resizing, end clipping and
zero-alpha retirement, without a GPU/FPS claim.

### Final source-icon answers

The shared resolver retains at most 256 final exact-name/school answers in a
FIFO generation, skipping repeated lower-tier alias/catalog/path resolution.
Existing dirty scans and pending native retries run before cache hits. Accepted
learned values/conflicts and existing spellbook, item, summon, language and world
resets retire the generation; authoritative ambiguity is retained. Unknown
answers expire after one second so native metadata can recover. Direct spellbook
hits and current native Melee/equipment artwork retain their own paths.

This adds bounded unsaved display metadata, not gameplay data or drawing regions.
Consumers keep their hidden/off/icon-off guards and texture assignment retries.
CI-only controller scenarios cover school refinement, meter ambiguity, stronger
metadata, failures/recovery, language/world retirement, weapon changes and FIFO
eviction. Existing learned-talent lifetime and source priority remain unchanged.

## Loot popup modes and marks — 2026-10-27

The new Loot notifications page uses existing editor artwork: one category
button, three mode buttons, one checkbox, a heading and a status description.
The authored controls add 49 texture regions and eight FontStrings in the lazy
dialog (category 12+1, mode buttons 33+3, checkbox 4+2, heading/description 0+2),
plus the native scrolling template used by other single-column option pages.
These allocate only when the editor is first opened, inherit its existing
visibility and use existing material images; they add no gameplay updater.
The selected-mode/checkbox comparisons, caption helper and shared dependency
group skip unchanged selection, text, dimming and input writes. The marks
control stays inactive at 0.45 alpha outside SDUI mode.

Game/Off clear the existing queue/cards, reject intake before parsing or metadata
resolution and detach the loot service updater after the native handoff. Only
pending native visibility handoffs retry on the existing five-Hz controller.
The shared HUD owner accepts true or false, retaining the original/latest
external preference across mode previews and guarded synchronous callbacks;
other owners still acquire hidden visibility by default. Getter matches skip
setter writes. World/logout/reload cleanup retains its native restoration.

Initial Game/Off creates only the existing non-rendering loot root/controller
frames; three cards and their nine textures/six FontStrings defer until the
first SDUI readiness request. Failed preparation stays unready without repeated
allocation. Once built, the original three-card pool, crop, quality rim, icons
and UVs remain reusable. The card geometry is unchanged; stack spacing and
fade deadlines now follow the retail running code described below. Both non-custom
modes actually hide all cards and stop cosmetic animation. Layout hiding remains
separate: current expiry and bounded metadata retries continue without painting.

Positive item conversions reuse the existing name region for a gold marks-only
label, such as `+0.5 Marks` or `+1 Mark`. Integer and decimal amounts use the
same shared validation, retaining received text without numeric conversion.
The converted item's class/metadata work and retries are skipped. The selected
**03 silver skull coin** reuses the pooled icon region at its existing 50-unit
size, with no rarity rim. Each marks card draws its background and static icon
plus two labels: one more visible texture than the text-only marks card, up to
three additional visible textures, with zero new allocated regions. Successful
bindings skip repeated native writes; failed bindings retry on an existing
required refresh, and hidden cards defer binding. The single new 64-by-64 Raw3
BLP occupies 17,556 bytes on disk (16,384 bytes of pixel data); this is not a live
GPU-memory or draw-call measurement. The full-resolution TGA is authoring-only.
Both modes share this static image and normal item reuse restores its own icon
and rarity rim. Only
enabled SDUI conversion rewards pass shared service/view eligibility; other
collected items stop before queue/metadata.
One latest formatted reward label per card is cached and cleared on language
change/retirement. Custom chat hides the two recognized reward/balance notices
while SDUI marks popups are active, retaining fallback chat when unavailable or
disabled. Intake still sees the original message first; the balance line adds
no card. Cards use retail's 106-unit stack step, 0.2-second fade-in, four-second
outro delay and 1.5-second fade-out. Each start/expiry remains independent;
Performance Mode keeps the same 5.5-second deadline with no fade. Hidden cards
expire without replay. The original three-card pool and its region count remain
unchanged. The selected coin adds one bound static image asset, with no new
drawing region, event, updater, gameplay counter/history or SavedVariable. The two normalized
display choices use the existing profile/draft/reset paths. Source review,
authored CI-only mocks and pinned formatting do not establish measured draw
calls, GPU/FPS, native box behavior or in-game font/appearance parity.

## Target health and compact labels — 2026-10-27

One non-rendering target-health controller accepts the official `AZS_TARGET`
publication for the label, percentage, fill and existing damage-loss texture.
Its new `CHAT_MSG_ADDON` subscription coalesces target/run/zone receipts into a
single deferred callback, detached immediately after reading. Target/world
events and Show/Hide own invalidation. It has no idle poll, new gameplay clock,
history, saved state or native-table writes. Hidden targets retain receipt
counts and boundary retirement only; they do not read/paint health, and Show
accepts current state with a fresh loss baseline. Same-name selection changes
require a fresh publication rather than guessing spawn identity from a name.
Selection now arms an unsaved provisional flag: existing target/native-health
callbacks can immediately paint validated `UnitHealth` / `UnitHealthMax` for the
current unit until its full-precision packet arrives. This adds native getter
reads only to that temporary source, not a reader, event, timer or idle poll.
The accepted AZS source disables the fallback and advances the existing loss
generation, so a precision/maximum change cannot create a false damage trail.
Hide and world/zone/phase retirement disable it. Missing/invalid native values
stay empty, and invalid packets after accepted AZS health never restore capped
health. Native limits can affect the temporary selection values. Existing
changed-only labels/fill and hidden guards are retained, with zero new frames,
regions, artwork, settings or saved state. CI-only mocks cover immediate
selection, namesakes/late packets, precision handoff, invalid native values and
native capped writes after acceptance; no local execution or measured latency,
FPS or visual-parity result is claimed.

The existing native target StatusBar uses a 0–1 fraction, preserving UV ownership
and artwork. Its two setter adapters compare actual native range/value before
writing, including after native resets, and guard synchronous value callbacks.
Labels share the full source and cache formatted text by current/maximum health
and effective visibility choices. The common health formatter adds fixed
K/M/B/T display tiers without changing counters, percentage math or loss
fractions. Player/party/pet health sources remain native, and percentage-off
labels still skip their native maximum-health getter.

Loss retirement removes the effect from its existing animation list immediately
on target/spawn/max changes, hiding, world leave or logout. Its original
half-second fade and fill geometry remain intact. The owner adds one passive
frame, zero drawing regions, zero textures/materials and no new alpha pass;
existing labels, health fill and loss texture are reused. There is no local
test or addon/game execution. These are source-level costs and authored CI mock
assertions, not measured GPU/FPS or visual-parity results. See
[target health](UNIT-PORTRAITS.md#target-health-and-compact-numbers).

Guardian and boss portrait classification uses a separate cosmetic roster path
to avoid waiting for a new target-health packet. A bounded forty-entry
`AZS_UNITS` publication is validated atomically, then indexed by exact localized
name and native maximum-health representations. `T.IndexUnitMaximum` now owns
the existing exact float32/ceiling/uint32/publication-preimage rules for both
this index and the nameplate filter; their encoding math is unchanged. Ordinary
elite entries block collided signatures. Only kind and maximum aliases are
copied, with no health/spawn identity acceptance, per-target history or native
table writes. Source table/stamp/parsed-receipt caches skip unchanged rebuilds
and cache invalid publications until new evidence arrives. Existing name buckets
are reused while accepted rosters change.

On target selection, `GetBorderKind()` first uses any authoritative accepted
target kind. Otherwise, one current native name/maximum sample can match the
known roster immediately through the existing target listener. The maximum
read is confined to this unresolved cosmetic path; accepted target kinds keep
the original no-extra-health-read path. No text, font, geometry or texture work
is added to unchanged classifications. Native rebuilds still force repair.
Copied matches stay stable while ordinary unit/run packets are pending; raw
roster parsing and alias rebuilding wait for the existing deferred callback.
Unknown or ambiguous matches retain native artwork pending target confirmation.

Hidden targets skip cosmetic matching, roster validation and target-health
reads. Unit/run receipts may arm one callback on the existing controller solely
to settle parser readiness and observe phase/run rollback, then detach again.
Selection/Hide retain current-run roster metadata for immediate reuse; zone,
world, inactive-phase, observed run rollback and language boundaries clear it
and block the old publication. A newly accepted roster notifies the existing
target listener even if the health publication is unchanged. This adds no idle
worker, new event registration or controller.

This adds zero frames, drawing regions, assets, events, updaters, settings or
SavedVariables. The existing three portrait-rim and seven health-border strips,
256-by-128 sheets, UVs, layers, alpha overdraw and classification-specific edit
bounds are unchanged. **Hide portraits** uses the existing closed border, and
Performance Mode retains the same static winged artwork. CI-only coverage
asserts immediate guardian/boss/final selection before `AZSTGT`, shared maximum
aliases and collision rejection, parser handoffs, publication retirement,
native fallback, hidden idling and unchanged/forced bindings. These are source/lifecycle
contracts, not measured draw-call, GPU/FPS or in-game visual-parity evidence.

## Player absorbs — 2026-10-27

The player absorb segment shares the existing ten-Hz player-resource controller
and its deferred `AZSRUN` reads. One phase/publication gate supplies both
absorbs and the optional secondary resource; shield display stays independent
of **Class resources**. Phase/zone/world retirement blocks the retired
table/stamp/receipt tuple. Hidden frames retain only phase retirement, clear
their absorb fractions on Hide and perform no shield reads or presentation.

The first valid positive shield lazily allocates one mouse-transparent frame
and one texture region, reusing `LargeHealthFill` with full UVs. Successful
texture binding is cached; failed assignments remain retryable through the
same reader. Anchors and width change only when their effective geometry
changes; dual vertical anchors follow the resource row's health-height change
without a new updater. Health-size callbacks reflow retained fractions only
while visible. Zero, invalid or retired data hides the region once.

There is at most one extra visible region and one additional tinted alpha
pass over the existing health opening. The segment can overlap the health
fill at full health or when the shield would exceed its right edge; it is
clamped to one bar and stays beneath the border and labels. No new texture
file, material image, animation, event subscription, gameplay history or saved
state is introduced. These are source-level costs, not measured draw calls,
GPU memory, pixel parity or FPS results. Only local formatting and source/diff
review were performed; addon/game execution remains unverified. See
[player absorbs](UNIT-PORTRAITS.md#player-absorbs) for the data and geometry.

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

Boss encounter retirement also uses that reader. Native `dead`/`ready` phases,
new-zone receipts, clock rollback and world cleanup clear active rows, debuffs,
hovers and copied entries once. Subsequent retired refreshes skip encounter
getters and repeated cleanup until a fresh `AZSUNITS` receipt is eligible.
Two session-only receipt counters and one flag add no event, updater, region,
texture/material state or saved data. Existing native visibility restoration
remains retryable; this is source-level lifecycle evidence, without measured
FPS or live death/retry proof. See the boss-health lifecycle in
[RUN-TIMER.md](RUN-TIMER.md#boss-health-on-death-and-restart).

All 25 current Layout groups were traced in the installed addon checkout. Layout uses
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

| Layout key          | Hidden presentation and retained work                                                                                                                                                                                                                                                                                                                                             |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `playerFrame`       | Custom health/level/color hooks, resource painting, portrait copy binding and cosmetic animations skip hidden work. Native unit events/values and secondary-resource phase retirement remain; Show refreshes current presentation.                                                                                                                                                |
| `targetFrame`       | Custom values, classification artwork and aura-anchor repairs defer until visible. Native target/death/aura state stays owned by the game; Show forces current styling and aura layout.                                                                                                                                                                                           |
| `partyFrames`       | Custom labels/colors skip invisible rows and refresh on Show. Native roster, unit values and shared edit bounds remain.                                                                                                                                                                                                                                                           |
| `buffs`             | Hiding clears custom timer rows/hovers and stops cosmetic ticking. Native packets may request one deferred phase/receipt check, without hidden timer getters or painting. Icon/font/anchor repair resumes on Show. Hidden edit entry may count slots for handle bounds. Native buffs/enchants remain native.                                                                      |
| `actionBar`         | Native buttons remain native. Custom cooldown numbers skip hidden getter/paint work; range polling detaches, existing indicators/fades clear, and hidden buttons allocate no indicator. Attached XP/jewelry/tally follow this owner.                                                                                                                                              |
| `runTimer`          | Hidden fill, caption, markers, foam and sparkle writes stop. Native clock/schedule validation and HUD ownership use the existing ten-Hz poll or deferred publication; visible clock effects retain frame cadence. HUD release paints cleanup once while failed native restorations can retry.                                                                                     |
| `bossBars`          | Hidden health/debuff text, icon allocation, timing getters and reflow stop. Existing hovers/debuff rows clear once on Hide. Native encounter validation, row retirement and takeover remain, including a valid empty boss list; Show requests fresh rows.                                                                                                                         |
| `runTally`          | Hidden counter formatting/measurement and glow preparation stop. Native counter validation/takeover and attachment metadata remain; Show requests fresh presentation.                                                                                                                                                                                                             |
| `xpBar`             | Native XP/level events still coalesce the latest tuple. Hidden gain animation stops and detaches, final private bar writes defer, and requested visibility changes only on transitions. Show restores the latest fraction and schedules a fresh instant read.                                                                                                                     |
| `jewelryBar`        | Its existing polling controller detaches behind the active hidden Layout owner. Hidden inventory/cooldown reads, icon composition and cosmetic cooldown painting stop; visible recovery retries metadata. Attachment changes and world cleanup remain. Exact fourteen-strip sampling is unchanged.                                                                                |
| `minimap`           | Clock painting stops with its hidden parent. The glyph launcher stops its active drag and clears its hover; square-edge button projection/reflow stops until shown. Custom pins skip hidden styling/projection/facing work, while required native guardian-flag ownership/restoration continues at the existing lifecycle poll. The addon creates no full world-map presentation. |
| `cacheWaypoint`     | Hidden guide interpolation, distance formatting, arrow rotation and facing samples stop. Native destination acceptance/selection, world cleanup and independently visible minimap markers remain.                                                                                                                                                                                 |
| `guardianWaypoint`  | Same visibility boundary as cache guidance; accepted lairs still feed the guardian data foundation independently of this HUD's visibility.                                                                                                                                                                                                                                        |
| `guardianTracker`   | Layout-hidden policy detaches its pure view controller before roster copying, measurements or row painting. The separate guardian foundation continues accepting native state. Show uses a fresh snapshot.                                                                                                                                                                        |
| `sctMSBT`           | Hiding clears active/queued scrolling hits and skips intake, resolver work, animation and measurement. Showing admits new hits only. The stream owner and its edit handle retire when Custom or MSBT-style turns off; over-enemy text uses its original parent and WorldFrame anchors.                                                                                            |
| `damageMeter`       | Layout-hidden mode validates newly published native data without copying view rows or sampling displayed rates, retaining phase retirement and takeover checks. Showing rebuilds from the getter. Feature-off remains stricter: no meter subscription, collection, getters or idle updater, apart from a pending native-preference restoration.                                   |
| `petFrames`         | Hidden/static groups skip timer sampling and all row/icon painting. New native roster receipts, phase retirement and changed edit bounds remain. Show refreshes current timing through the existing controller. The separate native primary pet retains its native ownership.                                                                                                     |
| `revive`            | Hidden progress/identity state stays current without glyph measurement, text/bar/cross/spark writes or cosmetic animation. Show requests a fresh deferred read. Existing native-HUD release while Layout-hidden remains; no revive time is invented.                                                                                                                              |
| `levelUp`           | Hidden class icon, count formatting/measurement, content alignment and pulse painting stop. Native stored-level validity/takeover remains. Hidden editor bounds still measure the active-language panel; Show refreshes current data.                                                                                                                                             |
| `lootNotifications` | Hidden labels/icons/colors, alpha animation and card reflow defer. Original lifetimes, bounded exact-reference metadata retries and queue retirement continue, so expired cards cannot reappear. Show expires old cards before painting.                                                                                                                                          |
| `banners`           | Hidden labels/colors, alpha animation and reflow defer. Native registration, preference ownership, delivery deduplication, queue promotion and original expiry cadence remain. Show retires expired rows before painting current notices.                                                                                                                                         |
| `chat`              | Its cosmetic updater inherits native hiding; native hooks skip hidden font/geometry/indicator work. Show repairs native presentation. Native messages, level/stat batching, history, opt-in capture and the separately parented command input remain available.                                                                                                                   |
| `copyWindow`        | No idle updater. Opening while Layout-hidden only establishes the lazy edit owner/requested visibility; it skips archive-page preparation and invisible focus. Existing close cleanup and capture policy remain.                                                                                                                                                                  |
| `menu`              | No idle updater or hidden decorative controller. Game-owned commands/window actions keep their existing behavior.                                                                                                                                                                                                                                                                 |
| `tooltip`           | Hide clears the current native hover immediately. Hidden ancestry prevents positioning/styling updates; no subject is forced visible on Show. Native content/owner and separate private readers stay native.                                                                                                                                                                      |

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

| Frame group                                             | Owners and preserved performance boundary                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pet summons and native primary pet                      | `modules/unit/pets.lua`, `modules/unit/mini.lua`: native cached circles, receipt/roster reuse, visible timer reads and actual native-state repair.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Equipped jewelry                                        | `modules/ui/jewelry.lua`: original fourteen-strip UVs, grouped texture order, unchanged layout, idle cooldown gating and metadata retries.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Run/boss/tally, guardian tracker                        | `modules/ui/run.lua`, `modules/ui/guardians.lua`, `modules/ui/guardian_tracker.lua`: receipt-based schedules/copies, pooled rows, hidden cosmetic guards, fixed pill backgrounds, retained marker/foam/glow equations and edge-to-edge bezel joins.                                                                                                                                                                                                                                                                                                                                                                                                  |
| Player/target/party, resources and portraits            | `modules/unit/player.lua`, `target.lua`, `mini.lua`, `resources.lua`, `portraits.lua`, `core/widgets.lua`: shared styling, completed fades, changed styles, exact native-unit routing, native health and model-paint evidence.                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Character and equipment                                 | `modules/ui/character.lua`: coalesced deferred work, measurement/discovery caches, actual native anchor repair and the three authored quality-rim passes.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Revive, stored levels, loot and banners                 | `modules/ui/revive.lua`, `levels.lua`, `loot_view.lua`, `banners.lua`: passive pools, changed-only presentation, requested visibility, bounded view queues and required hidden lifetime/ownership cleanup.                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Action bar, range and XP                                | `modules/bars/bars.lua`, `range.lua`, `modules/xprep/xprep.lua`: shared controllers, event-driven work, transition-only range fades, final cooldown sampling and pending-only XP animation.                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Minimap and waypoint guides                             | `modules/map/map.lua`, `buttons.lua`, `navigation.lua`, `waypoints.lua`: reusable accepted snapshots/pins and native direction/position sampling; skip unchanged clock labels and button anchors. The gold glyph and selected static square background use two bound-once textures: one added persistent background region/UV clamp and normal alpha overlap beneath the glyph, with no idle polling or extra hover region. Both inherit hiding/scale and stay static in Performance Mode; the pointer updater exists only while dragging. Square-edge adaptation runs on foreign placement calls or map/show/load events. See `MINIMAP-BUTTONS.md`. |
| SCT and nameplates                                      | `modules/nameplates/sct.lua`, `style.lua`: event-batch discovery plus independent frame discovery, preserved matching/animation, cached metadata and unchanged native styling.                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Layout/editor, tooltips, chat, Copy, menu and inspector | `core/layout.lua`, `editor.lua`, `tooltips.lua`, `fstack.lua`, `modules/chat/*`, `modules/menu/menu.lua`: bounded edit sampling, passive/pool reuse, owner/scale-aware hover work, native chat/fades, retained opt-in diagnostics and hidden inspector shutdown.                                                                                                                                                                                                                                                                                                                                                                                     |
| Meter and general warning overlay                       | `modules/ui/meter.lua`, `modules/ui/ui.lua`: native circles, one-Hz rate display with five-Hz data observation, visibility/change guards, transition-only warning visibility and preserved gradient animation.                                                                                                                                                                                                                                                                                                                                                                                                                                       |

Native aura/timer rows (`modules/unit/auras.lua`) retain changed-slot reflow,
hidden timer shutdown and required repair of native buff/enchant anchors.
Damage-loss artwork (`modules/unit/cut.lua`) installs its animation callback
only for active fades and removes it when the fading pool is empty. These
native repair and authored fade paths must not be removed as idle work.
Bag, cast-bar and micro-menu suppression have no replacement artwork or
decorative updater; their game-owned window/keyboard behavior stays intact.

## Meter drawing audit — 2026-10-26

Each meter rail now has a two-unit black outline. One additional pooled texture
per row reuses `meter/Background.blp`, cropped to its lower eighteen source rows
and tinted black. The original background and native StatusBar pixels/UVs stay
unchanged. The outline uses BACKGROUND and the original background uses BORDER,
keeping their order independent of native equal-texture sorting. Two permanent
anchors follow the existing background's width/icon-gutter changes without new
layout sampling or refresh writes. This adds one texture region and a cropped
UV/material state per allocated row, plus a thin visible alpha edge around each
shown rail; the opaque original rail covers its interior. Existing lazy row
pooling, hiding/off behavior and cleanup own it. No asset, frame, event, updater,
setting or SavedVariable is added. Source review and pinned formatting do not
establish in-game appearance or a measured GPU/FPS result.

Ability names and numeric row values now use DEFAULT/OUTLINE plus the shared
black chat shadow at `(1, -1)`, matching guardian/chat text. Each label retains
its font flags so existing size-change retries preserve the outline and require
both size and flags to match before caching success. Shadow setup reuses the
shared changed-only helper during label creation. There is no new per-refresh
font/shadow write, measurement, frame, FontString, texture, updater or saved state.
The existing two FontStrings per row remain; outlined glyphs cover additional
pixels, so unchanged region counts do not establish equal GPU cost or FPS.
Meter header styling, row geometry, font-size preferences and hidden/off guards
remain unchanged. Source/diff review and pinned formatting only; no local tests,
standalone validation or addon/game execution.

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

Damage Done now derives rolling DPS from native cumulative snapshots and run
seconds, defaulting to ten seconds. The existing five-Hz reader observes complete
sources even on another visible meter tab; no event, frame or updater is added.
`core/meter_rates.lua` caps each header/source series at 604 timestamp/value pairs,
retains at most 120 run seconds plus one boundary sample, and compresses flat
intervals to their endpoints. Source identities remain exact name/proc pairs;
new identities allocate once and reuse their numeric vectors. Left-boundary
queries use binary search at the one-Hz presentation cadence. All skips history;
The X captures all four native views once through the existing reader and keeps
one baseline/last-counter record per exact name/proc identity. It pools positive
session rows and recalculates their totals/shares/order only when counters or
native order change; unchanged counters refresh only native-time average rates.
No native counter or table is modified.

Party Damage reuses that fourth mode, existing packet intake, reader, session
reset model, one-Hz presentation and lazy row pool. Native class keys share the
existing class-color palette. Its only portrait discovery is a bounded five-unit
pass during visible, icons-enabled party painting; it skips all spell/item icon
resolution. Unit/name/native-frame-image and actual texture comparisons skip
unchanged native portrait binding. Failures remain memoized until the identity
or source image changes or the row retires; neutral fallback binding retains the
existing retry rules. Icons-off, hidden/off views and retired rows skip that pass
and binding; release clears the bounded metadata. All four views retain phase
and received-publication gates. No frame, region, model, artwork, event, updater,
setting or saved state is added. Native unit portraits occupy the existing icon
and gold-rim regions, so the authored visible-region budget below is unchanged;
neutral fallback can still use the existing more expensive strip path. Source
review and formatting are the only local checks; CI-only mocks are authored for
cycling, portraits, unchanged/hidden/off work, failure caching, reset metadata
and world retirement. No measured CPU/GPU/FPS or live visual-parity claim follows.

Hiding empties recent vectors once and stops observation; showing warms the
window again. Disabling and run/world retirement drop all rate state; language
changes rebase an active reset session. Repeated retirement of an empty model allocates nothing. Pause leaves the
native time coordinate unchanged. Window choices reuse normalized display drafts,
profiles and resets. The window row reuses existing editor controls. The old
rate-only Reset DPS settings action is removed. The header arrow FontString is
replaced by one native button using three already-bundled Close.blp states:
normal, pressed and additive hover. One image draws normally, with a second only
on hover; native button state handling needs no Lua updater or cosmetic polling.
The texture is bound once, retains its source proportions and inherits meter
scale/hiding. This adds one normal HUD texture region and removes one label,
without adding an image file or saved state. Rate text/tooltips still skip
unchanged writes; reset clears rows/icons/hovers and both rate caches immediately.
These bounds are source-level cost evidence; CPU time, gameplay behavior and FPS
remain unmeasured. See [DAMAGE-METER.md](DAMAGE-METER.md).

The meter's normal circular path uses six native icon regions plus six existing
ring regions. With its header, row backgrounds and fills, the full six-row view
has 32 authored texture regions normally, excluding the transient hover, text, native internal regions,
tooltips and other HUD owners. The configurable one-to-ten row limit defaults
to six; a fully populated native view has `2 + 5n` authored texture regions,
so ten rows use 52. One seeded row checks renderer readiness; additional rows
are allocated only when requested visible sources need them. Shrinking the
view retires surplus rows immediately and retains the pool for reuse.
No strip pool is allocated on the native path.

Meter DPS, icons and both header fields default on; ability damage, percentage
and ranks default off. Turning **Ability icons** off
clears pooled icon bindings, hides icons/rims and skips icon resolution and binding
in subsequent paints, leaving `2 + 3n` authored texture regions in a populated
view (20 at six rows, 32 at ten), plus the transient reset-button hover. Pools remain allocated for reuse. Disabled
row values do not trigger formatting when their native values change. Column
widths and the icon gutter reflow only for effective option changes; header
text is cached by its visible values, view, language and options revision.
These are source-level cost controls, without a measured FPS claim.

The compatibility path is deliberately more expensive: at effective scale one,
each 26-unit icon uses 24 nonempty strips. Including the header and normal X,
six such outlined rows have 170 visible
authored texture regions and 176 allocated regions including their six hidden
named portraits. These are construction counts, not measured material batches
or GPU draw calls. For a freshly populated ten-row fallback view the equivalent
counts are 282 visible / 292 allocated at scale one. Retained pools can have
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

Run-timer captions and the font preview align every pooled text segment to the
same baseline. Removing the seconds' one-pixel lift also removes its extra edit-bound
height. The existing text/font/scale cache, hidden guards and segment pool remain;
there is no added region, texture/material, alpha pass, allocation or updater.
This is source-level alignment evidence, without local execution or measured
GPU/FPS or in-game appearance results.

All resizing uses the existing editor controller, unchanged-pointer guards and final release sample. Root height changes from row/debuff reflow also invalidate the active opposite-edge calculation. Grid preference, row counts, widths and font size retain shared Confirm/Cancel/discard/profile/reset behavior, without a new SavedVariable or idle updater. Local work was limited to source inspection and pinned formatting; appearance, animation, input and renderer performance remain unverified.

## Unit health width handles — 2026-10-27

Player, target and party add six editor-only one-texture side marks. Player/target marks anchor to their compact border edit regions; party uses its existing multi-row region independently of the Layout owner's dimensions. Width remains in the existing Layout record and uses existing resize/editor/Show/unit-event paths, with no asset, SavedVariable or new updater. Portrait/model dimensions, health heights, animation timing and native values remain unchanged; the existing Cut-Out size callback reflows retained loss fractions.

Large-frame width reflows its shared health span and metal end position. Native StatusBar UVs remain untouched. Each large top/bottom artwork region becomes a fixed cap plus a straight span: two additional allocated/visible regions per large frame. Party's full resource-mode sheet becomes three pieces (one previously), and each health-only top/bottom span splits at the fixed outer cap, raising that variant from thirteen to fifteen pieces. Both party variants are allocated during the existing four-row setup, adding four allocated regions per row; only the selected variant has nonzero alpha, adding two visible regions per active row. Across player, target and four party rows this is twenty extra allocated artwork regions, up to twelve extra visible artwork regions, plus six editor-only marks. Four passive party anchors replace their old single-texture anchors; they have no updater or input.

The extra pieces preserve portrait/cap proportions during horizontal extension and use the same source pixel regions without added effects or alpha overlap. Changed widths update the affected sizes/anchors; unchanged state skips them, and actual large-bar/divider anchors are compared before repair. Width changes reuse successful texture bindings. Hidden large frames defer their reflow until visible or required editor entry; inactive party rows update only required root/border bounds and defer caption/texture work until Show or editing. Ordinary unit events make only the existing visibility checks and small width/state comparisons before any reflow. Party resource-mode changes and width changes share one owner, so later native value events or preview changes cannot restore the old health span.

The target's portrait-side fill overlap is reduced from 15 to seven UI units,
moving its right edge eight units left while retaining the same far-left edge
and health-label positions. The existing background and damage-loss texture
follow the narrower native StatusBar rectangle. Portraitless mode and player
geometry retain their previous spans. This reuses the existing geometry guards,
settings listener and size-change callback, with no new region, asset, material,
alpha pass, event, updater or allocation. The fill covers a narrower area, but
source inspection and pinned formatting do not establish measured GPU/FPS or
in-game alignment results.

The player/target outline correction adds two passive, mouse-transparent frames and no texture regions. Their portrait-mode bounds come from data-only alpha inspection of the unchanged prepared 256-by-128 sheets: pointed `(21,4)-(222,78)`, round `(23,11)-(218,75)`, boss `(23,1)-(245,81)`, elite `(23,1)-(227,81)`, rare elite `(23,0)-(245,82)` and rare `(23,0)-(227,82)`. Hidden portraits anchor the edit region to the actual closed border and extend only for enabled name/level captions. Bounds are mirrored and derived from the native owner/width delta. Target bounds include currently shown aura buttons from the tooltip module’s existing one-time discovery; the grouped registry adds no second discovery scan. Only editing samples measure those aura rectangles, using each widget’s effective scale. Cached edge coordinates skip unchanged anchors. The existing ten-Hz editor sampling and fresh drag/snap samples invoke the optional bounds callback, retrying unavailable caption heights without an idle updater. The active resize cache also observes changed edit-region dimensions, so aura or caption reflow can update the held opposite edge even at a stationary cursor. No artwork, native click bounds or confirmed geometry is changed.

Source/diff inspection and pinned formatting cover the geometry and shared save/discard paths. This is an explicit source-level drawing-cost increase for independent width, not measured FPS, GPU cost or pixel parity. No local tests, standalone validation or addon/game execution were run; packaged-client appearance and input remain unverified.

## Combat-text editor availability — 2026-10-27

The Combat text mode selector and status description stay outside one passive settings parent. When effective SCT mode is Off or Game settings, that parent uses the existing 0.45 alpha and every control below it disables mouse input: incoming/self text, damage icons, size buttons, class colors and all filter checkboxes. Headings, separators, labels and values inherit the same dimming. Custom restores the parent to full alpha and reenables its controls. All existing preference values are preserved, including the native incoming/self choice; availability itself writes no gameplay/native setting.

The shared editor availability helper now serves this group and the existing replacement-display dependents. It skips alpha/input writes when enabled state is unchanged. The existing SCT settings listener supplies the effective draft mode, including preview, profile loads, external mode changes, Confirm and discard. The lazy settings dialog adds one passive frame, zero texture regions, no animation, updater, game event, asset or SavedVariable. Source/diff inspection and pinned formatting only; local tests, standalone validation and addon/game execution were not run. Runtime appearance and interaction remain unverified.

## Guardian minimap timers — 2026-10-28

The default-off **Show guardian timers** checkbox uses the existing editor row
factory and display draft/profile/reset lifecycle. Enabling it retains defeated
minimap pins independently of the existing keep-icons choice. Guardian guidance,
native phase, minimap visibility and accepted-snapshot gates still apply.

Each existing pooled guardian pin gains at most one lazy FontString after its
first valid enabled countdown. Off by default allocates no timer labels. With
the option on, each visible known defeated lair adds one gold DEFAULT 8.6 outlined
text region and its black shadow below the icon. These glyphs add persistent
text/alpha drawing; existing medallion/check textures, UVs, materials, bounds and
mouse transparency stay unchanged. No image, texture region, marker frame,
event, updater or SavedVariable is added.
Each label receives an explicit 64-by-15 text box once at construction, since
this client does not supply an automatic width for its single center anchor.
The box leaves pin geometry and cached hover bounds unchanged. Font readiness
uses native face availability plus matching size/outline, like meter labels,
without requiring the requested alias and resolved font path to be identical.

The existing ten-Hz/deferred pin refresh samples `AZS_GetRunTime` at most once
when enabled countdown candidates can be drawn. The shared roster's `Remaining`
helper reuses its accepted run-clock anchor and 1.5-second smoothing bound;
minimap timers do not call the roster's health-bearing snapshot getter.
Per-frame projection skips timer work. Rounded-second caches skip repeated
formatting and native text writes; font readback retains failed assignments for
retry. Hidden/off/guidance-disabled paths skip timer sampling, formatting and
allocation. Retiring/recycling pins, unknown times and living replacements hide
and clear old labels; retained pins reuse their labels after showing again.

The two new UI captions have all fourteen source/runtime translations. CI-only
production-roster/source-extracted pin mocks cover defaults and drafts, native
pause/choice/regression timing, unknown times, hidden/off work, unchanged writes,
lazy pooling, explicit text dimensions, resolved font paths, font retries and
retirement. Local work is source/diff review and
pinned formatting only. These source costs do not establish live minimap
appearance, draw calls, GPU memory or FPS.

## Guardian Show dead control — 2026-10-27

Boss bars and Guardian tracker each have default-on current/maximum-health
checkboxes in the existing lazy settings dialog. Four standard checkbox rows
reuse its native control/label/hint construction; no encounter frame, font
region, artwork, material, alpha pass, event or updater is added. With the optional
percentage off, both values off empties and actually hides each existing health label while native fills
continue unchanged. One value alone omits the slash. Shared formatting caches
only the latest enabled values per label; with percentages off, changing a disabled value performs
no formatting or presentation write. Actual label text/visibility comparisons
still repair retired pooled labels.

Guardian health-width measurements retain one latest text/width record per
copied roster slot, prune retired slots and clear on option, scale, language and
view retirement. Unavailable glyph widths retry. With both values off the
tracker skips health formatting/measurement; its minimum pill width and
non-overlapping end caps remain intact. Hidden views defer all presentation
through their existing guards/controllers. The four booleans use the current
display table and normal draft/profile/reset paths, without another
SavedVariable. CI-only helper/display mocks are authored; local work is source
review and pinned formatting, without measured draw-call/FPS or live appearance
claims.

Guardian minimap names reuse each existing passive pin and the shared native
tooltip. Accepted minimap point copies carry only their received optional name.
The existing ten-Hz/deferred waypoint refresh performs one cursor/minimap
geometry sample when guardian pins exist, then tests their cached drawn centers
only while the pointer is inside the map. The per-frame projection path adds no
cursor reads. Unchanged pin/name/owner skips tooltip content writes; hide/recycle clears
only an owned hover, while hidden/editing tooltips stay suppressed. Native
minimap click/wheel input remains available because pins keep mouse input off.
No marker frame, texture, hit region, event, updater, artwork, setting or saved
state is added; the existing native tooltip draws only during hover. Guardian
pins register their cursor placement once in the existing icon-owner registry.
The shared visible-tooltip updater samples the cursor and uses the existing
scale-aware, changed-only cursor anchor regardless of the global cursor option;
it does not fight the saved bottom-right Layout seat. Other owners keep their
saved/icon/global-cursor behavior. This adds registry metadata and an existing
owner-hide hook per pooled pin, with no additional positioning frame or updater.
The hide hook checks actual shown state so cleanup does not repeat Hide writes.
Source-extracted placement mocks cover this owner-specific routing. This is
source-level cost evidence, with CI-only mocked coverage and no measured FPS or
live input/appearance result. See [GUARDIAN-TRACKER.md](GUARDIAN-TRACKER.md#minimap-names).

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

Accepted pet publications now contribute exact localized name/path metadata to the shared SCT/meter resolver after the pet reader's full validation. A changed publication adds one pass over its already copied display groups; timer-only updates do not repeat it. Cache hits add one name lookup before generated catalogs and can avoid weaker item/database lookups. There is no new native getter, event, updater, bitmap, frame or drawing region. The meter's existing refresh replaces a bound question mark when the path becomes available, retaining binding caches, circular masking and all off/hidden/icon-off guards. Only unsaved display names/paths remain after despawn, with zone/language/world cleanup; no summon IDs, timing, damage or roster history is learned. Source inspection and pinned formatting do not establish in-game appearance or FPS.

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

## MSBT-style combat text — 2026-10-27

The optional outgoing stream shares the existing SCT controller,
parser/intake, exact duplicate groups, active list and lazy text pool. Each
label still uses its original two passive frames, FontString and optional icon.
The movable stream adds one passive `sctMSBT` owner lazily on first effective
Custom/MSBT enable and reuses it afterward. This owner has no drawing regions.
Its shared editor handle adds one button, four corner buttons, 24 solid-texture
corner marks, one FontString and the standard native border. Those regions draw
only while editing the enabled style. There is no new gameplay texture/material,
UV state, asset, native event, updater or SavedVariable. Full bursts retain their
existing grouping and 1.45-second lifetime,
so peak active allocations can still grow with the actual event load.

Holders inherit the owner's movement, scale and visibility; animation anchors
remain local without per-frame owner geometry reads. Layout scaling refits only
active, visible labels through `onResize`. Holder parent changes occur only on
pool acquisition across styles, restoring the original parent for enemy text.
Default coordinates, curve, spacing and cadence remain unchanged. Layout hiding
retires active/queued hits and skips hidden intake, resolver work and animation;
unhiding admits only new hits. The cached visibility policy uses the existing
listener, and mode/world transitions retire the owner request and edit handle.
Geometry/visibility use the existing Layout/profile store and shared discard
paths, with no new gameplay persistence.

Only this style adds a newest-first spacing pass over active labels. It uses
pooled scalar offsets, existing text scale/crit sizing and one exponential
blend per update, with no per-frame table, glyph measurement or texture bind.
The ordinary animation pass applies a changed-only curved center-relative anchor and
reuses the existing changed-only scale/alpha writes and conditional measurement
retry. The default enemy layout retains its original animation equations and
does not run the spacing pass. Empty active lists skip the added work.

MSBT-style text skips origin creation, per-plate SCT coordinate/health-loss
sampling, per-hit plate discovery and origin resolution. The existing skin
discovery and visible nameplate/filter presentation remain independent. With V
off it also releases the native backing plate feed, so native projection and
collision work are no longer forced by this style. V-visible plates keep native
costs. Style transitions retire queued/active labels and matching state, reuse
the pool and restore the current native V request without preference writes.

The original checkbox has been replaced by the shared three-way style selector
described in [DIABLO-SCT.md](DIABLO-SCT.md). Existing MSBT saves/profiles migrate
through the display normalizer; the stream's Layout owner is unchanged.

Source/diff review and pinned formatting only; no local tests, standalone
validation or addon/game execution. CI-only native mocks cover the production
controller's defaults, movable-owner anchoring, burst spacing, tracking handoff,
hidden retirement, mode previews, cleanup and pool reparenting/reuse. These
source counts and authored assertions do not establish
in-game layout, native-name restoration, visual parity or FPS. Behavior is in
[API-NOTES.md](API-NOTES.md#msbt-style-combat-text--2026-10-27).

## Names-only nameplates — 2026-10-27

The default-off `nameplatesNamesOnly` choice is cached by the existing SCT
display listener and consumed by its existing visible-plate refresh. Each
style reuses its name label, remembers its color and changes visibility only
when the effective mode changes. Names-only updates copy changed native names
and reaction colors, then skip cosmetic health range/value/color writes and
raid-icon lookup/binding. Native health-loss matching, coordinate sampling,
collision placement, V/Shift-V ownership and the boss/guardian filter keep
their current lifecycles. Masked plates still skip the entire style refresh;
showing again applies the current choice and current native state.

No per-plate frame, drawing region, texture/material image, UV state, animation,
event or updater is added. The name overlay anchors to its visual parent at the
same one-unit inner inset, independently of a hidden cosmetic bar. Starting in
names-only mode now omits the cosmetic StatusBar and the shadow, background,
fill and raid-icon regions. They allocate once on the first eligible regular-bar
refresh and remain pooled afterward. Filtered plates do not trigger that lazy
allocation. Returning to Names only actually hides those existing regions and
skips their updates; only the custom name draws. Switching back reuses the
original art and pool without repeat allocation or fixed texture rebinding.
Native source bars, collision placement and required SCT tracking remain live;
this is not a zero-cost native renderer or a measured GPU saving. The lazy
settings dialog adds one standard checkbox: one button,
four texture regions (box, check, hover and divider) and two text regions,
reusing existing art and drawing only while its page is visible.

The nameplate **Font size** row reuses the numeric editor control and cached
display listener. A shown label changes its font and proportional text-box
width/height only when the effective size changes; failed font assignments
remain retryable without caching success. Masked plates defer the work until
shown. No text measurement, new plate region, native geometry change, event
or updater is added. Larger glyphs cover more screen pixels and can require
additional native glyph-atlas entries; this is not an FPS or memory saving.
The lazy editor adds one container, two styled buttons and their two caption
frames: 22 existing-art texture regions and five FontStrings after opening it.
Those controls draw only with the Nameplates settings page.

These are source-level work and visible-region observations, not measured
draw calls, GPU memory, FPS or native world-text parity. Source/diff review and
pinned formatting only; no local tests, standalone validation or addon/game
execution. Settings and behavior are documented in
[API-NOTES.md](API-NOTES.md#names-only-nameplates--2026-10-27).

## Boss and guardian nameplate filter — 2026-10-27

The default-off `nameplatesBossGuardiansOnly` option adds no gameplay frame,
texture, material or updater. It uses the current SCT controller's OnUpdate and
existing message subscription. While enabled, phase/receipt retirement and the
official unit-list index refresh run at five Hz. A matching source reference,
timestamp and receipt generation skip index rebuilding. Accepted changes reuse
exact-name/native-range buckets, with at most the native 40 entries; retired names
are removed. Off clears the index and skips its native metadata reads.

Accepted metadata indexes the original maximum, its float32 rounding and the
native ceil/uint32-clamped maximum with its float32 rounding. Whole-number
publications below 2^23 also index an upper ceiling only where a fractional
float32 actor maximum can serialize to that integer: all integers below 2^22,
and even half-ties below 2^23. This retains at most four distinct exact keys per
entry; it is not a per-plate tolerance search or a carried-forward identity.
The sleeping-to-awake conversion changes accepted display metadata only. These
numeric aliases are computed only when the accepted publication changes, reusing
the same buckets. Published elites mark collisions
ambiguous across those aliases too. No per-plate conversion, name-only bypass,
tolerance search, damage estimate, percentage-to-HP inference or new getter is
added. Names-only labels no longer depend on health-widget anchors, and unused
bar artwork remains unallocated until an eligible regular plate needs it.
CI-only full-controller/style mocks cover both options together, native range
representations, wake ceilings/serialization boundaries, exclusions/ambiguity, mode/V changes, retirement, lazy pooling
and unchanged writes. Local work is source/diff review and pinned formatting.

Shown hostile plates add a cached-index lookup using their native name and, only
for candidate names, raw health range. This stays in the existing native
show/health hooks and per-frame plate scan so reuse cannot carry stale styling.
Native-hidden plates return before filter/style work. Filtered plates reuse the
existing transition-only recursive draw-layer and hit-rectangle masking; their
complete custom visual child stays hidden and skips skin updates. SCT's native
position/health sampling and full combat-text animations continue unchanged.
No per-frame table, string formatting, texture bind or new artwork is introduced
by the filter. Existing pooled skins remain allocated; excluded skins contribute
no visible custom regions. This does not remove native plate collision work.

The existing lazy settings dialog adds one category button (12 texture regions
and one caption) and one checkbox row (four texture regions and two captions).
These reuse the editor artwork and draw only with their shown editor parents;
no new material or per-plate region is added. The maximum added allocation is
16 texture regions and three FontStrings after opening the editor. Source
counts are not measured draw calls, FPS, GPU memory or visual parity. The
anonymous-plate identity limit and snapshot policy are documented in
[API-NOTES.md](API-NOTES.md#boss-and-guardian-nameplate-filter--2026-10-27).

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

The cache guide, minimap markers and bottom cache-cost counter share the supplied
32-by-32 `waypoint/Chest.blp`, preserving their existing 32-, 16- and 18-unit
regions respectively. Full UVs retain the source chest and transparency without
cropping or baking another image. Textures still bind only when their existing
views/pins are created. Region counts, visible bounds, polling, hidden-view
guards stay unchanged; no updater or rendering pass is added. Lossless
source-pixel comparison does not establish in-game appearance or FPS.

The full world-map overlay is removed: no lazy map-layer frame, per-destination
button/texture pools, map click/hover handlers, tracked-pin styling or
`WORLD_MAP_UPDATE` subscription remain. Its periodic map traversal, closed-map
pin cleanup and map-tooltip refresh work are gone. The retired diamond BLP and
four map-only captions are removed from the runtime payload/catalogs. Read-only
map context, coordinate projection and scale calibration remain private
navigation helpers for HUD/minimap guidance; they allocate no world-map UI.
These source-level region and work reductions are not measured FPS results.

Native chat movement is retired by collapsing the inherited full-size title
region and keeping the message pane non-movable. Attachment and existing native
event/selection/Show/one-second presentation refreshes compare the current
title-region anchors, size and movable flag; unchanged state causes no writes.
This stops active native movement only when repairing those inputs, before the
normal anchor cache is refreshed. It adds no region, texture, event, pointer
poll or updater, and leaves per-frame slide work, native links/wheel input,
hidden-view policy and shared Layout movement/resizing unchanged. Native chat
remains resizable behind its hidden controls. Source review is not live input
or FPS evidence.

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
Cooldowns and circular rims retain their original layers above the icons.

Equipped rarity adds one optional inventory-quality read per populated slot to
the existing five-Hz equipment refresh. Native color lookup retries missing
metadata and otherwise runs only when quality changes; empty slots skip it.
The same five rim regions use a neutral shaded copy at `(664,56)-(736,128)`
inside the existing atlas and change vertex tint only when RGB changes. Stock
and neutral UVs switch only on known-rarity availability. Empty slots restore
the original gold crop and white vertex tint. The pooled effects card changes
text color before its unchanged-text measurement shortcut, without adding text
regions or remeasuring for color alone. Hidden/off views stop these reads and
writes through their existing controller. Atlas dimensions, file count,
fourteen icon strips, alpha coverage, material texture and visible-region count
stay unchanged; mixed empty/equipped slots can use two rim UV windows. No GPU
or FPS result is inferred from these source counts.

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

The timer's cosmetic layers use 44 shared regions plus up to 28 lazily prepared
tier glints, for at most 72 allocated/visible regions, plus the base pill,
schedule markers and one supported-rank numeral. Normal blue mode uses the
43 flow/foam pieces; Heroic glow and glints can draw alongside that motion. Active boss markers retain their
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
[UI renderer](https://github.com/samwhosung/benilla/blob/289b0ec5f64d7f58fa1a3f3b2347c0a056afba77/crates/benilla-app/src/ui_pass.rs#L947)
groups contiguous quads with the same texture and material, including their UV
clamp. The native-base
[layer ordering](https://github.com/samwhosung/benilla/blob/289b0ec5f64d7f58fa1a3f3b2347c0a056afba77/crates/benilla-ui/src/order.rs)
and
[texture sort](https://github.com/samwhosung/benilla/blob/289b0ec5f64d7f58fa1a3f3b2347c0a056afba77/crates/benilla-ui/src/script/layer_batch.rs)
can further permute equal-texture quads across all owners sharing a flat
stratum, level and layer. Owner creation order alone cannot guarantee a batch.
Its
[extraction code](https://github.com/samwhosung/benilla/blob/289b0ec5f64d7f58fa1a3f3b2347c0a056afba77/crates/benilla-app/src/ui_script/extract/mod.rs#L137)
defines cropped half-texel clamps. These sources explain the proposed batching
and the reason to retain every jewelry strip boundary. They do not establish
the complete packaged renderer's identity or a measured performance result.

### Submitted regions and engine boundaries — 2026-10-28

Count allocated regions, shown regions, nonzero-alpha regions and submitted
quads separately. The inspected native-base extractor skips hidden regions and
disabled owner layers, but still emits zero-alpha textures. Its fragment shader
samples before applying tint alpha. Thus earlier authored visible-region counts
describe the artwork, not a guarantee that transparent alternatives contribute
no rendering work. The unit-border and nameplate-layer fixes above remove those
specific submissions; retained hidden pools still occupy resident objects.
See [hidden/alpha extraction](https://github.com/samwhosung/benilla/blob/289b0ec5f64d7f58fa1a3f3b2347c0a056afba77/crates/benilla-ui/src/script/extract.rs#L218)
and [texture sampling](https://github.com/samwhosung/benilla/blob/289b0ec5f64d7f58fa1a3f3b2347c0a056afba77/crates/benilla-app/src/shaders/ui_quad.wgsl#L124).

SCT's authored crit pop retains its continuous inner scale and required refit.
Current benilla SetScale invalidates subtree layout and global text-measurement
tracking; the next sweep checks all nonempty FontStrings and remeasures only
stale entries. Wenilla retains that path. Glyph bitmaps cache by integer device
pixel size, so fractional scaling does not rasterize every glyph every frame.
No verified addon API scales an already rasterized label with identical output;
an engine-side narrower invalidation remains a separate investigation.
See [scale invalidation](https://github.com/samwhosung/benilla/blob/289b0ec5f64d7f58fa1a3f3b2347c0a056afba77/crates/benilla-ui/src/script/model.rs#L1796),
[measurement sweep](https://github.com/samwhosung/benilla/blob/289b0ec5f64d7f58fa1a3f3b2347c0a056afba77/crates/benilla-ui/src/script/layout.rs#L2047)
and [wenilla's equivalent](https://github.com/Arnesen/wenilla/blob/d68dcc539460e8fc5169105c790443489d91ca76/crates/benilla-ui/src/script/model.rs#L1979).

Animated UV windows can create new material keys, but the inspected material
cache clears above 256 entries before a rebuild and prunes removed images. This
establishes possible churn, not an unbounded material leak. Native OUTLINE is
baked into glyph atlas cells, while shadow emits another glyph pass. Required
shadows, jewelry's fourteen crops, independent timer effects and full SCT
lifetimes retain their authored drawing cost. Competitor hit caps, summed hits
and simpler artwork change those behaviors and are not equivalent fixes.
See [material lifetime](https://github.com/samwhosung/benilla/blob/289b0ec5f64d7f58fa1a3f3b2347c0a056afba77/crates/benilla-app/src/ui_pass.rs#L1004),
[outline baking](https://github.com/Arnesen/wenilla/blob/d68dcc539460e8fc5169105c790443489d91ca76/crates/benilla-app/src/ui_text/outline.rs#L1)
and [shadow emission](https://github.com/samwhosung/benilla/blob/289b0ec5f64d7f58fa1a3f3b2347c0a056afba77/crates/benilla-app/src/ui_script/extract/text.rs#L215).

These immutable public revisions explain the opportunities and limits. They do
not establish the installed package's revision, live CPU/GPU cost or resolution
of the reported stalls/out-of-memory behavior. No engine source or packaged
client is changed by this addon PR.

## Shared addon identity

The release package and local installation both use the `SurvivorsDragonUi`
folder and `SurvivorsDragonUi.toc`. The shared asset root and load-event name
use the same identity. Local work is edited directly in the installed Git checkout without identity translation or a separate worktree/sync step.
The action bar, range indicator, XP bar, minimap and window skins obtain their
texture subfolders through `DFRL:GetInfoOrCons("tex")`, as the newer modules do.
GitHub Actions enforces the single shared root across runtime Lua sources.

## Full chat history

**Use default chat** is a separate reload-only display choice, default off.
After Confirm and `/reload`, all four custom chat initializers return before
allocating presentation or diagnostic state. There is no SDUI chat root,
indicator, movement region, capture collector, archive, Copy command/dialog,
native method/script wrapper, settings listener, readiness frame, Layout group
or chat updater. Native chat owns its controls, fonts, messages and input. The
existing saved Copy choice is retained but cannot activate capture in this mode.
The normal chat Performance Mode behavior is unchanged.

Shared loot parsing and delivery deduplication move to `core/messages.lua` with
no added frame/region or updater. Independent SDUI loot delivery uses two message
subscriptions on its existing controller only while native-chat mode and active
SDUI loot ownership require them; mode/ownership/world retirement detaches them.
Custom-chat mode retains its original observation path without duplicate event
intake. Banners use the shared delivery helper and skip absent capture APIs.
CI-only fixtures assert skipped allocation/hooks, native ownership, reload-only
settings/profile/reset behavior, normal feature recovery, shared broadcast
semantics and independent loot/banner delivery. Source review and formatting do
not establish in-game rendering, memory use or an FPS result.

Marks chat formatting runs only during the existing accepted native message
path. It reuses cached named-field templates, retains original integer/decimal text and
adds no balance getter, currency history, frame, drawing region, asset, event,
updater or saved state. The collected-item parser supplies a positive reward
only when that exact suffix matches. Active SDUI marks popups hide recognized
conversion/balance lines from custom chat after intake; other modes or unavailable
popups retain fallback chat. The shared loot service/view guard permits a conversion card only in SDUI
mode with Show marks rewards on; other collected items stop before queueing and
icon metadata work.
Unknown text stays native. Extra compact chat lines use the native message
pane/history and its existing fonts/fades; there is no separate marks view.
Source/diff review and pinned formatting only; no local tests, standalone
validation or addon/game execution. CI-only mocks cover both formats across
all fourteen catalogs, link/color preservation and marks-off popup exclusion.

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
analysis, package/asset ownership and duplicate inventories, checker regression
fixtures, fractional timer-artwork sampling and the jewelry reference models.
The payload report compares file counts, bytes and deterministic in-memory ZIP
sizes. The source and artwork checks do not execute addon Lua or client code.
The separately authorized mocked UI step loads selected production Lua in CI
to assert cooldown/range write budgets, hidden work, loot pool reuse/expiry and
failure cleanup with native-HUD restoration. It observes mock calls and objects,
not the client's renderer. Configuration/registration source contracts report
orphan candidates and reject newly orphaned settings/captions and concrete schema,
shared-API or callback mistakes. No local test or game execution is authorized.
See [PR checks](PR-CHECKS.md) for enforced failures, dynamic-ownership evidence,
preparation-input retention and the limits of exported-helper candidates.
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

## Totems in Pet frames — 0.125.0, 2026-10-28

The pet controller now accepts the separate official totem feed through its
existing tenth-second update and CHAT_MSG_ADDON listener. Each stream owns a
small descriptor and reusable copied group tables, with independent receipt,
validation and retirement gates. Only changed publications and visible enabled
temporary timers call that stream's getter. The totem count is copied directly;
there is no expansion into individual rows or countdown-based count mutation.
A native run-time readiness read accompanies eligible totem timer refreshes;
hidden/timer-disabled groups skip that extra read. Static packet/stamp global
names are prepared once, and unchanged publications do not relearn icon metadata.

Each additional visible totem kind uses the existing lazy pet row: two passive
frames, two row labels and a count label, one native portrait texture and one
gold rim texture on the successful native path. These are additional visible
regions proportional to represented kinds, independent of the number of totems
within each kind. The existing lazy strip compatibility path retains its
scale-dependent region/overdraw cost and failure retries. Geometry, UVs,
layers, alpha, portrait binding cache and gold artwork are unchanged. Retired
rows return to the same pool; hidden snapshots allocate no row or artwork.

No controller, event registration, runtime module, asset, setting or
SavedVariable is added. The feed has no individual identity, health, damage or
pulse information; no such history is retained or inferred. CI-only scenarios
load the production controller against explicit fake native snapshots to cover
mixed/independent feeds, validation, timer readiness, pauses, changed-only work,
hiding, settings, pooling and cleanup. Local source/diff review and pinned
formatting do not establish live behavior, drawing submissions or FPS/GPU gains.

## Heroic affix row — 2026-10-28

The selected #04 affix row shares the run timer's existing phase-first reader,
zone/run receipt handshake, deferred packet handling and tenth-second retry
gate. It adds no event registration, updater, animation, setting or saved state.
A visible accepted zone snapshot is parsed only when its identity, receipt,
list bytes or language change. Static rows skip text lookup, anchors, UVs,
visibility and texture writes; failed artwork remains retryable at ten Hz.
Hidden owners allocate no affix rows and do no affix painting or metadata work.
Zone/run/world retirement clears identities and owned hovers; Layout hiding
inherits native visibility and the shared tooltip registry's cleanup.

Each represented kind lazily allocates one mouse-enabled hover frame and two
Texture regions, with no FontString. The chosen three kinds therefore cost at
most three frames and six visible textures when all three are actually
published. Frame and rim diameter is 22 units; the icon is `22 * 34 / 39`, with
five-unit gaps and a three-unit offset below the bar. The existing Layout
region adds the row's 25-unit vertical inset and includes any horizontal
overflow without changing the saved timer geometry. Frames and successful
artwork bindings remain pooled across publications and toggles.
The same count/bounds transition refreshes only the default boss placement,
reserving 33 units for the row and first boss caption; saved/draft positions
remain authoritative. There is no per-frame placement or new layout polling.

One new 256-by-64 lossless BLP atlas holds the three circular icons. Each icon
uses its fixed 64-square UV cell; the red rim reuses the neutral jewelry crop
at `(664,56)-(736,128)` in the existing atlas and the same native RGB tint
path as jewelry. There is no native-circle call, strip fallback, changing UV
animation or extra per-icon glow. Icon/rim alpha overlap, small persistent
regions, texture/material differences and distinct UV clamps retain their
normal renderer costs. Sharing an atlas does not establish batching or reduced
draw submissions. No GPU-memory, live FPS or pixel-parity result is claimed.

Eight CI-only scenarios extract the actual affix-view factory and use the
production tooltip registry with explicit fake native widgets. They cover
order/centering, exact rim crop/tint, unchanged and hidden work, malformed and
unknown keys, receipt retirement, asset failure cadence, pooling, owned/foreign
hover cleanup and all fourteen native name/description catalogs. The parent
timer's event integration was source-reviewed; these mocks do not establish
live delivery or the packaged Lua VM. Local work was source/diff inspection,
image-data preparation and pinned formatting, without local tests, standalone
validation or addon/game execution.
