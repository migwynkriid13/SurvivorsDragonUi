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
# Physical order of the reviewed embedded catalogs; TSV columns have their own
# named headers so an inserted native language cannot shift existing captions.
CODES = ["en", "pl", "cs", "de", "pt", "es", "fr", "ro", "tr", "ru", "uk", "zh", "ja", "ko"]
SOURCE_SHA256 = "6382e9ae654295293b82d48fb07a1aa999132775bda10c6c6f80d973d2c1ddfb"


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t") + '"'


def translations(path, numbered=False):
    lines = path.read_text(encoding="utf-8").splitlines()
    columns = lines[0].split("\t")[1:]
    if len(columns) != len(set(columns)) or set(columns) != set(CODES) - {"en"}:
        raise ValueError("Review the language columns in " + str(path))
    result = {}
    for line in lines:
        if not line or line.startswith("#"):
            continue
        row = line.split("\t")
        if len(row) != len(columns) + 1 or not all(row):
            raise ValueError("Each row needs a translation for every language: " + row[0])
        key = int(row[0]) if numbered else row[0]
        if key in result:
            raise ValueError("Duplicate translation row: " + row[0])
        result[key] = dict(zip(columns, row[1:]))
    return result


def icon_name(literal):
    """Read a quoted name from generated Lua metadata, without executing Lua."""
    result, cursor = [], 1
    escapes = {"a": "\a", "b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t", "v": "\v"}
    while cursor < len(literal) - 1:
        character = literal[cursor]
        cursor += 1
        if character == "\\":
            character = literal[cursor]
            cursor += 1
            if character.isascii() and character.isdigit():
                digits = character
                while cursor < len(literal) - 1 and len(digits) < 3 and literal[cursor] in "0123456789":
                    digits += literal[cursor]
                    cursor += 1
                character = chr(int(digits))
            elif character in "\\\"'":
                pass
            elif character in escapes:
                character = escapes[character]
            else:
                raise ValueError("Review the generated icon name escape: " + literal)
        result.append(character)
    return "".join(result)


def czech_spell_names(english, catalog):
    """Alias only official ability names and already verified custom talents."""
    source = (ROOT / "modules/nameplates/icons.lua").read_text(encoding="utf-8")
    block = re.search(r"^    game = \{\n(.*?)^    \},", source, re.MULTILINE | re.DOTALL)
    if not block:
        raise ValueError("Review the generated custom talent icon catalog.")
    literals = re.findall(r"^\s*\[((?:\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*'))\]\s*=", block[1], re.MULTILINE)
    talent_names = {icon_name(literal) for literal in literals}
    keys = {key for key in english if re.match(r"^ability\.[^.]+\.name$", key)}
    keys.update(name for name in talent_names if english.get(name) == name)
    groups = {}
    for key in sorted(keys):
        name, localized = english[key], catalog[key]
        groups.setdefault(localized, set()).add(name)
    # Exact English names already resolve directly. Keep an identity candidate
    # when another canonical name shares it, so its icon cannot hide a conflict.
    return {name: sorted(aliases) for name, aliases in sorted(groups.items()) if aliases != {name}}


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
    ui = translations(ROOT / "localization/ui.tsv")
    compact = translations(ROOT / "localization/effects.tsv", numbered=True)
    required = json.loads((ROOT / "localization/native-keys.json").read_text(encoding="utf-8"))
    identity = [key for key in english if re.match(r"^(class|race|zone)\.[^.]+\.(name|subtitle)$", key)]
    result = ["-- Generated text data; preparation and source fingerprint: docs/LOCALIZATION.md.", "DFRL.locale.data = {"]
    for code, catalog in zip(CODES, catalogs):
        result.extend(["    " + code + " = {", "        ui = {"])
        for source, localized in ui.items():
            value = source if code == "en" else localized[code]
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
            if code == "en":
                output = rule[1]
            elif number in compact:
                output = compact[number][code]
            else:
                output = catalog[rule[2]]
                if number in (40, 42):
                    output = output.replace("{n}", "1")
            if set(re.findall(r"\{(\w+)\}", source)) != set(re.findall(r"\{(\w+)\}", output)):
                raise ValueError("Review changed native value fields for " + code + " effect " + str(number))
            result.append("            { " + lua_string(source) + ", " + lua_string(output) + " },")
        result.extend(["        },", "        caps = { " + lua_string(catalog[" (max)"]) + ", " + lua_string(catalog["{mods} (max)"].replace("{mods}", "")) + " },", "        rate = " + lua_string(catalog[", at most {n} times a second"]) + ","])
        if code == "cs":
            result.append("        spellNames = {")
            for name, aliases in czech_spell_names(english, catalog).items():
                result.append("            [" + lua_string(name) + "] = { " + ", ".join(lua_string(alias) for alias in aliases) + " },")
            result.append("        },")
        result.append("    },")
    result.append("}")
    (ROOT / "localization/data.lua").write_text("\n".join(result) + "\n", encoding="utf-8")
    print("Prepared " + str(len(CODES)) + " language catalogs from client SHA-256 " + fingerprint)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", type=Path, required=True)
    generate(parser.parse_args().client)
