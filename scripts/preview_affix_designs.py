"""Prepare twenty-one red-outlined affix proposals from pinned Blizzard artwork.

This is artwork preparation only: no addon Lua, game or validation is run.
Original PNG bytes, source receipts and all proposals stay outside the payload.
"""

import hashlib
import json
import math
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

from prepare_client_textures import blp_bgra_levels

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/designs/heroic-affixes"
SOURCES = ROOT / "third_party/sources/affixes"
COMMIT = "d23deaf8f44a7d280dc974a5c9d5321c013db59b"
BASE = "https://raw.githubusercontent.com/Gethe/wow-ui-textures/" + COMMIT + "/ICONS/"
LABELS = ("Bolstering", "Sanguine", "Explosive")
OUTLINE_RED = (237, 35, 38)
# These are proposed visual associations, not new spell or mechanic mappings.
DESIGNS = [
    ("Familiar affix marks", "cutout", "ability_toughness", "Spell_Shadow_BloodBoil", "Spell_Fire_FelFlameRing_RED"),
    ("Battle cry", "round", "Ability_Warrior_BattleShout", "Spell_DeathKnight_BloodBoil", "Ability_FelArakkoa_FelDetonation_Red"),
    ("Command and blood", "cutout", "Ability_Warrior_CommandingShout", "Ability_DeathKnight_RoilingBlood", "Ability_FelArakkoa_FelDetonation_Green"),
    ("Rally and rupture", "gold", "Ability_Warrior_RallyingCry", "Ability_IronMaidens_BloodRitual", "Ability_IronMaidens_DetonationSequence"),
    ("Dragon fire", "cutout", "Ability_Warrior_DragonRoar", "Ability_IronMaidens_CorruptedBlood", "Ability_Hunter_ExplosiveShot"),
    ("Rage and ritual", "round", "Ability_Warrior_InnerRage", "Ability_IronMaidens_MaraksBloodcalling", "Spell_Fire_Fireball"),
    ("Shield and burst", "silver", "Ability_Warrior_ShieldWall", "Ability_IronMaidens_WhirlofBlood", "Spell_Fire_SelfDestruct"),
    ("Strength and flame", "cutout", "Ability_Warrior_StrengthOfArms", "Ability_Rogue_BloodSplatter", "SPELL_FIRE_INCINERATE"),
    ("Stone guardian", "round", "Ability_Warrior_StalwartProtector", "Ability_Rogue_HungerforBlood", "Spell_Fire_FlameBolt"),
    ("Steel and shadow", "gold", "Ability_Warrior_ShieldMastery", "Ability_Warrior_BloodBath", "Sha_Spell_Fire_Fireball02_nightmare"),
    ("Sacred oath", "cutout", "Spell_Holy_WordFortitude", "Ability_Warrior_BloodFrenzy", "INV_Misc_Bomb_02"),
    ("Golden kings", "round", "Spell_Holy_GreaterBlessingofKings", "Ability_Warrior_BloodNova", "INV_Misc_Bomb_04"),
    ("Sanctuary", "silver", "Spell_Holy_GreaterBlessingofSanctuary", "Ability_Warrior_Bloodsurge", "INV_Misc_Bomb_06"),
    ("Bloodlust", "cutout", "Spell_Nature_BloodLust", "Ability_Warrior_Trauma", "INV_Misc_Bomb_09"),
    ("Earthen power", "cutout", "Spell_Nature_Strength", "Ability_Racial_BloodRage", "Ability_Mage_LivingBomb"),
    ("War horn", "cutout", "INV_Misc_Horn_02", "Spell_Shadow_LifeDrain02", "Ability_Rhyolith_Immolation"),
    ("Predator", "round", "Ability_Druid_ChallangingRoar", "Spell_Shadow_LifeDrain", "INV_Azeriteexplosion"),
    ("Titan", "silver", "Ability_Racial_Avatar", "Spell_Deathknight_BloodPresence", "Ability_Xavius_TormentingDetonation"),
    ("Red crystal", "cutout", "Ability_Warrior_FocusedRage", "INV_Misc_Gem_Bloodstone_01", "6BF_Explosive_Shard"),
    ("Wild sigils", "round", "Ability_Druid_Enrage", "Ability_Skeer_BloodLetting", "ABILITY_MONK_CHIEXPLOSION"),
    ("01 transparent + red circle", "cutout_rim", "ability_toughness", "Spell_Shadow_BloodBoil", "Spell_Fire_FelFlameRing_RED"),
]


def font(size, bold=False):
    name = "/System/Library/Fonts/Supplemental/Arial" + (" Bold" if bold else "") + ".ttf"
    return ImageFont.truetype(name, size)


def download(name):
    file = SOURCES / (name + ".PNG")
    if not file.exists():
        with urlopen(BASE + quote(file.name)) as response:
            file.write_bytes(response.read())
    raw = file.read_bytes()
    image = Image.open(file).convert("RGBA")
    return name, {
        "file": file.relative_to(ROOT).as_posix(),
        "url": BASE + quote(file.name),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "canvas": list(image.size),
        "crop": [4, 4, image.width - 4, image.height - 4],
    }


def round_mask(size, feather=0):
    high = size * 4
    mask = Image.new("L", (high, high))
    pixels = mask.load()
    radius = high / 2 - 2
    for y in range(high):
        for x in range(high):
            distance = math.hypot(x + 0.5 - high / 2, y + 0.5 - high / 2)
            if feather:
                alpha = max(0, min(1, (radius - distance) / (feather * 4)))
            else:
                alpha = float(distance <= radius)
            pixels[x, y] = round(255 * alpha)
    return mask.resize((size, size), Image.Resampling.LANCZOS)


def rim(size):
    # The existing pet crop keeps its round contour without square shadows.
    width, height, levels = blp_bgra_levels((ROOT / "media/tex/jewelry/Frame.blp").read_bytes())
    image = Image.frombytes("RGBA", (width, height), levels[0], "raw", "BGRA")
    image = image.crop((576, 56, 648, 128)).resize((size, size), Image.Resampling.LANCZOS)
    red, green, blue, alpha = image.split()
    light = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    image = Image.merge("RGBA", tuple(light.point(lambda value, channel=channel: round(value * channel / 255))
                                     for channel in OUTLINE_RED) + (alpha,))
    return image


def red_outline(source):
    size = source.width
    canvas = Image.new("RGBA", source.size)
    canvas.alpha_composite(source.resize((size - 10, size - 10), Image.Resampling.LANCZOS), (5, 5))
    support = canvas.getchannel("A").point(lambda value: 255 if value >= 56 else 0)
    expanded = support.filter(ImageFilter.MaxFilter(9))
    edge = ImageChops.subtract(expanded, support).filter(ImageFilter.GaussianBlur(0.55))
    result = Image.new("RGBA", source.size, OUTLINE_RED + (0,))
    result.putalpha(edge)
    result.alpha_composite(canvas)
    return result


def red_circle(source):
    size = source.width
    result = Image.new("RGBA", source.size)
    icon_size = round(size * 0.82)
    margin = (size - icon_size) // 2
    result.alpha_composite(source.resize((icon_size, icon_size), Image.Resampling.LANCZOS), (margin, margin))
    high = Image.new("RGBA", (size * 4, size * 4))
    ImageDraw.Draw(high).ellipse((12, 12, size * 4 - 13, size * 4 - 13), outline=OUTLINE_RED + (255,), width=16)
    result.alpha_composite(high.resize(source.size, Image.Resampling.LANCZOS))
    return result


def symbol(name, style, size=112):
    if style == "cutout_rim":
        return red_circle(symbol(name, "cutout", size))
    source = Image.open(SOURCES / (name + ".PNG")).convert("RGBA")
    source = source.crop((4, 4, source.width - 4, source.height - 4))
    source = source.resize((size, size), Image.Resampling.LANCZOS)
    if style == "cutout":
        # Black-key alpha / inverse premultiplication preserves the source
        # appearance over black. The radial fade removes square source edges.
        rgba = []
        for red, green, blue, alpha in source.get_flattened_data():
            coverage = max(red, green, blue)
            if coverage < 12:
                rgba.append((red, green, blue, 0))
            else:
                rgba.append((round(red * 255 / coverage), round(green * 255 / coverage),
                             round(blue * 255 / coverage), round(alpha * coverage / 255)))
        source.putdata(rgba)
    mask = round_mask(size, 11 if style == "cutout" else 0)
    source.putalpha(ImageChops.multiply(source.getchannel("A"), mask))
    if style in ("gold", "silver"):
        canvas = Image.new("RGBA", (size, size))
        icon_size = round(size * 34 / 39)
        icon = source.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
        margin = (size - icon_size) // 2
        canvas.alpha_composite(icon, (margin, margin))
        canvas.alpha_composite(rim(size))
        return canvas
    return source


def checker(image, box, step=16):
    draw = ImageDraw.Draw(image)
    x0, y0, x1, y1 = box
    for y in range(y0, y1, step):
        for x in range(x0, x1, step):
            color = (43, 49, 48) if ((x - x0) // step + (y - y0) // step) % 2 else (53, 60, 57)
            draw.rectangle((x, y, min(x + step - 1, x1 - 1), min(y + step - 1, y1 - 1)), fill=color)


def timer(image):
    draw = ImageDraw.Draw(image)
    draw.text((450, 57), "RUN 00:00 / 10:00", font=font(26, True), fill=(241, 237, 221), anchor="mm")
    scale = 2.4
    left, top = 95, 86
    parts = (("BorderLeft", 35, 31), ("BorderCenter", 64, 31), ("BorderRight", 35, 31))
    draw.rounded_rectangle((left + 10, top + 15, left + 700, top + 55), radius=18, fill=(4, 6, 5))
    for index, (name, width, height) in enumerate(parts):
        original = Image.open(ROOT / ("media/tex/timer/" + name + ".tga")).convert("RGBA")
        part = original.crop((0, 0, width, height))
        if index == 1:
            part = part.resize((round((296 - 70) * scale), round(height * scale)), Image.Resampling.LANCZOS)
            x = left + round(35 * scale)
        else:
            part = part.resize((round(width * scale), round(height * scale)), Image.Resampling.LANCZOS)
            x = left if index == 0 else left + round((296 - 35) * scale)
        image.alpha_composite(part, (x, top))
    skull = Image.open(SOURCES / "UI-TargetingFrame-Skull.PNG").convert("RGBA")
    skull = skull.resize((43, 43), Image.Resampling.LANCZOS)
    for index in range(5):
        x = left + round(680 * (0.18 + index * 0.2))
        image.alpha_composite(skull, (x - 21, top + 16))


def card(number, title, style, icons):
    image = Image.new("RGBA", (900, 370), (19, 24, 25, 255))
    checker(image, (18, 40, 882, 297))
    draw = ImageDraw.Draw(image)
    draw.text((24, 16), f"{number:02d}  {title}", font=font(22, True), fill=(240, 211, 151), anchor="lm")
    timer(image)
    for index, icon in enumerate(icons):
        x = 450 + (index - 1) * 78
        image.alpha_composite(icon.resize((64, 64), Image.Resampling.LANCZOS), (x - 32, 174))
        draw.text((x, 263), LABELS[index], font=font(13), fill=(236, 234, 225), anchor="mm")
    treatment = {"cutout": "Transparent artwork / red silhouette outline", "round": "Round icons / red outline", "gold": "Metal rim / red outline", "silver": "Metal rim / red outline", "cutout_rim": "01 transparent artwork / red circular rim"}[style]
    draw.text((450, 318), treatment, font=font(20), fill=(214, 221, 219), anchor="mm")
    draw.text((450, 349), "STATIC PROPOSAL  /  all three shown for comparison", font=font(13), fill=(133, 150, 149), anchor="mm")
    return image


def html(records):
    cards = []
    for item in records:
        number = item["number"]
        links = " · ".join('<a href="' + item["sources"][key]["url"] + '">' + key + '</a>' for key in LABELS)
        cards.append(f'<article id="design-{number}"><h2>{number:02d} — {item["title"]}</h2><a href="{number:02d}.png"><img src="{number:02d}.png" alt="{item["title"]}: Bolstering, Sanguine, Explosive"></a><div class="transparent"><img src="{number:02d}-icons.png" alt="Transparent icon artwork"></div><p>Source artwork: {links}</p></article>')
    return '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>21 red-outlined Heroic affix icon proposals</title><style>
    *{box-sizing:border-box}body{margin:0;background:#101718;color:#e9efed;font:16px system-ui}header{padding:28px;max-width:1250px;margin:auto}h1{margin:0 0 12px}p{line-height:1.6}a{color:#e1c28a}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,460px),1fr));gap:22px;max-width:1500px;padding:0 24px 40px;margin:auto}article{border:1px solid #3b4845;border-radius:14px;overflow:hidden;background:#1b2526}h2{font-size:19px;margin:18px}article>a>img{display:block;width:100%}.transparent{margin:12px 18px;background:repeating-conic-gradient(#687268 0 25%,#43524a 0 50%) 50%/20px 20px;border-radius:8px;padding:8px;text-align:center}.transparent img{display:block;width:min(100%,400px);height:auto;margin:auto}article p{margin:18px;font-size:13px}.hint{color:#a9bbb4}button{background:#e1c28a;border:0;border-radius:7px;padding:9px 14px;font:inherit;cursor:pointer}
    </style><header><h1>21 red-outlined Heroic affix icon designs</h1><p>Sets <b>01–20</b> now have red outlines. <b><a href="#design-21">21</a></b> uses #01’s transparent artwork inside red circular rims. Every set shows <b>Bolstering → Sanguine → Explosive</b>, centered below the same timer. No square backgrounds. The second strip exposes actual transparency.</p><p class="hint">Custom visual proposals using Blizzard artwork from the verified Shadowlands 9.2.7 texture mirror. These are not official retail affix sets or game captures. The three icons are shown together for comparison; the game will show only the run’s published affixes.</p><button onclick="document.querySelectorAll('.transparent').forEach(e=>e.style.background=e.style.background?'':'#d1d5cf')">Toggle transparency background</button><p><a href="overview.png">All twenty-one overview</a> · <a href="ARTWORK.md">Source and adaptation notes</a></p></header><main>''' + "\n".join(cards) + "</main></html>\n"


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    SOURCES.mkdir(parents=True, exist_ok=True)
    names = sorted({name for _, _, *names in DESIGNS for name in names})
    with ThreadPoolExecutor(max_workers=6) as pool:
        metadata = dict(pool.map(download, names))
    records, cards = [], []
    for number, (title, style, *names) in enumerate(DESIGNS, 1):
        icons = [symbol(name, style) for name in names]
        if style != "cutout_rim":
            icons = [red_outline(icon) for icon in icons]
        strip = Image.new("RGBA", (448, 144))
        for index, icon in enumerate(icons):
            strip.alpha_composite(icon, (16 + index * 152, 16))
        strip.save(OUTPUT / f"{number:02d}-icons.png")
        preview = card(number, title, style, icons)
        preview.save(OUTPUT / f"{number:02d}.png")
        cards.append(preview)
        records.append({"number": number, "title": title, "treatment": "red_metal" if style in ("gold", "silver") else style,
                        "outline": "red circular rim around original 01 transparent artwork" if style == "cutout_rim" else "red icon outline",
                        "sources": {key: metadata[name] for key, name in zip(LABELS, names)}})
    overview = Image.new("RGB", (2400, math.ceil(len(cards) / 4) * 247), (19, 24, 25))
    for index, preview in enumerate(cards):
        x = (index % 4) * 600
        if index == len(cards) - 1 and len(cards) % 4 == 1:
            x = 900
        overview.paste(preview.resize((600, 247), Image.Resampling.LANCZOS), (x, (index // 4) * 247))
    overview.save(OUTPUT / "overview.png")
    for page in range(math.ceil(len(cards) / 5)):
        count = min(5, len(cards) - page * 5)
        sheet = Image.new("RGB", (900 if count == 1 else 1800, math.ceil(count / 2) * 370), (19, 24, 25))
        for slot in range(count):
            image = cards[page * 5 + slot]
            x = 450 if slot == 4 else (slot % 2) * 900
            sheet.paste(image, (x, (slot // 2) * 370))
        sheet.save(OUTPUT / f"sheet-{page + 1}.png")
    skull = SOURCES / "UI-TargetingFrame-Skull.PNG"
    receipt = {"source_commit": COMMIT, "build": "9.2.7 (45114)",
               "timer_marker": {"file": skull.relative_to(ROOT).as_posix(),
                                "url": BASE.replace("/ICONS/", "/TARGETINGFRAME/") + skull.name,
                                "sha256": hashlib.sha256(skull.read_bytes()).hexdigest(),
                                "canvas": list(Image.open(skull).size)},
               "designs": records}
    (ROOT / "third_party/affix-design-sources.json").write_text(json.dumps(receipt, indent=2) + "\n")
    (OUTPUT / "index.html").write_text(html(records))
    print(f"Prepared {len(records)} three-affix proposals from {len(metadata)} original textures; no runtime files changed.")


if __name__ == "__main__":
    main()
