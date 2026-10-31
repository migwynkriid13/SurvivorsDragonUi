# PR checks

Every PR push runs formatting, static Lua analysis, package and asset inventory,
source contracts, checker regression fixtures, mocked UI lifecycle tests and the
existing artwork checks. No game starts. Only the separate mocked UI test step
executes selected production Lua against fake native boundaries. Keep the `Formatting and local dead code` job as a required
check in the repository's branch rules; editing a workflow does not configure
branch protection by itself.

## What fails a PR

- Prettier or StyLua formatting differences, or a missing TOC version increment
  when the installable payload changes.
- Luacheck findings for unused locals, loop variables, local assignments,
  overwritten table fields, uninitialized locals and unreachable code. Native
  callback arguments and dynamic game globals remain outside this warning set.
- A duplicate, unsafe, missing, symlinked or case-colliding package path; disagreement
  between the runtime manifest and TOC; or tracked runtime Lua left outside the TOC.
- Test/tooling or reference-only Lua entering the payload/TOC, or an invalid
  reference-source classification with a missing file, non-Lua path or empty reason.
- An unexpected payload file. The addon ZIP contains Lua, BLP artwork, TTF fonts, its TOC
  and the required artwork license. Tools, test fixtures, documentation and
  authoring inputs stay out of it.
- A missing or unreferenced bundled texture/font, an unclassified file under `media/`,
  or a stale dynamic-owner/preparation-source rule.
- A new byte-identical runtime Lua, texture or font copy. Existing duplicate groups
  remain visible in the report; removing a member is allowed. A changed group
  cannot silently add another copy.
- A failing checker regression fixture or one of the existing artwork/root checks.
- A runtime Lua closure capturing more than the client's 32-upvalue limit.
  The source check follows lexical bindings, including captures carried through
  intermediate closures. Lua 5.1 lifecycle mocks alone cannot detect this Lua 5.0
  load failure. Mode switching and presentation use separate Layout helpers so
  the editor entry function stays below the limit.
- Duplicate literal table keys or module/Layout registrations, a display key missing
  from normalization, a normalization row reading the wrong key, an unknown literal
  display key, or an unknown method in the shared tools/display/Layout/locale/SCT APIs.
- A literal Layout option/flag with no reader in `core/layout.lua`, or a concrete
  broken callback supplied in its options table.
- A concrete callback registration that names an undeclared function or supplies
  a literal non-function. Aliases, parameters and conditional callbacks remain
  conservative evidence; unresolved dynamic references are reported for review.
- A setting or UI caption that becomes orphaned relative to the PR merge base.
  All current candidates are reported; there is no permanent ignore baseline.
- A failed production UI lifecycle assertion described below.

Checks continue after individual findings and report their results together.
The final step fails the job if any setup or check failed. New pushes cancel
superseded runs of the same PR. The workflow has read-only repository access
and does not modify PR contents or publish a release.
Independent UI fixture processes also continue after a failure. The runner
reports each failed fixture and exit code together after both extracted-source
and full-controller cases, while source-preparation failures still stop before
execution. CI-only Python regressions use fake subprocesses to verify that an
early failure in either group cannot skip later fixtures or produce success.
An explicit Bash shell enables `pipefail`, so piping fixture/model output into
`tee` cannot hide a failing check.

## UI work and cleanup tests

Nameplate camera cases use the production controller with explicit native
mouse-look boundaries. They cover right-button entry, left/native handler
preservation, synchronous synthetic release, real WorldFrame/plate release,
death/reuse during a hold, hidden/filtered plates, pre-existing/external camera
ownership and world/logout/reload cleanup in both Performance Mode states.
Reentrant world hiding, unnotified native stops and partially failed starts
clear or replace owned state without sticking later presses.
Missing APIs retain native interaction; repeated discovery and idle updates add
no hooks or drawing work. These cases remain CI-only and were not run locally.

Meter spacing cases use the production meter with explicit native text metrics.
They cover reclaiming unused numeric space, caption-aware metric caching and
retries, width/font/scale changes, independent name/number font sizes, preserved
native values/row geometry, hidden/off/disabled-number work and pooled-row
retirement. Display/editor cases cover inherited older saves, normalization,
preview/Confirm/discard/profiles/resets and searchable controls. These cases
remain CI-only and were not run locally; native glyph fit is unverified.

The editor fixture covers metadata search without constructing unopened pages,
active-language/English matching, supported case folding, literal punctuation,
empty results, pooled paging, fixed-width plain rows and their single hidden
hover texture, custom and ordinary option redirects, current
row offsets, pending drafts, shared Escape/Cancel, hidden focus/query cleanup
and unchanged/idle work. It loads the real navigator and settings constructor
over explicit native boundaries. Search only navigates to existing controls;
these CI-only cases do not establish in-game glyph fit or native scrolling.
They were not run locally.

SCT font-choice cases use real display notifications to check both buttons'
selected and native highlight states when switching in either direction, plus
unchanged clicks, hidden presentation and Cancel restoration.

Profile-save cases exercise the production Layout/Display/Profiles transaction
with fake native geometry and font/SCT owner boundaries. They cover save and
overwrite closing through one shared commit, Enter, pending numeric input,
validation failures, independent snapshots, load/delete previews, Cancel,
reload/world retirement and reset preserving saved profiles. Fresh production
Display/Profiles owners receive copied confirmed globals and load the setup.
The production editor fixture exercises translated save/overwrite buttons,
keyboard saving and a rejected shared commit without a staged replacement.
These are CI-only mocks, not tests of client serialization, external managers or
filesystem persistence; they were not run locally.

The full XP-controller fixture also covers default-off Show XP text, malformed
saves, preview/Confirm/discard/profile/reset, lazy hidden preparation and label
reuse, compact current/required XP without a percentage, immediate native text
during animated gains, toggles that preserve active
animation, Performance Mode, level/world/invalid-data recovery, zero XP, unchanged
caption writes and detached placement. The editor fixture exercises its actual
Action bar checkbox. Coverage is CI-only; no local tests or game execution.

Global font cases load the production font/display owners with explicit native
font boundaries. They cover enum normalization, preview/Confirm/discard/profiles/
reset, preserved native sizes/flags, independent text, hidden Show ordering,
rejected assignments, fallback recovery, reuse and unchanged writes. The editor
fixture exercises the Layout selector; SCT and segmented timer fixtures require
their production setters to opt out. These cases remain CI-only and were not
executed locally. See [FONTS.md](FONTS.md).

Health-format fixtures cover the independent default-on Unit frames, Boss bars
and Guardian tracker shortening choices through the real display normalizer,
preview/Confirm/discard/profile/reset paths. Production formatter/health owners
cover full whole numbers without suffixes/exponents, format-aware cache changes,
unchanged percentages and native fill, disabled current/maximum labels, pooled
guardian width invalidation, hidden recovery and unchanged writes. The production
boss row pass also forwards its own choice without changing health-loss state.
These cases remain CI-only and were not executed locally.

Player-absorb cases exercise the production resource reader, player absorb
owner and shared health labels. They cover current amount and uncapped
percentage of received maximum HP, independent text choices, shortening,
deferred run reads, Performance Mode text without overlay allocation, invalid
data, hidden work, phase/zone/world retirement, failed text/texture retries and
unchanged formatting/writes/allocations. The native boundaries are explicit;
no buff values, capacity history or client files are read. Coverage is CI-only
and was not executed locally.

The default-off boss/guardian percentage cases cover independent transactions,
current-only/maximum-only/combined/percentage-only captions, calculation from
full values in both number formats, zero/100% boundaries, invalid health,
rounded-caption cache reuse and release, hidden recovery, stable allocations
and unchanged health fill/loss ownership. Existing production labels and native
boundaries are used; no local checks or game execution are authorized.

The default-chat fixture invokes all four production chat initializers with the
native option enabled and an existing enabled Copy preference. It asserts no
custom namespace, frame allocation, native method/script replacement, Layout
registration, input/tab hiding, collector or Copy command, and checks reload-only
draft/Cancel/Confirm/profile/reset behavior. Other cases retain custom formatter
and Copy setup, shared cross-frame delivery semantics and native-chat loot intake
with active-only message subscriptions. The banner fixture also runs without a
custom chat namespace. These remain CI-only; no local tests or game execution.

`scripts/run_ui_contracts.py` runs scenarios in Lua 5.1 with fresh mock
state per scenario. Tests exercise the actual source, including the shared text
helper, cooldown controller, range controller, HUD owner, loot intake and loot
renderer, target-health owner, health labels, damage-loss animation and SCT
controller. There is no copied cooldown algorithm, runtime test export, shipped
fixture, client-data reader or game process. AST selection extracts the original
cooldown declarations and constants by their exact byte ranges; a missing or
ambiguous declaration fails preparation.

The assertions cover:

- Editor navigation loads `core/editor.lua` against explicit native scroll and
  glyph-width boundaries. It covers grouped visibility, original section owners,
  retained section state, per-category offsets, duplicate-heading suppression,
  search redirects and lazy result pooling, close/reopen, compact/wrapped caption spacing,
  compact numeric captions, mixed-height two-column placement, odd last rows,
  full-row master clearance, locale reflow and single-option/mode spacing,
  missing-metric retry, stable allocations and hidden/unchanged work without an
  idle updater. The shared button cases cover pressed/released/leave/hide recovery,
  native 1/0 disabled values, click callback ownership, selected highlight locking,
  narrow/resized caps and deferred hidden writes. The fixture is CI-only and was
  not run locally; it does not render the dialog.

  The same fixture loads the AST-extracted production settings constructor with
  the actual locale/Display/Profiles owners and explicit native font/HUD
  boundaries. It covers shell-only construction, selected-page preparation, all
  nine categories/twenty sections, current defaults, preview/Confirm/discard,
  pending Layout input, independent Damage meter preparation, centered section
  headings, description-free checkbox alignment, plain input regions,
  deferred font-menu selection and reuse, closed language
  changes and no added background updater. Live caption updates also run through
  the production clock function with the settings shell open before Encounters
  exists, across the category walk and
  after closing. They require normal HUD updates without an early sample access,
  and sample presentation only on its visible prepared page. Active-language
  width cases cover one measurement, cache reuse, font/flags/width/scale/language
  invalidation and
  missing-metric retry. The Layout fixture also covers two-group per-frame
  preparation, fast continuation through the existing controller, cancellation
  of unfinished work and reuse after reopening. Retail-layout cases also cover
  paired Hide frame/Show grid, full-width Hide frame in the moving popup, wrapped
  popup growth/clamping and unchanged locale reflow. Reparenting cases model
  native root-only level changes and stale hidden visibility, then require the
  reused numeric form and every input/button to draw above the popup and return
  to the settings layer without repeated layer writes. These are CI-only source mocks,
  not first-open latency or native rendering measurements.

  The selected-frame width slider cases cover reuse across both editors,
  selection-specific limits and visibility, synchronous range/value callbacks,
  unchanged writes, live width with stable center/scale/height, valid/invalid
  pending numeric input, Chat dimensions, automatic Revive sizing, profile loads,
  Save/Cancel, world discard and full reset. The production Layout owner supplies
  the draft and resize behavior; fixtures provide only native slider/geometry
  boundaries. These cases remain CI-only and were not run locally.
  The frame boundary includes real stored scale and scale-aware TOPLEFT edge
  reads, so applying a pending scale edit exercises the existing center and
  save/discard assertions instead of failing on a missing fake `SetScale`.

  Close cases cover repeated launcher-toggle open/cancel, native registered-window
  hiding, focused invalid numeric input, profile-name Escape, duplicate Escape
  registration and draft retention when switching to moving mode. The minimap
  fixture covers the launcher's edit-layer priority, unchanged assignments and
  restoration to the current minimap layer without new views or workers.

- Settings visibility mocks exercise the production Display/SCT/font-control
  listeners with explicit native ancestor visibility and font boundaries. Closed
  windows and unselected categories perform no settings reads, formatting or font
  work, then catch up from current values on Show. Repeated visible updates skip
  unchanged writes. Layout fixtures also cover actually hidden overlays on other
  categories, retained pending input and removal of the numeric form's separate
  polling callback. These are CI-only and do not measure native rendering or FPS.

- Retail-moving fixtures load the production magnetism/selection factories and
  real Layout/Display owners against explicit native scroll, geometry, keyboard,
  focus and slider boundaries. They cover eight-physical-pixel capture, corner
  priority, grid-independent screen/frame magnets, reused state, free pointer
  movement until release, one-/ten-unit nudging, shared-form/native-chat focus and validation,
  Save/Cancel, mode switching, resize-grip hiding and world cleanup. The full
  editor’s older grip/lazy-preparation cases remain separate. These are CI-only
  and were not run locally; no retail C API or game client is loaded.

- Compact target-of-target mocks load the production Mini and loss controllers
  with explicit native boundaries. They cover name containment, stable health
  label positions, clean pooled border reuse, portrait previews, hidden recovery,
  dead/native-health updates and Performance Mode trail retirement/rearming.
  They do not establish in-game appearance or native texture sampling.

- Shared-rule mocks exercise restoration readback/retry, deferred native opt-out,
  synchronous HUD callbacks and visibility encodings; shared encounter validation
  rejects duplicate IDs before either cosmetic index is built. Circular-image
  cases cover native path verification, failed-binding memoization, retryable
  pooled strips at both existing icon sizes, unchanged writes and cleanup.
  Display copies retain false values, range/enum normalization, legacy fallbacks
  and draft isolation. Source contracts accept the complete defaults-driven
  normalization loop and reject filtered, mis-keyed or wrong-source copies.

- Projection/metadata cases exercise production navigation cache boundaries and
  resolver preparation: successful same-pass reuse, exact coordinate identity,
  accepted-roster retirement, map/getter changes, failed projection recovery,
  fresh frame motion, bounded tab/slot/validation chunks, atomic publication, dirty/language/world
  invalidation and fresh synchronous first-use completion. They preserve the
  absence of new runtime test hooks and remain CI-only, without live FPS claims.

- The remaining-frame pass adds CI-only cases for the default-off minimap clock,
  centered zone text and display transactions; selective final-window cooldown
  reads; strict SCT retirement deadlines and native raid-icon UV forms; dirty
  boss marker reconciliation with exact active halos; settled loot hold/hidden
  expiry; Revive clipping reuse; event-driven player pulses; shared Layout
  samples/final release; unchanged waypoint math with active interpolation;
  lazy Chat time and observed/unreported tooltip owners. These fixtures are
  authored for CI and were not run locally; no live rendering/FPS is inferred.

- Fallen-ally waypoint mocks load the production controller with explicit
  native roster boundaries and check dead/alive/ghost/disconnect retirement,
  slot changes during reads, literal native names, nearest/stable selection,
  hidden/off sampling, display preview/Confirm/Cancel/profile/reset, world and
  phase cleanup, missing getters and stationary work in Performance Mode.
  Cache/guardian cases cover nearer arrivals, movement, equal-distance stability,
  missing-coordinate fallback, hidden/off distance-work deferral and retired
  identities. They retain party selection and next-respawn priority, and check
  the ally default clears the shared static jewelry bounds without Show-time
  reanchoring.
  Navigation cases reject missing/invalid and foreign-sheet party coordinates;
  shared pin cases cover four edge indicators, changed-only writes and reuse.
  The full controller also draws received cache and fallen-ally pins on a visible
  native minimap, without supplying global visibility helpers. Boolean/numeric
  visibility, hidden/nil cleanup and recovery cover both geometry and placement.
  The same full-controller fixture checks the default-off guardian respawn
  option, invalid normalization, preview/Confirm/Cancel,
  profiles/reset, immediate cached reselection, fallback after all lairs empty,
  stable ties, due and unknown timers, living priority, navigation copies,
  independent minimap choices, unchanged
  normal/Performance Mode work, hidden/off recovery and run/world retirement.
  Settings visibility mocks also cover the option dimming and disabling with
  Guardian guidance while retaining its value and skipping unchanged writes.
  These tests remain CI-only; local work uses source review, artwork preparation
  and pinned formatting, with no addon/game execution or Actions polling.

- Cadence-cleanup production mocks cover event-driven low-health eligibility
  with unchanged active pulse equations, idle versus editing Layout geometry,
  settled language/cooldown detachment and rearming, actual tooltip/target color
  repair, hidden minimap-clock recovery, dirty aura layout with native anchor
  repair, duration/pet/level/lair caption reuse, idle SCT/Chat, lazy guardian
  clock reads and ten-Hz/deferred/fresh-hover boss-debuff work. Clock tests keep
  raw native phase/time/ownership and original effect inputs. These are CI-only
  call/lifecycle contracts and do not establish rendered parity or FPS gains.
- Extracted production unit-border transitions actually hide inactive party and
  portrait variants, restore the retained artwork on option changes and skip
  unchanged writes. These assertions distinguish shown state from alpha; they
  do not measure the packaged renderer's submitted quads or GPU time.
  Target classification mocks also cover accepted guardian silver wings,
  boss/final gold wings, native artwork fallback, unchanged/forced bindings and
  hidden reads/writes. Full target-health mocks cover accepted-kind copying and
  retirement through the existing deferred publication lifecycle. Both reuse
  the bundled border sheets without extra regions or runtime test hooks.
  Immediate-border cases select known guardian/boss/final artwork during
  `PLAYER_TARGET_CHANGED`, before a target packet or the next update. They
  exercise exact name/maximum aliases, sleeping/waking guardians, namesake elite
  and clamped-value collisions, atomic invalid-roster rejection, authoritative
  target precedence, copied metadata reuse, pending-parser stability, hidden
  receipt settlement and zone/world/phase/language/run-rollback retirement.
  The nameplate fixture also checks string-kind collisions in the shared
  production maximum-alias helper; no local execution or live latency claim is
  implied by these authored CI cases.
- Performance follow-up fixtures also exercise production banner detach/retry,
  Layout handle preparation/failure, unchanged meter publications with changing
  rates, shown-plate sampling, shared navigation reads, tooltip content/owner
  caches, loot backpressure, parser descriptors and XP fade geometry. Extracted
  helpers retain explicit fake native boundaries; full controllers still load
  only in CI. These assert call/object/lifecycle behavior, not rendering or FPS.
  Movement follow-ups cover incremental target-change discovery and synchronous
  minimap-size sharing, including unavailable and insufficient geometry retry.
  Extracted timer foam also checks one native height sample per paint while
  retaining the original clipping geometry and UVs at different authored heights.
  Production clock-progress cases cover unchanged writes within a native second,
  whole-second steps, native pauses/corrections, exact fractional completion,
  maximum changes and hidden recovery. They keep raw caption/marker inputs
  separate from the stepped flow/foam clipping boundary.
  Timer-caption mocks cover unchanged/disabled formatting, current-value option
  previews, language/mode changes, scale and missing-metric retries, font preview,
  retirement and repeated empty-clock idling. They use the production label
  constructor and non-default font styling after formatting, preserving the
  separate string/nil font caption and formatting-cache owners.
  Full nameplate mocks also cover exact-name origin indexing, stable ordered
  retirement, loss ambiguity, native reuse, strict expiry and index cleanup.
  Pass-local query cases cover repeated no-match/ambiguous results, exact
  name/kind/amount/fallback separation, consumed-loss invalidation, fresh passes
  and cache overflow without dropped hits. Color-key cases preserve the four
  original fields and separators without the former temporary concatenation table.
  Source-extracted SCT queue cases retain original metadata/color intake,
  amount/critical/icon identities, inclusive intake and subtraction-based
  settle boundaries while checking that MSBT stores no per-hit pending record.
  Grouping cases retain the original 75 ms normal path and cover Performance
  Mode's fixed inclusive 300 ms window in both SCT styles, same-attack sums
  (`20 + 100 = 120`, including equal amounts), unchanged normal duplicate
  suppression, preserved original per-hit values, separate critical/source/icon
  identities, numeric overflow splitting, stable bucket cleanup,
  old/new intake separation and active animation
  surviving preview/Cancel window changes. Matching and settling keep their
  original gates. These are CI-only source/lifecycle assertions.
  Default per-hit matching/fallback remains covered. Extraction keeps complete
  multi-variable constant declarations once, with uniqueness regression cases.

- Boss/guardian current and maximum health defaults, independent preview,
  Confirm/Cancel, profile discard and reset use the real display module. Shared
  encounter-label mocks cover all four combinations, slash visibility, actual
  label hiding, disabled/unchanged formatting, pooled text restoration and no
  added drawing objects. These do not prove native rendering or font geometry.
- Boss Crimson echo cases extract the production loss controller, row refresh
  and retirement. They cover immediate native fill/text, one lazy reused loss
  region on the existing plain overlay, selected easing/brightness, rapid-loss
  coalescing without replay,
  equal trail composition over red and black backings with opaque vertex alpha,
  anchor-sized native width/edge differences across UI/group scales,
  resizing, unchanged writes, failed artwork retry, shared active time samples
  and idle completion. Healing, maximum/name/identity changes, hidden recovery,
  pooled retirement and Performance Mode clear effects and old baselines;
  Performance Mode allocates no loss artwork or cosmetic clock work. The
  existing HUD-controller case also asserts frame-cadence loss updates. These
  are CI-only mocked contracts, authored without local execution or live FPS proof.
- Full production guardian tracker mocks cover status-caption reuse, native
  rounding boundaries, static statuses, language changes, actual text resets,
  failed setters, hidden work, pooled-row reuse, options/world cleanup and
  unchanged health controls. Revive production mocks cover caption/percentage
  reuse, hidden formatting, identity/language/retirement, actual text repair,
  measurement readiness, native progress and shared animation-width reads.
  These are CI-only call/lifecycle assertions, without live rendering evidence.
- Guardian minimap timer mocks load the production roster and extracted pin
  functions to cover default-off drafts/profiles/reset, native pause-aware
  countdowns, unchanged/hidden/off work, lazy label pooling, font retry and retirement.
  These checks do not establish live minimap appearance or rendering cost.
- Source-extracted guardian minimap hover uses accepted names and scaled cached
  pin bounds, skips unchanged tooltip writes, clears retired hovers and respects
  foreign owners, Tooltip hiding, re-entry and Layout editing. Pins remain
  mouse-transparent. Source-extracted shared tooltip placement also verifies
  guardian cursor routing with the global option off and preserves ordinary
  Layout/icon/global-cursor behavior. Mocks do not establish live minimap input
  or cursor pixel placement.
- Unchanged cooldown values still read the native boundary but perform zero
  presentation writes and allocate no replacement objects. Caption-cache cases
  also check unchanged localization, rounded-value/unit/language changes,
  actual native text/color repair, failed setter retries and every-frame
  final-window sampling with the exact positive-zero boundary.
- Hidden/off cooldowns skip native reads and presentation; world retirement
  clears overlays and suspends reads, and world entry resumes them.
- Native ability Model mocks cover Performance Mode's completion-flash guard,
  unfinished swipes, active-flash cleanup, mode exit without stale replay,
  numbers-off independence and preserved native timing/animation handlers.
  They do not establish the packaged client's live rendering or FPS.
- Range indicators reuse their texture, avoid restarting unchanged fades and
  detach their polling and clear effects when the action bar hides. One lazy
  target sample serves each pass while visible buttons retain independent
  range reads; missing/friendly/hostile transitions and hidden allocation/cleanup
  use fresh native boundaries.
- Loot cards clear retired text/icon bindings and reuse the original three-card
  pool. Settled updates perform zero presentation writes, and a full pool does
  not allocate a fourth card.
- Layout-hidden loot keeps expiry running while skipping cosmetic work. An
  expired card cannot be replayed when the group becomes visible.
- An injected native text failure releases every card and native HUD ownership
  and detaches both the renderer animation and failed intake controller.
- A failed optional icon binding retries on the next required refresh, while a
  successful binding skips subsequent texture and presentation writes.
- Target-health labels, percentages, fills and loss effects share the accepted
  native publication above the 32-bit health ceiling. Native capped writes cannot
  replace that fraction or repaint unchanged content; compact K/M/B/T labels do
  not change the counters.
- Target changes, invalid publications, hiding and phase/zone/world retirement
  clear stale health and loss effects. Player targets retain native health and
  the existing label visibility settings.
- New target selection immediately uses validated current native unit health
  while awaiting `AZSTGT`, including same-name switches and late mismatched
  packets. The full-precision handoff resets the loss baseline and prevents
  later capped native writes from replacing accepted values. Invalid native
  pairs stay empty; waiting adds no idle reader.
- SCT keeps over-enemy defaults and the display transaction, releases forced
  plate tracking in MSBT-style mode with V off, uses outgoing anchors relative
  to a movable Layout owner, spaces distinct burst lines
  and animates without enemy projection. Mocks cover registration before combat,
  parent/anchor inheritance after movement and scale, hidden intake/queue
  retirement without replay, mode preview/discard and pool reparenting between
  styles. Style changes retire active and queued hits, and expiry/world cleanup
  clears labels and the owner request while retaining pool reuse and empty-list
  idling. These mocks do not exercise native dragging or independently retest
  the shared Layout save/profile transaction.
- Diablo IV style cases exercise the production SCT controller's full numeric
  formatting, native critical colors, icon/filter choices, compact launch,
  settled hold, fade deadline, unchanged work, style retirement, pool reuse and
  world cleanup. They retain the animated Performance Mode presentation and
  300 ms sums across mode transitions. Enum cases cover legacy MSBT migration,
  invalid values, preview/Confirm/Cancel, profile normalization and reset.
  Settings fixtures cover style selection, hidden listeners and page extent.
  Full plate cases compare repeated native camera/collision changes with an
  otherwise identical stationary production controller. Over enemies and
  Diablo IV retain identical authored motion, amounts, fade and expiry while
  their base coordinates follow the matched native plate. Grouped cases require
  one common nonnil origin; mixed/ambiguous groups retain a fixed centroid.
  Cases cover invalid coordinates, native frame retirement/reuse, Performance
  Mode transitions, fresh pooled origins and world cleanup. Existing native
  sampling supplies the coordinates without extra reads or smoothing state.
  These cases are CI-only and do not prove Diablo IV visual parity or native
  font rendering. Font cases cover invalid/default choices, preview, Confirm,
  Cancel, profiles/reset, active width invalidation without motion/lifetime
  restart, pooled reuse across all styles and Performance Mode states, rejected
  native loads/fallback/retry/expiry, and non-Latin avoidance glyph coverage.
  Native rounded-height cases keep successful PT Serif bindings across reuse
  without fallback/retries; genuinely different heights remain rejected.
  Color cases retain white/yellow native-result priority over class colors and
  preserve class colors in other styles. Cosmetic amber cases exercise the
  three-critical warmup, previous-mean/inclusive 1.5x threshold, exclusion of
  normal hits, native identity isolation, original members versus summed totals,
  active-color retention, half-second bucket expiry, time regression,
  style/mode/world/zone cleanup, 64-identity eviction/reuse and preservation
  across Performance Mode transitions. No native Overpower result is inferred.
  Abbreviation cases cover boolean
  defaults/invalid values, all K/M/B/T boundaries, original per-hit amounts,
  75 ms duplicate versus 300 ms summed totals, active width refitting without
  coordinate/font/lifetime restart, Cancel, pooled reuse and localized misses.
  Settings cases retain the disabled class-color choice across Custom mode
  changes and cover abbreviation preview/Cancel and final page extent.
  Settings cases cover font selection, Custom-only input and final page extent;
  package fixtures reject unreferenced or missing font payloads.
  The shared SCT label sink identifies the real holder/visual pool through its
  observed native root binding, excluding native enemy-name labels from combat
  assertions.
  See [DIABLO-SCT.md](DIABLO-SCT.md) for the video study and tuning.
- Full SCT/filter and nameplate-style fixtures combine Names only with the
  boss/guardian filter. They cover exact capped/float32 ranges and halfway
  rounding, sleeping-to-awake ceiling conversion and its float32 serialization
  boundaries, ordinary/ambiguous elite exclusion, percentage-only rejection,
  both toggles, V and zone retirement, independent name visibility, lazy bar
  allocation/reuse and no unchanged cosmetic writes. The scrolling and plate
  fixtures share explicit native setup; production algorithms are not copied.
- Native marks messages use exact templates in all fourteen catalogs. Tests
  preserve item links/colors and original integer/decimal amounts/totals, keep zero-reward
  duplicates hidden, leave conversations/unknown suffixes unchanged and reject
  collected conversions before popup delivery or item metadata reads when marks
  rewards are off. Loot mode tests exercise the production display/service/view:
  defaults and invalid preferences, all modes, preview/Confirm/Cancel, profiles,
  resets, native visible/hidden ownership, failed handoff retries and synchronous
  CVar callbacks, later external preferences, no Game/Off intake or idle updater,
  deferred/reused card artwork, positive conversion labels and zero/invalid
  rewards. The Hogger `+0.5 marks` regression loads the production parser,
  service, renderer and chat formatter together. It covers one marks-only card,
  singular wording, the selected static coin without converted-item metadata
  or rarity work, chat suppression only
  while SDUI marks popups are active, no second card from the balance notice,
  two-card retail spacing and independent fade/expiry in normal and Performance
  Mode, pooled reuse and hidden retirement. Coin cases also cover failed binding
  retry on required refresh, unchanged and hidden writes, cleared retired
  bindings, and item-to-currency reuse without another region. These cases were not run locally.
  No mock proves native box content or live font rendering.
- The production meter cycles Party Damage after Boss Damage, reads native
  player totals/rates, binds uniquely matched native unit portraits, and retains
  class metadata across shared Reset deltas. Mocks cover unchanged/hidden/off
  and icons-off work, missing APIs, ambiguous/replaced units, failed-portrait
  caching and world retirement until a fresh `AZSPARTY` publication.
  Deferred view-selection cases cover unpublished-view skipping in both
  directions, rapid clicks, initial fallback, valid empty/error pages, all-waiting
  stability, new publications, reset/disable cleanup and hidden/off probes.
  They retain native freshness gates, assert no getter runs from clicks and
  bound each getter to one read per pass across selection, Reset and rate work.
  New-pass and failed-render recovery cases reject retained native results.

The mocks implement only explicit API methods and record calls, allocation and
effective parent visibility. An unsupported method fails rather than silently
succeeding. Native fades are modeled as boundary calls, not rendered animations.
A small table-size shim covers the explicit Lua 5.0 queue sizes used here; the
interpreter and mock objects do not emulate the packaged engine. These tests
cover the named controllers, not every Layout group, native visual parity or FPS.

## Configuration and registration contracts

`scripts/addon_contracts.cjs` parses the runtime manifest's Lua with the shared
parser. Display defaults and normalization come from `core/display.lua`, rather
than another maintained settings list. It checks direct getters/setters, bounded
string expressions, option-table values and named-field values. A write from an
editor alone cannot keep a setting alive; recognized getters are recorded with
their source locations. Duplicate literal keys are checked in runtime tables,
including generated data, and literal module/Layout IDs must be unique.
Literal Layout option names are compared with actual option-field reads in
`core/layout.lua`; there is no second maintained list of allowed flags. Dynamic
options tables remain visible for review.

Shared API methods are checked against source declarations, including the
project's `T` and module aliases. Concrete `SetScript`, `HookScript`, listener and
Layout/module callbacks are checked for obvious invalid types and missing Lua
declarations. This does not import a Retail API catalog or guess native method
availability. File-wide alias/string inference is conservative and does not
prove lexical reachability, every callback's type or initialization order.

UI caption candidates come from `localization/ui.tsv`, excluding comments and
the generated catalog as usage evidence. A dynamically assembled caption can
become a candidate even when it is reachable. The full report preserves all
orphan candidates and unresolved dynamic references. A candidate newly introduced
by a PR fails, including an existing setting/caption whose last recognized use
was removed; a legitimate dynamic refactor needs corresponding inference and a
regression fixture. Existing candidates remain visible without automatically
deleting preferences, captions or code.

## Asset ownership

Lua under `scripts/` and `tests/` is development source and does not need TOC
entries. Deliberately retained legacy Lua elsewhere is classified by exact path
and a nonempty reason in `packaging/asset-usage.json` → `reference_lua`.
`modules/chat/filters.lua` is the retained broad formatter; the loaded
`modules/chat/prettify.lua` implements current behavior. All other tracked Lua
must remain in the runtime manifest and TOC. These classifications do not skip
formatting or static Lua analysis, do not provide texture-ownership evidence and
fail if development/reference Lua enters the payload. A stale or invalid
reference classification also fails. No historical geometry fixture or legacy
formatter is loaded into the addon to satisfy the inventory.

`scripts/lua_inventory.cjs` uses pinned luaparse 0.3.1 to parse loaded Lua as data.
Comments and developer documents cannot keep a runtime texture alive. The
inventory resolves full local filenames and unique relative filenames in their
source's texture directories, with exact filename case. Native `Interface\\...`
artwork belongs to the client and is excluded from package ownership.

`packaging/asset-usage.json` records the places where filenames are constructed:
sheet-name roots, the tally data's runtime consumer and the minimap zoom helper's
stems and button-state suffixes. The inventory checks that the configured sources,
root literals, caller/helper and data consumer still exist. These are evidence
rules, not blanket exceptions for a whole asset directory. Remove obsolete rules
when removing their consumers.

The asset gate establishes **syntactic ownership**, not complete execution-path
reachability. A literal in an unused exported table can still look owned; review
such tables along with the exported-helper report. New dynamic naming patterns
need a reviewed rule and a regression fixture. The checker does not guess a
missing extensionless filename from arbitrary text.

Original TGAs with a current runtime BLP of the same stem are preparation inputs.
Other retained media needs an exact source-file rule with a current output and
reason. Keep required originals at full resolution with their original pixels
and alpha. When retiring artwork, remove its BLP, manifest entry, obsolete input
and ownership rule together; retain applicable license and provenance notices.

## Reports for review

The PR job summary shows payload file count, uncompressed size, deterministic
in-memory ZIP size and the twenty largest changed files. Sizes are compared with
the PR's merge base. Growth is visible without an arbitrary cap that discourages
necessary features or rewards minification. The ZIP measurement writes no addon
archive and is not a GPU-memory or FPS measurement.

Download the seven-day `pr-quality-<number>` artifact for:

- `asset-usage.json`: each runtime texture and its source references.
- `payload-size.json`: all changed file sizes, comparison commit and every group
  of byte-identical runtime Lua/texture files, including pre-existing groups.
- `export-candidates.json`: shared DFRL functions with no statically recognized
  member read. These are review candidates, not automatic failures: native
  callbacks, aliases and dynamic indexing can explain them. Local dead code is
  separately enforced by Luacheck.
- Formatting patches, analysis logs and `fixtures.log`.
- `addon-contracts.json` and `addon-contracts.log`: source-contract failures,
  setting readers, current/new orphan candidates, registrations and dynamic
  references requiring review.
- `ui-lifecycle.log`: production UI lifecycle assertions against native mocks.

The checker fixtures cover comments masquerading as references, native textures,
missing/case-mismatched paths, same-named sheets, removed dynamic consumers,
authoring-input retention, stale rules, unsafe/case-colliding/symlinked package
paths, TOC drift, deterministic ZIP membership, new duplicate payloads and the
configured dead-code warning policy. Source-classification fixtures cover the
historical geometry test, retained formatter, ordinary unloaded runtime Lua,
accidental development/reference payload entries, stale reasons/files and
unreferenced artwork despite retained source. Source-checker fixtures execute only tooling
against synthetic source/data; the parser never loads those Lua chunks. Separate
mutation fixtures verify that orphan regressions, duplicate keys, misspelled APIs,
broken callbacks and stale/ambiguous production seams are rejected.

## What still needs the client

Performance Mode fixtures exercise the production display/profile transaction,
native Chat fade/slide owners, XP, cooldown-number and stored-level controllers,
and the static low-health warning. Extracted timer ownership checks cover lazy
decoration, static blue/red fills and restoration of the original effect pool.
Related production mocks cover notification expiry, revive progress, static
range feedback and skull-glow transitions. These fixtures run only in CI and
were not run locally; they do not measure frame rate or verify native rendering.

Extracted tally cases cover five-second kills/gold presentation, unchanged
normal/cache-cost cadence, retained-text fitting, hidden recovery, mode changes
and existing native run/tally retirement boundaries. These remain CI-only.

Banner cases include the former
fade-out window and hidden-born rows, preserving original receipt lifetimes.

Static checks cannot prove that a shared callback is reached, native publications
arrive in the expected order, hidden views remain idle, or textures render with
the correct pixels. They also cannot measure live draw calls, GPU memory or FPS.
Use source review for ownership/lifecycle changes and a separate in-game check
when authorized. Local work remains limited to source review and pinned
formatting; these regression tests and audits run in GitHub Actions.

## Pet and totem controller scenarios

`ui_pets_totems_spec.lua` loads the production PetFrames module against fake
native getters, snapshots, phase and run time. It covers unchanged grouped pets
alongside grouped totems; deferred reads; exact published names/icons/counts;
future keys/caps; missing and malformed independent feeds; no timer before run
clock readiness; pause/choosing behavior; zero-time counts retained until native
removal; hidden allocation/polling; shared display settings; receipt retirement;
world/reload/reset cleanup and row-pool reuse. Metadata learning runs only for
changed accepted publications. The fixture and runner remain outside the
runtime manifest, run only in CI and do not prove live delivery or rendering.

## Heroic timer and affix scenarios

The source-extracted foam fixture also covers the Endless wash: reuse of the
twelve existing flecks, one height read, low peak opacity, full-width and cap
clipping, the brighter end crest and retained regular-run placement. This is
CI-only drawing-boundary coverage, with no local execution or FPS evidence.
The extracted live fill owner checks Normal and Heroic I–V palettes, higher-rank
fallback, invalid metadata, lazy bounded glint growth, full-width Endless,
moving pinpoints, shared throttle, cleanup/reuse and Performance Mode. Native
caption cases return only accepted `endl` modes; clock cases verify that the
same mode controls fill without changing native elapsed time or inferring
Endless from the duration. Pending publications retain no old rank or mode.

`ui_run_numerals_spec.lua` exercises the extracted static numeral renderer:
I–X selection, invalid-rank retirement, hidden lazy allocation, one-minute and
width geometry, unchanged writes, binding retries and Performance Mode.
Clock-progress cases check the native rank handshake and hidden sample gate;
affix cases check rank acceptance without an affix list or visible affix row.
These CI-only scenarios were authored without local execution and do not prove
Bildad rendering, BLP decoding or native layering in game.

`ui_run_affixes_spec.lua` uses the extracted production `CreateRunAffixes`
factory, shared tooltip registry and generated native captions against fake
widgets/snapshots. Scenarios cover ordered centering, the exact neutral
jewelry crop and red tint, hidden/unchanged work, missing or non-Heroic data,
unknown keys, receipt retirement, retry cadence, pool reuse, editing/Tooltip
visibility, foreign ownership and all fourteen native name/description sets.
The existing required job runs the fixture; it is not shipped or run locally.
This isolates the view boundary, rather than executing the full timer/game or
proving native packet delivery and appearance.
