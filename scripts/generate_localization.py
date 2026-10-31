"""Prepare Lua text data from embedded JSON catalogs, without running the client.

Usage: python scripts/generate_localization.py --client PATH_TO_CLIENT
Use --refresh-spell-names-only for the separately pinned current icon aliases.
This is a data-generation tool, not a formatter, syntax check or runtime test.
"""
import argparse
import hashlib
import json
import mmap
import re
from pathlib import Path

from generate_spell_icons import lua_string

ROOT = Path(__file__).resolve().parents[1]
# Physical order of the reviewed embedded catalogs; TSV columns have their own
# named headers so an inserted native language cannot shift existing captions.
CODES = ["en", "pl", "cs", "de", "pt", "es", "fr", "ro", "tr", "ru", "uk", "zh", "ja", "ko"]
SOURCE_SHA256 = "22f7938eb4f99f2857dc091b1c57c147bd848eaabfeaa81e444c0a3393ca8150"
SPELL_NAMES_SHA256 = "80ac3217660a02020b3e09f1ce93bfaa6ba89abd9a9d62405b9f70114fd6d46c"
MARKS_KEYS = ("marks.gained", "marks.earned")
AFFIXES_SHA256 = "08f8c58d6967b94598c56b822a1e6b323a52924a299a6df70ef6055ca839b8cd"
AFFIX_WARNINGS_SHA256 = "5dd6819d836748ccf809ab76fe6509c9ee793e087939b5d036c430d835a14e63"
AFFIX_WARNING_KEYS = ("An Explosive Orb appears! Destroy it before it bursts!",)
AFFIX_KEYS = (
    "Bolstering", "Sanguine", "Explosive",
    "A death makes the enemies near it tougher and stronger, stacking.",
    "A slain elite leaves a pool that heals enemies standing in it.",
    "Orbs come out of the horde: only direct hits hurt them, so kill them before they burst.",
)


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


def spell_names(english, catalog):
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


def spell_names_block(names):
    if not names:
        return "        spellNames = {},\n"
    result = ["        spellNames = {"]
    for name, aliases in names.items():
        result.append("            [" + lua_string(name) + "] = { " + ", ".join(lua_string(alias) for alias in aliases) + " },")
    result.append("        },")
    return "\n".join(result) + "\n"


def refresh_spell_names(client, metadata):
    """Refresh only icon aliases from the reviewed current client, as data.

    Keep the separately sourced UI/native captions and effect templates intact.
    The shared pinned PE reader supplies the same fourteen catalogs as items.
    """
    from generate_loot_icons import Native

    catalogs = Native(client, SPELL_NAMES_SHA256).catalogs()
    output = ROOT / "localization/data.lua"
    source = output.read_text(encoding="utf-8")
    counts = {}

    def replace(match):
        code, body = match[1], match[2]
        if code not in catalogs or code in counts:
            raise ValueError("Review the runtime language sections before refreshing icon aliases.")
        body = re.sub(r"^        spellNames = \{(?:\},\n|\n.*?^        \},\n)", "", body, flags=re.MULTILINE | re.DOTALL)
        names = spell_names(catalogs["en"], catalogs[code])
        counts[code] = {"groups": len(names), "merged": sum(len(aliases) > 1 for aliases in names.values())}
        return "    " + code + " = {\n" + body + spell_names_block(names) + "    },"

    result = re.sub(r"^    (\w+) = \{\n(.*?)^    \},$", replace, source, flags=re.MULTILINE | re.DOTALL)
    if set(counts) != set(CODES):
        raise ValueError("Review the runtime language population before refreshing icon aliases.")
    output.write_text(result, encoding="utf-8")
    if metadata:
        metadata.write_text(json.dumps({"source_sha256": SPELL_NAMES_SHA256, "catalogs": counts}, indent=2) + "\n", encoding="utf-8")
    print("Prepared spell-name aliases for " + str(len(counts)) + " languages from client SHA-256 " + SPELL_NAMES_SHA256)


def refresh_native_templates(client, metadata, keys, fingerprint, subject):
    """Prepare reviewed native captions without replacing unrelated catalogs."""
    from generate_loot_icons import Native

    catalogs = Native(client, fingerprint).catalogs()
    output = ROOT / "localization/data.lua"
    source = output.read_text(encoding="utf-8")
    prepared = {}

    def replace(match):
        code, body = match[1], match[2]
        if code not in catalogs or code in prepared:
            raise ValueError("Review runtime languages before preparing " + subject + " captions.")
        values = {key: catalogs[code][key] for key in keys}
        prepared[code] = values

        def native_block(native):
            entries = native[1]
            for key in keys:
                entries = re.sub(r"^            \[" + re.escape(lua_string(key)) + r"\] = .*\n", "", entries, flags=re.MULTILINE)
            additions = "".join("            [" + lua_string(key) + "] = " + lua_string(value) + ",\n" for key, value in values.items())
            return "        native = {\n" + additions + entries + "        },"

        body, count = re.subn(r"^        native = \{\n(.*?)^        \},", native_block, body, count=1, flags=re.MULTILINE | re.DOTALL)
        if count != 1:
            raise ValueError("Missing native caption section for " + code)
        return "    " + code + " = {\n" + body + "    },"

    result = re.sub(r"^    (\w+) = \{\n(.*?)^    \},$", replace, source, flags=re.MULTILINE | re.DOTALL)
    if set(prepared) != set(CODES):
        raise ValueError("Review the fourteen-language " + subject + " catalog population.")
    output.write_text(result, encoding="utf-8")
    if metadata:
        metadata.write_text(json.dumps({"source_sha256": fingerprint, "catalogs": prepared}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Prepared " + subject + " templates for " + str(len(prepared)) + " languages from client SHA-256 " + fingerprint)


def refresh_marks(client, metadata):
    refresh_native_templates(client, metadata, MARKS_KEYS, SOURCE_SHA256, "marks")


def refresh_affixes(client, metadata):
    refresh_native_templates(client, metadata, AFFIX_KEYS, AFFIXES_SHA256, "affix")


def refresh_affix_warnings(client, metadata):
    refresh_native_templates(client, metadata, AFFIX_WARNING_KEYS, AFFIX_WARNINGS_SHA256, "affix warning")


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
        result.append(spell_names_block(spell_names(english, catalog)).rstrip("\n"))
        result.append("    },")
    result.append("}")
    (ROOT / "localization/data.lua").write_text("\n".join(result) + "\n", encoding="utf-8")
    print("Prepared " + str(len(CODES)) + " language catalogs from client SHA-256 " + fingerprint)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", type=Path, required=True)
    refresh = parser.add_mutually_exclusive_group()
    refresh.add_argument("--refresh-spell-names-only", action="store_true", help="Refresh icon aliases from the separately pinned client without replacing captions/effects.")
    refresh.add_argument("--refresh-marks-only", action="store_true", help="Refresh only the two native marks templates from the reviewed Heroic update.")
    refresh.add_argument("--refresh-affixes-only", action="store_true", help="Prepare the six reviewed native affix names/descriptions from 0.125.0.")
    refresh.add_argument("--refresh-affix-warnings-only", action="store_true", help="Prepare the reviewed native affix warning templates from 0.131.0.")
    parser.add_argument("--metadata", type=Path, help="Optional data-preparation receipt for a targeted refresh.")
    arguments = parser.parse_args()
    if arguments.refresh_affix_warnings_only:
        refresh_affix_warnings(arguments.client, arguments.metadata)
    elif arguments.refresh_affixes_only:
        refresh_affixes(arguments.client, arguments.metadata)
    elif arguments.refresh_marks_only:
        refresh_marks(arguments.client, arguments.metadata)
    elif arguments.refresh_spell_names_only:
        refresh_spell_names(arguments.client, arguments.metadata)
    else:
        generate(arguments.client)
