# Client update compatibility

The reported regression followed the Azeroth Survivors client update. The supplied changelog identifies 0.101.0 as the move to a newer client and Lua 5.0 behavior. The screenshots show `SetText(): Font not set` in the player and target modules, an incomplete layout entry at `core/layout.lua:730`, and the client's 48 MB script-memory popup. They do not establish the exact engine commit packaged by the game or the allocation responsible for the memory popup.

## Fonts and incomplete layout registration

The addon previously passed the literal filename `DEFAULT` to `SetFont` throughout its HUD, editor and chat. Current client code checks whether a font file loads, returns nil without changing the receiver when it does not, and rejects `SetText` on an uninitialized FontString. See the pinned [WeNilla font loader](https://github.com/Arnesen/wenilla/blob/6934a85c5da7/crates/benilla-ui/src/script/font_block.rs) and [FontString text binding](https://github.com/Arnesen/wenilla/blob/6934a85c5da7/crates/benilla-ui/src/script/region/text.rs). The same behavior remains in current BeNilla.

This explains the reported source path: player and target health labels are created without an inherited font and their failed font assignment was followed by `SetText`. Layout labels used the same sequence. Registration had already added an entry to the shared update list before constructing its handle; an error in its label therefore left `entry.handle` nil for the later update loop. A failed module also skipped the positioning and hooks that followed its failed caption.

`core/fonts.lua` now resolves the game default once at file load, before factories or modules construct captions. It retains `DEFAULT` on clients that accept it; otherwise it tries the native `GameFontNormal` face, the native standard-font filename, and the original client's bundled Friz Quadrata file. The probe checks the native assignment result and its font getter without writing text. Every addon default-font assignment uses this shared resolved face, including native font globals; the Run timer's existing selected-face fallback remains in place. No external font is installed or shipped.

Layout entries become visible to the update list and native visibility wrappers only after their anchors and complete handles have been constructed. A new handle starts hidden. This prevents a failed handle setup from creating the repeated nil-handle error.

## Screen-unit rounding

BeNilla [#1946](https://github.com/samwhosung/benilla/pull/1946) changed frame sizes, positions, screen extents and cursor coordinates to the original client's screen-unit conversions. [#1962](https://github.com/samwhosung/benilla/pull/1962) extended them to font sizes, shadows, insets and other lengths. Native getters can now differ slightly from the Lua values passed to setters: a width of 100 can read back as 99.99999850988391 at 4:3 or 100.00000136774479 at 16:9, as documented in the upstream [source cases](https://github.com/samwhosung/benilla/blob/adbfedc3660d/crates/benilla-ui/src/script/tests/screen_units.rs).

Layout and chat now compare these values with one finite-number tolerance instead of continually reapplying nominally identical anchors, dimensions, fonts and insets. The existing effective-scale conversions, confirmed normalized positions and independent group geometry remain authoritative. There is no resolution cutoff or replacement coordinate system. These changes address source-level causes of incomplete or repeatedly invalidated layout; they do not establish visual alignment on any particular monitor.

## Lua globals and memory

BeNilla [#1792](https://github.com/samwhosung/benilla/pull/1792) removed the native `_G` global. The addon already supplies `_G = getfenv(0)` inside its private module environment through `DFRL:GetEnv()`. Adding a global `_G` shim is not needed for the reported paths.

BeNilla [#1782](https://github.com/samwhosung/benilla/pull/1782) enabled the original client's `scriptMemory` enforcement. Its default 49,152 KB limit covers the whole Lua state, including the game interface and all addons. The client attempts collection, shows the supplied popup if usage remains over the limit, and may exit after 15 seconds. [#1788](https://github.com/samwhosung/benilla/pull/1788) subsequently aligned the accounting with 32-bit Lua 5.0 object sizes. WeNilla's [upstream merge](https://github.com/Arnesen/wenilla/commit/024ae5882e44) includes these Lua and memory changes.

The screenshot alone cannot attribute those allocations. This fix removes the font/layout error cascade and redundant native writes; it does not claim to prove or eliminate script-memory exhaustion. The requested complete session diagnostics remain uncapped and session-only. The addon does not change the game's memory limit, discard capture records or alter other addons.

## Evidence limits

Investigation and implementation used the supplied screenshots/changelog and read-only source inspection. No local tests, syntax checks, formatting checks, harnesses, addon execution or game startups were run. The existing GitHub Actions workflow performs the authorized formatting, local dead-code and TOC metadata checks only. Packaged-game startup, memory use and appearance at 1080p, 1440p, 4K and different UI scales require game-side confirmation.
