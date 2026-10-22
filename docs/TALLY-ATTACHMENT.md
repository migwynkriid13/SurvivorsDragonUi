# Tally attachment and appearance

`/sdui` → **Kills, Gold & Caches** contains the attachment switch, appearance choices,
individual kills/gold/cache controls and the optional affordability highlight.
Demon reliquary is the default. The selected Gothic proposals are 01, 02,
03, 04, 07, 10, 11 and 13; Continuous silver and Soft graphite are also available.

All controls preview through the existing display draft. Confirm alone saves
in `SurvivorsDragonUiDisplay`; Cancel, world leave, logout and reload discard
unconfirmed changes. Both full resets restore attached Demon reliquary,
all three counters shown and affordability highlighting off. No SavedVariable,
command or gameplay persistence is added. All captions and style names use the
fourteen-language source/runtime catalogs.

## Settings and artwork ownership

`core/tally.lua` supplies the ten stable style IDs, labels, prepared texture
names, row heights, lower extents and content fit. It is loaded before `core/display.lua`,
which validates `tallyStyle` against that shared registry and falls back to its
`gothic13` default. The existing normalized `attachTally` remains true by default.
`showTallyKills`, `showTallyGold` and `showTallyCache` default to true;
`highlightAffordableCache` defaults to false. Invalid saved values use these
defaults, while valid confirmed choices are preserved.

Removed Acanthus base and Dragon iron choices fall back to Demon reliquary
through the same registry validation.

The five checkboxes occupy two rows, with three controls followed by two.
The style picker remains a full-width, two-column list below them. The page
fits without scrolling and uses translated width measurement, selected button
states and the shared footer. Attachment is moved here from Action bar.
Styles apply to the attached lower compartment. Detaching retains the chosen
style and restores the original gold pill without changing saved geometry.

Only the prepared compartment textures and shared registry enter the runtime
manifest. `scripts/prepare_tally_styles.py` prepares uncompressed legacy RGBA
TGA canvases with no counter icons, text, action bar or upper rim. Published
artwork, original bytes, exact crops and notices are documented in
[the artwork records](designs/tally-gothic/ARTWORK.md) and
[runtime-artwork.json](designs/tally-gothic/runtime-artwork.json).

## Attached placement

The tally is parented to `DFRL.mainBar` at local scale one, inheriting movement,
scale and hiding. Its width includes the original action-bar side insets.
`DFRL.GetActionBarSilverBottom()` exposes the visible lower silver edge;
`actionBarDefaults.silverBottomInset` accounts for the shell's sixteen blank
source rows. The edge includes the XP extension only while XP has actually
joined the shell. `SetXPBarJoined` refreshes attachment, including unavailable
native XP. Detached XP does not move the tally.

Every style begins at this edge and uses it as its only top border. The
original pill background, yellow fill and bezel are hidden only while attached.
The new texture has no upper rim, suspension bracket or gap. Artwork scales
from the shared 300-unit reference width, and each style's real lower extent
sets the action-bar edit bounds. Jewelry still owns the upper edit bound.
Position, parent and counter anchors change only for attachment, width, style,
visibility or shell transitions, not every native counter refresh.

Iron sarcophagus clips only its projected background above the lower flare:
the top 18 units use the action bar's visible lower-edge inset of 3.515625 units
per side. This removes square background ears at the shared seam while keeping
the original R04 side-wall pixels, angular lower border and 36-unit extent.

Demon reliquary uses the native target-frame lower rail. Its
center crop stops at source x400, excluding six faded columns before x406.
The existing 242-unit destination and both ornament anchors stay unchanged;
the corrected source joins the right cap without a transparent vertical gap.

At the default 36-unit button reference, the shared seam is 41 units above
screen bottom with joined XP, or 49 with XP unjoined. Continuous silver extends
27 units below the seam. The deeper styles have their own extents; Gothic 13's
pendant is proportionally reduced to a 14-unit canvas height so its total
39-unit lower extent fits the default joined-XP clearance. The proposal gallery
retains its larger pendant. These are source/artwork calculations, not
measurements from a running game.

## Content fit

Each style supplies `contentY`, the counter center below the shared seam, and
`contentScale` for its icon/text group. These six styles use the following fit
at the 300-unit artwork reference. Centers are UI layout reference units;
screen displacement follows the inherited action-bar and UI scales.

| Style               | Center below seam | Content scale |
| ------------------- | ----------------- | ------------- |
| Demon reliquary     | 13                | 95%           |
| Gothic leaf corners | 13                | 95%           |
| Gothic cornerwork   | 13                | 95%           |
| Roth shrine         | 12                | 90%           |
| Roth scrollwork     | 10                | 90%           |
| ARPG carved cornice | 14                | 100%          |

Roth scrollwork and ARPG carved cornice have each moved another two reference
units upward. Their existing content scales, native font, icon sizes and frame
borders remain unchanged. The remaining styles retain their previous fit.
Frame artwork, lower extent and saved geometry do not change. These are
appearance constants, not additional settings or saved fields.

Each unscaled hover cell owns one passive content frame, centered with a zero
anchor offset. Its native 18-unit icon, DEFAULT 12 text and affordability
underline inherit the same scale. Explicit content width keeps the group
centered inside its enabled counter's share. Changing style applies this only
through the cached attachment refresh. Detached mode restores scale one and
the original pill's 15.5-unit center. The [static content preview](designs/tally-gothic/content-fit.png)
shows the prepared frames and chosen fit; it does not execute native rendering.

## Counter visibility and affordability

Enabled counters keep their native icons and order. They divide the available
interior space evenly, with each icon/text pair centered inside its share.
Disabled fields and their dividers hide together. Turning off all three hides
the entire compartment and removes its action-bar edit extension, while
retaining native tally takeover for valid data so the default box stays hidden.

The optional highlight compares only finite nonnegative native `AZS_RUN.gold`
and `AZS_RUN.chest`, before display rounding. At or above the cache cost,
including an explicit zero cost, the gold amount becomes pale gold with a fine
gold underline. Below the cost it retains its regular color. No red/green,
pulse, icon replacement or estimated cost is used. Turning the option off or
clearing the tally removes the highlight immediately on the next phase-gated
presentation update. Gold can be highlighted even when the cache cost is hidden.

Display changes mark presentation dirty, so previews do not wait for another
native packet while paused. Native reads still occur in the existing OnUpdate
path after phase acceptance. The original all-three-counter validity gate,
formatting, tooltips and HUD preference release remain. Missing data clears the
view rather than manufacturing a value. No counter or affordability state is
saved.

## Detached placement

The existing `runTally` key owns a UIParent root. Its confirmed/draft position,
scale and hidden flag survive attached mode and apply again when detached.
The original 31-unit pill and default top of 39 units remain. The translated
**Kills / Gold / Cache (detached)** Layout entry has handles only while its root
is shown; selecting it does not force a hidden tally visible. Individual
visibility and affordability controls also apply to this original pill.

## Proposal galleries and evidence

The [twenty-design Gothic gallery](designs/tally-gothic/index.html) retains
Vanilla-style and installed-bar comparisons, XP on/off views and direct source
links. The [earlier thirty studies](designs/tally-attachment/index.html) remain
research artifacts. Neither gallery nor its sample icons/fonts enters runtime.
The prepared [runtime texture sheet](designs/tally-gothic/runtime-styles.png)
shows the ten selected compartment textures without text or icons.

Installed files were edited first and copied to the existing PR #31 checkout.
Only source inspection and permitted artwork preparation/previewing were
performed locally. Local tests, syntax/formatting checks and addon/game
execution were intentionally not run. Use the existing PR's GitHub Actions for
authorized static verification; live rendering remains unverified.
