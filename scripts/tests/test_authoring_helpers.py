"""CI-only synthetic authoring inputs; no client, network or artwork writes."""

import hashlib
import importlib
import io
from pathlib import Path
import struct
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import extract_meter_healing_icons
import generate_localization
import generate_loot_icons
import generate_spell_icons
from native_pe import PeImage
from prepare_client_textures import image_from_bytes


def pe_bytes():
    """Two separated virtual sections whose file bytes are adjacent."""
    raw = bytearray(0x240)
    raw[:2] = b"MZ"
    struct.pack_into("<I", raw, 0x3C, 0x80)
    raw[0x80:0x84] = b"PE\0\0"
    struct.pack_into("<H", raw, 0x86, 2)
    struct.pack_into("<H", raw, 0x94, 0xF0)
    struct.pack_into("<H", raw, 0x98, 0x20B)
    struct.pack_into("<Q", raw, 0xB0, 0x140000000)
    struct.pack_into("<4I", raw, 0x190, 0x20, 0x1000, 0x20, 0x200)
    struct.pack_into("<4I", raw, 0x1B8, 0x20, 0x2000, 0x20, 0x220)
    raw[0x200:0x220] = bytes(range(32))
    raw[0x220:0x240] = b"x" * 32
    return raw


class PeReaderTests(unittest.TestCase):
    def test_virtual_mapping_and_complete_span_boundaries(self):
        image = PeImage(pe_bytes())
        self.assertEqual(image.offset(0x140001005), 0x205)
        self.assertEqual(image.read(0x14000101E, 2), b"\x1e\x1f")
        self.assertEqual(image.read(0x140002000, 4), b"xxxx")
        self.assertEqual(image.read(0x140001000, 0), b"")
        for address, length in ((0x14000101E, 3), (0x140001020, 1), (0x140001100, 1), (0x140001000, -1)):
            with self.subTest(address=address, length=length), self.assertRaises(ValueError):
                image.read(address, length)

    def test_truncated_headers_and_file_backing_are_rejected(self):
        raw = pe_bytes()
        for end in (0, 0x3F, 0x98, 0x1C0):
            with self.subTest(end=end), self.assertRaises(ValueError):
                PeImage(raw[:end])
        image = PeImage(raw[:-1])
        with self.assertRaises(ValueError):
            image.read(0x14000201E, 2)
        with self.assertRaises(ValueError):
            image.number(-1, "I")

    def test_wrong_container_signatures_are_rejected(self):
        for offset, value in ((0, b"NO"), (0x80, b"BAD!"), (0x98, b"\x0b\x01")):
            raw = pe_bytes()
            raw[offset:offset + len(value)] = value
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                PeImage(raw)

    def test_loot_reader_retains_string_limits_and_shared_mapping(self):
        raw = pe_bytes()
        text = "Žluťoučký".encode("utf-8")
        struct.pack_into("<QQ", raw, 0x200, 0x140002000, len(text))
        raw[0x220:0x220 + len(text)] = text
        path = SimpleNamespace(read_bytes=lambda: bytes(raw))
        native = generate_loot_icons.Native(path, hashlib.sha256(raw).hexdigest())
        self.assertEqual(native.text(0x200), "Žluťoučký")
        self.assertEqual(native.offset(0x140002000), 0x220)
        self.assertEqual(native.number(0x200), 0x140002000)
        for address, length in ((0x14000201F, 2), (0x140002000, 0), (0x140002000, 1024)):
            struct.pack_into("<QQ", raw, 0x200, address, length)
            native = generate_loot_icons.Native(path, hashlib.sha256(raw).hexdigest())
            with self.subTest(address=address, length=length), self.assertRaises(ValueError):
                native.text(0x200)

    def test_build_fingerprints_are_checked_before_container_parsing(self):
        path = SimpleNamespace(read_bytes=lambda: b"unreviewed client")
        with patch.object(generate_loot_icons, "PeImage") as reader:
            with self.assertRaisesRegex(ValueError, "executable"):
                generate_loot_icons.Native(path)
            reader.assert_not_called()
        with patch.object(extract_meter_healing_icons, "PeImage") as reader:
            with self.assertRaisesRegex(ValueError, "executable"):
                extract_meter_healing_icons.extract(path)
            reader.assert_not_called()


def blp_bytes(encoding, alpha_bits, payload):
    header = bytearray(1172)
    struct.pack_into("<4sI4BII", header, 0, b"BLP2", 1, encoding, alpha_bits, 0, 0, 2, 1)
    struct.pack_into("<I", header, 20, 1172)
    struct.pack_into("<I", header, 84, len(payload))
    header[148:156] = b"\x10\x20\x30\x00\x40\x50\x60\x00"
    return bytes(header) + payload


class ArtworkReaderTests(unittest.TestCase):
    def setUp(self):
        self.image = SimpleNamespace(frombytes=Mock(), open=Mock())
        self.pillow = patch.dict(sys.modules, {"PIL": SimpleNamespace(Image=self.image, ImageDraw=Mock())})
        self.pillow.start()
        self.addCleanup(self.pillow.stop)

    def assert_pixels(self, data, pixels):
        self.assertIs(image_from_bytes(data), self.image.frombytes.return_value)
        self.image.frombytes.assert_called_with("RGBA", (2, 1), pixels, "raw", "BGRA")
        self.image.open.assert_not_called()

    def test_raw3_preserves_rgb_even_under_zero_alpha(self):
        pixels = b"\x10\x20\x30\x00\x40\x50\x60\x7f"
        self.assert_pixels(blp_bytes(3, 8, pixels), pixels)

    def test_raw1_uses_the_separate_alpha_block_at_each_precision(self):
        for bits, alpha, expected in (
            (0, b"", b"\xff\xff"),
            (1, b"\x02", b"\x00\xff"),
            (4, b"\xf0", b"\x00\xff"),
            (8, b"\x00\x7f", b"\x00\x7f"),
        ):
            with self.subTest(bits=bits):
                pixels = b"\x10\x20\x30" + expected[:1] + b"\x40\x50\x60" + expected[1:]
                self.assert_pixels(blp_bytes(1, bits, b"\x00\x01" + alpha), pixels)

    def test_other_formats_keep_the_pillow_fallback(self):
        for data in (b"\x89PNG\r\n", blp_bytes(2, 8, b"DXT input")):
            with self.subTest(data=data[:9]):
                self.assertIs(image_from_bytes(data), self.image.open.return_value.convert.return_value)
                self.assertEqual(self.image.open.call_args.args[0].getvalue(), data)
                self.image.open.return_value.convert.assert_called_with("RGBA")
        self.image.frombytes.assert_not_called()

    def test_current_download_and_file_loaders_use_the_same_decoder(self):
        character = importlib.import_module("prepare_character_art")
        jewelry = importlib.import_module("prepare_jewelry_art")
        data = blp_bytes(1, 8, b"\x00\x01\x00\x7f")
        with patch.object(character.urllib.request, "urlopen", return_value=io.BytesIO(data)) as download:
            character.source("https://example.invalid/", "pinned.blp")
        download.assert_called_once_with("https://example.invalid/pinned.blp", timeout=60)
        jewelry.rgba(SimpleNamespace(read_bytes=lambda: data))
        self.assertEqual(self.image.frombytes.call_count, 2)
        self.image.frombytes.assert_called_with("RGBA", (2, 1), b"\x10\x20\x30\x00\x40\x50\x60\x7f", "raw", "BGRA")
        self.image.open.assert_not_called()


class LuaStringTests(unittest.TestCase):
    def test_generators_keep_utf8_quotes_and_control_bytes(self):
        cases = (
            ("Žluťoučký", '"Žluťoučký"'),
            ('"name"', "'\"name\"'"),
            ("C:\\art", r'"C:\\art"'),
            ("line\n\t\r\x00\x1b\x7f9", r'"line\010\009\013\000\027\1279"'),
        )
        for generator in (generate_localization, generate_spell_icons, generate_loot_icons):
            for text, expected in cases:
                with self.subTest(generator=generator.__name__, text=repr(text)):
                    self.assertEqual(generator.lua_string(text), expected)


if __name__ == "__main__":
    unittest.main()
