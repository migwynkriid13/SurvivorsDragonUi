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
    def test_empty_jewelry_housing_retains_the_original_input_and_exact_runtime_pixels(self):
        source = (ROOT / "media/tex/jewelry/Runecarver.tga").read_bytes()
        self.assertEqual(
            hashlib.sha256(source).hexdigest(),
            "b53931149f049507f2ac5a983340ffbf3c886cd691e083bee8d8c0690acc6b17",
        )
        converted, _ = blp_from_tga(source)
        source_width, source_height, source_levels = blp_bgra_levels(converted)
        width, height, levels = blp_bgra_levels((ROOT / "media/tex/jewelry/Frame.blp").read_bytes())
        self.assertEqual((source_width, source_height), (128, 128))
        self.assertEqual((width, height), (512, 128))
        empty, equipped = bytearray(), bytearray()
        for row in range(128):
            left = (row * width + 256) * 4
            empty.extend(levels[0][left:left + 128 * 4])
            left = (row * width + 384) * 4
            equipped.extend(levels[0][left:left + 128 * 4])
        self.assertEqual(empty, source_levels[0], "empty slots received equipped brightness or another crop")
        self.assertEqual(empty[3::4], equipped[3::4], "housing variants changed coverage")
        self.assertNotEqual(empty, equipped, "equipped housing lost its separate brightness treatment")

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
