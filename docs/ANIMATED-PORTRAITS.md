# Native animated unit portraits

The player, target and target-of-target frames create independent anonymous `PlayerModel` widgets in their existing portrait slots. Each uses the actual unit's native appearance and animation. Existing health-only frames, gold artwork, native clicks and shared layout controls remain in use. Models do not intercept mouse input, and this feature adds no settings or saved gameplay state.

## Client support

The owner reported incorporating the upstream animated-model work into the game. The upstream implementation is [Benilla #1352](https://github.com/samwhosung/benilla/pull/1352), which supersedes the original [#1343 proposal](https://github.com/samwhosung/benilla/pull/1343). It renders each named or anonymous character-model frame's own `SetUnit` subject. The old draft's eight-generic-pane limit does not describe this successor.

The addon uses existing frame methods and `OnUpdateModel`; it requires no new global API names. Creating a model widget or successfully calling `SetUnit` does not establish that a visible copy exists. The merged client's [model-paint gates](https://github.com/samwhosung/benilla/blob/b727e30f312df6e17c846f8695091d2c30a3354d/crates/benilla-ui/src/script/tick.rs#L383-L405) require an allocated unit copy and a visible resolved viewport before invoking that callback.

The still portrait remains under native control. Before each ordinary model update it is restored, and only that frame's model callback suppresses it. This avoids treating an old callback as proof that the subject remains available. It is copy-and-viewport evidence, not an explicit loading-state API or proof that the GPU displayed a particular frame. An unsupported or unavailable model leaves the still portrait visible without a guessed loading timeout.

## Subject and appearance changes

`SetUnit` captures native identity when called. The addon therefore binds again on target and target-of-target changes, world entry and relevant native appearance updates. Health updates do not rebuild the model or restart animation. Native idle animation runs independently of the run clock; the addon does not scrub a sequence every rendered frame.

Hidden portraits release their model copies and recover from the current unit when shown. World leave and logout clear the copies and restore still portraits. A new Lua session creates fresh widgets; no model, target or readiness state is persisted.

## Presentation limits

The currently inspected unit renderer provides a body view in a rectangular viewport. Its [unit-pane state](https://github.com/samwhosung/benilla/blob/b727e30f312df6e17c846f8695091d2c30a3354d/crates/benilla-ui/src/script/modelframe.rs#L681-L710) does not forward the model camera, scale or position controls to that renderer. The [rendered transform](https://github.com/samwhosung/benilla/blob/b727e30f312df6e17c846f8695091d2c30a3354d/crates/benilla-app/src/portrait/panes.rs#L572-L586) and [body camera](https://github.com/samwhosung/benilla/blob/b727e30f312df6e17c846f8695091d2c30a3354d/crates/benilla-app/src/portrait/panes.rs#L1026-L1040) consequently cannot supply reliable head-and-shoulders framing through `SetCamera`, `SetModelScale` or `SetPosition`.

The original gold border remains above the model, but it does not create a circular clipping mask. Native head-and-shoulders framing, true circular clipping and a documented loading/ready/unavailable interface remain client capabilities to expose. The addon does not guess a portrait-camera index or race-specific offsets, draw opaque corners to simulate transparency, or treat the path-only `GetModel()` result as readiness.

## Nameplate first-draw compatibility

The owner also reported including [Benilla #1341](https://github.com/samwhosung/benilla/pull/1341) in the game. That change defers newly shown WORLD-layer nameplate artwork until the next ordinary Lua update. The addon's existing `OnUpdate` discovery loop already skins and masks those plates; synchronous show/health hooks handle reused plates. No additional addon call or SCT change is required to consume that ordering fix.

The change addresses the first stock-artwork flash. It adds no stable enemy IDs, retained death-location projection or nameplate overlap control, and preserves native picking behavior. Source comparison supports compatibility; first-frame input behavior and the packaged game's exact integration remain runtime questions.

## Verification boundary

The integration was reviewed from source. Formatting, local dead-code and TOC-version checks run only in GitHub Actions. No local addon tests, syntax checks, formatting tools, game startup or addon execution were performed. Native callback delivery, visual framing, draw order and fallback behavior still require confirmation in the matching game build.
