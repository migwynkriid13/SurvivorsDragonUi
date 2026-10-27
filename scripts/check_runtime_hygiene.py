"""CI-only package, source and artwork inventory. Never execute addon Lua."""

import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import zipfile

from package import ADDON_DIRECTORY, SOURCE, runtime_files


REPORTS = SOURCE / "dist/pr-quality"
TEXTURES = "media/tex/"


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=SOURCE)


def parse_sources(sources):
    result = subprocess.run(
        ["node", str(SOURCE / "scripts/lua_inventory.cjs")],
        input=json.dumps(sources), text=True, capture_output=True, check=True,
    )
    return json.loads(result.stdout)


def normalized(value):
    return value.replace("\\", "/")


def check_assets(files, tracked, inventory, rules):
    """Require literal evidence in loaded Lua, with explicit dynamic families.

    This is a syntactic ownership check, not a claim that a path is reachable.
    A comment, document or manifest entry alone cannot keep a texture alive.
    """
    failures = []
    used = {name: [] for name in sorted(files) if name.endswith(".blp")}
    values = {name: {row["value"] for row in data["strings"]} for name, data in inventory.items()}

    def reference(name, source, line):
        if name not in used:
            failures.append(f"{source}:{line}: missing packaged texture {name}")
        else:
            used[name].append(f"{source}:{line}")

    for source, data in inventory.items():
        roots = set()
        for value in values[source]:
            value = normalized(value)
            if value.lower().startswith("interface/"):
                continue  # Client-owned textures are not addon package inputs.
            if re.fullmatch(r"[A-Za-z][A-Za-z0-9_/-]*/", value):
                roots.add(TEXTURES + value.rstrip("/"))
            elif "/" in value and value.endswith(".blp"):
                roots.add(TEXTURES + str(PurePosixPath(value).parent))
        data_rule = rules["data_roots"].get(source)
        if data_rule:
            consumer = inventory.get(data_rule["consumer"], {})
            if not any(row["name"] == data_rule["member"] for row in consumer.get("reads", [])):
                failures.append(f"{source}: stale data owner {data_rule['consumer']}:{data_rule['member']}")
            roots.add(TEXTURES + data_rule["root"])
        dynamic = rules["dynamic_roots"].get(source)
        if dynamic is not None:
            # Do not let an obsolete directory rule keep an asset family alive.
            if dynamic and dynamic + "\\" not in values[source]:
                failures.append(f"{source}: stale dynamic root {dynamic}")
        for row in data["strings"]:
            value, line = normalized(row["value"]), row["line"]
            if value.lower().startswith("interface/"):
                continue
            if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_./-]*\.blp", value):
                if "/" in value:
                    reference(TEXTURES + value, source, line)
                else:
                    candidates = {root + "/" + value for root in roots} & used.keys()
                    if len(candidates) != 1:
                        failures.append(f"{source}:{line}: cannot resolve texture {value}; candidates={sorted(candidates)}")
                    else:
                        reference(candidates.pop(), source, line)
            elif dynamic is not None and re.fullmatch(r"[A-Za-z0-9_-][A-Za-z0-9_/-]*", value):
                candidate = TEXTURES + (dynamic + "/" if dynamic else "") + value + ".blp"
                if candidate in used:
                    reference(candidate, source, line)

    for source in rules["dynamic_roots"] | rules["data_roots"]:
        if source not in inventory:
            failures.append(f"Stale asset rule for unloaded source {source}")
    for family in rules["families"]:
        source, helper = family["source"], family["helper"]
        calls = inventory.get(source, {}).get("calls", [])
        definitions = inventory.get(helper, {}).get("definitions", [])
        valid = any(row["name"] == family["call"] for row in calls)
        valid = valid and any(row["name"] == family["definition"] for row in definitions)
        valid = valid and family["root"] + "\\" in values.get(helper, set())
        valid = valid and set(family["stems"]) <= values.get(source, set())
        valid = valid and set(family["suffixes"]) <= values.get(helper, set())
        if not valid:
            failures.append(f"Stale dynamic texture family {source} -> {helper}; review calls, stems and suffixes")
            continue
        call_line = next(row["line"] for row in calls if row["name"] == family["call"])
        for stem in family["stems"]:
            for suffix in family["suffixes"]:
                reference(TEXTURES + family["root"] + "/" + stem + suffix, source, call_line)

    for name, references in used.items():
        if not references:
            failures.append(f"{name}: no reference in loaded Lua; remove the asset and manifest entry or document its dynamic owner")
    for name in sorted(tracked):
        path = PurePosixPath(name)
        if path.suffix == ".lua" and name not in files and not name.startswith("scripts/tests/fixtures/"):
            failures.append(f"{name}: tracked addon Lua is not loaded by the TOC")
        if not name.startswith("media/") or name in files:
            continue
        if path.suffix.lower() == ".tga" and str(path.with_suffix(".blp")) in used:
            continue  # Original, full-resolution preparation input; never ship it.
        retained = rules["source_assets"].get(name)
        if retained and retained["output"] in used and retained["reason"].strip():
            continue
        failures.append(f"{name}: unclassified media; remove it or record its active preparation output and reason")
    for name, rule in rules["source_assets"].items():
        if name not in tracked or rule["output"] not in used or not rule["reason"].strip():
            failures.append(f"Stale preparation-source rule: {name}")
    return failures, used


def zip_bytes(payload):
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(payload.items()):
            info = zipfile.ZipInfo(ADDON_DIRECTORY + "/" + name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data, compresslevel=9)
    return output.getvalue()


def duplicate_groups(payload):
    groups = {}
    for name, data in payload.items():
        if PurePosixPath(name).suffix in {".blp", ".lua"}:
            groups.setdefault(hashlib.sha256(data).hexdigest(), []).append(name)
    return {digest: sorted(names) for digest, names in groups.items() if len(names) > 1}


def compare_payload(current, previous):
    duplicates, old_duplicates = duplicate_groups(current), duplicate_groups(previous)
    failures = []
    for digest, names in duplicates.items():
        if not set(names) <= set(old_duplicates.get(digest, [])):
            failures.append("New byte-identical runtime copies: " + ", ".join(names))
    rows = []
    for name in current.keys() | previous.keys():
        before, after = len(previous.get(name, b"")), len(current.get(name, b""))
        if current.get(name) != previous.get(name):
            rows.append({"file": name, "before": before, "after": after, "delta": after - before})
    rows.sort(key=lambda row: (-abs(row["delta"]), row["file"]))
    return failures, {
        "before_files": len(previous), "after_files": len(current),
        "before_bytes": sum(map(len, previous.values())),
        "after_bytes": sum(map(len, current.values())),
        "before_zip_bytes": len(zip_bytes(previous)), "after_zip_bytes": len(zip_bytes(current)),
        "changed_files": rows, "identical_runtime_files": duplicates,
    }


def main():
    REPORTS.mkdir(parents=True, exist_ok=True)
    failures = []
    try:
        files = set(runtime_files())
        tracked = set(git("ls-files", "-z").decode().rstrip("\0").split("\0"))
        for name in files:
            suffix = PurePosixPath(name).suffix
            if suffix not in {".lua", ".blp"} and name != ADDON_DIRECTORY + ".toc" and PurePosixPath(name).name != "LICENSE.txt":
                failures.append(f"Unexpected installable payload file: {name}")
        rules = json.loads((SOURCE / "packaging/asset-usage.json").read_text(encoding="utf-8"))
        if rules.get("format_version") != 1:
            raise ValueError("Unsupported asset-usage format")
        inventory = parse_sources({name: (SOURCE / name).read_text(encoding="utf-8") for name in sorted(files) if name.endswith(".lua")})
        asset_failures, used = check_assets(files, tracked, inventory, rules)
        failures.extend(asset_failures)
        (REPORTS / "asset-usage.json").write_text(json.dumps(used, indent=2) + "\n", encoding="utf-8")
        reads = {row["name"] for data in inventory.values() for row in data["reads"]}
        candidates = [{"file": name, **row} for name, data in inventory.items() for row in data["definitions"]
                      if row["name"] and row["name"].startswith("DFRL.") and row["name"] not in reads]
        (REPORTS / "export-candidates.json").write_text(json.dumps(candidates, indent=2) + "\n", encoding="utf-8")
        base_sha = os.environ["PR_BASE_SHA"]
        if not re.fullmatch(r"[0-9a-f]{40}", base_sha):
            raise ValueError("PR_BASE_SHA must be the event's full base commit SHA")
        base = git("merge-base", base_sha, "HEAD").decode().strip()
        old_manifest = json.loads(git("show", base + ":packaging/runtime-files.json"))
        previous = {name: git("show", base + ":" + name) for name in old_manifest["files"]}
        current = {name: (SOURCE / name).read_bytes() for name in files}
        duplicate_failures, size = compare_payload(current, previous)
        failures.extend(duplicate_failures)
        size["base_commit"] = base
        (REPORTS / "payload-size.json").write_text(json.dumps(size, indent=2) + "\n", encoding="utf-8")
        lines = ["## Runtime assets and package hygiene", "",
                 f"Files: {size['before_files']} -> {size['after_files']}. "
                 f"Uncompressed bytes: {size['before_bytes']} -> {size['after_bytes']}. "
                 f"Deterministic ZIP bytes: {size['before_zip_bytes']} -> {size['after_zip_bytes']}.", "",
                 "| Changed file | Before | After | Delta |", "| --- | ---: | ---: | ---: |"]
        lines.extend(f"| `{row['file']}` | {row['before']} | {row['after']} | {row['delta']:+} |" for row in size["changed_files"][:20])
        lines.extend(["", f"Exported helper candidates for manual review: {len(candidates)}. "
                      "Dynamic lookup and native callbacks can explain these; they are not automatic deletion findings.", "",
                      "All byte-identical runtime groups, including pre-existing copies, are in payload-size.json. "
                      "New copies fail; size growth is reported without an arbitrary size cap.", ""])
        report = "\n".join(lines)
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        detail = error.stderr if isinstance(error, subprocess.CalledProcessError) and error.stderr else str(error)
        failures.append(str(detail))
        report = "## Runtime assets and package hygiene\n\nInventory could not complete.\n"
    report += "\n" + ("\n".join("- " + message for message in failures) if failures else "Passed all runtime inventory checks.") + "\n"
    (REPORTS / "runtime-hygiene.log").write_text(report, encoding="utf-8")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
            output.write(report)
    print(report)
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())
