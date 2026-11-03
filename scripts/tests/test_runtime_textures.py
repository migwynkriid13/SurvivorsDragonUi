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

    def test_shared_jewelry_housing_retains_original_pixels_without_the_bright_variant(self):
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
        empty, retired = bytearray(), bytearray()
        for row in range(128):
            left = (row * width + 256) * 4
            empty.extend(levels[0][left:left + 128 * 4])
            left = (row * width + 384) * 4
            retired.extend(levels[0][left:left + 128 * 4])
        self.assertEqual(empty, source_levels[0], "empty slots received equipped brightness or another crop")
        self.assertFalse(any(retired), "retired bright housing and glow cell still contains pixels")

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
