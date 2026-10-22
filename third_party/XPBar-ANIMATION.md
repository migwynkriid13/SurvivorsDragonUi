# XP animation and fill credits

The gain animation independently adapts the gradual-fill approach in Blizzard's
Dragonflight 10.2.7 UI source, pinned to
`6b65c2922baca3db5a28fb39b69c95cef1047bec`:

- [XP owner](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_ActionBar/Mainline/ExpBar.lua).
- [Gradual animated status bar](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_FrameXMLBase/GradualAnimatedStatusBar.lua).
- [Animation configuration](https://github.com/Gethe/wow-ui-source/blob/6b65c2922baca3db5a28fb39b69c95cef1047bec/Interface/AddOns/Blizzard_FrameXMLBase/GradualAnimatedStatusBar.xml).

The addon uses its own bounded distance-based motion and fading gain highlight
through legacy texture APIs. Blizzard source and artwork remain their owners'
property; the public mirror grants no new license to Blizzard material.

The original 512×16 RGBA `media/tex/xprep/main.tga` supplies the prepared
`main_soft.tga`. Each channel blends 70% original with 30% opaque reference
from interior column x384, retaining the vertical bevel and normalized rounded
outline in the outer six columns. Alpha alone receives an additional vignette:
at most 18% reduction at x0, tapering quadratically to zero across the first
12 columns. The remaining RGB and columns from x12 onward are unchanged.
The fill and gained-region effect use the same prepared texture and retain the
existing source permission and notices. The original remains unchanged as a
non-runtime preparation source.

The native Blizzard texture `Interface\CastingBar\UI-CastingBar-Spark` is
referenced rather than shipped. Its
[pinned public image mirror](https://github.com/Gethe/wow-ui-textures/blob/d23deaf8f44a7d280dc974a5c9d5321c013db59b/CastingBar/UI-CastingBar-Spark.PNG)
records the longstanding source family. The effect uses an additive
purple-white tint and crops its UVs at the bar edges.
