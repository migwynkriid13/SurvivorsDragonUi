# PR checks

Every PR push runs formatting, static Lua analysis, package and asset inventory,
source contracts, checker regression fixtures, mocked UI lifecycle tests and the
existing artwork checks. No game starts. Only the separate mocked UI test step
executes selected production Lua against fake native boundaries. Keep the `Formatting and local dead code` job as a required
check in the repository's branch rules; editing a workflow does not configure
branch protection by itself.

The 0.139.0 compatibility cases are authored for CI only. Artwork data fixtures
check every packaged BLP against the native power-of-two size gate and compare
both neighbour pixels at each strip join. Mocked production helpers cover strip
region counts, resizing, right anchoring, parent visibility, failed bindings and
unchanged writes. Navigation covers old zero-valued and new texture-height map
returns; party portraits cover object and legacy-name forms. Native SCT cases
separate equal-caption borrowed spells by received meter source keys, retain
same-key sums and accept older events without optional attribution. These cases
do not establish packaged-client appearance or repair native FrameXML errors
that occur before addon loading.

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

Shared-tooltip cases load the production controller over explicit native owner,
content-clear, visibility and scale boundaries. They cover Tooltip hiding/scaling
without suppressing ability/item UI hovers or changing the game's Enhanced
Tooltips choice, retained native returns, unregistered UI buttons, unobserved
owner replacement, cursor/icon placement, unchanged work, editor suppression and
world cleanup in both Performance Mode states. These cases remain CI-only and
were not run locally; they do not prove native tooltip rendering or event order.

Native world-SCT cases run the actual adapter and controller over explicit fake
capability/event/projection/registration endpoints. Their ordinary and post-camera
frame phases are separate. They cover native-only intake, one-shot
anchors without plates, camera movement after death, living/dead offscreen
hiding and remaining-life recovery, bounded distance scaling, distinct native
targets/casters, both grouping modes, malformed/throwing responses, retry
throttling, stream retirement, MSBT/legacy fallback and off/world cleanup.
Documented-shape cases omit `basicAttack`/`abilityKey`, group by native `spellId`,
preserve literal native miss words and accept absent miss captions without
rejecting other hits. Cases require `frameCurrent = true`, reject early-phase
native reads/positioning, retain one handler across Performance Mode changes,
and cover partial registration, failed release, hidden/retired callbacks and
style/mode/world/reload cleanup without affecting foreign handlers.
They add no runtime hook or shipped fixture. Cases are CI-only and were not run
locally; mocks cannot establish native death-position capture, camera-update
ordering, provider availability, appearance or FPS.

Distance-choice cases retain default-off normalization and explicit saved choices,
preview/Confirm/Cancel, older/named profiles and resets. Production-controller
comparisons toggle sizing in both enemy styles and Performance Mode states while
retaining death anchors, motion, fade, expiry, pooled objects and frame ownership.
Editor cases cover the actual checkbox/search target, hint, final filter extent,
MSBT/mode dependencies and hidden/unchanged writes. These remain CI-only.

Meter processing cases exercise growing native source/member lists through the
production adapter and controller. Fixture-only counters check that ordinary
counter changes reuse identity preparation, appended history reuses contribution
positions, unchanged/rate-only summaries retain their ordering and controller
row copies stay bounded by the viewport. Cases retain source/member/positive
attribution changes, per-source metadata updates, unknown and mixed origins,
clock-only rates, native errors, checkpoints and lifecycle retirement. Viewport
cases cover immediate initialization of newly revealed identities, ranks and
bar proportions, one-second displayed rates, shared refresh contexts, fresh
manual Reset contexts, hidden/off work and both Performance Mode states. Legacy
cases retain complete rolling observations while another meter tab is visible
and same-publication Party rate validation. These cases are CI-only and were
not run locally; operation counts do not establish native snapshot cost or FPS.

Totem-ledger cases count native member/origin ID reads with explicit array
boundaries over 120–180 records, including first preparation and appended actors.
Malformed keys, sparse/non-string lists and recovery must preserve conservative
talent attribution without needing a metadata revision. Aliased display/recent
or average rates avoid duplicate validation; separately returned malformed rates
still fail, with and without checkpoints. Full-controller cases grow to 240
historical totem actors while retaining one item row, native totals, Reset,
pet-summary choices, pooling, unchanged work and hidden/off cleanup in both modes.
These cases are CI-only and do not measure native allocation, history cost or FPS.

Native history-cadence cases count positive-window and zero-window queries
through the production adapter/controller. They cover shared one-Hz regular
native/legacy reads, next-frame input/settings/scroll/Reset/show refreshes,
extra zero-window reads within a native rate sample, newly revealed and replaced identities,
unavailable history, warmup after atomic Reset, native checkpoint denominators,
All, view return, hidden/off retirement and both Performance Mode states.
Adapter cases keep physical query retries/captures separate and invalidate
samples when attribution or context changes; counter/ordering updates retain a
row's own sample. These cases remain CI-only and were not run locally. The
query counts do not prove reduced native snapshot-copy cost or live FPS.

Early row-piece cases count fixture-only getter, font, static-icon and bar
operations through the production controller in both Performance Mode states.
Settled rows retain their targeted numeric-font check while skipping text,
width, per-row scale, metric and static-binding helpers. Cases cover unchanged
compact captions, changed captions and leading amounts, proc colors, failed
artwork retries, scrolling with pooled rows, width/scale/global font changes,
unannounced numeric-font changes, failed font assignments and missing metrics.
Existing portrait, legacy resolver, tooltip ownership and retirement cases
retain those regular checks and cleanup boundaries. Coverage is CI-only and was
not run locally; helper counts do not establish frame timings or FPS.

Action-bar choice cases use the production display/bar owners and explicit fake
native frames. They cover default-on normalization, shared preview/Confirm/Cancel,
profiles and resets, native presentation restoration, retained attachment
choices with detached jewelry/counters, SDUI XP hiding, disabled dependent
controls and both Performance Mode states. Max-level cases cover a 119→120
transition, repeated native Show calls and direct native OnShow delivery,
already-capped reacquisition, native-mode restoration of latest Show/Hide
requests and callbacks, Cancel, world/release cleanup and pool reuse. Bar
snapshots must leave the XP owner's max-level frame, descendants and hooks
untouched. These cases remain CI-only and were not run locally; they do not
prove native input or in-game appearance.

The native API draft adds production-boundary fixtures for the v1 meter adapter,
complete meter view, retained portrait circle helper, native language selection
and live navigation. They cover all fourteen literal label sets, duplicate names
with distinct row IDs, direct source icons/retained portraits, native recent/All
rates, unavailable history, synchronous checkpoint Reset and cleanup retries,
epoch/encounter retirement, hidden/off work, circular fallback reuse, typed
readiness failures, native retry delays and instance coordinate-space matching. No test stub or fake
native API enters the runtime payload. These scenarios run only in CI and were
not executed locally; the future game's implementation still needs native
integration and rendering verification.
Native label cases use distinct committed snapshot/metadata revisions, including
metadata-only changes with stable row IDs and counters. Portrait cases include
opaque retained images, unchanged strip-backed writes and malformed-response
cleanup. Navigation cases supply explicit native minimap bounds and the shared
marker/tooltip boundaries, checking copied coordinate tags separately from
guide and pin visibility.
Native-language cases separate the native environment without `_G` from the
addon initializer environment. They retain all fourteen catalogs, native errors,
legacy fallback and deferred recovery when the capability endpoint is absent
or appears after initialization.

Native and legacy meter cases keep forward and reverse navigation within the
four supported views in both Performance Mode states, even when incoming-damage
categories are published. They reject category reads and retain native counters;
the native API path keeps legacy packet intake detached. These cases remain
CI-only and were not executed locally.

Ability-rank cases add nine native ranks and a later upgrade, checking one
combined row, amounts, available/unavailable rates, shares and sorting without
changing native counters or checkpoints. They retain unrelated same-name
sources, owner/proc/variant/item/talent distinctions, ambiguous same-rank
families and missing-identity sources. Legacy duplicate cases exercise grouping
before session Reset and rolling-rate observation. Metadata/language changes,
pool reuse, hidden/off work and both Performance Mode states use the production
owners over explicit fake boundaries. These cases are CI-only and were not
executed locally; they do not prove native client behavior.

Native hover-ID cases expose received source/owner/caster/proc/rank and actual
positive-origin metadata without a new snapshot. They distinguish equally named
rows with the same source ID but different native proc flags, avoid private
display tokens and ignore zero-display origin history. The adapter prepares
text lazily in one bounded reusable buffer, reuses it for counter-only changes,
refreshes changed metadata and retires old handles on Clear. Full meter cases
exercise ordinary unshifted figures without diagnostic preparation, Shift-held
entry, press/release while already hovered, immediate modifier-only repaint
without native snapshots, missing Shift getters and unchanged holds. Unshifted
metadata changes defer diagnostic work until Shift; hidden/unhovered/header and
foreign tooltips do no modifier reads. They retain metadata changes with unchanged
captions and amounts, foreign tooltip ownership and hidden work in both Performance Mode
states. Diagnostics do not establish the identities in a screenshot until the
actual tooltip is observed. Coverage remains CI-only.

Talent-rank cases cover direct known talent descriptors and ability rows with
validated actual talent origins. They combine native ranks without rewriting
counter records, check later upgrades and stable display identities across the
three source views, and retain explicit variants, owner/caster/proc/item
distinctions and same-rank ambiguity. Actual-origin cases reproduce received
Flametongue shapes with absent/present Fire Nova ranks and Windfury shapes with
Rockbiter/Stormstrike triggers. They group by validated actual talent ownership,
preserve the original ability keys/ranks, reject missing or multiple ownership,
and retain conflicting source slots or same-rank origin IDs. Full meter cases
check that an additional triggering ability reuses one row in both modes.
Checkpoint deltas, unavailable rates, localization, highest-rank artwork
readiness and counter-only identity reuse share the production adapter. Full
meter cases check pooled row reuse and hidden work in both Performance Mode
states. The reported tooltips supply the source/origin shapes; these CI-only
mocks use illustrative counters and do not establish the complete native
snapshot, patched live appearance or FPS.

Item-rank cases add differing rank-specific item IDs under one explicit item
key, direct and item-bound sources, single actual-origin joins, independent
components and item copies. Cross-caster cases combine player, pet, summon and
totem item damage with both pet-summary choices, retaining native records and
bounded caster diagnostics. They cover counter changes, reordered/replaced
casters, Reset, zero-to-positive contributions, unavailable rates and pooled
visible/hidden/off reuse in both Performance Mode states. They retain unknown
or mixed origins, same-rank ambiguity, owner/proc/variant/talent distinctions,
exact member-caster joins and original native records. Other cases cover
highest-rank captions/artwork readiness, zero-display historical members and
unchanged reuse. These cases remain CI-only
and were not executed locally; no live Eye of Hakkar snapshot was available.

Pet meter cases add explicit recorded hero/pet/summon/totem actors, overlapping
spell names, repeated summon incarnations and native type-key fallbacks. They
cover default spell/caster captions, exact-match suffix suppression without
merging player/pet identities, localized name changes, optional pet summaries, native rates and
checkpoint preservation, retained portraits, metadata changes, unchanged reuse,
hidden/off work and both Performance Mode states. Display/editor cases cover
default-off normalization, searchable controls, preview, Confirm, discard,
profiles and resets. These cases remain CI-only and were not executed locally;
they do not prove native actor metadata or live rendering.

Talent proc cases join only each positive member's single actual native talent
origin. They retain ordinary casts, native proc flags, source IDs/counters/checkpoints
and separate origin identities; definition-only, absent, conflicting, malformed
or multiple origins keep the received source presentation. Full-controller
cases show Pyroblast beside Hot Streak, FX Holy nova as Chastise and a generic
received shaman talent caption, without a hardcoded spell/talent mapping. They
cover metadata-only caption/artwork changes, pending/missing icon recovery,
unchanged pooled writes, hidden/off work and both Performance Mode states.
These cases remain CI-only and were not run locally. Actual Rockbiter, Hot Streak
and Chastise native snapshots and live rendering remain unverified.

The production banner fixture supplies an explicit `UIErrorsFrame.AddMessage`
boundary and the generated fourteen-language native catalogs. Affix-warning
cases cover exact received-text admission and native suppression, separate
identical calls, unchanged ordinary-error arguments, normal/static animation,
pool reuse, hidden expiry, mode changes, disabled/failure fallback and
world/reload/external-wrapper cleanup. These cases remain CI-only and were not
executed locally; they do not prove actual client event delivery or rendering.

SCT default cases use real Display/SCT owners to check Custom mode, Diablo IV
style, Default font, 90% size and enabled abbreviations. Missing/invalid modes
suppress native outgoing damage once during initialization, including synchronous
CVar callbacks, without touching incoming/self text; valid saved modes and later native changes keep their usual
behavior. Cases retain explicit saved values and both legacy style choices,
display preview/Confirm/discard/profiles/reset and confirmed-mode preservation
on full reset. These cases remain CI-only and were not run locally.

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

The editor fixture covers the single sidebar search above Performance Mode,
compact caption/input geometry, all nine category rows staying clear of the footer,
the recovered full content viewport and result geometry remaining in that
viewport. Category changes reuse the same header and preserve draft/scroll
behavior. It also covers metadata search without constructing unopened pages,
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
reset, preserved sizes/non-outline flags, independent text, hidden Show ordering,
rejected font/shadow assignments, fallback recovery, reuse and unchanged writes.
The editor fixture exercises all three Layout outline choices and Black shadow
in both Performance Mode states, search, unchanged clicks and Cancel/re-entry;
profile cases retain the choices through save, overwrite, load, discard and
fresh-owner restoration. Meter cases cover effective outline caching and retries;
guardian minimap cases cover countdown readiness under None and Thick outline.
SCT and segmented timer fixtures require
their production setters to opt out. These cases remain CI-only and were not
executed locally. See [FONTS.md](FONTS.md).
Stored-level integration cases load the real Display, Fonts and StoredLevels
owners: the badge keeps plain Default 12 through shared font/style transactions
and both Performance Mode states while the heading follows the shared choices.

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
data, silver fill and a dark bounded divider over mage/default health colours,
sub-unit shields, resize and pool reuse, hidden work, phase/zone/world retirement,
failed text/fill/divider texture retries and
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

- Meter-color cases exercise Default/Custom normalization, six-digit RGB values,
  missing/invalid/older-profile defaults, preview/Confirm/discard/reset and
  retained custom choices. The production editor uses explicit fake native
  picker methods to cover synchronous initialization, independent ability/proc
  previews, picker Cancel, Default retirement, foreign callback takeover,
  missing-picker hex fallback and settings search. Native and legacy meter
  cases cover both Performance Mode states, unchanged numeric values and
  fractions, changed-only RGB writes, hidden deferral, pooled reuse and retained
  Party class colors. These CI-only cases do not establish native picker
  availability, live appearance or measured performance; no local execution is
  authorized.
- Automatic Default-color cases use received native source kinds and contribution
  school/periodicity/credit fields through the existing exact same-snapshot member
  joins. They distinguish same-school/equal-caption melee, periodic damage,
  direct talents (even without a proc flag), validated talent/item origins and
  other procs, with periodic priority. Ordinary abilities retain all seven
  schools and explicit hybrid colors. Missing/unknown/malformed periodicity or
  credit, mixed members/families and non-damage credit cannot claim an all-periodic
  category; zero-display history does not vote after Reset. Category-only changes
  retain counters, rates, fractions and rate identities where source identity
  stays unchanged. Both Performance Mode states cover changed-only RGB writes,
  hidden deferral, pooled/world cleanup, Custom precedence and return to Default.
  Legacy and Party retain their existing fallbacks. These cases are CI-only and
  do not verify current provider payloads or appearance.
- Exact skill/talent suffix cases cover all three current catalog pairs and a
  future canonical pair, without a per-ability allowlist. They reject missing or
  extra suffixes, partial names, changed case, unknown/nested class prefixes and
  conflicting classes at equal or different ranks. Optional matching components
  and metadata-driven retirement are covered. Different actual casters never form
  a mixed pair even when they share a native summon definition; ordinary summon
  skill grouping keeps its existing cases. Cases combine known ability/non-proc and
  talent/proc records only with matching owner, actual caster and components.
  They use different received captions to establish key-based grouping and
  equal captions for negative identity cases. Native amounts, recent/average
  rates, mixed presentation, highest positive ability-rank artwork/caption,
  counter/order identity reuse and both original Native IDs remain covered.
  Owner/caster, role, kind, unknown attribution, missing/invalid ranks,
  variant/item components, source-only/healing scope and same-rank ambiguity
  keep their boundaries; Boss Damage shares the exact-pair rule. Reset ignores
  zero-display high ranks. Full view cases in both Performance Mode states
  include Holy Nova/Radiance and Holy Fire/Purifying Flame with different labels; they
  cover one displayed bar, Custom's mixed ability color, changed-only writes,
  hidden deferral, pooled reuse and world cleanup. These cases are CI-only;
  no local tests or native appearance verification was performed.
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
  Texture readiness cases retain true/1 success, exact/extension-stripped
  readback and explicit-failure precedence. Production loot cases hide
  unconfirmed icons without an empty gutter, then recover through the existing
  refresh and reuse the pool in both Performance Mode states.
  Display copies retain false values, range/enum normalization, legacy fallbacks
  and draft isolation. Source contracts accept the complete defaults-driven
  normalization loop and reject filtered, mis-keyed or wrong-source copies.

- Projection/metadata cases exercise production navigation cache boundaries and
  resolver preparation: successful same-pass reuse, exact coordinate identity,
  accepted-roster retirement, map/getter changes, failed projection recovery,
  fresh frame motion, bounded tab/slot/validation chunks, atomic publication, dirty/language/world
  invalidation and fresh synchronous first-use completion. They preserve the
  absence of new runtime test hooks and remain CI-only, without live FPS claims.

- The remaining-frame pass adds CI-only cases for the default-on minimap clock,
  saved off choices, missing/invalid and reset defaults, centered zone text while
  off and display transactions; selective final-window cooldown
  reads; strict SCT retirement deadlines and native raid-icon UV forms; dirty
  boss marker reconciliation with exact active halos; settled loot hold/hidden
  expiry; Revive clipping reuse; event-driven player pulses; shared Layout
  samples/final release; unchanged waypoint math with active interpolation;
  lazy Chat time and observed/unreported tooltip owners. These fixtures are
  authored for CI and were not run locally; no live rendering/FPS is inferred.

- Native local-clock cases in `ui_idle_clock_spec.lua` reuse the production
  clock and shared HUD owner. They cover 24-hour conversion from native numeric
  fields, midnight/noon, changed and backwards device readings, five-second and
  hidden/off sampling, shared tooltip content and foreign owners, preview/Cancel,
  world/logout/reload restoration, synchronous CVar callbacks and later external
  preferences. Malformed/unavailable snapshots and missing fonts/failed text
  assignments release native ownership and recover without a date fallback;
  partial HUD support avoids visibility writes and
  failed handoffs retire the duplicate custom caption. These authored CI-only
  contracts do not verify native provider availability or live clock rendering.

  Clock-fit cases supply explicit natural glyph metrics and owning-frame scale.
  They cover leftward growth past the old fixed slot, remaining zone width,
  font/scale invalidation, unchanged measurement/write reuse, hidden/off deferral,
  Show recovery and failed-metric native ownership retries in both Performance
  Mode states. No local tests or native rendering verification were performed.

- Fallen-ally waypoint mocks load the production controller with explicit
  native roster boundaries and check dead/alive/ghost/disconnect retirement,
  slot changes during reads, literal native names, nearest/stable selection,
  hidden/off sampling, display preview/Confirm/Cancel/profile/reset, world and
  phase cleanup, missing getters and stationary work in Performance Mode.
  Cache/guardian cases cover the five-second nearest-selection cadence for
  nearer arrivals and movement, responsive selected-arrow updates between
  checks, equal-distance stability, missing-coordinate fallback, hidden/off
  distance-work deferral and immediate retired-identity/visible recovery. They
  retain party selection and next-respawn priority, and check the ally default
  clears the shared static jewelry bounds without Show-time reanchoring.
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
- API-timer presentation cases in `ui_aura_layout_perf_spec.lua` exercise
  the production owner with explicit native boundaries. They cover bright,
  text-free, borderless talent/jewelry timer icons filling their existing buttons
  with positive and zero remaining time, stable received
  order at either anchor without ready/waiting movement, retained timer tooltips
  and unchanged regular native aura handling. Separate Debuffs cases retain
  native button IDs/handlers, independent roots and slots, below-Buffs defaults,
  six-column wrapping, both flip directions, anchor repair, independently hidden
  groups, pending hidden reflow and pool reuse in both Performance Mode states.
  Callback cases retire any captured native loop entry through fixture-only
  upvalue access, modeling Lua 5.0's final nil iterator result under the CI
  Lua 5.1 interpreter. They require one stable Show/Hide callback per group
  and exercise native visibility reflow after binding. This is a targeted model,
  not execution under the native Lua 5.0 client.
  Shared Layout continues to own position/scale/visibility transactions, profiles
  and resets. These authored cases remain
  CI-only and were not run locally; native appearance remains unverified.
- Extracted production unit-border transitions actually hide inactive party and
  portrait variants, restore the retained artwork on option changes and skip
  unchanged writes. These assertions distinguish shown state from alpha; they
  do not measure the packaged renderer's submitted quads or GPU time.
  The full compact-frame fixture also creates all four native party rows and
  loads the shared health-label and Mini owners. It checks Dead/Ghost changes
  from `UNIT_FLAGS` and `UNIT_CONNECTION` without health events, suppression of
  stale positive health, Ghost priority, numeric-zero flags, centered reused
  captions, independent numeric choices, resurrection, missing units, localized
  status refresh, hidden/Show recovery, unchanged writes and native bar-value
  preservation in both Performance Mode states. No new object or idle updater
  may appear during these transitions. The fixture remains CI-only.
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
  Normal-mode cases retain every identical simultaneous hit in all three styles,
  separate same-target and different-target native anchors, original values,
  independent settling, pooled reuse and world cleanup without group intake.
  Performance Mode cases retain its fixed inclusive 300 ms window, same-attack sums
  (`20 + 100 = 120`, including equal amounts), preserved original per-hit values, separate critical/source/icon
  identities, numeric overflow splitting, stable bucket cleanup,
  old/new intake separation and active animation
  surviving preview/Cancel window changes. Matching and settling keep their
  original gates. Pool reuse accepts either retired normal label while requiring
  no replacement allocation and a fresh display value; abbreviation/Cancel must
  update both normal labels. Matching-cache cases check each original hit's
  position and loss consumption instead of a shared presentation centroid.
  These are CI-only source/lifecycle assertions.
  Area-filter cases load the generated native spell data and production SCT
  over fake boundaries. They cover default-on normalization, saved off,
  profile/discard/reset behavior, all styles and both modes, native Consecration
  and totem pulse IDs, independent critical/periodic choices, current queued
  choices, mixed grouping, active removal, unchanged pool allocation, exact
  localized aliases, conflicts, unknown native IDs and world cleanup. Editor
  cases cover search, the compact category grid without a description and the final row. These cases do not
  establish live provider payloads or native cast-consumer parity.
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
- SCT layer cases model a native MEDIUM character panel above every active text
  owner, holder and visual frame across all three styles and both Performance
  Mode states. They cover repeated style/pool reuse, ongoing hits while the
  panel opens/closes, retained captions/expiry and no layer writes during
  animation. This is a relative native-frame contract; it does not exercise
  rendered panel occlusion, and the authored cases were not run locally.
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
  individual normal values versus 300 ms summed totals, active width refitting without
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

Authoring-helper fixtures use synthetic PE32+ and BLP bytes, with a fake Pillow
boundary. They cover complete file-backed spans, truncated headers/data,
fingerprint rejection before PE parsing, retained loot string limits, Raw1
alpha precision, Raw3 transparent RGB and the existing format fallback. Current
character/jewelry loaders use the production decoder without network access.
Generator cases retain UTF-8, quotes, backslashes and control bytes through the
shared Lua 5.0 string writer. These cases run in the existing CI fixture step;
they read no client files, regenerate no artwork/catalogs and were not run locally.

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

The meter view/legacy cases and `ui_pets_totems_spec.lua` cover temporary
upgrade-card hiding in both Performance Mode states: complete roots and children
hide, competing Show calls are rejected, unchanged choice passes perform no
presentation writes or source/timer reads, and returning reuses the pool.
Meter recent samples and native checkpoints survive; updated pet/totem receipts
are applied on return. Disabling and world retirement still prevent stale
reappearance. These cases are authored for CI only and were not run locally;
they do not prove the native card overlay or actual hide/show timing.

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
I–X selection, invalid-rank retirement, hidden lazy allocation, vertical
centering of the visible lettering and alignment under the first attached
affix's gold opening. The 9.375% position remains the fallback for absent,
hidden, detached or unready affixes. Cases include width/cap geometry,
unchanged anchors across positive native durations including a sub-minute
zone, binding retries and Performance Mode.
Clock-progress cases check the native rank handshake and hidden sample gate;
affix cases check rank acceptance without an affix list or visible affix row.
These CI-only scenarios were authored without local execution and do not prove
Bildad rendering, BLP decoding or native layering in game.

`ui_run_affixes_spec.lua` uses the extracted production `CreateRunAffixes`
factory, shared tooltip registry and generated native captions against fake
widgets/snapshots. Scenarios cover ordered placement, the selected 25-by-23
gold minimap bevel and exact normal-state crop, the 16-square icon above its
background layer, its measured rightward correction, source-coordinate bounds
strictly inside the gold rails for both known and unknown pictures, untinted
artwork, caption/edit bounds, first-opening coordinates for one/two captions,
row growth, resize, attachment, hidden retirement and same-width readiness
transitions, and shared static
behavior in both Performance Mode states. Hidden/unchanged work, missing or
non-Heroic data, unknown-key/known-icon reuse, receipt retirement, separate
icon/background binding failures, retry cadence, pool reuse, editing/Tooltip
visibility, foreign ownership and all fourteen native name/description sets
retain CI-only coverage.
The existing required job runs the fixture; it is not shipped or run locally.
This isolates the view boundary, rather than executing the full timer/game or
proving native packet delivery and appearance.
