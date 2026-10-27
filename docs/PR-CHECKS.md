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
  between the runtime manifest and TOC; or tracked addon Lua left outside the TOC.
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

- Unchanged cooldown values still read the native boundary but perform zero
  presentation writes and allocate no replacement objects.
- Hidden/off cooldowns skip native reads and presentation; world retirement
  clears overlays and suspends reads, and world entry resumes them.
- Range indicators reuse their texture, avoid restarting unchanged fades and
  detach their polling and clear effects when the action bar hides.
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
- SCT keeps over-enemy defaults and the display transaction, releases forced
  plate tracking in MSBT-style mode with V off, uses fixed center-relative
  outgoing anchors, spaces distinct burst lines and animates without enemy
  projection. Style changes retire active and queued hits, and expiry/world
  cleanup clears labels while retaining pool reuse and empty-list idling.

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
configured dead-code warning policy. Source-checker fixtures execute only tooling
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
