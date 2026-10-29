"""Render design-only boss health-loss GIFs from existing artwork, without Lua."""

from pathlib import Path
import math

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/designs/boss-health-loss"
ART = ROOT / "media/tex"
WIDTH, HEIGHT = 1060, 202
SCALE = 1.48
FPS, SECONDS = 20, 5
GOLD = "#e5c383"
MUTED = "#98a8b3"
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
HITS = [(0.7, 1.0, 0.84), (1.9, 0.84, 0.58), (2.2, 0.58, 0.52), (3.4, 0.52, 0.28)]
DESIGNS = [
    ("Gold catch-up", "Amber holds briefly, then glides down to current health.", "1 loss strip", "Best all-round fit"),
    ("White cut-out", "The lost section flashes white and fades in place, like player / target health.", "1 loss strip", "Most consistent with SDUI"),
    ("Spark wipe", "A bright gold edge sweeps back through the lost section.", "1 strip + 1 spark", "Clear, restrained impact"),
    ("Crimson echo", "A dark red afterimage follows the real fill with a softer, longer catch-up.", "1 loss strip", "Quietest animated option"),
    ("Three-beat drain", "The amber afterimage retreats in three crisp steps.", "1 loss strip", "Mechanical / chunky"),
    ("Shatter drop", "The missing section splits into six pieces that fall away.", "6 pooled strips", "Strong physical impact"),
    ("Ember burn", "A hot edge burns the lost section away, shedding a few rising embers.", "1 strip + 1 spark + 4 glints", "Fiery / dramatic"),
    ("Arcane dissolve", "Violet slivers lift and dissolve out of the lost section.", "8 pooled strips", "Magic / ethereal"),
    ("Bezel hit pulse", "The existing gold housing flashes twice; the fill still snaps immediately.", "3 bezel copies + 1 spark", "No trailing health block"),
    ("Twin recoil", "Two bright cuts part across the lost section, then fade.", "1 strip + 2 sparks", "Fast, sharp hit feedback"),
]


def load(name, box=None):
    result = Image.open(ART / name).convert("RGBA")
    return result.crop(box) if box else result


FILL = load("timer/FillWhite.tga", (0, 0, 256, 15))
LEFT = load("timer/BorderLeft.tga", (0, 0, 35, 31))
RIGHT = load("timer/BorderRight.tga", (0, 0, 35, 31))
CENTER = load("timer/BorderCenter.tga", (0, 0, 64, 31))
BACK = load("timer/BackgroundFixed.tga", (0, 0, 284, 18))
SPARK = load("timer/Spark.tga")
GLINT = load("tally/AffordableSparkle.tga")


def tint(source, color, alpha=1):
    result = ImageChops.multiply(source, Image.new("RGBA", source.size, (*color, 255)))
    if alpha < 1:
        result.putalpha(result.getchannel("A").point(lambda value: round(value * max(0, alpha))))
    return result


def paste(image, source, x, y, width, height, color=None, alpha=1, additive=False):
    if width < 0.6 or height < 0.6 or alpha <= 0:
        return
    layer = source.resize((max(1, round(width)), max(1, round(height))), Image.Resampling.LANCZOS)
    if color:
        layer = tint(layer, color, alpha)
    elif alpha < 1:
        layer = layer.copy()
        layer.putalpha(layer.getchannel("A").point(lambda value: round(value * max(0, alpha))))
    if additive or source is SPARK:
        box = (round(x), round(y), round(x) + layer.width, round(y) + layer.height)
        ground = image.crop(box)
        added = ImageChops.add(ground.convert("RGB"), layer.convert("RGB")).convert("RGBA")
        added.putalpha(ground.getchannel("A"))
        image.paste(Image.composite(added, ground, layer.getchannel("A")), box[:2])
    else:
        image.alpha_composite(layer, (round(x), round(y)))


def text(image, x, y, message, size=16, color="#eee9dc", bold=False, center=False):
    font = ImageFont.truetype(BOLD if bold else FONT, size)
    draw = ImageDraw.Draw(image)
    if center:
        x -= draw.textlength(message, font=font) / 2
    draw.text((round(x), round(y)), message, font=font, fill=color, stroke_width=1, stroke_fill="#080c10")


def strip(image, x, y, start, end, color, alpha=1, dy=0, height=None):
    paste(image, FILL, x + start * 280 * SCALE, y + dy, (end - start) * 280 * SCALE,
          height or 15 * SCALE, color, alpha)


def bezel(image, x, y, color=None, alpha=1):
    paste(image, LEFT, x, y, 35 * SCALE, 31 * SCALE, color, alpha, additive=bool(color))
    paste(image, RIGHT, x + 261 * SCALE, y, 35 * SCALE, 31 * SCALE, color, alpha, additive=bool(color))
    paste(image, CENTER, x + 35 * SCALE, y, 226 * SCALE, 31 * SCALE, color, alpha, additive=bool(color))


def current(t):
    return next((after for at, before, after in reversed(HITS) if t >= at), 1.0)


def effects(image, number, x, y, t):
    fx, fy = x + 8 * SCALE, y + 8 * SCALE
    value = current(t)
    for at, before, after in HITS:
        age = t - at
        if age < 0 or age > 1.05:
            continue
        low, high = max(value, after), before
        span = high - low
        if number == 0:
            p = min(1, max(0, (age - .12) / .60))
            edge = low + span * (1 - p) ** 2
            strip(image, fx, fy, low, edge, (255, 188, 63), .96)
        elif number == 1:
            strip(image, fx, fy, low, high, (255, 247, 221), max(0, 1 - age / .52))
        elif number == 2 and age < .62:
            p = age / .62
            edge = high - span * p
            strip(image, fx, fy, low, edge, (255, 175, 45), .82)
            paste(image, SPARK, fx + edge * 280 * SCALE - 5, fy - 9, 10, 42,
                  (255, 225, 130), math.sin(math.pi * min(1, p * 3)) if p < .33 else 1 - p * .45)
        elif number == 3:
            p = min(1, age / .95)
            strip(image, fx, fy, low, low + span * (1 - p) ** 1.45, (235, 65, 51), .74)
        elif number == 4 and age < .76:
            step = min(3, int(max(0, age - .1) / .19))
            edge = low + span * (1 - step / 3)
            strip(image, fx, fy, low, edge, (255, 202, 99), .94)
        elif number == 5 and age < .72:
            for piece in range(6):
                p = max(0, min(1, (age - piece * .025) / .56))
                start = low + span * piece / 6
                end = start + span / 6 * max(.1, 1 - p * .35)
                strip(image, fx, fy, start, end, (255, 157, 105), (1 - p) ** 1.1,
                      dy=30 * p * p + math.sin(piece * 2) * p * 4)
        elif number == 6 and age < .76:
            p = age / .76
            edge = high - span * p
            strip(image, fx, fy, low, edge, (255, 102, 22), 1 - .25 * p)
            paste(image, SPARK, fx + edge * 280 * SCALE - 7, fy - 13, 14, 48,
                  (255, 214, 76), 1 - p)
            for i in range(4):
                q = (p + i * .18) % 1
                gx = fx + edge * 280 * SCALE + math.sin(i * 2.7) * 13 * q
                paste(image, GLINT, gx - 4, fy - q * 28 + i * 3, 7, 7,
                      (255, 174 + i * 16, 45), (1 - q) * (1 - p))
        elif number == 7 and age < .78:
            for i in range(8):
                p = max(0, min(1, (age - (7 - i) * .025) / .56))
                start = low + span * (i + .06 * p) / 8
                end = low + span * (i + 1 - .16 * p) / 8
                strip(image, fx, fy, start, end, (175 + i * 8, 146, 255), (1 - p) ** 1.1,
                      dy=-p * (14 + (i % 3) * 5), height=15 * SCALE * (1 - p * .5))
        elif number == 8 and age < .5:
            pulse = math.exp(-age * 9) * (0.6 + .4 * math.cos(age * 36))
            bezel(image, x, y, (255, 244, 184), min(.88, pulse * 1.5))
            paste(image, SPARK, fx + low * 280 * SCALE - 3, fy - 5, 6, 32,
                  (255, 234, 181), max(0, 1 - age / .3))
        elif number == 9 and age < .5:
            p = age / .5
            strip(image, fx, fy, low, high, (255, 211, 143), (1 - p) * .72)
            middle = (low + high) / 2
            for direction in (-1, 1):
                edge = middle + direction * span * .5 * min(1, p * 1.7)
                paste(image, SPARK, fx + edge * 280 * SCALE - 4, fy - 6, 8, 35,
                      (255, 245, 218), 1 - p)


def bar(image, x, y, t, number=None):
    value = current(t)
    paste(image, BACK, x + 6 * SCALE, y + 6.5 * SCALE, 284 * SCALE, 18 * SCALE)
    strip(image, x + 8 * SCALE, y + 8 * SCALE, 0, value, (219, 31, 26))
    if number == 8:
        bezel(image, x, y)
    if number is not None:
        effects(image, number, x, y, t)
    # Each path draws the original translucent bezel exactly once.
    if number != 8:
        bezel(image, x, y)
    text(image, x + 148 * SCALE, y - 24, "Edwin VanCleef", 18, center=True)
    text(image, x + 148 * SCALE, y + 12, f"{value * 10:.1f}M / 10.0M", 18, center=True)


def card(number, t):
    image = Image.new("RGBA", (WIDTH, HEIGHT), "#11191f")
    draw = ImageDraw.Draw(image)
    draw.line((20, HEIGHT - 1, WIDTH - 20, HEIGHT - 1), fill="#34404a")
    title, description, cost, tag = DESIGNS[number]
    text(image, 24, 10, f"{number + 1:02d}  {title}", 23, GOLD, True)
    text(image, 24, 43, "NORMAL MODE", 12, "#e3bf7b", True)
    text(image, 568, 43, "PERFORMANCE MODE  ·  INSTANT", 12, "#a8c4bc", True)
    bar(image, 32, 92, t, number)
    bar(image, 568, 92, t)
    text(image, 24, 157, description, 15, "#d7e0e4")
    text(image, 24, 181, f"{tag}  ·  Per-pulse concept budget: {cost}", 12, MUTED)
    return image


def palette():
    samples = Image.new("RGB", (WIDTH, HEIGHT * 10))
    for number in range(10):
        samples.paste(card(number, 2.08).convert("RGB"), (0, number * HEIGHT))
    return samples.quantize(colors=256, method=Image.Quantize.MEDIANCUT)


def save_gif(frames, path, colors):
    indexed = [frame.convert("RGB").quantize(palette=colors, dither=Image.Dither.NONE) for frame in frames]
    indexed[0].save(path, save_all=True, append_images=indexed[1:], loop=0,
                    duration=1000 // FPS, disposal=1, optimize=True)


def sheet(cards, start):
    result = Image.new("RGBA", (WIDTH, HEIGHT * 5 + 65), "#0b1218")
    text(result, 24, 10, f"BOSS HEALTH LOSS  /  {start + 1:02d}–{start + 5:02d}", 24, GOLD, True)
    text(result, 24, 42, "Simulated damage · Existing Blizzard pill artwork · 5-second loop · No addon changes", 14, MUTED)
    for i, image in enumerate(cards):
        result.alpha_composite(image, (0, 65 + i * HEIGHT))
    return result


def asset_sheet():
    image = Image.new("RGBA", (1060, 445), "#182129")
    text(image, 24, 15, "INSPECTED ARTWORK", 24, GOLD, True)
    text(image, 24, 52, "Original source pieces on a neutral background; all are already bundled.", 16, MUTED)
    for i, (label, source, w, h) in enumerate([
        ("Blizzard FillWhite · content 256 × 15", FILL, 400, 30),
        ("Blizzard Spark · 8 × 32", SPARK, 16, 64),
        ("Blizzard bezel · left 35 × 31 / center 64 × 31 / right 35 × 31", LEFT, 70, 62),
        ("SDUI original sparkle mask · 32 × 32", GLINT, 64, 64),
    ]):
        y = 99 + i * 83
        text(image, 24, y, label, 16)
        paste(image, source, 600, y - 8, w, h)
        if i == 2:
            paste(image, CENTER, 670, y - 8, 230, 62)
            paste(image, RIGHT, 900, y - 8, 70, 62)
    image.convert("RGB").save(OUT / "asset-regions.png")


def gallery():
    cards = "\n".join(
        f'<article id="idea-{i+1}"><h2>{i+1:02d} · {title}</h2>'
        f'<a href="{i+1:02d}.gif"><img src="{i+1:02d}.gif" alt="{title}: normal mode and Performance Mode animated comparison" loading="lazy"></a>'
        f'<p>{description}</p><p class="meta">{tag} · Proposed active regions: {cost}.</p></article>'
        for i, (title, description, cost, tag) in enumerate(DESIGNS)
    )
    html = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SDUI · 10 boss health-loss ideas</title>
<style>
:root{color-scheme:dark;font-family:Arial,sans-serif;background:#0b1218;color:#e7e5dc}
body{max-width:1120px;margin:0 auto;padding:36px 22px}h1{font-size:36px;color:#e5c383;margin-bottom:12px}
p{line-height:1.6;margin:8px 0}a{color:#e5c383}header{margin-bottom:28px}.meta{color:#98a8b3;font-size:14px}
nav{display:flex;gap:9px;flex-wrap:wrap;margin:22px 0}nav a{padding:9px 13px;border:1px solid #44515a;border-radius:6px;text-decoration:none}
article{background:#11191f;border:1px solid #34404a;border-radius:10px;padding:18px 20px;margin:18px 0;scroll-margin-top:15px}
h2{font-size:21px;margin:0 0 14px;color:#e5c383}img{display:block;width:100%;height:auto;border-radius:5px}
.pick{border-left:3px solid #e5c383;padding-left:15px}footer{margin:30px 0;color:#98a8b3}
</style><header><p class="meta">SURVIVORSDRAGONUI / DESIGN STUDY / 28 OCTOBER 2026</p>
<h1>10 ways to show a boss taking damage</h1>
<p>All previews keep the existing gold pill and red health fill. The health number and real fill update immediately.
Only the missing section or housing animates. Performance Mode shows the same health instantly with the optional effect hidden.</p>
<p class="pick"><strong>My first choice: 01 Gold catch-up.</strong> Choose 02 for consistency with player / target bars,
03 for a small but obvious hit, or 06 for a stronger physical effect.</p>
<p class="meta">Five-second looping GIFs. The larger second hit and two close hits are intentional simulated inputs.
These are custom animation assemblies using inspected artwork, not captured game footage or copied Blizzard animation sequences.
The budget labels describe possible added texture regions, not measured draw calls or FPS.</p>
<nav>NAVIGATION</nav><p><a href="SOURCES.md">Source details and implementation limits</a> ·
<a href="01-05.gif">Animated sheet 01–05</a> · <a href="06-10.gif">Animated sheet 06–10</a></p></header>
CARDS<footer>No runtime files were changed. Click a GIF to inspect it at full size. All previews and this gallery are outside the shipped addon payload.</footer></html>'''
    html = html.replace("NAVIGATION", "".join(f'<a href="#idea-{i}">{i:02d}</a>' for i in range(1, 11))).replace("CARDS", cards)
    (OUT / "index.html").write_text(html)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    colors = palette()
    for start in (0, 5):
        group = []
        for number in range(start, start + 5):
            frames = [card(number, frame / FPS) for frame in range(FPS * SECONDS)]
            save_gif(frames, OUT / f"{number + 1:02d}.gif", colors)
            group.append(frames)
            print(f"Rendered {number + 1:02d} {DESIGNS[number][0]}", flush=True)
        sheets = [sheet([group[n][frame] for n in range(5)], start)
                  for frame in range(FPS * SECONDS)]
        save_gif(sheets, OUT / f"{start + 1:02d}-{start + 5:02d}.gif", colors)
        del group, sheets, frames
        print(f"Rendered animated sheet {start + 1:02d}–{start + 5:02d}", flush=True)
    asset_sheet()
    gallery()
    print(f"Design gallery: {OUT / 'index.html'}", flush=True)


if __name__ == "__main__":
    main()
