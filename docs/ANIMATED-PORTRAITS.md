# Native animated unit portraits

Player, target and target-of-target portraits default to their original native 2D images. **3D Portrait** under `/sdui` → **Unit frames** enables all three independent anonymous `PlayerModel` instances together. Each model uses its unit's native appearance and animation. Existing health-only frames, gold artwork, native clicks and shared layout controls remain in use, and models do not intercept mouse input.

## Portrait choice

The shared option defaults off, including older saves without the field and invalid saved values. It retains the legacy `playerPortrait3D` key for compatibility with existing saves, now covering all three portraits. It previews immediately and saves only that normalized boolean in the existing `SurvivorsDragonUiDisplay` table when Confirm is clicked. Cancel, world leave/logout/reload discard drafts; `/sdui reset` and Addon defaults restore 2D. No separate SavedVariable or saved model/gameplay state is added. Round player portrait remains an independent choice of border artwork.

While off, all three models stay hidden and unbound, and the native stills keep their normal updates. Turning 3D on binds each available unit through the existing protected model path. Turning it off immediately clears/hides every copy and restores each original still alpha. Late model-paint callbacks cannot suppress the 2D portraits after disable. Only effective option changes apply this transition: unrelated display previews and confirming an unchanged choice do not restart the models. New targets, target-of-target changes and world entry all respect the same choice.

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

The gold sheet and native still portrait share the raised border layer above health fill and damage loss. The model uses the still portrait parent's level; if the player border initializes later, it aligns the existing copy's level through an owner-held widget reference without calling SetUnit. This keeps the optional round-player fill extension behind the portrait. The native rectangular viewport is now centered and inscribed inside the portrait circle: for diameter `d`, its side is `(d - 2) / sqrt(2)`. All corners remain inside the ring with one unit of diagonal clearance. This makes the 3D view smaller; it does not add a circular model mask or change camera framing.

Twenty-two passive native white-texture strips, tinted near-black at alpha `0.72`, form a round background beneath the model and gold artwork. Each strip uses the narrower circular width at its two outer edges so it cannot protrude outside the circle. The backing belongs to the model frame and inherits its visibility. Geometry is refreshed only when the native portrait dimensions change, through the existing model update; no new updater or model copy is created. A resolved contained viewport joins the existing readiness conditions before suppressing the still. True circular model clipping and a documented loading/ready/unavailable interface still need client support. Camera selection neither changes the existing still fallback nor turns `GetModel()` or a successful setter into readiness evidence.

## Nameplate first-draw compatibility

The owner also reported including [Benilla #1341](https://github.com/samwhosung/benilla/pull/1341) in the game. That change defers newly shown WORLD-layer nameplate artwork until the next ordinary Lua update. The addon's existing `OnUpdate` discovery loop already skins and masks those plates; synchronous show/health hooks handle reused plates. No additional addon call or SCT change is required to consume that ordering fix.

The change addresses the first stock-artwork flash. It adds no stable enemy IDs, retained death-location projection or nameplate overlap control, and preserves native picking behavior. Source comparison supports compatibility; first-frame input behavior and the packaged game's exact integration remain runtime questions.

## Verification boundary

The camera-selection change was reviewed against the native implementation and build/show ordering. The shared three-portrait option was reviewed against the display lifecycle, per-unit copy binding, target changes and late paint callbacks. The later caption, containment and backing changes were formatted locally with the pinned StyLua and Prettier versions. No local tests, standalone syntax checks or game/addon execution were performed. The earlier client-compatibility validation predates these changes. Native callback delivery, visual framing, draw order and fallback behavior still require confirmation in the matching game build.
