# Rendering and update costs

The October 2026 performance work removes repeated presentation writes while
retaining native data, pause-aware timing, saved preferences and artwork.
It adds no gameplay clock, setting, SavedVariable or native client dependency.

## What changes

- Text and DEFAULT font helpers compare current widget values before writing.
  Localized labels retain their original source caption for language changes.
- Nameplate styling skips unchanged native suppression, health, names and raid
  icon writes. Live SCT discovery, position sampling and hit matching keep their
  original cadence.
- Run schedules are validated and copied per received native publication rather
  than per rendered frame. Receipt generations, run boundaries and the one-use
  reload handoff remain authoritative.
- Hidden timer groups keep native clock observation and HUD preference ownership
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
The default docked action-button icons share this layer, so the isolated
examples do not predict the live combined batch's draw count.
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
bands has a different half-texel sampling window. Five distinct images therefore
still require seventy texture/window states in this renderer. An atlas shares
the image handle but cannot share those windows. A full quad or baked alpha mask
changes the original hard boundaries or their filtering at fractional scales.

Removing this cost exactly needs native support, such as a per-quad sampling
window inside one batch or an equivalent compositor/mask API. The inspected
addon interface exposes neither. This PR does not patch the client or present
the remaining seventy draws as fixed.

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

The timer also retains all existing cosmetic layers: 66 allocated textures,
with at most 37 blue flow/foam pieces or 29 red sparkle/glow pieces visible at
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

## Asset roots in the legacy installation

The public package uses the `SurvivorsDragonUi` folder; the existing local
installation uses `-DragonflightReloaded`. The action bar, range indicator,
XP bar, minimap and older window skins now obtain their texture subfolders
through `DFRL:GetInfoOrCons("tex")`, as the newer modules already did. No module
bypasses the shared root with a hardcoded public folder name.

This corrects missing action-bar backgrounds/buttons, purple XP fill and borders,
minimap borders/shadow, zone-strip background and older window textures after a
legacy sync. Filenames, pixels, UVs, colors, dimensions and native handlers are
unchanged. The local copy translates only the shared core root and loader event
identity. Actions statically enforces one asset root across every runtime Lua
file and checks both root spellings without loading Lua.

## Full chat history

Every diagnostic record remains available for the complete Lua session, with
the same ordering, duplicate-delivery rules, native-history append and literal
markup. Completed batches are joined once; appending does not recopy earlier
history. Copy requests equivalent plain diagnostic text directly, retains one
complete editable and selectable field, and releases the hidden measurement
text after calculating its height. There is no truncation, retention limit,
pagination or saved archive. Memory still necessarily grows with retained text.

## Verification limits

Checks run only in GitHub Actions: version gating, formatting, Lua static
analysis, fractional timer-artwork sampling, a native-base batching reference
model and runtime-manifest validation. The extra checks read TGA pixels and model
ordering only; they do not execute addon Lua or client code.
No local tests, syntax checks,
formatters, addon execution or game launches are part of this work.
PR checks do not build an addon ZIP. Local installation copies the checked
source files directly, retaining the legacy folder and loader identity.

The source review covers unchanged values, reused rows, malformed reload
handoffs, native unit aliases, receipt boundaries, hidden-to-visible transitions
and failed texture assignment retries. Static checks do not establish in-game
pixel parity, an FPS improvement or resolution of the separate world-entry
stall and GPU out-of-memory reports. Those require new user-recorded captures.
