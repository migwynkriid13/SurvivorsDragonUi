"""CI-only artwork data contracts; never execute addon or game code."""

import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from prepare_client_textures import blp_bgra_levels, blp_from_tga


ROOT = Path(__file__).resolve().parents[2]


class RuntimeTextureTests(unittest.TestCase):
    def test_static_resting_icon_keeps_original_pixels_without_the_animation_sheet(self):
        directory = ROOT / "media/tex/unitframes"
        runtime = (directory / "Resting.blp").read_bytes()
        width, height, levels = blp_bgra_levels(runtime)
        self.assertEqual((width, height, len(levels)), (64, 64, 1))
        self.assertLess(len(runtime), 16 * 1024, "static resting icon regained a large canvas")
        # Pinned from the former sheet before removal: retain the exact visible
        # 60-pixel tile and its original neighbouring filter pixels, without scaling.
        self.assertEqual(
            hashlib.sha256(levels[0]).hexdigest(),
            "4e7fe88b7b8f61aa875762a5a9f6fc896d760d7bd6c5bb405e4f52626293d903",
        )
        tile = b"".join(levels[0][row * width * 4:row * width * 4 + 60 * 4] for row in range(60))
        self.assertEqual(
            hashlib.sha256(tile).hexdigest(),
            "a1704812e2ac22ac71693815e36e99c54e89f060e0c588b85d88b6137cf92227",
        )
        prepared, _ = blp_from_tga((directory / "Resting.tga").read_bytes())
        self.assertEqual(blp_bgra_levels(prepared), (width, height, levels))
        manifest = json.loads((ROOT / "packaging/runtime-files.json").read_text())
        self.assertIn("media/tex/unitframes/Resting.blp", manifest["files"])
        self.assertNotIn("media/tex/unitframes/UIUnitFrameRestingFlipbook.blp", manifest["files"])
        for suffix in (".blp", ".tga"):
            self.assertFalse((directory / ("UIUnitFrameRestingFlipbook" + suffix)).exists())

    def test_jewelry_housing_preserves_neutral_pixels_and_bakes_ranked_gems_and_halo(self):
        directory = ROOT / "media/tex/jewelry"
        source = (directory / "Runecarver.tga").read_bytes()
        self.assertEqual(
            hashlib.sha256(source).hexdigest(),
            "b53931149f049507f2ac5a983340ffbf3c886cd691e083bee8d8c0690acc6b17",
        )
        converted, _ = blp_from_tga(source)
        source_width, source_height, source_levels = blp_bgra_levels(converted)
        width, height, levels = blp_bgra_levels((directory / "Frame.blp").read_bytes())
        self.assertEqual((source_width, source_height), (128, 128))
        self.assertEqual((width, height), (512, 128))
        empty = bytearray()
        for row in range(128):
            left = (row * width + 256) * 4
            empty.extend(levels[0][left:left + 128 * 4])
        self.assertEqual(empty, source_levels[0], "empty slots received equipped brightness or another crop")

        width, height, gemmed = blp_bgra_levels((directory / "GemmedRunecarver.blp").read_bytes())
        self.assertEqual((width, height, len(gemmed)), (512, 128, 1))
        width, height, attached = blp_bgra_levels((directory / "AttachedRunecarver.blp").read_bytes())
        self.assertEqual((width, height, len(attached)), (512, 256, 1))

        def pixel(pixels, cell, x, y):
            offset = (y * width + cell * 128 + x) * 4
            blue, green, red, alpha = pixels[offset:offset + 4]
            return red, green, blue, alpha

        crops = [(levels[0], 3, None)]
        crops.extend((gemmed[0], cell, channel) for cell, channel in enumerate((1, 2, 2, 0)))
        for index, (pixels, cell, dominant_channel) in enumerate(crops):
            with self.subTest(cell=cell, dominant_channel=dominant_channel):
                for x, y in ((64, 17), (21, 64), (95, 34), (95, 94), (6, 64)):
                    rgb = pixel(pixels, cell, x, y)
                    self.assertGreater(rgb[3], 0)
                    if dominant_channel is None:
                        self.assertLessEqual(max(rgb[:3]) - min(rgb[:3]), 2)
                    else:
                        self.assertEqual(rgb[dominant_channel], max(rgb[:3]))
                self.assertEqual(pixel(pixels, cell, 64, 64)[3], empty[(64 * 128 + 64) * 4 + 3])
                self.assertEqual(pixel(pixels, cell, 0, 64)[3], empty[(64 * 128) * 4 + 3])
                # These points are equally far from the center. Only the left
                # one is close to the protruding metal socket.
                near_socket = pixel(pixels, cell, 8, 56)[3]
                across_from_socket = pixel(pixels, cell, 119, 56)[3]
                self.assertGreater(near_socket, across_from_socket + 80)
                # The selected metal sample is solid and outside every gem.
                offset = (64 * 128 + 110) * 4
                blue, green, red, alpha = empty[offset:offset + 4]
                self.assertEqual(alpha, 255)
                self.assertEqual(pixel(pixels, cell, 110, 64), (red, green, blue, alpha))
                row, column = divmod(index, 4)
                for x, y in ((24, 108), (103, 108)):
                    clipped = pixel(attached[0], column, x, y + row * 128)[3]
                    self.assertEqual(clipped, empty[(y * 128 + x) * 4 + 3])
                    self.assertGreater(pixel(pixels, cell, x, y)[3], clipped + 80)
                for x, y in ((64, 6), (64, 17), (64, 64), (110, 64)):
                    self.assertEqual(pixel(attached[0], column, x, y + row * 128), pixel(pixels, cell, x, y))
        self.assertNotEqual(pixel(gemmed[0], 1, 6, 64), pixel(gemmed[0], 2, 6, 64), "blue and purple share the same halo")

    def test_every_shipped_texture_fits_the_native_device_size_gate(self):
        manifest = json.loads((ROOT / "packaging/runtime-files.json").read_text())
        for name in manifest["files"]:
            if not name.endswith(".blp"):
                continue
            with self.subTest(texture=name):
                header = (ROOT / name).read_bytes()[:148]
                self.assertEqual(header[:4], b"BLP2")
                for dimension in struct.unpack_from("<II", header, 12):
                    self.assertGreaterEqual(dimension, 8)
                    self.assertLessEqual(dimension, 512)
                    self.assertEqual(dimension & (dimension - 1), 0)

    def test_jewelry_rail_keeps_lower_arches_without_old_upper_circle(self):
        names = ["SocketRail.blp", "SocketRail_2.blp", "SocketRail_3.blp"]
        strips = [blp_bgra_levels((ROOT / "media/tex/jewelry" / name).read_bytes())[2][0] for name in names]

        def alpha(x, y):
            strip, local_x = divmod(x, 400)
            return strips[strip][(y * 512 + local_x + 1) * 4 + 3]

        for y in range(104):
            self.assertFalse(any(alpha(x, y) for x in range(1200)), "old socket arch remains above the bar")
        self.assertTrue(any(alpha(212, y) for y in range(104, 134)), "small lower connector was removed")
        for start in (184, 352, 520, 688, 856):
            for y in range(104, 120):
                self.assertFalse(any(alpha(start + x, y) for x in range(24)), "left crop tab remains exposed")
                self.assertFalse(any(alpha(start + 159 - x, y) for x in range(24)), "right crop tab remains exposed")
        # The new upper connector starts beneath solid housing pixels.
        width, _, housing = blp_bgra_levels((ROOT / "media/tex/jewelry/Frame.blp").read_bytes())
        self.assertGreaterEqual(housing[0][(85 * width + 256 + 25) * 4 + 3], 224)
        for center in (264, 432, 600, 768, 936):
            self.assertFalse(any(alpha(center, y) for y in range(104, 134)), "bar crosses an item opening")
        self.assertTrue(any(alpha(348, y) for y in range(104, 152)), "straight bar edge was removed")
        manifest = json.loads((ROOT / "packaging/runtime-files.json").read_text())
        self.assertNotIn("media/tex/jewelry/SocketDetached.blp", manifest["files"])

    def test_strip_joins_retain_both_neighbour_pixels_at_every_row(self):
        registry = (ROOT / "core/tally.lua").read_text()
        pairs = re.findall(r'textures = \{ "([^"]+)", "([^"]+)" \}', registry)
        self.assertEqual(len(pairs), 20, "both attachment modes of every tally style need strip coverage")
        joins = [("tally/" + left, "tally/" + right, 300) for left, right in pairs]
        joins.extend([
            ("jewelry/SocketRail.blp", "jewelry/SocketRail_2.blp", 400),
            ("jewelry/SocketRail_2.blp", "jewelry/SocketRail_3.blp", 400),
            ("guardians/Header.blp", "guardians/Header_2.blp", 280),
            ("editor/divider.blp", "editor/divider_2.blp", 315),
        ])
        for left_name, right_name, span in joins:
            with self.subTest(join=left_name):
                left_width, left_height, left = blp_bgra_levels((ROOT / "media/tex" / left_name).read_bytes())
                right_width, right_height, right = blp_bgra_levels((ROOT / "media/tex" / right_name).read_bytes())
                self.assertEqual((left_width, left_height), (right_width, right_height))
                for y in range(left_height):
                    offset = y * left_width * 4
                    self.assertEqual(left[0][offset + span * 4:offset + (span + 2) * 4], right[0][offset:offset + 8])

    def test_health_fill_has_a_full_range_power_of_two_canvas(self):
        width, height, levels = blp_bgra_levels((ROOT / "media/tex/unitframes/healthDF2Fill.blp").read_bytes())
        self.assertEqual((width, height), (128, 32))
        self.assertEqual(len(levels[0]), 128 * 32 * 4)


if __name__ == "__main__":
    unittest.main()
