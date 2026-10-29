"""Prepare the pinned Dragonflight Edit Mode pixels without executing the addon."""
from pathlib import Path
import io
import hashlib
import json
import urllib.request
from PIL import Image
from prepare_client_textures import blp_from_bgra, blp_bgra_levels, lossless_palette

ROOT = Path(__file__).resolve().parents[1]
REF = 'e80e3278cc833c89e1f3fc79557b68315d750935'  # Dragonflight 10.0.0.45454
BASE = 'https://raw.githubusercontent.com/Gethe/wow-ui-textures/' + REF + '/Editmode/'


def prepare():
    sources = {}
    def source(name):
        with urllib.request.urlopen(BASE + name + '.PNG', timeout=30) as response:
            data = response.read()
        sources[name] = hashlib.sha256(data).hexdigest()
        return Image.open(io.BytesIO(data)).convert('RGBA')
    sheet, vertical = source('EditModeUI'), source('EditModeUIVertical')
    output = Image.new('RGBA', (256, 64))
    for selected in (False, True):
        y = 32 if selected else 0
        corner = sheet.crop((1, 91 if selected else 73, 17, 107 if selected else 89))
        pieces = [corner, corner.transpose(Image.Transpose.ROTATE_270),
                  corner.transpose(Image.Transpose.ROTATE_90), corner.transpose(Image.Transpose.ROTATE_180),
                  sheet.crop((0, 55 if selected else 19, 16, 71 if selected else 35)),
                  sheet.crop((0, 37 if selected else 1, 16, 53 if selected else 17)),
                  vertical.crop((37 if selected else 1, 0, 53 if selected else 17, 16)),
                  vertical.crop((55 if selected else 19, 0, 71 if selected else 35, 16)),
                  source('EditModeUISelectedBackground' if selected else 'EditModeUIHighlightBackground')]
        for index, piece in enumerate(pieces):
            output.paste(piece, (index * 16, y))
    destination = ROOT / 'media/tex/editor'
    output.save(destination / 'selection.tga', compression=None)
    raw = blp_from_bgra(output.width, output.height, output.tobytes('raw', 'BGRA'))
    encoded = lossless_palette(raw)
    width, height, levels = blp_bgra_levels(encoded)
    if (width, height) != output.size or levels != [output.tobytes('raw', 'BGRA')]:
        raise ValueError('Prepared BLP changed source RGBA pixels')
    if Image.open(destination / 'selection.tga').convert('RGBA').tobytes() != output.tobytes():
        raise ValueError('Retained TGA changed source RGBA pixels')
    (destination / 'selection.blp').write_bytes(encoded)
    receipt = {
        'source_commit': REF, 'build': '10.0.0.45454', 'source_sha256': sources,
        'destination': 'media/tex/editor/selection.blp', 'canvas': list(output.size),
        'rgba_sha256': hashlib.sha256(output.tobytes()).hexdigest(),
        'blp_sha256': hashlib.sha256(encoded).hexdigest(),
        'decoded_pixels_and_tga_match': True,
        'preparation': 'Exact crops and 90-degree corner rotations; no recoloring or resampling.',
    }
    (ROOT / 'third_party/Editor-PREPARATION.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    prepare()
