# Tooltip style attribution

The shared hover presentation in `core/tooltips.lua` adapts the unit color and native-tooltip styling approach from:

- [PentSec/DragonUI](https://github.com/PentSec/DragonUI/tree/623eca5893c9d475a7b77bd25808bdbe801d247c), commit `623eca5893c9d475a7b77bd25808bdbe801d247c`.
- [DragonUI/modules/tooltip.lua](https://github.com/PentSec/DragonUI/blob/623eca5893c9d475a7b77bd25808bdbe801d247c/DragonUI/modules/tooltip.lua).
- [MIT license](https://github.com/PentSec/DragonUI/blob/623eca5893c9d475a7b77bd25808bdbe801d247c/LICENSE), copyright 2026 NeticSoul and DragonUI contributors.

The reference enhances the stock tooltip and inherits its native frame artwork. It does not supply a separate tooltip-image atlas to copy. This adaptation gives native unit/ability hovers and the independent jewelry effects card a common dark backdrop and thin rounded border through ordinary 1.12 backdrop APIs. Player class and NPC reaction colors follow the source's approach; the source's module registry, profile controls, anchor widget, aura additions and Wrath-only hook interfaces are not included.

The user's final choice omits the source's targeting line and health-bar enhancement. No added rows or replacement health bar are created. The earlier bronze editor-card border, divider and geometric speech-bubble pointer are removed from jewelry hovers; editor artwork remains in use by the editor.

Runtime texture paths are the game's own `Interface\\Tooltips\\UI-Tooltip-Background` and `Interface\\Tooltips\\UI-Tooltip-Border`. These World of Warcraft assets are copyright Blizzard Entertainment, Inc.; the MIT license applies to the software adaptation, not Blizzard's underlying artwork. No new raster asset is shipped.

The complete MIT permission and warranty text and source commit are embedded in `core/tooltips.lua`, so the notice accompanies the runtime ZIP even though attribution Markdown is not packaged. Technical scope and the static-inspection boundary are in [TOOLTIPS.md](../docs/TOOLTIPS.md).
