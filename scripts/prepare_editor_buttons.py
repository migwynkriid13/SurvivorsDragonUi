"""Prepare the pinned retail red button pixels; no addon or game code executes."""
from pathlib import Path
import hashlib
import io
import json
import urllib.request
from PIL import Image
from prepare_client_textures import blp_from_bgra, blp_bgra_levels, lossless_palette

ROOT = Path(__file__).resolve().parents[1]
REF = 'e80e3278cc833c89e1f3fc79557b68315d750935'
SOURCE = 'Buttons/128GoldRedButton.PNG'
# Full source atlas rectangles are documented in third_party/SDUI-ARTWORK.md.
STATES = {
    'normal': ((295, 521, 409, 649), (0, 1, 64, 129), (179, 521, 293, 649)),
    'pressed': ((295, 781, 409, 909), (0, 261, 64, 389), (179, 781, 293, 909)),
    'disabled': ((295, 651, 409, 779), (0, 131, 64, 259), (179, 651, 293, 779)),
}
HIGHLIGHT = (1, 391, 442, 519)


def prepare():
    url = 'https://raw.githubusercontent.com/Gethe/wow-ui-textures/' + REF + '/' + SOURCE
    with urllib.request.urlopen(url, timeout=30) as response:
        data = response.read()
    source = Image.open(io.BytesIO(data)).convert('RGBA')
    if source.size != (512, 1024):
        raise ValueError('Pinned button sheet dimensions changed')
    output = Image.new('RGBA', (512, 512))
    for index, rectangles in enumerate(STATES.values()):
        for x, rectangle in zip((0, 128, 208), rectangles):
            output.paste(source.crop(rectangle), (x, index * 128))
    output.paste(source.crop(HIGHLIGHT), (0, 384))
    folder = ROOT / 'media/tex/editor'
    output.save(folder / 'button.tga', compression=None)
    pixels = output.tobytes('raw', 'BGRA')
    encoded = lossless_palette(blp_from_bgra(output.width, output.height, pixels))
    if blp_bgra_levels(encoded) != (output.width, output.height, [pixels]):
        raise ValueError('Prepared button BLP changed source pixels')
    if Image.open(folder / 'button.tga').convert('RGBA').tobytes() != output.tobytes():
        raise ValueError('Retained button TGA changed source pixels')
    (folder / 'button.blp').write_bytes(encoded)
    receipt = {
        'source_commit': REF, 'build': '10.0.0.45454', 'source': SOURCE,
        'source_sha256': hashlib.sha256(data).hexdigest(),
        'source_canvas': list(source.size), 'canvas': list(output.size),
        'state_rectangles': STATES, 'highlight_rectangle': HIGHLIGHT,
        'destination': 'media/tex/editor/button.blp',
        'rgba_sha256': hashlib.sha256(output.tobytes()).hexdigest(),
        'blp_sha256': hashlib.sha256(encoded).hexdigest(),
        'decoded_pixels_and_tga_match': True,
        'preparation': 'Exact crops; retain each outer cap and stretch only the center at runtime. No recoloring or resampling.',
    }
    (ROOT / 'third_party/EditorButtons-PREPARATION.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    prepare()
