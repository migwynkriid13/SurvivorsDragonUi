# Full codebase validation — 2026-10-19

The owner explicitly authorized this local validation pass after the client-update fixes. It covers all tracked Lua source and the complete shipped payload, plus focused behavior checks of actual modules. It does not change the standing project policy for future validation or start the game.

## Defect found and corrected

`core/localization.lua` escaped every non-word byte when compiling localized message templates. This also escaped each byte of accented and Asian text. Stock Lua 5.0 failed those escaped UTF-8 literal matches, leaving some talent notices unformatted and some requested announcement suppression inactive.

The matcher now escapes only Lua pattern metacharacters and preserves UTF-8 literal bytes. The initial formatter/display suite exposed 57 failing assertions; after correction, all 197 assertions pass across the 13 supplied language catalogs, including explicit metacharacter, anchoring and newline cases. Existing jewelry-effect matching already used the correct literal-escaping rule and needed no change.

## Follow-up: native edit-region geometry

Subsequent action-bar and chat screenshots exposed a gap in the first geometry adapter: it modeled all size getters as local values. The native client instead returns authored local sizes for nonzero dimensions and already-scaled spans for automatically sized axes. Edit regions use the latter path, so their outlines could be scaled twice. The original adapter's passing cases did not establish this native behavior.

The corrected source-calibrated fixture reproduces the old outline at exactly 90% of the artwork width under UI scale 0.9: 252.72 versus 280.8. The edge-based local-size helper fixes the outline, resize geometry, numeric screen centers and dialog width clipping. Existing saved-position normalization is preserved so confirmed geometry does not shift or require a reset.

The first 73 assertions in `tests/layout_geometry.lua` pass; the prior layout fails 41 of those 73. It covers four UI scales crossed with four group scales, explicit and anchored dimensions, chat footer bounds, numeric centers, uniform/dimensional corner resizing, Cancel/Reset and already-confirmed positions. This adapter checks native source examples explicitly rather than treating every size getter alike.

With a stock Lua 5.0 interpreter, the focused regression runs without starting the game:

```sh
lua tests/layout_geometry.lua .
```

## Follow-up: defaults after a fresh run

The owner then reported Addon defaults shifting the run timer, chat, micro menu, minimap and cache/guardian guides left/up after the next run, without making further edits. The native save file correctly contained empty layout geometry and cleared display/timer-font preferences. Source inspection found that native startup applies UI scale after addon initialization; Layout Ready had captured defaults earlier, and its first update skipped viewport recovery because no previous sample existed.

The first valid layout update now refreshes default anchors in the current viewport before applying existing geometry. The committed fixture models the native ordering explicitly: initialize at scale 1, apply scale 0.9 before the first world update, then reset, leave/re-enter and create another fresh session with the saved reset. Its expanded 175 assertions pass; the immediately preceding layout fails 18 startup assertions. Confirmed record identity, normalized coordinates and group scale are preserved. The earlier passing same-session transition checks did not exercise this fresh-session ordering.

## Static and package checks

- All 42 tracked Lua files compile with unmodified Lua 5.0.3, including the two unshipped Lua files. The original `main` copy of `modules/ui/run.lua` reproduces the reported line-1761 `too many upvalues (limit=32)` compiler failure; the corrected version passes.
- The TOC loads exactly the manifest's 40 Lua files, without duplicates or unloaded packaged Lua. All 125 runtime files exist and pass the package script's path and membership checks.
- The package contains exactly those 125 files under `SurvivorsDragonUi/`, and every ZIP member passes its CRC check.
- All 84 texture files are present. The 71 TGA files pass dimensions, supported header and uncompressed-payload length checks; the 13 BLP files have valid BLP signatures. These are file checks, not native texture rendering tests.
- The current TOC version is checked against the latest target `main` using the shared payload comparison.
- Pinned Prettier 3.9.10 and StyLua 2.6.0 check all tracked owned text and Lua. Luacheck 1.2.0 checks all 42 Lua files with the repository's dead-code warning selection, reporting zero warnings, errors or fatal results.

The machine's default Lua 5.5 is unsuitable for the client checks, and its installed Luacheck launcher also fails under that version. Isolated stock Lua 5.0.3 and Lua 5.1.5 toolchains were built outside the repository instead. The latter runs the installed Luacheck 1.2.0 API with the same warning selection as CI. Official Lua source archives were checked against their published SHA-256 hashes. No system Lua installation or client setting was replaced.

## Behavior checks

All eleven separate harness runs pass. The five suites with explicit counters total 502 passing assertions; the other runs exercise boot and HUD scenarios. Each loads the actual addon modules, using small native-API/widget adapters where required:

- File-load smoke: all 40 shipped Lua files load with native `_G` absent and the old `DEFAULT` alias rejected; 33 unique modules register in the dependency order. Native font fallback succeeds without adding a native `_G`. This smoke check registers modules without running all their initializers.
- Font initializer: 62 assertions cover both supported/rejected `DEFAULT` clients, native-face fallback, stale `GetObjectType` and broken `GetFont` candidates, zero-size global fonts, invalid-size fallback and private `_G` isolation.
- Formatter and display: 197 assertions cover requested ability, skill, level, decimal stat, loot, talent and announcement rules, all 13 languages, raw fallback, and display normalization/draft/confirm/reset behavior.
- Layout lifecycle: 41 assertions cover fractional and decimal-comma coordinates, four viewport/UI-scale combinations including 1080p, 1440p and 4K, Apply versus Confirm, invalid input, discard, world leave, reset and hidden targets. The geometry adapter supplies independent WoW-style coordinate conversions.
- Native geometry: 175 assertions check the mixed size contract, action/chat outlines, preserved confirmed positions and late UI-scale application across fresh sessions as described above.
- Chat integration: 27 assertions cover level/stat coalescing, standalone timeout and message order, insert direction, player speech, NPC yells, suppression, untouched combat-log formatting, protected-call raw fallback, wheel-only history, cross-frame capture deduplication, same-frame repeated calls and a fresh `/copy` snapshot.
- Run HUD: clock/tally initialization, zero-valued gold/cache, encounter pool retirement/reuse, native takeover/restoration, world leave and reacquisition.
- Schedule: complete due/up/dead lists, rejection of incomplete/duplicate/mismatched-final/unknown-state lists, skull/glow/check behavior, time-limit hiding/restoration and unused-marker cleanup.
- SCT: 400 hits across 50 display/retirement cycles, remembered-table-length cleanup, mode preview/discard/confirm and world transitions.
- Waypoints: awake/asleep guardians, native snapshot acceptance, paused retention, observed run/world boundaries, independent-prefix replay, fresh same-batch zone data, guardian replacement and guide cleanup.
- Resources and portraits: per-class native primary-resource delivery, invalid/off cleanup and recovery, independent model copies, still portraits remaining until accepted callbacks, ordinary-update still restoration without rebinding, and retired-subject cleanup.

The code audit also traced module exports, deferred world-entry setup, private environments, tooltip method signatures, unit frames, menus, minimap and native action/key self-cast wiring. No additional evidence-backed defect was found in those paths.

## Practical limits

The language compiler is stock Lua 5.0.3, not the packaged game's custom VM. Native widget/rendering APIs are adapters in the behavior tests. These results establish the exercised Lua wiring and lifecycle behavior, not pixel alignment, font glyph availability, model rendering, native direct writes bypassing Lua, performance or memory use in the game.

The 48 MB popup still identifies the whole native Lua state exceeding its limit, without identifying which game/addon allocations caused it. This pass neither attributes that memory use nor changes the requested uncapped session diagnostics or native memory setting. No game startup, GPU rendering or live-game validation was performed.
