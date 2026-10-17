"""Prepare Lua text data from embedded JSON catalogs, without running the client.

Usage: python scripts/generate_localization.py --client PATH_TO_CLIENT
This is a data-generation tool, not a formatter, syntax check or runtime test.
"""
import argparse
import hashlib
import json
import mmap
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CODES = ["en", "pl", "de", "pt", "es", "fr", "ro", "tr", "ru", "uk", "zh", "ja", "ko"]
SOURCE_SHA256 = "2149da82c8e6e1096cdd7d600c60a2b7d763a6969bae425323db9ebbe6e56a4e"


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") + '"'


def generate(client):
    catalogs, seen = [], set()
    with client.open("rb") as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
        cursor, needle = 0, b'"Increases your luck by {p}."'
        while True:
            hit = data.find(needle, cursor)
            if hit < 0:
                break
            cursor = hit + len(needle)
            start = data.rfind(b'{\n', max(0, hit - 2_000_000), hit)
            if start < 0 or start in seen:
                continue
            try:
                catalog, _ = json.JSONDecoder().raw_decode(data[start:start + 2_000_000].decode("utf-8"))
            except (ValueError, UnicodeError):
                # Bytes after the complete JSON can belong to a binary section.
                catalog, _ = json.JSONDecoder().raw_decode(data[start:start + 2_000_000].decode("utf-8", errors="replace"))
            if isinstance(catalog, dict) and "Increases your luck by {p}." in catalog:
                catalogs.append(catalog)
                seen.add(start)
        fingerprint = hashlib.sha256(data).hexdigest()
    if fingerprint != SOURCE_SHA256:
        raise ValueError("Review the new client catalogs and their language order before updating SOURCE_SHA256.")
    if len(catalogs) != len(CODES):
        raise ValueError("Review the native catalog layout before generating another client build.")
    english = catalogs[0]
    english_values = {value: key for key, value in english.items()}
    rules = json.loads((ROOT / "localization/effects.json").read_text(encoding="utf-8"))
    rows = [line.split("\t") for line in (ROOT / "localization/ui.tsv").read_text(encoding="utf-8").splitlines() if line and not line.startswith("#")]
    overrides = [line.split("\t") for line in (ROOT / "localization/effects.tsv").read_text(encoding="utf-8").splitlines() if line and not line.startswith("#")]
    ui = {row[0]: row[1:] for row in rows}
    compact = {int(row[0]): row[1:] for row in overrides}
    required = json.loads((ROOT / "localization/native-keys.json").read_text(encoding="utf-8"))
    identity = [key for key in english if re.match(r"^(class|race|zone)\.[^.]+\.(name|subtitle)$", key)]
    result = ["-- Generated text data; preparation and source fingerprint: docs/LOCALIZATION.md.", "DFRL.locale.data = {"]
    for index, (code, catalog) in enumerate(zip(CODES, catalogs)):
        result.extend(["    " + code + " = {", "        ui = {"])
        for source, translations in ui.items():
            if len(translations) != len(CODES) - 1:
                raise ValueError("Each addon caption needs all twelve translations: " + source)
            value = source if index == 0 else translations[index - 1]
            if value.startswith("@"):
                value = catalog[value[1:]]
            result.append("            [" + lua_string(source) + "] = " + lua_string(value) + ",")
        # Native captions are shared by value only when no addon-specific row exists.
        for source, key in sorted(english_values.items()):
            if source not in ui and key in required:
                result.append("            [" + lua_string(source) + "] = " + lua_string(catalog[key]) + ",")
        result.extend(["        },", "        native = {"])
        for key in sorted(set(required + identity)):
            result.append("            [" + lua_string(key) + "] = " + lua_string(catalog[key]) + ",")
        result.extend(["        },", "        effects = {"])
        for number, rule in enumerate(rules, 1):
            source = catalog[rule[0]]
            if index == 0:
                output = rule[1]
            elif number in compact:
                if len(compact[number]) != len(CODES) - 1:
                    raise ValueError("Each effect override needs twelve translations.")
                output = compact[number][index - 1]
            else:
                output = catalog[rule[2]]
                if number in (40, 42):
                    output = output.replace("{n}", "1")
            if set(re.findall(r"\{(\w+)\}", source)) != set(re.findall(r"\{(\w+)\}", output)):
                raise ValueError("Review changed native value fields for " + code + " effect " + str(number))
            result.append("            { " + lua_string(source) + ", " + lua_string(output) + " },")
        result.extend(["        },", "        caps = { " + lua_string(catalog[" (max)"]) + ", " + lua_string(catalog["{mods} (max)"].replace("{mods}", "")) + " },", "        rate = " + lua_string(catalog[", at most {n} times a second"]) + ",", "    },"])
    result.append("}")
    (ROOT / "localization/data.lua").write_text("\n".join(result) + "\n", encoding="utf-8")
    print("Prepared thirteen language catalogs from client SHA-256 " + fingerprint)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", type=Path, required=True)
    generate(parser.parse_args().client)
