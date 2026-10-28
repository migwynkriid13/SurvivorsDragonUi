"""Prepare ten static Level Up artwork proposals without loading addon Lua.

Requires Pillow. Downloads live only in a temporary directory unless --sources
supplies a scratch folder. Final output is the comparison; ARTWORK.md records
its reviewed sources and adaptation limits.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import tempfile
import urllib.request

from PIL import Image, ImageDraw, ImageFont

from prepare_jewelry_art import rgba


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/designs/level-up-styles"
S = 2
MIRROR = "Gethe/wow-ui-textures"
TEXTURE_REF = "e80e3278cc833c89e1f3fc79557b68315d750935"
SHADOW_REF = "da4d3587e46ee7db8655b978d49b7d55024084ff"
NEWERA_REF = "2384e1d96dd58ef325b236c0dfccbd21a08bfccb"
DRAGON_REF = "6d9cc95eedd1de78fab3b965683df13421e21604"
FONT = "/System/Library/Fonts/Supplemental/Georgia.ttf"
LABEL_FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
GOLD = "#f3dda5"
SOURCES = {
    "classes.PNG": (MIRROR, TEXTURE_REF, "GLUES/CHARACTERCREATE/UI-CharacterCreate-Classes.PNG"),
    "LEVELUPTEX.PNG": (MIRROR, TEXTURE_REF, "LEVELUP/LEVELUPTEX.PNG"),
    "CovenantChoiceCelebration.PNG": (MIRROR, SHADOW_REF, "CovenantChoice/CovenantChoiceCelebration.PNG"),
    "CovenantRenownKyrian.PNG": (MIRROR, SHADOW_REF, "CovenantRenown/CovenantRenownKyrian.PNG"),
    "CovenantRenownNightfae.PNG": (MIRROR, SHADOW_REF, "CovenantRenown/CovenantRenownNightfae.PNG"),
    "CovenantRenownNecrolord.PNG": (MIRROR, SHADOW_REF, "CovenantRenown/CovenantRenownNecrolord.PNG"),
    "CovenantRenownVenthyr.PNG": (MIRROR, SHADOW_REF, "CovenantRenown/CovenantRenownVenthyr.PNG"),
    "IconFrameGold.tga": ("NeticSoul/DragonUI", DRAGON_REF, "DragonUI/Textures/Collections/IconFrameGold.tga"),
    "professions.blp": ("ghbset/DragonUI_NewEra", NEWERA_REF, "Textures/Professions/4417031-professions-chrome-sheet.blp"),
}

# Exclusive far edges. Covenant rectangles come from TextureAtlasViewer's
# build-37864 AtlasInfo export and were inspected against these pinned sheets.
# Profession rectangles follow NewEra's build-12.0.5.67451 Assets.lua.
REGIONS = {
    "kyrian": ("CovenantRenownKyrian.PNG", (1, 841, 416, 977)),
    "nightfae": ("CovenantRenownNightfae.PNG", (418, 703, 833, 839)),
    "necrolord": ("CovenantRenownNecrolord.PNG", (723, 158, 1138, 294)),
    "venthyr": ("CovenantRenownVenthyr.PNG", (814, 315, 1229, 451)),
    "kyrian-line": ("CovenantChoiceCelebration.PNG", (1, 263, 363, 330)),
    "nightfae-line": ("CovenantChoiceCelebration.PNG", (417, 1, 779, 68)),
    "necrolord-line": ("CovenantChoiceCelebration.PNG", (1, 401, 363, 468)),
    "venthyr-line": ("CovenantChoiceCelebration.PNG", (417, 139, 779, 206)),
    "quality-top": ("professions.blp", (478, 431, 738, 531)),
    "quality-middle": ("professions.blp", (818, 331, 1078, 332)),
    "quality-bottom": ("professions.blp", (740, 431, 1000, 530)),
    "skill-frame": ("professions.blp", (478, 587, 929, 616)),
    "skill-bg": ("professions.blp", (1360, 396, 1811, 425)),
    "slot": ("professions.blp", (405, 1643, 445, 1683)),
    "gold-line": ("LEVELUPTEX.PNG", (1, 10, 419, 17)),
    "black-bg": ("LEVELUPTEX.PNG", (1, 19, 327, 122)),
}

DESIGNS = [
    ("Golden announcement", "Blizzard LevelUpTex · legacy artwork", "Floating gold rules with a soft black center."),
    ("Silver alert", "Retail loot toast · Dragonflight-era export", "A wide silver rim, dark leather and a clear icon."),
    ("Gilded spellbook", "DragonflightUI / DragonUI artwork", "The full ornamental gold frame, with open text."),
    ("Artisan metal", "Dragonflight professions · shared retail artwork", "Beveled corners and a small central crest."),
    ("War Within iron", "Details! The War Within · addon-authored skin", "A compact dark tray matching our damage meter."),
    ("Midnight slimline", "12.0.5 atlas evidence · shared profession artwork", "A slim silver rail with an overlapping class tile."),
    ("Kyrian marble", "Shadowlands · Kyrian renown + celebration", "Pale stone, warm metal and a blue winged flourish."),
    ("Night Fae twilight", "Shadowlands · Night Fae renown + celebration", "Blue woodwork and a curling arcane flourish."),
    ("Necrolord stone", "Shadowlands · Necrolord renown + celebration", "Green-lit stone with a bone-and-metal flourish."),
    ("Venthyr gothic", "Shadowlands · Venthyr renown + celebration", "Red-edged stone, dark silver and thorned wings."),
]


def put(canvas, layer, x, y, width=None, height=None, opacity=1):
    width = layer.width if width is None else width
    height = layer.height if height is None else height
    layer = layer.resize((round(width * S), round(height * S)), Image.Resampling.LANCZOS)
    if opacity != 1:
        layer.putalpha(layer.getchannel("A").point(lambda a: round(a * opacity)))
    canvas.alpha_composite(layer, (round(x * S), round(y * S)))


def text(canvas, value, x, y, size=12, color=GOLD, label=False, anchor="la"):
    font = ImageFont.truetype(LABEL_FONT if label else FONT, round(size * S))
    ImageDraw.Draw(canvas).text(
        (round(x * S), round(y * S)), value, font=font, fill=color,
        anchor=anchor, stroke_width=1 if not label else 0, stroke_fill="#080a0c",
    )


def crop(art, key):
    source, rect = REGIONS[key]
    return art[source].crop(rect)


def content(canvas, art, x=82, y=74, title_color=GOLD, rim=True, icon_size=43, title_x=None):
    put(canvas, art["class"], x, y, icon_size, icon_size)
    if rim:
        # Existing plain frame: native icon opening (29,24)-(93,89).
        factor = icon_size / 64
        put(canvas, art["plain"], x - 29 * factor, y - 24 * factor, 128 * factor, 128 * factor)
    badge_size = 19
    put(canvas, art["badge"], x + icon_size - 9, y - 10, badge_size, badge_size)
    text(canvas, "5", x + icon_size + 0.5, y - 1, 12, "#332817", anchor="mm")
    text(canvas, "LEVEL UP", x + icon_size + 28 if title_x is None else title_x,
         y + icon_size / 2 + 1, 24, title_color, anchor="lm")


def panel(canvas, art, x, y, width, height):
    # Preserve the corner geometry instead of flattening an entire tall card.
    cap = min(36, height / 2)
    top = crop(art, "quality-top")
    bottom = crop(art, "quality-bottom")
    put(canvas, top.crop((0, 0, 260, 45)), x, y, width, cap)
    put(canvas, crop(art, "quality-middle"), x, y + cap, width, height - 2 * cap)
    put(canvas, bottom.crop((0, 54, 260, 99)), x, y + height - cap, width, cap)


def render(number, art):
    canvas = Image.new("RGBA", (400 * S, 200 * S), "#151c21")
    draw = ImageDraw.Draw(canvas)
    draw.line((18 * S, 194 * S, 382 * S, 194 * S), fill="#303a41", width=S)
    title, era, note = DESIGNS[number - 1]
    text(canvas, f"{number:02d}  {title}", 20, 15, 15, "#e7dfce", True)
    text(canvas, era, 20, 38, 9, "#9cabb3", True)
    text(canvas, note, 20, 177, 10, "#b4bdc1", True)

    if number == 1:
        put(canvas, crop(art, "black-bg"), 35, 62, 330, 72)
        put(canvas, crop(art, "gold-line"), 30, 65, 340, 5)
        put(canvas, crop(art, "gold-line"), 30, 127, 340, 5)
        content(canvas, art, y=76)
    elif number == 2:
        put(canvas, art["toast"].crop((0, 0, 276, 96)), 42, 53, 316, 110)
        content(canvas, art, x=79, y=76)
    elif number == 3:
        put(canvas, art["backdrop"], 38, 58, 324, 85)
        put(canvas, art["class"], 83, 77, 42, 42)
        put(canvas, art["IconFrameGold.tga"], 65, 61, 82, 82)
        put(canvas, art["badge"], 120, 65, 19, 19)
        text(canvas, "5", 129.5, 74.5, 12, "#332817", anchor="mm")
        text(canvas, "LEVEL UP", 163, 99, 24, anchor="lm")
    elif number == 4:
        panel(canvas, art, 51, 61, 298, 80)
        put(canvas, crop(art, "slot"), 76, 74, 49, 49)
        content(canvas, art, x=79, y=77, rim=False)
    elif number == 5:
        put(canvas, art["meter-bg"].crop((0, 15, 256, 32)), 47, 72, 306, 63)
        put(canvas, art["meter-header"], 47, 57, 306, 22)
        content(canvas, art, x=78, y=79, title_color="#e4d5b2")
    elif number == 6:
        put(canvas, crop(art, "skill-bg"), 62, 77, 292, 49)
        put(canvas, crop(art, "skill-frame"), 62, 77, 292, 49)
        put(canvas, crop(art, "slot"), 58, 70, 58, 58)
        content(canvas, art, x=63, y=75, icon_size=48, rim=False, title_x=145, title_color="#ece8dd")
    else:
        covenant = ["kyrian", "nightfae", "necrolord", "venthyr"][number - 7]
        put(canvas, crop(art, covenant), 47, 68, 306, 100.28)
        flourish = crop(art, covenant + "-line")
        put(canvas, flourish, 62, 49, 276, 51.08)
        color = ["#f1dba7", "#c4e5ff", "#dbe8b9", "#f0c7ba"][number - 7]
        content(canvas, art, x=82, y=100, title_color=color, icon_size=38, title_x=153)
    return canvas


def fetch_sources(scratch):
    def fetch(entry):
        name, (repo, ref, path) = entry
        target = scratch / name
        if not target.exists():
            url = f"https://raw.githubusercontent.com/{repo}/{ref}/{path}"
            with urllib.request.urlopen(url, timeout=40) as response:
                target.write_bytes(response.read())
        return name, rgba(target)
    with ThreadPoolExecutor(max_workers=5) as pool:
        art = dict(pool.map(fetch, SOURCES.items()))
    classes = art["classes.PNG"]
    art["class"] = classes.crop((classes.width // 4, 0, classes.width // 2, classes.height // 4))
    for key, path in {
        "plain": "levelup/IconFrameGold.tga", "badge": "levelup/CountBadge.tga",
        "backdrop": "levelup/Backdrop.tga", "toast": "loot/Toast.tga",
        "meter-header": "meter/Header.tga", "meter-bg": "meter/Background.tga",
    }.items():
        art[key] = rgba(ROOT / "media/tex" / path)
    return art


def prepare(scratch):
    art = fetch_sources(scratch)
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (824 * S, 1118 * S), "#0d1317")
    text(sheet, "LEVEL UP  /  TEN ARTWORK STYLES", 24, 23, 23, "#f0d7a0", True)
    text(sheet, "Same class icon, waiting-count badge and title. Select a style by number.",
         25, 62, 12, "#b2bec4", True)
    text(sheet, "Static proposals · Mage / 5 waiting levels · enlarged for comparison", 25, 82, 10, "#91a3ac", True)
    for number in range(1, 11):
        x = 8 + ((number - 1) % 2) * 408
        y = 112 + ((number - 1) // 2) * 200
        put(sheet, render(number, art), x, y, 400, 200)
    sheet.convert("RGB").save(OUT / "comparison.png", optimize=True)
    print(OUT / "comparison.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, help="Optional existing scratch downloads")
    args = parser.parse_args()
    if args.sources:
        prepare(args.sources)
    else:
        with tempfile.TemporaryDirectory(prefix="sdui-levelup-styles-") as folder:
            prepare(Path(folder))
