# XP animation source research and artwork

## Selected approach

Dragonflight 10.2.7 uses a gradual animated status bar for XP, with a flare
when a gain finishes and separate level rollover effects. The release tag
resolves to commit `6b65c2922baca3db5a28fb39b69c95cef1047bec` in the public
Blizzard UI source mirror:

- [XP owner and its atlas choices](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_ActionBar/Mainline/ExpBar.lua).
- [Status tracking template inheriting the gradual bar](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_ActionBar/Mainline/StatusTrackingBarTemplate.xml).
- [Gradual fill, pending updates and rollover behavior](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_FrameXMLBase/GradualAnimatedStatusBar.lua).
- [Timing, additive blend and flipbook configuration](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_FrameXMLBase/GradualAnimatedStatusBar.xml).

The native gradual template uses 0.008 seconds per horizontal unit and a
0.1-second accumulation interval. Its gain flare is a 28-frame, four-column,
seven-row flipbook lasting 0.9 seconds. The addon independently implements
bounded distance-based fill motion and a short fading highlight through
legacy Lua OnUpdate and ordinary texture APIs. It does not import Blizzard
mixins, masks, atlas lookup or flipbook animation APIs. Source code and assets
remain owned by their respective authors; this source mirror grants no new
license to Blizzard material.

## Curated repository comparison

The inspected XP paths below set the status-bar value directly; they do not
supply the requested gradual XP fill. They were used for comparison, with no
code or new artwork imported:

- [NeticSoul/DragonUI mainbars](https://github.com/NeticSoul/DragonUI/blob/0b6439e402cdf5c488f515bb93431bc18403e4cf/DragonUI/modules/mainbars.lua), `UpdateDragonflightUIXPBar`: direct XP SetValue.
- [Karl-HeinzSchneider/WoW-DragonflightUI status bar mixin](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI/blob/f59cbc3f7010ef692fb983c7c3c848c4b70f56ce/Mixin/Statusbar.mixin.lua): direct XP SetValue.
- [Turtle-Dragonflight XP bar](https://github.com/DustinChecketts/Turtle-Dragonflight/blob/b2c62e9095e1c859bff0209db09f4ff5b9884f5a/tXPbar.lua): direct normalized XP SetValue.
- [DragonflightUI-Reforged XP module](https://github.com/Stormhand-dev/DragonflightUI-Reforged/blob/2a8d2ffb3d9262f0d2af2071b9b47ef27f76f7f8/modules/xprep/xprep.lua): direct XP SetValue. Its XP texture family matches the destination's existing Reloaded foundation.

## Reused artwork

`media/tex/xprep/main.tga` is the original 512-by-16 RGBA source fill. At the
user's request, `scripts/prepare_xp_fill.py` reduces its overall fading by 30%
in a 512-by-16 uncompressed RGBA `main_soft.tga`. It constructs an opaque
reference from interior column x=384, retaining the vertical bevel and original
rounded outline through normalized antialiasing in the outer six columns.
The result blends 70% of the original source with 30% of that reference in
every RGBA channel. Original horizontal shading and vertical alpha fading
therefore remain at 70% strength; the ends stay slightly rounded.
The requested slight vignette at the beginning adds at most 18% transparency
at x=0, tapering quadratically to zero over the first 12 source columns. It
changes alpha only, leaving all RGB and every column from x=12 onward intact.
Both the status-bar fill and gained-region effect use this prepared texture;
the latter retains ADD blending and its pale purple tint. The original source
remains unchanged in the repository, outside the runtime manifest. The
prepared texture replaces it in the ZIP and retains the existing source
permission, ownership and license notices.

`Interface\CastingBar\UI-CastingBar-Spark` is a native Blizzard texture already
used by the run-timer module. The native texture is referenced, not shipped.
A [public PNG mirror](https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/CastingBar/UI-CastingBar-Spark.PNG)
records the source family; this longstanding texture is not described as
exclusive to Dragonflight. The effect uses an additive purple-white tint,
a 12-by-10 local-unit canvas, and horizontal UV cropping at each bar edge.
Both new regions use ARTWORK, below the unchanged OVERLAY metal border.

The existing fill was inspected as a static enlarged PNG. This verifies its
appearance as source artwork, not in-game animation or packaged-client rendering.
