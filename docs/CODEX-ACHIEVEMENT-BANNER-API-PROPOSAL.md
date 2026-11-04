# Codex achievement banners during a run

Proposed extension to the public Lua addon API.

## What the player sees

When you earn a Codex achievement during a run, an addon can show its icon,
localized name and the points awarded in an on-screen notice. You see the
award while playing, without opening the Codex or Achievements tab.

## Requested Lua API

The existing [`AZS_RegisterBannerHandler(handler)`](AzerothSurvivors-Addon-API.md#azs_registerbannerhandlerhandler--azs_unregisterbannerhandlerhandler)
already reports `kind = "achievement"` with a localized `name` and `text`. Add
an optional `achievement` table to that same banner when the native award
supplies the metadata. Use the same extended payload for the handler,
`AZS_BANNER` and the existing bounded `AZS_BANNERS` history.

| Field                | Type           | Meaning                                                      |
| -------------------- | -------------- | ------------------------------------------------------------ |
| `achievement.key`    | string         | Stable achievement identifier shared across languages.       |
| `achievement.icon`   | string or nil  | Native achievement texture path, ready for `SetTexture()`.   |
| `achievement.points` | integer or nil | Non-negative achievement points awarded for this completion. |

Supply the key and icon for the achievement the player earned, along with the
points granted for that award. Omit an unavailable icon or points value and use
`0` only for a confirmed zero-point award. Keep `banner.id` as the identity of
the individual notification. Preserve the existing fields and the full
localized `text` on every banner.

## Delivery during the run

- Publish the enriched banner as soon as the game confirms the local player's
  new achievement. This includes an award caused by discovering jewelry while
  choosing a card, wherever the native game already grants the achievement. The
  notice can display before the card closes or the run ends.
- Deliver the complete payload with the original banner ID in the same callback,
  including when the native banner HUD is hidden. Existing consumers continue
  to receive the same banner text.
- If one action grants two achievements, publish each award with its own ID,
  icon and points. In co-op, use the local player's confirmed award.
- Preserve future-only callback registration. Entering a run, opening the Codex
  or reloading the UI does not replay past awards. This proposal needs no new
  progress or completion-history getter.

## Addon usage

Register a banner handler and listen for `kind = "achievement"`. When the
metadata is available, show the native icon, use `banner.name` for the title
and format the numeric award as a localized points line. If the icon cannot
be loaded or the amount is unavailable, keep the rest of the notice usable.
For a legacy payload, display `banner.text`. The event supplies the fields
needed to display the notice without a catalog lookup or polling.

## Acceptance cases

- Earn a Codex achievement during a run. The banner shows the game's achievement
  icon, localized name and exact points awarded.
- Change the game's language. The localized name follows the selected language
  and the achievement key stays the same.
- Hide the native banner HUD. The addon still receives the award and can
  display it once during the run, with its icon and amount.
- Receive an older text-only payload or an award with missing metadata. The
  achievement message still appears, with any available icon or amount.
- Reload after earning an achievement. The prior award does not pop up again.
