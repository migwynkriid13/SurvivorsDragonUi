# Rarity odds

Enable **Show rarity odds** in **Interface** → **Rarity odds**. In Layout, drag
a side handle to widen the panel or a corner to scale it. It shares the visible
default width and gold title style of Guardians and the DPS meter. The panel
centers between the tracker and the space reserved for the meter, or sits beside
that stack when the viewport is too short. Layout keeps the geometry you save.
**Show over reward cards** defaults on and uses the game's frame layer API when
available. Both settings use the existing preview, Confirm, Cancel, profiles
and reset paths.

## What the numbers measure

The table estimates each base rarity roll given a reward type. Spell cards and
cache rings/trinkets share a row because they use the same base roll. Guardian
jewelry and new amulets each show the applicable source modifier. Spell upgrade
eligibility can raise the rolled tier, a new amulet may use a different
available tier, and empowering an existing amulet keeps its rarity. The odds
for any particular hand of cards also depend on which reward types the game
offers.

The [game's addon API](AzerothSurvivors-Addon-API.md) publishes the player's Luck
as `AZS_STATS.luck` and the current run level as `AZS_RUN.lvl`. The installed
0.139.2 executable's embedded Lua shows that the `AZS` parser replaces the
stats table without publishing a stats timestamp. `AZSRUN` and `AZSZONE` have
their own update stamps. The panel reads the current phase first and rejects a
retired run stamp or prior stats table across an observed run boundary.

The model uses the five base weights recovered from the 0.97.2 spell-card
generator and the 0.113.2 cache/guardian reward path. For
`k = 1 + luck + min(level / 100, 0.30) + source bonus`, divide the weights
`60, 25k, 10k², 4k³, k⁴` by their sum. Spell cards and cache rings/trinkets use
zero source bonus. New amulets add 0.50, and guardian rewards add 0.25 to both
jewelry rows. The displayed Rare, Epic and Legendary values use one decimal
place. The recovered model has not been verified against rolls in the installed
game.

## Drawing and lifecycle

The panel defaults off. The module allocates one event controller and one
mouse-transparent Layout frame. The first usable reading adds 20 font strings
and four textures. The two [Quest Tracker header strips](../third_party/GuardianTracker-ARTWORK.md)
share the guardian tracker's layout and alpha. The native amulet icon uses
the existing loot quality rim with a warm gold tint. Four text rows sit
directly over the world, with the shared text outline and shadow for contrast.
Reward names can wrap. The side handles resize the header and all columns, with
the default 240-unit width as the minimum for full percentages.
Both Performance Mode states use this static presentation. The controller
samples at most four times per second while permitted. Unchanged roll strength
skips odds formatting and text writes. A language change refreshes captions on
the next permitted update. Off, Layout hiding, world leave and logout detach
the reader.

Playing, paused and eligible card selection show the panel. On supported
builds SDUI verifies that its named frame is above the cards before showing it
there. Invalid data, disabled visibility, world leave and reload hide the
panel and release its registration. The panel accepts no clicks. The feature
adds no asset or separate SavedVariable. Mock coverage runs in PR CI.
Appearance and layering in the installed game remain unverified.
