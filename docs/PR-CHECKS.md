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
- An unexpected payload file. The addon ZIP contains Lua, BLP artwork, its TOC
  and the required artwork license. Tools, test fixtures, documentation and
  authoring inputs stay out of it.
- A missing or unreferenced bundled texture, an unclassified file under `media/`,
  or a stale dynamic-owner/preparation-source rule.
- A new byte-identical runtime Lua or texture copy. Existing duplicate groups
  remain visible in the report; removing a member is allowed. A changed group
  cannot silently add another copy.
- A failing checker regression fixture or one of the existing artwork/root checks.
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
An explicit Bash shell enables `pipefail`, so piping fixture/model output into
`tee` cannot hide a failing check.

## UI work and cleanup tests

`scripts/run_ui_contracts.py` runs scenarios in Lua 5.1 with fresh mock
state per scenario. Tests exercise the actual source, including the shared text
helper, cooldown controller, range controller, HUD owner, loot intake and loot
renderer, target-health owner, health labels, damage-loss animation and SCT
controller. There is no copied cooldown algorithm, runtime test export, shipped
fixture, client-data reader or game process. AST selection extracts the original
cooldown declarations and constants by their exact byte ranges; a missing or
ambiguous declaration fails preparation.

The assertions cover:

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
  Default per-hit matching/fallback remains covered. Extraction keeps complete
  multi-variable constant declarations once, with uniqueness regression cases.

- Boss/guardian current and maximum health defaults, independent preview,
  Confirm/Cancel, profile discard and reset use the real display module. Shared
  encounter-label mocks cover all four combinations, slash visibility, actual
  label hiding, disabled/unchanged formatting, pooled text restoration and no
  added drawing objects. These do not prove native rendering or font geometry.
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
- Full SCT/filter and nameplate-style fixtures combine Names only with the
  boss/guardian filter. They cover exact capped/float32 ranges and halfway
  rounding, sleeping-to-awake ceiling conversion and its float32 serialization
  boundaries, ordinary/ambiguous elite exclusion, percentage-only rejection,
  both toggles, V and zone retirement, independent name visibility, lazy bar
  allocation/reuse and no unchanged cosmetic writes. The scrolling and plate
  fixtures share explicit native setup; production algorithms are not copied.
- Native marks messages use exact templates in all fourteen catalogs. Tests
  preserve item links/colors and original amounts/totals, keep zero-reward
  duplicates hidden, leave conversations/unknown suffixes unchanged and reject
  collected conversions before popup delivery or item metadata reads when marks
  rewards are off. Loot mode tests exercise the production display/service/view:
  defaults and invalid preferences, all modes, preview/Confirm/Cancel, profiles,
  resets, native visible/hidden ownership, failed handoff retries and synchronous
  CVar callbacks, later external preferences, no Game/Off intake or idle updater,
  deferred/reused card artwork, positive conversion labels and zero/invalid
  rewards. No mock proves native box content or live font rendering.
- The production meter cycles Party Damage after Boss Damage, reads native
  player totals/rates, binds uniquely matched native unit portraits, and retains
  class metadata across shared Reset deltas. Mocks cover unchanged/hidden/off
  and icons-off work, missing APIs, ambiguous/replaced units, failed-portrait
  caching and world retirement until a fresh `AZSPARTY` publication.

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

## Heroic affix view scenarios

`ui_run_affixes_spec.lua` uses the extracted production `CreateRunAffixes`
factory, shared tooltip registry and generated native captions against fake
widgets/snapshots. Eight scenarios cover ordered centering, the exact neutral
jewelry crop and red tint, hidden/unchanged work, missing or non-Heroic data,
unknown keys, receipt retirement, retry cadence, pool reuse, editing/Tooltip
visibility, foreign ownership and all fourteen native name/description sets.
The existing required job runs the fixture; it is not shipped or run locally.
This isolates the view boundary, rather than executing the full timer/game or
proving native packet delivery and appearance.
