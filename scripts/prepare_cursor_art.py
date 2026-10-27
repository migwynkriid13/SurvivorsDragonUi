"""Prepare the selected Blizzard gauntlet for the client's 32-pixel cursor.

Only artwork is read and written; no addon or game code is executed.
The full source canvas stays outside the runtime manifest.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "media/tex/cursor"
# Blizzard's UICursor2x, 10.0.0 (45454), mirrored by Gethe/wow-ui-textures
# at e80e3278cc833c89e1f3fc79557b68315d750935. Coordinates select the
# complete normal 128-pixel hand, excluding its one-pixel atlas gutter.
SOURCE_REGION = (1, 1, 129, 129)


def prepare():
    source = Image.open(ART / "UICursor2x.tga").convert("RGBA")
    if source.size != (512, 256):
        raise ValueError("The source atlas changed; review its cursor regions")
    hand = source.crop(SOURCE_REGION)
    hand.save(ART / "PointSource.tga", compression=None)
    # SetCursor accepts exactly 32 by 32. This is an intentional adaptation,
    # separate from the later lossless TGA-to-BLP container preparation.
    hand.resize((32, 32), Image.Resampling.LANCZOS).save(ART / "Point.tga", compression=None)


if __name__ == "__main__":
    prepare()
