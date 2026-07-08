"""
Compare archive (mods/.../locale.csv) vs active (build/.../locale.csv).

Rows are keyed by (File, Key). Reports counts and changed translations,
then optionally opens a side-by-side diff in cursor, code, or codium.
"""

import argparse
import csv
import os
import shutil
import subprocess
import sys
from pathlib import Path


def load_rows(path: Path) -> dict[tuple[str, str], dict[str, str]]:
    rows: dict[tuple[str, str], dict[str, str]] = {}
    with path.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            key = (row.get("File", ""), row.get("Key", ""))
            rows[key] = {
                "source": row.get("CultureInvariantString", ""),
                "translation": row.get("Translation", ""),
            }
    return rows


def find_editor() -> str | None:
    override = os.environ.get("ES3D_DIFF", "").strip()
    candidates = []
    if override:
        candidates.extend(name.strip() for name in override.split(",") if name.strip())
    candidates.extend(("cursor", "code", "codium"))
    seen = set()
    for name in candidates:
        if name in seen:
            continue
        seen.add(name)
        path = shutil.which(name)
        if path:
            return path
    return None


def open_in_editor(editor: str, left: Path, right: Path) -> bool:
    left_s = str(left.resolve())
    right_s = str(right.resolve())
    args = [editor, "--diff", left_s, right_s]
    try:
        if os.name == "nt" and editor.lower().endswith((".cmd", ".bat")):
            subprocess.Popen(["cmd", "/c", *args])
        else:
            subprocess.Popen(args)
        return True
    except OSError as exc:
        print(f"WARNING: could not launch {editor}: {exc}", file=sys.stderr)
        return False


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Diff archive vs active locale CSV (mods vs build)"
    )
    parser.add_argument("archive", help="Archive CSV (mods/.../locale.csv)")
    parser.add_argument("active", help="Active CSV (build/.../locale.csv)")
    parser.add_argument(
        "--open",
        action="store_true",
        help="Open side-by-side diff in cursor/code/codium when available",
    )
    parser.add_argument(
        "--no-open",
        action="store_true",
        help="Print summary only; do not launch an editor",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=20,
        help="Max changed rows to print (default: 20, 0 = no limit)",
    )
    args = parser.parse_args()

    archive = Path(args.archive).resolve()
    active = Path(args.active).resolve()

    if not archive.is_file():
        print(f"ERROR: archive not found: {archive}", file=sys.stderr)
        return 1
    if not active.is_file():
        print(f"ERROR: active CSV not found: {active}", file=sys.stderr)
        print("Hint: just mod-locale MOD LOCALE seed-locale", file=sys.stderr)
        return 1

    archive_rows = load_rows(archive)
    active_rows = load_rows(active)

    archive_keys = set(archive_rows)
    active_keys = set(active_rows)

    only_archive = archive_keys - active_keys
    only_active = active_keys - archive_keys
    shared = archive_keys & active_keys

    changed = []
    same = 0
    for key in sorted(shared):
        a = archive_rows[key]
        b = active_rows[key]
        if a["translation"] != b["translation"] or a["source"] != b["source"]:
            changed.append((key, a, b))
        else:
            same += 1

    print(f"Archive: {archive}")
    print(f"Active:  {active}")
    print()
    print(f"  archive rows:  {len(archive_rows)}")
    print(f"  active rows:   {len(active_rows)}")
    print(f"  unchanged:     {same}")
    print(f"  changed:       {len(changed)}")
    print(f"  only archive:  {len(only_archive)}")
    print(f"  only active:   {len(only_active)}")

    if changed:
        print()
        limit = len(changed) if args.limit == 0 else min(args.limit, len(changed))
        print(f"Changed rows (showing {limit}/{len(changed)}):")
        for (file_, key), a, b in changed[:limit]:
            label = file_.replace("\\", "/")
            if a["translation"] != b["translation"]:
                print(f"  {label}  [{key}]")
                print(f"    archive: {a['translation']!r}")
                print(f"    active:  {b['translation']!r}")
            elif a["source"] != b["source"]:
                print(f"  {label}  [{key}]  (source text differs)")

        if limit < len(changed):
            print(f"  ... and {len(changed) - limit} more")

    if only_archive:
        print()
        print(f"Only in archive ({len(only_archive)} rows) — first 5:")
        for key in sorted(only_archive)[:5]:
            print(f"  {key[0]}  [{key[1]}]")

    if only_active:
        print()
        print(f"Only in active ({len(only_active)} rows) — first 5:")
        for key in sorted(only_active)[:5]:
            print(f"  {key[0]}  [{key[1]}]")

    if args.open and not args.no_open:
        editor = find_editor()
        if editor:
            print()
            print(f"Opening diff in {Path(editor).name}...")
            if not open_in_editor(editor, archive, active):
                print("Diff summary printed above.")
        else:
            print()
            print("No editor CLI found (tried cursor, code, codium).")
            print("Set ES3D_DIFF=cursor or run with --no-open.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
