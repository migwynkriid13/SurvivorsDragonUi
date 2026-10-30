# Shared font choice

`/sdui` → **Layout** → **Font** changes text styled by SDUI. Choose Default,
Friz Quadrata, Arial Narrow, Morpheus or Skurri. Default preserves the existing
faces, including Friz Quadrata on loot cards. Font sizes, outlines, shadows,
colors and layout geometry retain their own styling and controls.

The run timer and numeric outgoing combat text have independent font selectors.
Their sources, rulers, pooled segments and damage labels stay outside the shared
font registry, including when their own Default option is selected.

The normalized `uiFont` enum lives in the existing display table. Preview,
Confirm-only saving, Cancel, world/logout/reload discard, profiles and both full
resets use the existing display transaction. Missing or invalid choices use
Default. The source/runtime hint is translated in all fourteen languages; font
family names remain literal.

`core/fonts.lua` owns weak registries of styled objects and pending hidden owners.
`T.SetFont` keeps size/flags and a view's optional authored default face; passing
`true` as its fourth argument excludes independently styled text. The existing
native Font-object pass and font-path globals follow the shared choice without
changing native Font sizes or flags. The original resolved game face remains
available through `GetDefaultFont` for independent selectors and fallback.

A changed choice visits registered objects once. Hidden frame owners defer
bindings to one preserved OnShow wrapper per owner, before existing measurements.
Permanently hidden measurement labels update with their visible frame owner.
Retired wrappers are guarded, font assignments compare current state, and a
rejected assignment restores readable native text. Existing setter calls or
later Show transitions can retry failed object bindings. Native face probing is
cached for the UI session; an unavailable family uses the game face.

Settings and Copy wrapping, guardian health slots and tally fitting invalidate
their measurements when fonts change. Existing font-aware character, revive,
stored-level and localization measurements retain their normal controllers.
There is no font updater, event, gameplay region, asset or new SavedVariable.
Both Performance Mode states share this instant presentation change.

CI-only mocks load the production display/font owners and exercise normalization,
preview, saving, discard, profiles, reset, preserved native sizes/flags, independent
text, hidden Show ordering, rejected bindings, reuse and unchanged writes. The
production editor, SCT controller and timer-caption fixtures also cover the
selector or exclusion boundary. No local tests, standalone validation, addon or
game execution were performed; source review and formatting do not establish
native glyph coverage, visual fit or handheld readability.
