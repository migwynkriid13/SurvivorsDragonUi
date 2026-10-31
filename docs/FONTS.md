# Shared font choice

`/sdui` → **Layout** → **Font** changes text styled by SDUI. Choose Default,
Arial Narrow, Morpheus or Skurri. Default preserves the existing
faces, including Friz Quadrata on loot cards. **Outline** offers None, Outline
and Thick outline; **Black shadow** can be switched independently. These choices
also apply with the Default face. Missing or invalid style choices use Outline
and enabled black shadow. Font sizes, colors and layout geometry retain their
own controls.

The run timer and numeric outgoing combat text have independent font selectors.
Their sources, rulers, pooled segments and damage labels stay outside the shared
font registry, including when their own Default option is selected.

The normalized `uiFont` and `uiFontOutline` enums and boolean `uiFontShadow`
live in the existing display table. Outline stores `""`, `"OUTLINE"` or
`"THICKOUTLINE"`; unrelated native font flags are retained. Preview,
Confirm-only saving, Cancel, world/logout/reload discard, profiles and both full
resets use the existing display transaction. Missing or invalid choices use
Default, including older saved settings and profiles that selected Friz Quadrata.
The source/runtime hint is translated in all fourteen languages; font
family names remain literal.

`core/fonts.lua` owns weak registries of styled objects and pending hidden owners.
`T.SetFont` keeps size and a view's optional authored default face; passing
`true` as its fourth argument excludes independently styled text. The existing
native Font-object pass and font-path globals follow the shared choice without
changing native Font sizes. Managed native Font objects also follow the outline
and shadow choices. The original resolved game face remains
available through `GetDefaultFont` for independent selectors and fallback.
The font owner captures native globals through `getfenv(0)` because the Lua 5.0
client can lack `_G`; rebinding the module initializer does not rebind file-scope
font helpers.

A changed face, outline or shadow visits registered objects once. Hidden frame owners defer
bindings to one preserved OnShow wrapper per owner, before existing measurements.
Permanently hidden measurement labels update with their visible frame owner.
Retired wrappers are guarded, font assignments compare current state, and a
rejected assignment restores readable native text. Existing setter calls or
later Show transitions can retry failed object bindings. Native face probing is
cached for the UI session; an unavailable family uses the game face.
Managed constructors use the shared shadow helper so newly created labels
respect a disabled shadow. The helper compares native shadow state when getters
exist and caches successful assignments otherwise; failed assignments remain
retryable through the same setter/Show paths.

Settings and Copy wrapping, guardian health slots and tally fitting invalidate
their measurements when faces or outlines change. The meter and guardian minimap
countdowns compare effective shared outline flags before accepting font readiness.
Existing font-aware character, revive,
stored-level and localization measurements retain their normal controllers.
There is no font updater, event, gameplay region, asset or new SavedVariable.
Both Performance Mode states share this instant presentation change.

CI-only mocks load the production display/font owners and exercise normalization,
preview, saving, discard, profiles, reset, preserved sizes/non-outline flags, independent
text, native font paths without `_G`, hidden Show ordering, rejected bindings,
shadow retries, reuse and unchanged writes. The production editor, SCT controller and timer-caption
fixtures also cover the selector or exclusion boundary. No local tests, standalone
validation, addon or game execution were performed. The font fixture separates
native globals without `_G` from the addon environment supplied to module
initializers, matching the loader. Source review and formatting do not establish
native glyph coverage, visual fit or handheld readability.
