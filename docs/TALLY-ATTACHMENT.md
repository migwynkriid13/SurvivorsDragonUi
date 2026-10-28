# Tally attachment and appearance

With **Performance Mode** on, the kill and gold numbers refresh every five
seconds. Cache cost keeps its normal refresh speed. Turning Performance Mode
off restores the usual updates. The first display and a new run use current
values immediately; changing the style or attachment does not restart the
five-second interval. These are display changes only: native counters, cache
affordability data and HUD ownership remain current.

The **Kills, Gold & Caches** page in `/sdui` owns the selected style, attachment,
counter visibility and affordability highlight. The same style selection works
in both modes. Changes preview through the existing display draft; Confirm saves,
and Cancel, world leave, logout and reload discard unconfirmed changes.

The gold counter retains its original 18-unit coin icon and four-unit gap
beside the full native amount. The unchanged coin atlas lives in
`media/tex/tally/Coins.blp`, using the original top-left gold crop. Its TGA
preparation input retains the original pixels. The shared
fitter reserves its icon width, the tooltip anchors above the icon, and the
affordability halo includes both the coin and amount with its original offset.

The cache-cost counter uses the supplied chest artwork from
`media/tex/waypoint/Chest.blp`, shared with cache guidance and minimap markers.
It retains its 18-unit icon, full texture coordinates, four-unit text gap,
native `AZS_RUN.chest` value and tooltip above the icon.

## Attached and detached artwork

Attached artwork has an open top, sharing the action bar's lower silver edge.
Detached artwork has a complete matching surround. The shared registry in
`core/tally.lua` owns each mode's texture, full extent and counter center.
`tallyAttachment.Refresh` selects these together whenever attachment or style
changes, and retains the shared content scale, counter values and divider rules.
The tally creates only its frame, counter overlay and selected artwork; it has
no hidden status bar, yellow fill, pill background, border pieces or title.
Its existing frame name, initial dimensions, overlay level and layout lifecycle
are retained.

Most detached versions reflect the structural lower half above the counter
center, preserving its palette, source alpha and lower details. Iron sarcophagus
keeps the entire attached frame at its original size beneath a six-unit top
bevel sampled from its lower rim. Its long walls and lower cornerwork remain
unchanged instead of switching to the differently scaled complete source frame.

Demon reliquary restores the native upper halves of its wings instead of
reflecting through their middle. A reflected lower rail closes the top, and
the original pendant remains only below. Both modes mirror the left structural
artwork and backing to the right, removing the darker right-edge join while
retaining the original pendant pixels.

| Style               | Detached extent | Counter center from top |
| ------------------- | --------------- | ----------------------- |
| Continuous silver   | 27              | 13.5                    |
| Soft graphite       | 29              | 14.5                    |
| Roth scrollwork     | 52              | 26                      |
| Roth shrine         | 48              | 24                      |
| Gothic cornerwork   | 46              | 23                      |
| Iron sarcophagus    | 42              | 22                      |
| Knotted iron        | 42              | 21                      |
| ARPG carved cornice | 52              | 26                      |
| Gothic leaf corners | 46              | 23                      |
| Demon reliquary     | 55              | 29                      |

Measurements are in the existing 300-unit reference width. Every prepared TGA
retains the 1024×128 canvas and the same 600×128 UV content region. Counter text
and icons remain live widgets. Only the selected mode's artwork is displayed.

Knotted iron's attached version uses the original tapered upper walls rather
than a nine-unit rectangular backing. ARPG carved cornice follows the existing
curved shoulder, removing the side slabs while retaining the carved lower curls.
Source crops, contour points and notices are in
[Tally-ARTWORK.md](../third_party/Tally-ARTWORK.md).

## Layout lifecycle

The existing `runTally` key retains independent detached position, scale and
visibility while attached. The detached root's height follows the complete
mode extent, so shared editing handles include the upper trim and lower
ornaments. Its unsaved default remains centered, with the top at least 39 units
above screen bottom and enough clearance for the selected frame. Confirmed and
draft geometry are retained without migration. Profiles, resets, hidden fields
and affordability effects use the existing shared lifecycle and saved choices.
No new setting, command, SavedVariable or gameplay persistence is added.

## Artwork preparation

`scripts/prepare_tally_variants.py` stages the three attached corrections, ten
detached TGAs and corresponding registry metadata. It reads the existing
attached runtime artwork and style records as its baseline, without executing
Lua or loading the addon. Pillow is a preparation-only dependency.

Obtain the five immutable originals listed in
[tally-sources.json](../third_party/tally-sources.json), retaining the listed
filenames, then run:

```sh
python3 scripts/prepare_tally_variants.py --originals /path/to/originals --output dist/tally-prepared
```

The script checks original-source fingerprints and writes a staged `tally.lua`,
the TGAs and `recipe.json`. Originals, previews and preparation tools stay outside
the runtime manifest; only runtime textures and the existing registry ship.

The artwork was prepared and visually inspected as static images. Local addon
checks, formatters, tests and addon/game execution were intentionally not run.
Use GitHub Actions for the authorized static checks. In-game rendering and mode
transitions remain unverified.
