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

### Rounded waypoint labels

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
allocation. Once built, the original three-card pool, crop, quality rim, icons,
UVs, geometry and authored fades remain unchanged and reusable. Both non-custom
modes actually hide all cards and stop cosmetic animation. Layout hiding remains
separate: current expiry and bounded metadata retries continue without painting.

Positive item conversions reuse the existing name region, showing the item and
received marks amount. Only enabled SDUI conversion rewards pass shared
service/view eligibility; other collected items stop before queue/metadata.
One latest formatted reward label per card is cached and cleared on language
change/retirement. No new drawing region, currency artwork, material, event,
updater, gameplay counter/history or SavedVariable is added. The two normalized
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

| Frame group                                             | Owners and preserved performance boundary                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Pet summons and native primary pet                      | `modules/unit/pets.lua`, `modules/unit/mini.lua`: native cached circles, receipt/roster reuse, visible timer reads and actual native-state repair.                                                                                                                                                                                                                                                                                         |
| Equipped jewelry                                        | `modules/ui/jewelry.lua`: original fourteen-strip UVs, grouped texture order, unchanged layout, idle cooldown gating and metadata retries.                                                                                                                                                                                                                                                                                                 |
| Run/boss/tally, guardian tracker                        | `modules/ui/run.lua`, `modules/ui/guardians.lua`, `modules/ui/guardian_tracker.lua`: receipt-based schedules/copies, pooled rows, hidden cosmetic guards, fixed pill backgrounds, retained marker/foam/glow equations and edge-to-edge bezel joins.                                                                                                                                                                                        |
| Player/target/party, resources and portraits            | `modules/unit/player.lua`, `target.lua`, `mini.lua`, `resources.lua`, `portraits.lua`, `core/widgets.lua`: shared styling, completed fades, changed styles, exact native-unit routing, native health and model-paint evidence.                                                                                                                                                                                                             |
| Character and equipment                                 | `modules/ui/character.lua`: coalesced deferred work, measurement/discovery caches, actual native anchor repair and the three authored quality-rim passes.                                                                                                                                                                                                                                                                                  |
| Revive, stored levels, loot and banners                 | `modules/ui/revive.lua`, `levels.lua`, `loot_view.lua`, `banners.lua`: passive pools, changed-only presentation, requested visibility, bounded view queues and required hidden lifetime/ownership cleanup.                                                                                                                                                                                                                                 |
| Action bar, range and XP                                | `modules/bars/bars.lua`, `range.lua`, `modules/xprep/xprep.lua`: shared controllers, event-driven work, transition-only range fades, final cooldown sampling and pending-only XP animation.                                                                                                                                                                                                                                                |
| Minimap and waypoint guides                             | `modules/map/map.lua`, `buttons.lua`, `navigation.lua`, `waypoints.lua`: reusable accepted snapshots/pins and native direction/position sampling; skip unchanged clock labels and button anchors. The transparent glyph adds one texture, no idle polling or extra hover region; its pointer updater exists only while dragging. Square-edge adaptation runs on foreign placement calls or map/show/load events. See `MINIMAP-BUTTONS.md`. |
| SCT and nameplates                                      | `modules/nameplates/sct.lua`, `style.lua`: event-batch discovery plus independent frame discovery, preserved matching/animation, cached metadata and unchanged native styling.                                                                                                                                                                                                                                                             |
| Layout/editor, tooltips, chat, Copy, menu and inspector | `core/layout.lua`, `editor.lua`, `tooltips.lua`, `fstack.lua`, `modules/chat/*`, `modules/menu/menu.lua`: bounded edit sampling, passive/pool reuse, owner/scale-aware hover work, native chat/fades, retained opt-in diagnostics and hidden inspector shutdown.                                                                                                                                                                           |
| Meter and general warning overlay                       | `modules/ui/meter.lua`, `modules/ui/ui.lua`: native circles, one-Hz rate display with five-Hz data observation, visibility/change guards, transition-only warning visibility and preserved gradient animation.                                                                                                                                                                                                                             |

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
region, artwork, material, alpha pass, event or updater is added. Both values
off empties and actually hides each existing health label while native fills
continue unchanged. One value alone omits the slash. Shared formatting caches
only the latest enabled values per label, so changing a disabled value performs
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

The lazy Combat text page adds one standard checkbox: one button, four texture
regions (box, mark, hover and divider) and one caption, using existing editor
art. It joins the shared inactive-mode alpha/input guard. The checkbox sits beside SCT size, with the class-color control below it;
all filters fit the existing page without enlarging the dialog or adding scrolling.

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

Marks chat formatting runs only during the existing accepted native message
path. It reuses cached named-field templates, retains original integer text and
adds no balance getter, currency history, frame, drawing region, asset, event,
updater or saved state. The collected-item parser supplies a positive reward
only when that exact suffix matches; chat displays it independently of the popup
mode. The shared loot service/view guard permits a conversion card only in SDUI
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
