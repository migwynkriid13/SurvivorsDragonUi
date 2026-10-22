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

## Exact artwork boundaries

Jewelry keeps its existing magnified icon crop and stepped circular outline.
The two identical central strips are merged into one continuous rectangle:
13 regions per populated icon instead of 14, or 65 instead of 70 across five
populated slots. Texture content and alpha outside that merge are unchanged.

The native portrait conversion used by pet frames is not interchangeable here.
The reviewed client masks portrait pixels before applying texture coordinates;
the jewelry crop would enlarge that circle, and the partially transparent gold
rim does not fully conceal the difference. No approximate native-circle
replacement, prepared item images or new artwork are included.

The timer also retains all existing cosmetic layers: 66 allocated textures,
with at most 37 blue flow/foam pieces or 29 red sparkle/glow pieces visible at
once, plus the base pill and schedule markers. Active boss markers retain their
eight glow copies. The work avoids unnecessary hidden and unchanged updates;
it does not claim to eliminate the cost of drawing these requested effects.

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
analysis and runtime-manifest packaging. No local tests, syntax checks,
formatters, addon execution or game launches are part of this work.

The source review covers unchanged values, reused rows, malformed reload
handoffs, native unit aliases, receipt boundaries, hidden-to-visible transitions
and failed texture assignment retries. Static checks do not establish in-game
pixel parity, an FPS improvement or resolution of the separate world-entry
stall and GPU out-of-memory reports. Those require new user-recorded captures.
