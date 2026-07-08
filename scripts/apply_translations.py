"""
Apply translations from CSV back into UAssetAPI JSON files.
Finds all TextPropertyData entries by $type anywhere in the JSON tree.
If Translation column is non-empty, uses it. Otherwise falls back to CultureInvariantString (raw text).
"""

import json, glob, csv, os, argparse

def load_translations(csv_path):
    """Load translations keyed by (File, Key).
    Uses Translation if non-empty, else falls back to CultureInvariantString."""
    translations = {}
    with open(csv_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            translation = row.get("Translation", "").strip()
            fallback = row.get("CultureInvariantString", "").strip()
            translations[(row["File"], row["Key"])] = translation if translation else fallback
    print(f"Loaded {len(translations)} translations from {csv_path}")
    return translations

def apply_to_file(filepath, input_dir, output_dir, translations):
    rel = os.path.relpath(filepath, input_dir)

    with open(filepath, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"  [ERR] Invalid JSON in {rel}: {e}")
            return 0

    count = 0

    def walk(obj):
        nonlocal count
        if isinstance(obj, dict):
            if (obj.get("$type", "").endswith("TextPropertyData, UAssetAPI")
                    and obj.get("CultureInvariantString") is not None):
                key = (rel, obj.get("Value", ""))
                if key in translations:
                    obj["CultureInvariantString"] = translations[key]
                    count += 1
            for v in obj.values():
                walk(v)
        elif isinstance(obj, list):
            for item in obj:
                walk(item)

    walk(data)

    if count > 0:
        out_path = os.path.join(output_dir, rel)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"  [{count} updated] {rel}")

    return count

def main():
    parser = argparse.ArgumentParser(description="Apply translated strings back into UAssetAPI JSON files")
    parser.add_argument("input", help="Folder with original UAssetAPI JSON files")
    parser.add_argument("csv", help="CSV file with Translation and CultureInvariantString columns")
    parser.add_argument("--output", "-o", default="translated", help="Output folder (default: translated/)")
    args = parser.parse_args()

    translations = load_translations(args.csv)

    files = glob.glob(os.path.join(args.input, "**", "*.json"), recursive=True)
    print(f"Found {len(files)} JSON files")

    total = 0
    for f in sorted(files):
        total += apply_to_file(f, args.input, args.output, translations)

    print(f"\nDone! Applied {total} translations. Output: {args.output}")

if __name__ == "__main__":
    main()
