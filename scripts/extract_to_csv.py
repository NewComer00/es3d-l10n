"""
Extract subtitle strings from UAssetAPI JSON files into a CSV.
Finds all TextPropertyData entries with CultureInvariantString anywhere in the JSON tree.
Columns: File, Key, CultureInvariantString, Translation
"""

import json, glob, csv, os, argparse, re


def natural_sort_key(s):
    """Split string into text and numeric chunks for natural ordering."""
    return [int(c) if c.isdigit() else c.lower() for c in re.split(r'(\d+)', s)]


def load_existing_entries(csv_path):
    """Load existing entries from CSV file if it exists."""
    existing = set()
    if os.path.exists(csv_path):
        with open(csv_path, 'r', encoding='utf-8-sig') as f:
            reader = csv.DictReader(f)
            for row in reader:
                key = (row.get("File", ""), row.get("Key", ""), row.get("CultureInvariantString", ""))
                existing.add(key)
    return existing


def extract_from_file(filepath, input_dir, rows, existing_entries):
    with open(filepath, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError:
            return

    rel = os.path.relpath(filepath, input_dir)

    def walk(obj):
        if isinstance(obj, dict):
            if (obj.get("$type", "").endswith("TextPropertyData, UAssetAPI")
                    and obj.get("CultureInvariantString")):
                file_key = rel
                value_key = obj.get("Value", "")
                string_key = obj["CultureInvariantString"]
                
                # Check if this entry already exists in the CSV
                entry_key = (file_key, value_key, string_key)
                if entry_key not in existing_entries:
                    rows.append({
                        "File": file_key,
                        "Key": value_key,
                        "CultureInvariantString": string_key,
                        "Translation": "",
                    })
                    # Add to existing entries to avoid duplicates in current run
                    existing_entries.add(entry_key)
                    
            for v in obj.values():
                walk(v)
        elif isinstance(obj, list):
            for item in obj:
                walk(item)

    walk(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input", help="Folder with UAssetAPI JSON files")
    parser.add_argument("--output", "-o", default="subtitles.csv")
    parser.add_argument("--natural-sort", "-n", action="store_true",
                        help="Sort files using natural order (e.g. file2 before file10)")
    parser.add_argument("--skip-existing", "-s", action="store_true",
                        help="Skip entries that already exist in the output CSV")
    args = parser.parse_args()

    files = glob.glob(os.path.join(args.input, "**", "*.json"), recursive=True)
    print(f"Found {len(files)} JSON files")

    if args.natural_sort:
        files = sorted(files, key=natural_sort_key)
    else:
        files = sorted(files)

    # Load existing entries if skip-existing is enabled
    existing_entries = set()
    if args.skip_existing:
        existing_entries = load_existing_entries(args.output)
        print(f"Found {len(existing_entries)} existing entries in {args.output}")

    rows = []
    for f in files:
        extract_from_file(f, args.input, rows, existing_entries)

    # Write to CSV
    if rows or not os.path.exists(args.output):
        mode = 'w' if not (args.skip_existing and os.path.exists(args.output)) else 'a'
        write_header = mode == 'w'
        
        with open(args.output, mode, encoding='utf-8-sig', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=["File", "Key", "CultureInvariantString", "Translation"])
            if write_header:
                writer.writeheader()
            writer.writerows(rows)
        
        action = "appended" if mode == 'a' else "written"
        print(f"Extracted {len(rows)} new strings and {action} to {args.output}")
    else:
        print(f"No new strings found. {args.output} remains unchanged.")

if __name__ == "__main__":
    main()
