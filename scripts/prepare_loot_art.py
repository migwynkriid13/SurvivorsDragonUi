"""Repack selected Blizzard pixels and compose a static preview, without Lua.

Requires Pillow. See third_party/LootNotifications-ARTWORK.md for source terms.
No downloaded original or representative item icon enters the runtime payload.
"""

import argparse
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
PIN = "e80e3278cc833c89e1f3fc79557b68315d750935"
ICON_PIN = "d23deaf8f44a7d280dc974a5c9d5321c013db59b"
RAW = "https://raw.githubusercontent.com/Gethe/wow-ui-textures/"


def source(scratch, pin, name):
    path = scratch / Path(name).name
    if not path.exists():
        with urllib.request.urlopen(RAW + pin + "/" + name, timeout=30) as response:
            path.write_bytes(response.read())
    return Image.open(path).convert("RGBA")


def prepare(scratch, retail_font):
    scratch.mkdir(parents=True, exist_ok=True)
    crop = source(scratch, PIN, "LootFrame/LootToast.PNG").crop((289, 148, 565, 244))
    canvas = Image.new("RGBA", (512, 128))
    canvas.paste(crop, (0, 0))
    target = ROOT / "media/tex/loot/Toast.tga"
    target.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(target)

    # Same 276x96 card geometry as loot_view.lua, enlarged only for inspection.
    image = Image.new("RGBA", (780, 460), "#172023")
    draw = ImageDraw.Draw(image)
    sans = "/System/Library/Fonts/Supplemental/Arial.ttf"
    draw.text((32, 20), "02 · Selected silver loot alert", font=ImageFont.truetype(sans, 25), fill="#d7bd80")
    draw.text((32, 58), "You received + item name. Already-collected drops show no popup.", font=ImageFont.truetype(sans, 17), fill="#b8b9ad")
    rim = Image.open(ROOT / "media/tex/character/QualityBorder.tga").convert("RGBA")
    samples = [
        ("Squire's Helm", "ICONS/INV_Helmet_25.PNG", "#eeeeee"),
        ("Warlord's Boots", "ICONS/INV_Boots_Plate_04.PNG", "#bc76ef"),
    ]
    for index, (name, icon_path, color) in enumerate(samples):
        card = crop.resize((552, 192), Image.Resampling.LANCZOS)
        icon = source(scratch, ICON_PIN, icon_path).resize((100, 100), Image.Resampling.LANCZOS)
        card.alpha_composite(icon, (46, 48))
        border = rim.resize((116, 116), Image.Resampling.LANCZOS)
        tint = Image.new("RGBA", border.size, color)
        tint.putalpha(border.getchannel("A"))
        card.alpha_composite(tint, (38, 40))
        text = ImageDraw.Draw(card)
        for position, caption, size, face, shade in [
            ((166, 40), "You received", 24, retail_font, "#ffd100"),
            ((166, 86), name, 28, retail_font, color),
        ]:
            text.text((position[0] + 1, position[1] + 2), caption, font=ImageFont.truetype(face, size), fill="#000000")
            text.text(position, caption, font=ImageFont.truetype(face, size), fill=shade)
        image.alpha_composite(card.resize((414, 144), Image.Resampling.LANCZOS), (183, 102 + index * 150))
    draw.text((32, 421), "Static artwork preview · representative icons · game Friz Quadrata · no game execution", font=ImageFont.truetype(sans, 15), fill="#b8b9ad")
    image.convert("RGB").save(ROOT / "docs/designs/loot-notifications/selected.png")
    print(target)
    print(ROOT / "docs/designs/loot-notifications/selected.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, required=True)
    parser.add_argument("--font", required=True, help="Path to the game's native Friz Quadrata, for the preview only")
    arguments = parser.parse_args()
    prepare(arguments.sources, arguments.font)
