# Client update compatibility

The reported regression followed the Azeroth Survivors client update. The supplied changelog identifies 0.101.0 as the move to a newer client and Lua 5.0 behavior. The screenshots show `SetText(): Font not set` in the player and target modules, an incomplete layout entry at `core/layout.lua:730`, and the client's 48 MB script-memory popup. They do not establish the exact engine commit packaged by the game or the allocation responsible for the memory popup.

## Exact lossless palettes — 2026-10-27

Runtime artwork now uses BLP2 Raw1 where one palette can represent every RGB
value exactly, retaining a separate full-precision alpha block. The remaining
prepared textures keep Raw3. This supersedes the Raw3-only preparation policy
described in the earlier compatibility history below; native/browser runtime
paths remain explicit `.blp` files in one shared package.

The pinned Wenilla
[Raw1 decoder](https://github.com/Arnesen/wenilla/blob/3426fd28c55b1d3dad22459d1a80e72a05a8006c/crates/benilla-blp/src/lib.rs#L372-L412)
reads a 256-entry BGRA palette, one byte per pixel of color indices, and a
separate alpha block. Zero alpha bits means every pixel is opaque. One-bit
alpha is used only when every original byte is exactly 0 or 255, packed least
significant bit first. All other alpha bytes are stored unchanged at eight bits.
The palette's own alpha bytes do not replace that block. Both Raw1 and Raw3
retain the required 1,024-byte palette area after the 148-byte header.

`scripts/prepare_client_textures.py` indexes exact BGR triples across every mip
level, including RGB under fully transparent pixels. More than 256 distinct
colors or a file that would not become smaller retains its original encoding.
No color quantization, alpha approximation, trimming, resizing or mip removal
is allowed. The converter decodes its result and compares every BGRA byte before
accepting a palette. Its final manifest pass also covers prepared BLP files
without a same-name TGA, and `save_image` uses the same policy. The original
target-of-target Health BLP remains intact; HealthFill retains the distinct
converted-TGA path and the large health fill keeps its exact source crop.

The shared `image_from_bytes` authoring reader in
`scripts/prepare_client_textures.py` serves character, jewelry/tally and loot
preview inputs. It decodes Raw1/Raw3 through `blp_bgra_levels`, preserving the
separate alpha block. Pillow's installed BLP reader reads palette alpha instead
of that block, so it must not decode these prepared files. Other formats retain
the existing Pillow fallback, including DXT sources.

Exactly 48 files changed: seven have fully opaque alpha, three have binary alpha,
and 38 retain arbitrary eight-bit alpha. They all retain their original single
mip level. Independent integer-based reconstruction, following the pinned native
layout, matched every original BGRA and alpha byte; the shared authoring reader
matched those originals too. The other 60 BLP files and all 72 TGA preparation
inputs stayed byte-identical. The manifest, filenames, Lua, UVs, canvases, native
values, fonts and geometry are unchanged.

| Measurement                                                   |           Before |            After |
| ------------------------------------------------------------- | ---------------: | ---------------: |
| Runtime BLP files                                             | 26,788,520 bytes | 23,427,192 bytes |
| Complete runtime ZIP, measured in memory with DEFLATE level 9 |  2,110,316 bytes |  2,076,700 bytes |

That saves 3,361,328 bytes (3.21 MiB) after extraction and 33,616 bytes
(32.8 KiB, 1.59%) in the ZIP. Its current 108 images are 48 Raw1, 54 Raw3 and
six unchanged original DXT5 files. These are file-size results, not memory/FPS
measurements: the reference
[UI sprite path](https://github.com/Arnesen/wenilla/blob/3426fd28c55b1d3dad22459d1a80e72a05a8006c/crates/benilla-assets/src/world_assets/mod.rs#L643-L670)
decodes interface textures to RGBA before uploading them. Palette packing does
not change the decoded dimensions, sampling or number of drawn regions, and
does not require GPU block-compression support.

The local backup and per-file pixel/alpha hashes are under
`validation/local-backups/lossless-palette-20261027/`, outside the runtime payload.
The original inputs and their upstream provenance are retained. Data-only asset
preparation and byte comparisons were performed; no addon/game execution or
local test suite was run. Raw1 is accepted by the referenced shared decoder,
including the browser's BLP path, avoiding the earlier TGA header-probe boundary.
Actual packaged native/browser rendering remains unverified; the exact deployed
engine revisions are not established by this conversion.

## Texture loading after the 0.116 engine update

The reported missing jewelry rims, rail, tally surrounds and `/sdui` borders
match two constraints in the updated client. The pinned
[Wenilla TGA loader](https://github.com/Arnesen/wenilla/blob/3426fd28c55b1d3dad22459d1a80e72a05a8006c/crates/benilla-formats/src/tga.rs)
accepts power-of-two TGA dimensions strictly below 1024. Its truecolour decoder
also requires the pixel depth minus the declared alpha bits to equal 24.
An admitted header whose pixels fail decoding draws opaque white, explaining
the coin square without requiring a Lua error. The same decoder error wording
is present in the installed executable, SHA-256
`507a791fad3aec59afb2f90d2737cdab4dbbe79b98c5e74d7699fe44bed16293`,
whose embedded game version is 0.117.0.

Twenty-six shipped sheets were 1024 or 2048 pixels wide: character chrome,
the editor border and divider, the guardian header, jewelry rims and rail,
and all twenty attached/detached tally styles. They now use uncompressed
BLP2 Raw3 files with the required palette block, supported by the native
[BLP reader](https://github.com/Arnesen/wenilla/blob/3426fd28c55b1d3dad22459d1a80e72a05a8006c/crates/benilla-blp/src/lib.rs).
The conversion preserves every BGRA pixel, the original canvas dimensions
and all runtime UVs and geometry. It performs no resizing or recompression.
The original `Coins.tga` remains a TGA; only its descriptor changes from
`0x20` to `0x28` to declare the eight alpha bits already in its pixels.

Runtime filenames and the shared manifest name the BLP outputs. After
regenerating the original TGA artwork, run
`python3 scripts/prepare_client_textures.py` to repack oversized manifest
inputs and align generated tally filenames. Source artwork and provenance
remain unchanged. Original TGA files remain available in the parent Git
revision for pixel comparison. A local rollback copy and conversion receipt
are retained outside the runtime manifest.

The local artwork comparison records identical pixel buffers and canvas sizes
for all 26 BLP outputs against those backed-up TGAs. The coin differs at byte
17 only. This is file-conversion evidence, not an in-game rendering result.

Reload the UI to rebuild texture lookup state and load the changed filenames.
No addon, game or local test suite was executed; restored appearance and any
remaining health-bar mismatch require game-side confirmation.

## Browser and native artwork

The browser report affects the remaining small TGAs as well as oversized
artwork. Firefox's stored addon was `3.2.47-survivors`. Its action-bar
background, blue timer fill, fixed timer background, cache-guide icon and coin
atlas contained the same bytes as the working local installation. These files
have power-of-two dimensions below 1024 and eight declared alpha bits. The
screenshots retain the BLP jewelry rail and tally surround while the TGA
action-bar material, timer pill, minimap trim and cache guide are absent.

The public Wenilla [texture probe](https://github.com/Arnesen/wenilla/blob/3426fd28c55b1d3dad22459d1a80e72a05a8006c/crates/benilla-assets/src/world_assets/mod.rs#L230)
reads a TGA header through `LooseFile::read_prefix`, whose
[plain-file path](https://github.com/Arnesen/wenilla/blob/3426fd28c55b1d3dad22459d1a80e72a05a8006c/crates/benilla-formats/src/loose.rs#L148)
uses `std::fs::File::open`. The site's browser addons are supplied through an
in-memory `window.__wenilla_fs` bridge. This is a likely boundary for the
TGA-only failure; the exact deployed engine revision and failing call were
not established by runtime diagnostics.

All 72 remaining bundled TGAs now have uncompressed BLP2 Raw3 runtime versions,
using the same container and required palette block as the earlier oversized
conversions. Browser and native clients use one package with explicit BLP
filenames. There is no browser detection, texture fallback, extra updater or
layout migration. The manifest excludes every TGA; the original inputs remain
in the source checkout for preparation and provenance. Native game texture
paths and metadata normalization retain their existing behavior.

`scripts/prepare_client_textures.py` now repacks every manifest BLP with a TGA
input, including the two RLE close-button images and three opaque 24-bit unit
textures. It expands RLE without resampling, preserves each 32-bit alpha byte
and adds opaque alpha to 24-bit pixels. Orientation is normalized to top-first
BGRA, with unchanged dimensions, colors, crops and UVs. Its optional receipt
records the dimensions and pixel-buffer SHA-256 for each conversion. The
original coin remains the preparation input for `Coins.blp`; it is no longer
rewritten during preparation.

The original target-of-target `Health.blp` and `Health.tga` artwork have distinct
callers. The converted TGA uses the separate `HealthFill.blp` suffix, preserving
the existing BLP. The player/target `healthDF2Fill.blp` preparation below retains
its original crop and pixels. Existing artwork generators can still write TGA
inputs; run the shared preparation step before packaging.

Version `3.2.48-survivors` contains this format-only compatibility change. The
artwork preparation ran locally; no local test, standalone validation, addon
or game execution was performed. Rendering in both clients remains unverified.

## Missing native textures

The reported `modules/micro/micro.lua:41` and `modules/ui/character.lua:832`
errors came from styling a button-state texture without checking the native
getter's result. A texture setter does not guarantee that the following
getter returns a region. Both affected paths were present in addon
`3.2.42-survivors`; these errors alone do not establish an older installation.

Micro-menu and character close-button styling now check each returned texture
before cropping, anchoring, desaturating or changing its blend mode. An
unavailable state no longer aborts the rest of the module's setup. Available
states keep their original artwork, coordinates and styling, and the
character window's existing refresh continues to call the texture setters.
Action-button highlights and the character scrollbar thumb are also checked
before styling or sizing. Party-bar backgrounds are created only when the
native fill texture exists. Missing textures no longer stop the remaining
action-bar, character-window or party-frame setup; available textures retain
their existing appearance and dimensions.
No updater or saved state is added. The underlying load failure and in-game
appearance remain unverified; no local tests or addon/game execution were run.

## Unit health labels

The Unit frames page offers independent **Show health** and **Show health percentage** controls. Their normalized `showHealthValue` and `showHealthPercentage` booleans live in the existing display table, defaulting to true and false respectively for missing or invalid saves. The shared display lifecycle includes live preview, Confirm-only saving, Cancel/world/logout/reload discard, profiles and both resets.

Player, target, target-of-target, party and native pet labels use `T.BindUnitHealthText` in `core/widgets.lua`. One enabled value stays at the existing centered health-label position. With both visible, current health anchors to the left and percentage to the right, respecting portrait/resource insets. Disabling both clears the text. Missing units and dead target/target-of-target units retain their existing clearing behavior. Boss and guardian bars retain their separate current / maximum labels.

Percentages use native `UnitHealth` and `UnitHealthMax`, rounded to the nearest whole percent and bounded to 0–100. Unavailable, nonfinite or nonpositive maxima omit the percentage; an enabled health value then remains centered. Existing health/native refresh paths and `UNIT_MAXHEALTH` events refresh labels, with unchanged text and anchors skipped. No additional updater or native health override is added. Source TSV and runtime UI captions cover all fourteen languages. Appearance and runtime behavior remain unverified.

## Class-colored player and party health

**Class-colored health** in `/sdui` → **Unit frames** applies the existing `classHealth` choice to the player and all four native party health bars. Each bar reads its own canonical class through native `UnitClass(unit)` and the shared original class palette, including the Shaman blue override. Missing class data and the disabled choice use the original green. The existing preview, Confirm, Cancel/world/logout/reload discard, profiles and both resets remain shared; no setting, SavedVariable or updater is added.

`T.BindClassHealthColor` in `core/widgets.lua` shares the player's native recolor protection with party bars. It retains the original setter, compares actual RGBA before painting and refreshes its effective color from the existing native value/event paths and display listeners. Party roster changes refresh each slot's current class through the existing Mini event handler. The original party `Health.blp` has baked green pixels, so multiplying it by a class color only darkens that green. Party bars now use the same neutral prepared `T.LargeHealthFill.texture` as the player in both color modes. This supersedes the intermediate switch between the original green fill and neutral target-of-target fill; disabling class colors restores green through the tint alone. Target, target-of-target, pet and encounter color rules remain separate.

## Party health seams and corners

Party bars reuse the player's prepared `healthDF2Fill.blp` with native full UVs, without a crop callback or changes to native fill-rectangle behavior. Their thinner metal edge uses half of `T.LargeHealthFill.underlap`: a 0.5-unit render extension on every side. The original health content centers and 11/17.5-unit resource split remain the reference geometry; label insets compensate for the extension so both health captions stay in their old positions. The health background uses the player's passive black native-texture treatment instead of repeating the old shaded green fill. Power artwork, values and positioning keep their existing behavior.

With resources hidden, the party-only border pieces follow the actual gold portrait contour through source rows 26–34 instead of carrying old divider fragments past the ring. Single-row tips clamp their UVs to source pixel centers so neighboring divider pixels cannot filter back in. The top strip stops at source y18, removing the old rectangular shadow that stopped abruptly at y22. The outer end includes source x112–114's full rounded contour, replacing the obsolete divider rows y26–29 with the clean vertical edge at y22–25. Pieces meet edge to edge without overlapping alpha. Enabling resources restores the original complete border and divider. The target-of-target crop is unchanged.

All artwork already ships in the shared runtime manifest; no file is generated or added. The original ring, outer frame, portrait, names, resource row, native values and saved layout remain owned by their existing widgets. Static source-artwork inspection and illustrative composites guided the crop; those composites do not establish in-game filtering. Edited Lua and Markdown were formatted with the pinned tools. No local tests, standalone validation or addon/game execution were run, and corrected in-game appearance remains unverified.

## Native health-fill coordinates

The later player/target screenshot shows a separate compatibility problem.
The original `healthDF2.tga` is a valid 128-by-32 image, but its padding was
removed by setting UVs on the native StatusBar texture in `OnValueChanged`.
Wenilla's
[StatusBar update](https://github.com/Arnesen/wenilla/blob/3426fd28c55b1d3dad22459d1a80e72a05a8006c/crates/benilla-ui/src/script/statusbar.rs)
writes the fill coordinates after callbacks, replacing that crop. Its
[rectangle calculation](https://github.com/Arnesen/wenilla/blob/3426fd28c55b1d3dad22459d1a80e72a05a8006c/crates/benilla-ui/src/script/extract.rs)
also uses those coordinates to size the fill. Disabling that behavior or
continually reapplying the artwork crop would interfere with native health
fractions.

`scripts/prepare_client_textures.py` now copies the original interior pixels
from rectangle `(6, 5, 122, 25)` into the 116-by-20 uncompressed
`healthDF2Fill.blp`. These columns enclose the former half-texel horizontal
sampling window; the twenty rows retain its original vertical crop. No pixels
are resized, recolored or recompressed. The distinct filename avoids the
loader preferring the original TGA over a BLP with the same basename.
The original TGA remains a preparation input outside the runtime manifest.

Player and target use this fill with native full UVs, and their shared
damage-loss overlay uses the same prepared image. The old crop callback is
removed. Native values, range changes, fill clipping, class/party colors
and overlay fading keep their existing ownership.

The later close-up also exposes two border-cut problems. The old outer-end
strip stopped at source x30, dropping the rounded opening's contour through
x32 while retaining part of the former resource divider. The side pieces now
include that contour. With resources off, the four-unit divider span samples
the clean neighboring edge at y47.5–51.5; with resources on, the player retains
the original divider and its end. The pointed portrait's inner crop stops at
x153.5, excluding the obsolete x152 divider and its filtered neighbors without
moving the gold artwork.

`T.LargeHealthFill.underlap` extends the native health rectangle by one UI unit
on every side, beneath the original border. This closes the inner-edge gaps
while the restored corner artwork shapes the visible fill. Health-label
insets, player-name anchors, the original resource row/divider and portraitless
borders compensate for that underlap, retaining their previous positions.
The prepared fill pixels and full UVs are unchanged; damage loss follows the
same expanded rectangle through its existing size hook. Outer frames, saved
geometry, native health reads and the resource content split remain unchanged.

No updater, asset or saved state is added. The source pixels and edited code
were inspected and the Lua and Markdown were formatted with the pinned tools.
Exact filtering and in-game appearance remain unverified; no local addon,
game, test or standalone validation execution was performed.

## FontString scale and Lua errors

The Level Up measurement cache reads effective scale from the FontString's
owning frame, matching the existing run-clock label renderer. The current
client exposes `GetEffectiveScale` on frames, but the reported FontString call
raised a nil-method error during Layout Ready and later stored-level updates.

At the user's request, the original `core/error.lua` handler is restored and
loads before the other addon files. It installs the global error handler at
file load and after every `ADDON_LOADED`, printing the original red
`DFRL: Error` messages directly to chat. Each distinct message appears twice,
followed by one `ERROR SPAM THROTTLED` notice; later repeats stay hidden for
the Lua session. Chat announcement filtering leaves these messages visible.
Caught module failures still call the current `geterrorhandler()`. This
restores the original behavior without forwarding to collectors such as
SurvivorBugs. Reloading the UI is required to use the restored handler.

## Fonts and incomplete layout registration

The addon previously passed the literal filename `DEFAULT` to `SetFont` throughout its HUD, editor and chat. Current client code checks whether a font file loads, returns nil without changing the receiver when it does not, and rejects `SetText` on an uninitialized FontString. See the pinned [WeNilla font loader](https://github.com/Arnesen/wenilla/blob/6934a85c5da7/crates/benilla-ui/src/script/font_block.rs) and [FontString text binding](https://github.com/Arnesen/wenilla/blob/6934a85c5da7/crates/benilla-ui/src/script/region/text.rs). The same behavior remains in current BeNilla.

This explains the reported source path: player and target health labels are created without an inherited font and their failed font assignment was followed by `SetText`. Layout labels used the same sequence. Registration had already added an entry to the shared update list before constructing its handle; an error in its label therefore left `entry.handle` nil for the later update loop. A failed module also skipped the positioning and hooks that followed its failed caption.

`core/fonts.lua` now resolves the game default once at file load, before factories or modules construct captions. It retains `DEFAULT` on clients that accept it; otherwise it tries the native `GameFontNormal` face, the native standard-font filename, and the original client's bundled Friz Quadrata file. The probe checks the native assignment result and its font getter without writing text. Every addon default-font assignment uses this shared resolved face, including native font globals; the Run timer's existing selected-face fallback remains in place. This default-font repair adds no font asset. The later optional [PT Serif combat-text face](DIABLO-SCT.md#damage-number-font) is bundled separately and falls back to this resolved game font if rejected.

Layout entries become visible to the update list and native visibility wrappers only after their anchors and complete handles have been constructed. A new handle starts hidden. This prevents a failed handle setup from creating the repeated nil-handle error.

The additional reported missing UI follows these same initialization dependencies:

| Reported symptom                        | Affected source path                                                                                                                                                                                                |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Missing player/target health text       | Their new value FontStrings use the rejected default-font assignment before their first health `SetText`.                                                                                                           |
| CleanerChat presentation absent         | Its first custom captions require a loaded default font; a failed caption stops `Chat` setup. Native chat can remain visible.                                                                                       |
| Jewelry textures absent                 | `Jewelry` registers its layout handle before attaching its hidden HUD to the action bar and enabling inventory texture refresh. A failed handle caption aborts those steps even when the texture files are present. |
| SCT text absent                         | Its pooled damage FontStrings use the same default-font assignment before the first damage label is written.                                                                                                        |
| Nameplate text absent                   | Both the copied-name FontStrings and native `NAMEPLATE_FONT` previously used the rejected alias.                                                                                                                    |
| Kills, gold and cache-cost tally absent | `RunTimers` registers its run-timer and boss-bar handles before creating the three tally fields. A failed handle caption prevents tally creation.                                                                   |

This maps the reports to source-level failure paths; visibility and texture rendering still require confirmation in the packaged game.

The first installed fix exposed another native-handle difference: `Fonts` stopped at `core/fonts.lua:36` with `stale or invalid widget handle` while scanning globals. A retained wrapper can expose `GetObjectType` but raise when called. Each native font candidate is now inspected and updated within its own protected call, so a retired widget cannot abort the rest of the pass.

## Native chat resize error

The supplied screenshot reports `FloatingChatFrame.lua:600: Frame ChatFrame1 is not resizable`. The addon marked each attached native chat frame non-resizable but hid only a control named `ResizeButton`. The pinned [original FloatingChatFrame XML](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/d162a4c0d198a4381b5b6573d975635ed7316702/1.12.1/FrameXML/FloatingChatFrame.xml) instead defines eight edge/corner resize buttons. Their mouse handlers call `FCF_Resize`, whose [native Lua implementation](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/d162a4c0d198a4381b5b6573d975635ed7316702/1.12.1/FrameXML/FloatingChatFrame.lua#L600) calls `StartSizing` on the parent. Those untouched buttons could therefore invoke sizing on a frame the addon had made non-resizable.

Chat setup now permanently hides all eight controls through the existing control-hiding helper, retaining `ResizeButton` support for other client layouts. It restores the native frame's XML-declared resizable capability. The separate `/sdui` container still owns chat position and dimensions; native events, history, hyperlinks, wheel scrolling and message formatting remain in place. No FrameXML globals are overridden and no error handler is suppressed. This is a source-reviewed correction; local checks and addon/game execution were intentionally not run, so live behavior remains unverified.

## Lua 5.0 closure limit

The subsequent supplied reload screenshot reports `modules/ui/run.lua:1761: too many upvalues (limit=32)`. This is a compiler rejection: the combined HUD update captured more locals than Lua 5.0 permits, so the whole `RunTimers` module was unavailable before any of its initialization ran. That independently explains the absent run clock, encounter bars and kills/gold/cache-cost tally. The earlier font errors also affected these paths where compilation succeeded.

The update now calls separate boundary and clock helpers. Each helper captures only its own dependencies, and the small coordinator still checks native phase before reading retained tables, updates run boundaries before the clock, and refreshes the tally/encounters last. Native timing, schedule continuity, takeover/release and reload handoff behavior are preserved. No captured state becomes global or saved, and no native compiler limit is bypassed.

## Screen-unit rounding

BeNilla [#1946](https://github.com/samwhosung/benilla/pull/1946) changed frame sizes, positions, screen extents and cursor coordinates to the original client's screen-unit conversions. [#1962](https://github.com/samwhosung/benilla/pull/1962) extended them to font sizes, shadows, insets and other lengths. Native getters can now differ slightly from the Lua values passed to setters: a width of 100 can read back as 99.99999850988391 at 4:3 or 100.00000136774479 at 16:9, as documented in the upstream [source cases](https://github.com/samwhosung/benilla/blob/adbfedc3660d/crates/benilla-ui/src/script/tests/screen_units.rs).

Layout and chat now compare these values with one finite-number tolerance instead of continually reapplying nominally identical anchors, dimensions, fonts and insets. The existing effective-scale conversions, confirmed normalized positions and independent group geometry remain authoritative. There is no resolution cutoff or replacement coordinate system. These changes address source-level causes of incomplete or repeatedly invalidated layout; they do not establish visual alignment on any particular monitor.

## Anchor-sized edit regions

The later action-bar and chat screenshots expose a separate size-contract mismatch, larger than float rounding. Native `GetWidth`/`GetHeight` return authored local dimensions when nonzero, but an automatically sized axis returns its resolved span without dividing by effective scale. Edge getters do divide that scale. This distinction exists in both the examined [WeNilla implementation](https://github.com/Arnesen/wenilla/blob/6934a85c5da7/crates/benilla-ui/src/script/object/layout_methods.rs) and [BeNilla implementation](https://github.com/samwhosung/benilla/blob/adbfedc3660d/crates/benilla-ui/src/script/object/layout_methods.rs); it is not a claim that the later float-rounding changes introduced the distinction.

The edit regions are sized by opposite anchors. Treating their returned spans as local dimensions scaled them again: at UI scale 0.9, the chat edit region's actual 521-by-372 local bounds, including the 32-unit footer, read as 468.9 by 334.8. The outline therefore became 90% of the intended size. A source-calibrated regression reproduces the action region at 280.8 physical width with a 252.72-wide old handle.

The shared `GetLocalSize` helper now measures rendered local bounds from right-minus-left and top-minus-bottom, retaining raw getters only while edge geometry is unavailable. Handles, resize diagonals/opposite corners, numeric screen-center calculations and dialog width clipping use those extents. Explicitly authored sizes, native chat input ownership, artwork and fonts remain as before. Saved-position normalization retains its existing denominator; no confirmed coordinates are reinterpreted, cleared or migrated.

The committed [geometry regression](../tests/layout_geometry.lua) passes 73 assertions across four UI scales and four group scales. The prior layout implementation fails 41 of those assertions. It covers action/chat outlines, chat footer bounds, numeric centers, corner resizing and confirmed-position preservation. The earlier geometry adapter assumed uniformly local size getters and missed this native distinction; the new fixture explicitly models both getter paths.

The boss-health loss strip also uses `T.GetLocalSize` for its anchor-sized
StatusBar. Its earlier raw-width calculation applied effective scale twice,
placing the strip inside the remaining fill and leaving red health visible
after it. The existing XP effect already used the shared helper for the same
coordinate boundary. CI-only boss-loss cases now model an anchor-sized bar whose
raw width contains scale while its edge extent remains local, covering UI/group
scales, resizing and rapid decreases. Native fill ownership, UVs and values are
unchanged; source-calibrated geometry does not prove live rendering.

## Defaults shifting after a new run

The owner reported that Addon defaults looked correct, but the run timer, chat, micro menu, minimap and waypoint HUDs shifted left/up after ending the run and entering again, without making further edits. The account save file contained the reset correctly: empty layout geometry and cleared display/timer-font choices. An empty layout is the intended saved representation of code-defined defaults.

The examined [native startup sequence](https://github.com/Arnesen/wenilla/blob/6934a85c5da7/crates/benilla-app/src/ui_script/lifecycle.rs) loads addons and emits `ADDON_LOADED` before applying the saved UI scale. The addon's Layout Ready initializer had already captured default positions at the earlier scale. The first layout update skipped viewport-change recovery because it had no previous viewport sample, then reapplied those stale positions. Pressing Addon defaults during a run recalculated them at the current scale, but a fresh UI session repeated the earlier capture.

The first valid layout update now recalculates authored default anchors just as a later viewport change does, before applying current geometry. Confirmed records still use their existing normalized coordinates; neither startup nor world transitions save, clear or reinterpret them. Addon defaults still applies immediately without Confirm, while later custom edits still require Confirm. This corrects default-position reconstruction rather than changing SavedVariables serialization. The expanded geometry fixture passes all 175 assertions. Before this startup fix, 18 assertions reproduce shifted defaults for the reported groups, both on first entry and after a fresh session following Addon defaults; confirmed geometry remains unchanged.

## SCT numbers ending in dots

The supplied screenshot shows orange critical values such as `1...` and `10...` alongside complete normal-hit numbers. The addon passes the full `tostring(value)` to `SetText`; it does not abbreviate damage amounts. Its FontString had only a center anchor and no explicit dimensions. The surrounding 240-by-60 visual frame does not give that FontString its text box.

The native [text extraction path](https://github.com/Arnesen/wenilla/blob/6934a85c5da7b304b42b9aae5f65410401b94653/crates/benilla-app/src/ui_script/extract/text.rs) ellipsizes a region's string when its wrapped lines exceed the region bounds. Natural-width measurement and the rendered shadow use different scale factors, so an exact automatic width can be too narrow during the critical pop. Rasterized natural width can also change with scale.

SCT now applies the visual scale before measuring each new label and refits when that scale changes, including critical/miss animation and live size preview. Each label receives `ceil(GetStringWidth()) + 4` local units of width and a 36-unit line box for the 18-unit font. The getter already returns local natural width, so it is not divided by effective scale again. Width writes are cached. If native metrics are temporarily unavailable, a 240-unit provisional width is used and measurement is retried during normal updates; pooled labels are fitted again even when their scale is unchanged.

Centering, adjacent icons, full original values, hit matching/grouping, launch positions, colors, lifetime and motion remain as before. No text is abbreviated or edited to remove dots after rendering. This change was reviewed from source; its local checks and addon/game execution were intentionally not run under the standing policy. GitHub Actions checks formatting, local dead code and TOC metadata; live rendering remains unverified.

## Lua globals and memory

BeNilla [#1792](https://github.com/samwhosung/benilla/pull/1792) removed the native `_G` global. The addon supplies `_G = getfenv(0)` inside its private module environment through `DFRL:GetEnv()`, but `modules/chat/prettify.lua` defines helpers directly at file load and had not entered that environment. Its reads of learned-ability, level-up and self-loot format globals therefore raised. The chat wrapper's protected call preserved the raw message, explaining the supplied screenshot's unformatted level announcements, stat gains and learned Gouge notice without a visible Lua error. The prettifier now enters the same private environment before defining its helpers. No native global alias or extra formatting category is added.

BeNilla [#1782](https://github.com/samwhosung/benilla/pull/1782) enabled the original client's `scriptMemory` enforcement. Its default 49,152 KB limit covers the whole Lua state, including the game interface and all addons. The client attempts collection, shows the supplied popup if usage remains over the limit, and may exit after 15 seconds. [#1788](https://github.com/samwhosung/benilla/pull/1788) subsequently aligned the accounting with 32-bit Lua 5.0 object sizes. WeNilla's [upstream merge](https://github.com/Arnesen/wenilla/commit/024ae5882e44) includes these Lua and memory changes.

The screenshot alone cannot attribute those allocations. This fix removes the font/layout error cascade and redundant native writes; it does not claim to prove or eliminate script-memory exhaustion. The requested complete session diagnostics remain uncapped and session-only. The addon does not change the game's memory limit, discard capture records or alter other addons.

## Target debuff placement

**Target debuffs on top** in `/sdui` → HUD defaults off. When enabled, the target's native debuff rows grow above its frame, while buffs stay below. The setting uses the existing display preview, Confirm, Cancel and reset behavior.

The integration follows the original [1.12.1 target-frame code](https://github.com/MOUZU/Blizzard-WoW-Interface/blob/d162a4c0d198a4381b5b6573d975635ed7316702/1.12.1/FrameXML/TargetFrame.lua): `TargetDebuffButton_Update()` manages both aura types and only rewrites selected row anchors. The addon changes those same TOPLEFT points, preserving native icon sizes and horizontal chains. Calling the native updater restores every changed point when the option is disabled. Buffs use the native friendly-target anchor so they do not follow the moved debuff rows. No additional per-frame aura scan is added.

The hook is feature-detected. The packaged game's FrameXML was not extracted, and live placement remains unverified; this contract comes from the pinned original source. No local checks or game execution were run.

## Party target health

The target module formerly forced every health-color write to red, including
selected party heroes. It now uses one shared live-alias helper to distinguish
the player and `party1` through `party4`. Both units must exist and native
`UnitIsUnit` must return true or 1; names and class are not identity evidence.
These aliases receive green health through native color writes and the
existing target refresh path. Other Survivors targets retain enemy red.
Target and world changes, health/faction updates and party membership changes
refresh the choice without an idle updater or saved subject.

Target-of-target uses the same party-alias helper before its existing reaction
color choice. Its tapped-NPC gray, non-party reaction colors and dead/absent
cleanup remain in place. Unit existence, native health values, target selection,
clicks, portraits, visibility and geometry are unchanged. Native co-op color
transitions still require in-game verification; local addon execution was not
performed.

## Evidence limits

The initial investigation and fixes used the supplied screenshots/changelog and read-only source inspection. The user subsequently authorized a full local validation pass on 2026-10-19. That pass compiled all tracked Lua with stock Lua 5.0.3, checked the package and formatting, and exercised actual modules through focused native-API adapters. It found and fixed an additional UTF-8 literal-matching defect; see the [validation report](VALIDATION-2026-10-19.md).

No game was started. The existing GitHub Actions workflow still performs formatting, local dead-code and TOC metadata checks only. Stock Lua and adapter results do not establish packaged-game startup, memory use, native rendering or appearance on particular monitors; these still require game-side confirmation.
