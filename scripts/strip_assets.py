"""
Usage: python strip_assets.py <input_dir> <output_dir>

Scans input_dir recursively for .json files, collects their basenames,
then copies any sibling files with the same basename (but different extension)
to the mirrored path in output_dir.

Compatible with Windows, macOS, and Linux. Requires Python 3.7+.
"""

import sys
import shutil
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        print("Usage: python strip_assets.py <input_dir> <output_dir>")
        sys.exit(1)

    input_dir = Path(sys.argv[1]).resolve()
    output_dir = Path(sys.argv[2]).resolve()

    if not input_dir.is_dir():
        print("Error: input dir not found: {}".format(input_dir))
        sys.exit(1)

    if output_dir.exists() and not output_dir.is_dir():
        output_dir.unlink()

    # Step 1: collect all basenames (without extension) that have a .json file,
    # keyed by (relative_parent, stem) so paths in different subdirs don't collide.
    # Stems are lowercased for case-insensitive matching on Windows.
    json_keys = set()  # set of (Path, str) tuples

    for json_file in input_dir.rglob("*.json"):
        rel_parent = json_file.parent.relative_to(input_dir)
        json_keys.add((rel_parent, json_file.stem.lower()))

    if not json_keys:
        print("WARNING: No .json files found in input — copying all files (json strip skipped).")
        copied = 0
        for src in input_dir.rglob("*"):
            if not src.is_file():
                continue
            rel = src.relative_to(input_dir)
            dest = output_dir / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest)
            copied += 1
        print("\nDone. {} file(s) copied to '{}'.".format(copied, output_dir))
        return

    print("Found {} unique JSON basename(s). Scanning for matching files...".format(len(json_keys)))

    # Step 2: walk every file in input_dir; copy those whose (rel_parent, stem)
    # matches a JSON key, skipping the .json files themselves.
    copied = 0
    for src in input_dir.rglob("*"):
        if not src.is_file():
            continue
        if src.suffix.lower() == ".json":
            continue

        rel_parent = src.parent.relative_to(input_dir)
        if (rel_parent, src.stem.lower()) not in json_keys:
            continue

        dest = output_dir / rel_parent / src.name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        print("  Copied: {}  ->  {}".format(
            src.relative_to(input_dir), dest.relative_to(output_dir)
        ))
        copied += 1

    print("\nDone. {} file(s) copied to '{}'.".format(copied, output_dir))


if __name__ == "__main__":
    main()
