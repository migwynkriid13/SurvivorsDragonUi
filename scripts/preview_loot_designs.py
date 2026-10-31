"""Compose loot design proposals from pinned artwork; never execute addon Lua.

Requires Pillow. Original downloaded bytes remain in the supplied scratch folder.
Only static previews and their source index are written under docs/designs/.
"""

import argparse
import json
import tempfile
import urllib.request
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

from preview_guardian_designs import panel
from prepare_client_textures import image_from_bytes


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/designs/loot-notifications"
S = 2
BODY = "/System/Library/Fonts/Supplemental/Georgia.ttf"
LABEL = "/System/Library/Fonts/Supplemental/Arial.ttf"
GOLD = "#d7bd80"
WHITE = "#eee9df"
MUTED = "#aaa899"
GREEN = "#72e775"
PURPLE = "#bc76ef"
SOURCES = {
    "card": {
        "repository": "NeticSoul/DragonUI",
        "commit": "27255b131d734113f92a379c55a7df054e36be52",
        "path": "DragonUI/Textures/UI/looting-itemcard.blp",
        "canvas": [512, 256],
        "regions": {"background": [0, 0, 298, 76], "normal": [0, 78, 298, 154], "rarity": [304, 0, 512, 15]},
    },
    "toast": {
        "repository": "Gethe/wow-ui-textures",
        "commit": "e80e3278cc833c89e1f3fc79557b68315d750935",
        "path": "LootFrame/LootToast.PNG",
        "canvas": [1024, 256],
        "regions": {"background": [289, 148, 565, 244]},
    },
    "boots": {
        "repository": "Gethe/wow-ui-textures",
        "commit": "d23deaf8f44a7d280dc974a5c9d5321c013db59b",
        "path": "ICONS/INV_Boots_Plate_04.PNG",
        "canvas": [64, 64],
    },
    "helm": {
        "repository": "Gethe/wow-ui-textures",
        "commit": "d23deaf8f44a7d280dc974a5c9d5321c013db59b",
        "path": "ICONS/INV_Helmet_25.PNG",
        "canvas": [64, 64],
    },
}
DESIGNS = [
    ("Retail item card", "Recommended: a restrained quality wash and the published retail item-card rim.", "DragonUI retail item-card atlas; native quality colouring."),
    ("Silver loot alert", "The recognisable Blizzard loot-alert frame, with quieter text and effects.", "Dragonflight-era LootToast crop, also referenced by later retail UI."),
    ("Plain addon metal", "A small sibling of our character window with the same plain metal corners.", "Existing bundled Blizzard character-frame chrome; custom card assembly."),
    ("Floating loot label", "A light, open layout that fits our waypoints and stored-level button.", "Existing soft backdrop, gold glow and native-quality icon rim."),
]
SAMPLES = [
    ("COMMON / ALREADY COLLECTED", "Footpad's Cover", "HEAD", "Already collected", WHITE, False, "helm"),
    ("COMMON / NEW IN COLLECTION", "Squire's Helm", "HEAD", "New in your collection!", WHITE, True, "helm"),
    ("EPIC / ALREADY COLLECTED", "Warlord's Boots", "FEET", "Already collected", PURPLE, False, "boots"),
]


def load(path):
    return image_from_bytes(path.read_bytes())


def fetch(scratch, key):
    spec = SOURCES[key]
    url = "https://raw.githubusercontent.com/" + spec["repository"] + "/" + spec["commit"] + "/" + spec["path"]
    path = scratch / (key + Path(spec["path"]).suffix)
    if not path.exists():
        with urllib.request.urlopen(url, timeout=30) as response:
            path.write_bytes(response.read())
    return load(path)


def paste(image, layer, box, alpha=1):
    x, y, width, height = box
    layer = layer.resize((round(width * S), round(height * S)), Image.Resampling.LANCZOS)
    if alpha != 1:
        layer.putalpha(layer.getchannel("A").point(lambda value: round(value * alpha)))
    image.alpha_composite(layer, (round(x * S), round(y * S)))


def text(image, x, y, value, size=13, color=WHITE, label=False):
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(LABEL if label else BODY, round(size * S))
    draw.text((round(x * S) + 1, round(y * S) + 2), value, font=font, fill="#000000")
    draw.text((round(x * S), round(y * S)), value, font=font, fill=color)


def tinted(layer, color):
    result = ImageChops.multiply(layer, Image.new("RGBA", layer.size, color))
    result.putalpha(layer.getchannel("A"))
    return result


def strip(image, layer, box):
    x, y, width, height = box
    cap = 24
    scaled_cap = cap * height / layer.height
    paste(image, layer.crop((0, 0, cap, layer.height)), (x, y, scaled_cap, height))
    paste(image, layer.crop((cap, 0, layer.width - cap, layer.height)), (x + scaled_cap, y, width - 2 * scaled_cap, height))
    paste(image, layer.crop((layer.width - cap, 0, layer.width, layer.height)), (x + width - scaled_cap, y, scaled_cap, height))


def card(image, number, sample, y, art):
    caption, name, slot, status, color, new, icon_key = sample
    x, width, height = 135, 430, 78
    text(image, x + 2, y - 19, caption, 9, MUTED, label=True)
    if new:
        paste(image, art["glow"], (x - 20, y - 7, width + 40, height + 14), 0.36)
    if number == 1:
        paste(image, tinted(art["card_bg"], color), (x, y, width, height))
        paste(image, art["card_rim"], (x, y, width, height), 0.88)
    elif number == 2:
        strip(image, art["toast"], (x - 5, y - 5, width + 10, height + 10))
    elif number == 3:
        panel(image, x - 10, y - 8, width + 20, height + 16, "metal")
    else:
        paste(image, art["backdrop"], (x - 15, y - 3, width + 30, height + 6), 0.85)
        ImageDraw.Draw(image).line((round((x + 80) * S), round((y + 75) * S), round((x + width - 10) * S), round((y + 75) * S)), fill="#927343", width=1)
    paste(image, art[icon_key], (x + 14, y + 14, 50, 50))
    paste(image, tinted(art["icon_rim"], color), (x + 9, y + 9, 60, 60))
    text(image, x + 81, y + 8, "LOOT  ·  " + slot, 10, GOLD, label=True)
    text(image, x + 80, y + 25, ("+" if number == 4 else "") + name, 18, color)
    text(image, x + 81, y + 52, status, 12, GREEN if new else MUTED)


def prepare(scratch):
    scratch.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = fetch(scratch, "card")
    toast = fetch(scratch, "toast")
    art = {
        "card_bg": atlas.crop((0, 0, 298, 76)),
        "card_rim": atlas.crop((0, 78, 298, 154)),
        "toast": toast.crop((289, 148, 565, 244)),
        "boots": fetch(scratch, "boots"),
        "helm": fetch(scratch, "helm"),
        "icon_rim": load(ROOT / "media/tex/character/QualityBorder.tga"),
        "backdrop": load(ROOT / "media/tex/levelup/Backdrop.tga"),
        "glow": load(ROOT / "media/tex/levelup/Glow.tga"),
    }
    # Actual candidate pixels on a checkerboard, distinct from the assembled proposals.
    candidates = Image.new("RGBA", (800, 490), "#202729")
    draw = ImageDraw.Draw(candidates)
    for y in range(0, 490, 16):
        for x in range(0, 800, 16):
            if (x // 16 + y // 16) % 2:
                draw.rectangle((x, y, x + 15, y + 15), fill="#303739")
    for index, key in enumerate(("card_bg", "card_rim", "toast", "icon_rim")):
        draw.text((15, index * 120 + 8), key, font=ImageFont.truetype(LABEL, 15), fill=GOLD)
        candidates.alpha_composite(art[key], (240, index * 120 + 7))
    candidates.convert("RGB").save(OUT / "asset-regions.png")
    sheet = Image.new("RGB", (1400, 940), "#101719")
    proposals = []
    for number, (title, description, source) in enumerate(DESIGNS, 1):
        image = Image.new("RGBA", (700 * S, 470 * S), "#182022")
        text(image, 30, 19, str(number).zfill(2) + "  " + title, 23, GOLD, label=True)
        text(image, 30, 53, description, 11, MUTED, label=True)
        for index, sample in enumerate(SAMPLES):
            card(image, number, sample, 109 + index * 112, art)
        text(image, 30, 431, source, 10, MUTED, label=True)
        text(image, 30, 449, "Static proposal · representative icons and substitute font · no design selected", 9, MUTED, label=True)
        filename = str(number).zfill(2) + ".png"
        image.convert("RGB").save(OUT / filename)
        sheet.paste(image.convert("RGB").resize((700, 470), Image.Resampling.LANCZOS), (((number - 1) % 2) * 700, ((number - 1) // 2) * 470))
        proposals.append({"id": str(number).zfill(2), "title": title, "description": description, "image": filename, "source": source})
    sheet.save(OUT / "comparison.png")
    (OUT / "designs.json").write_text(json.dumps({"selected": "02", "selectedImage": "selected.png", "sources": SOURCES, "proposals": proposals}, indent=2) + "\n")
    tiles = "".join('<a href="' + row["image"] + '"><img src="' + row["image"] + '" alt="' + row["title"] + '"></a>' for row in proposals)
    (OUT / "index.html").write_text('''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SurvivorsDragonUi · Loot designs</title>
<style>body{margin:0;background:#101719;color:#eee9df;font:16px system-ui}main{max-width:1500px;margin:auto;padding:30px}h1{color:#d7bd80}p{line-height:1.6;color:#b8b9ad}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(480px,1fr));gap:20px}img{width:100%;border-radius:12px}a{color:#d7bd80}@media(max-width:550px){.grid{display:block}main{padding:16px}}</style>
<main><h1>Selected: 02 · Silver loot alert</h1><p>The final version uses You received and the item name in the game's Friz Quadrata font. Already-collected drops never show a popup. No loot/slot or collection line appears.</p><a href="selected.png"><img src="selected.png" alt="Selected silver alert with two text lines"></a><h2>Original proposals</h2><p>Four proposals using actual published WoW artwork and our existing bundled pieces. Each shows collected common, new common and collected epic items. Click a proposal for its full image. The native popup stays active until the chosen view is ready.</p>
<div class="grid">''' + tiles + '''</div><p>These are static artwork previews, not game captures. Item icons are representative; the runtime uses native item data when available. These original proposals retain their earlier text and substitute fonts; the selected preview above shows the final direction. Only the selected silver frame enters the runtime payload. Sources and exact crops: <a href="../../LOOT-NOTIFICATIONS.md">developer notes</a>.</p></main></html>''')
    print(str(OUT / "comparison.png"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, default=Path(tempfile.gettempdir()) / "sdui-loot-preview-sources")
    prepare(parser.parse_args().sources)
