# Native animated unit portraits

The player portrait defaults to the original native 2D still. **Experimental 3D player portrait** under `/sdui` → **HUD** enables an independent anonymous `PlayerModel` in that same slot. Target and target-of-target retain their independent animated models. Each model uses the actual unit's native appearance and animation. Existing health-only frames, gold artwork, native clicks and shared layout controls remain in use, and models do not intercept mouse input.

## Player portrait choice

The player option defaults off, including older saves without the field and invalid saved values. It previews immediately and saves only the normalized `playerPortrait3D` boolean in the existing `SurvivorsDragonUiDisplay` table when Confirm is clicked. Cancel, world leave/logout/reload discard drafts; `/sdui reset` and Addon defaults restore 2D. No separate SavedVariable or saved model/gameplay state is added. Round player portrait remains an independent choice of border artwork.

While off, the player's model stays hidden and unbound, and the native still keeps its normal updates. Turning 3D on binds the current player through the existing protected model path. Turning it off immediately clears/hides the copy and restores the original still alpha. A late model-paint callback cannot suppress the 2D portrait after disable. Only effective option changes apply this transition: unrelated display previews and confirming an unchanged choice do not restart the model. Target and target-of-target models are unaffected by this player-only toggle.

## Client support

The owner reported incorporating the upstream animated-model work into the game. The upstream implementation is [Benilla #1352](https://github.com/samwhosung/benilla/pull/1352), which supersedes the original [#1343 proposal](https://github.com/samwhosung/benilla/pull/1343). It renders each named or anonymous character-model frame's own `SetUnit` subject. The old draft's eight-generic-pane limit does not describe this successor.

The addon uses existing frame methods and `OnUpdateModel`; it requires no new global API names. Creating a model widget or successfully calling `SetUnit` does not establish that a visible copy exists. The merged client's [model-paint gates](https://github.com/samwhosung/benilla/blob/b727e30f312df6e17c846f8695091d2c30a3354d/crates/benilla-ui/src/script/tick.rs#L383-L405) require an allocated unit copy and a visible resolved viewport before invoking that callback.

The still portrait remains under native control. Before each ordinary model update it is restored, and only that frame's model callback suppresses it. This avoids treating an old callback as proof that the subject remains available. It is copy-and-viewport evidence, not an explicit loading-state API or proof that the GPU displayed a particular frame. An unsupported or unavailable model leaves the still portrait visible without a guessed loading timeout.

## Subject and appearance changes

`SetUnit` captures native identity when called. The addon therefore binds again on target and target-of-target changes, world entry and relevant native appearance updates. Health updates do not rebuild the model or restart animation. Native idle animation runs independently of the run clock; the addon does not scrub a sequence every rendered frame.

Hidden portraits release their model copies and recover from the current unit when shown. World leave and logout clear the copies and restore still portraits. A new Lua session creates fresh widgets; no model, target or readiness state is persisted.

## Presentation limits

The addon requests `SetCamera(0)` after each `SetUnit` and `Show`, once per ordinary binding transition. Camera 0 supplies the standard character headshot described in [BeNilla #1835](https://github.com/samwhosung/benilla/issues/1835). [BeNilla #1849](https://github.com/samwhosung/benilla/pull/1849), merged as `30f2955e974b1de9fe5ac1d0a47b78b6b0c22426`, makes this call affect character-pane rendering. Its [copy lifecycle](https://github.com/samwhosung/benilla/blob/7dfd17e5202cf8336bd7c1d750ee0f1104f781e2/crates/benilla-ui/src/widget/kinds/character.rs) clears queued camera choices when a new build is requested and applies a later choice after the default camera is installed. Showing can request another build, so the camera request comes after Show as well. Health updates and ordinary per-frame callbacks never reapply it.

The method is optional and its call is protected, preserving the existing model when a client rejects it. Method presence does not prove renderer support: the examined [WeNilla head](https://github.com/Arnesen/wenilla/blob/6934a85c5da7b304b42b9aae5f65410401b94653/crates/benilla-ui/src/script/modelframe.rs) still accepts the camera method without forwarding it to the unit copy. Such a game build can retain the body view. The packaged game's exact inclusion of #1849 remains unconfirmed; no companion or client patch is distributed.

Framing uses each model's raw camera 0 rather than a fixed zoom or invented race offsets. It is not a guarantee of an identical face/shoulder crop for every creature: native still portraits use `cameraLookup[0]`, while `SetCamera(0)` names raw index 0. The supported [renderer](https://github.com/samwhosung/benilla/blob/7dfd17e5202cf8336bd7c1d750ee0f1104f781e2/crates/benilla-app/src/portrait/framing.rs) uses its orthographic path when that camera is absent. There is no public camera-count or portrait-camera lookup API to select an asset-aware fallback. `SetModelScale` and `SetPosition` are not added as universal zoom controls; their transforms cancel under authored live cameras.

The gold sheet and native still portrait share the raised border layer above health fill and damage loss. The model uses the still portrait parent's level; if the player border initializes later, it aligns the existing copy's level through an owner-held widget reference without calling SetUnit. This keeps the optional round-player fill extension behind the portrait. Viewports remain rectangular: gold artwork does not create a circular clipping mask. True circular clipping and a documented loading/ready/unavailable interface still need client support. Camera selection neither changes the existing still fallback nor turns `GetModel()` or a successful setter into readiness evidence.

## Nameplate first-draw compatibility

The owner also reported including [Benilla #1341](https://github.com/samwhosung/benilla/pull/1341) in the game. That change defers newly shown WORLD-layer nameplate artwork until the next ordinary Lua update. The addon's existing `OnUpdate` discovery loop already skins and masks those plates; synchronous show/health hooks handle reused plates. No additional addon call or SCT change is required to consume that ordering fix.

The change addresses the first stock-artwork flash. It adds no stable enemy IDs, retained death-location projection or nameplate overlap control, and preserves native picking behavior. Source comparison supports compatibility; first-frame input behavior and the packaged game's exact integration remain runtime questions.

## Verification boundary

The camera-selection change was reviewed against the native implementation and build/show ordering. The player option was reviewed against the shared display lifecycle, copy binding and late paint callbacks. Formatting, local dead-code and TOC-version checks run in GitHub Actions. Local tests, syntax checks, formatting tools and game/addon execution were intentionally not run for these changes under the standing project policy. The earlier client-compatibility validation predates them. Native callback delivery, visual framing, draw order and fallback behavior still require confirmation in the matching game build.
