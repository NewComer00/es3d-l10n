"""
Bidirectional batch converter between .uasset and UAssetAPI JSON using UAssetGUI.

Usage:
  uasset -> json:  python convert.py tojson   <input> <output> --uassetgui UAssetGUI.exe --version VER_UE5_3 [--usmap output.usmap] [--workers 4] [--skip-existing] [--exclude "pattern1" --exclude "pattern2"]
  json -> uasset:  python convert.py fromjson <input> <output> --uassetgui UAssetGUI.exe [--usmap output.usmap] [--workers 4] [--skip-existing] [--exclude "pattern1" --exclude "pattern2"]

Requirements:
  pip install psutil
"""

import os, glob, shutil, subprocess, argparse, time, threading, fnmatch
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    import psutil
except ImportError:
    psutil = None


# ─────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────

# Valid uexp file signatures (first 2 bytes)
DEFAULT_UEXP_SIGNATURES = [b'\x0d\x02']
DEFAULT_MAX_RETRIES     = 3
DEFAULT_RETRY_DELAY     = 0.5

# JSON validation strings (any match = valid)
DEFAULT_JSON_SIGNATURES = ["CultureInvariantString"]


# ─────────────────────────────────────────────
# Exclusion pattern matching (gitignore-style)
# ─────────────────────────────────────────────

def matches_exclude_patterns(filepath: str, patterns: list[str], base_dir: str) -> bool:
    """
    Check if a file matches any exclusion pattern.
    Supports gitignore-style globbing:
    - `*.tmp` matches any .tmp file
    - `**/folder/**` matches files in nested folder
    - `/absolute/path` matches from root
    - `!pattern` negates (un-excludes) a pattern

    Returns True if file should be excluded, False otherwise.
    """
    if not patterns:
        return False

    # Get relative path for matching
    rel_path = os.path.relpath(filepath, base_dir)
    filename = os.path.basename(filepath)

    excluded = False

    for pattern in patterns:
        # Handle negation patterns
        if pattern.startswith('!'):
            negate = True
            pattern = pattern[1:]
        else:
            negate = False

        # Normalize path separators
        pattern = pattern.replace('\\', '/')

        # Try matching against relative path
        if _match_pattern(rel_path.replace('\\', '/'), pattern):
            excluded = not negate
            continue

        # Try matching against just filename
        if _match_pattern(filename.replace('\\', '/'), pattern):
            excluded = not negate
            continue

        # Try matching against full path
        if _match_pattern(filepath.replace('\\', '/'), pattern):
            excluded = not negate
            continue

    return excluded


def _match_pattern(path: str, pattern: str) -> bool:
    """
    Match a path against a gitignore-style pattern.
    Handles **, *, ?, and character classes.
    """
    # Handle ** pattern (matches any number of directories)
    if '**' in pattern:
        # Split pattern by **
        parts = pattern.split('**')

        # Check if pattern starts with **
        if pattern.startswith('**/'):
            remaining = pattern[3:]
            # Check if any suffix of path matches remaining
            path_parts = path.split('/')
            for i in range(len(path_parts)):
                if fnmatch.fnmatch('/'.join(path_parts[i:]), remaining):
                    return True
            return False

        # Check if pattern ends with /**
        elif pattern.endswith('/**'):
            prefix = pattern[:-3]
            return fnmatch.fnmatch(path, prefix + '/*') or fnmatch.fnmatch(path, prefix)

        # Handle ** in the middle
        else:
            left, right = pattern.split('**', 1)
            # Match left part at start, right part at end
            path_parts = path.split('/')
            for i in range(len(path_parts) + 1):
                test_path = '/'.join(path_parts[:i] + ['']).rstrip('/') + right
                if fnmatch.fnmatch(path, left + test_path[len(left):]):
                    return True
            return fnmatch.fnmatch(path, pattern.replace('**', '*'))

    # Check if pattern contains a slash (directory-specific)
    if '/' in pattern:
        # Pattern with slash must match from the beginning
        if pattern.startswith('/'):
            # Absolute pattern - match from root of base_dir
            return fnmatch.fnmatch(path, pattern[1:])
        else:
            # Relative pattern with directory components
            return fnmatch.fnmatch(path, pattern)
    else:
        # Pattern without slash matches any directory
        return fnmatch.fnmatch(path, '*/*/' + pattern) or \
               fnmatch.fnmatch(path, '*/' + pattern) or \
               fnmatch.fnmatch(path, pattern)


# ─────────────────────────────────────────────
# Portable mode + mappings setup
# ─────────────────────────────────────────────

def ensure_portable(uassetgui: str, verbose: bool):
    gui_dir = os.path.dirname(os.path.abspath(uassetgui))
    data_dir = os.path.join(gui_dir, "Data")

    if os.path.isdir(data_dir):
        if verbose:
            print("[portable] Data/ already exists, skipping")
        return

    print("[portable] Data/ not found — initializing portable mode...")
    proc = subprocess.Popen(
        [uassetgui, "portable"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    deadline = time.time() + 15
    while time.time() < deadline:
        if os.path.isdir(data_dir):
            time.sleep(1.5)
            break
        time.sleep(0.2)

    try:
        proc.terminate()
        proc.wait(timeout=5)
    except Exception:
        proc.kill()

    if psutil:
        for p in psutil.process_iter(["name", "pid"]):
            if "UAssetGUI" in (p.info["name"] or ""):
                try:
                    p.kill()
                    if verbose:
                        print(f"[portable] Killed PID {p.info['pid']}")
                except Exception:
                    pass

    if os.path.isdir(data_dir):
        print("[portable] Data/ created successfully")
    else:
        print("[portable] WARNING: Data/ still not found after timeout")


def setup_mappings(uassetgui: str, usmap_path: str, verbose: bool) -> str:
    gui_dir = os.path.dirname(os.path.abspath(uassetgui))
    mappings_dir = os.path.join(gui_dir, "Data", "Mappings")
    os.makedirs(mappings_dir, exist_ok=True)

    usmap_name = os.path.basename(usmap_path)
    dst = os.path.join(mappings_dir, usmap_name)

    if not os.path.exists(dst) or os.path.getmtime(usmap_path) > os.path.getmtime(dst):
        shutil.copy2(usmap_path, dst)
        if verbose:
            print(f"[mappings] Copied {usmap_name} -> {mappings_dir}")
    else:
        if verbose:
            print(f"[mappings] {usmap_name} already up to date")

    return Path(usmap_name).stem


# ─────────────────────────────────────────────
# Validation
# ─────────────────────────────────────────────

def validate_uexp(uexp_path: str, signatures: list) -> bool:
    """
    Validate uexp file has correct header signature.
    Returns True if header is valid, False otherwise.
    """
    if not os.path.exists(uexp_path):
        return False

    try:
        with open(uexp_path, 'rb') as f:
            header = f.read(2)
        return header in signatures
    except Exception:
        return False


def validate_uasset(uasset_path: str, signatures: list) -> bool:
    """
    Validate uasset file exists and is not empty.
    Also checks corresponding uexp file if it exists.
    """
    if not os.path.exists(uasset_path):
        return False

    if os.path.getsize(uasset_path) == 0:
        return False

    # Check uexp if it exists (not all uassets have uexp)
    uexp_path = uasset_path[:-7] + '.uexp'  # .uasset -> .uexp
    if os.path.exists(uexp_path):
        if not validate_uexp(uexp_path, signatures):
            return False

    return True


def validate_json(json_path: str, json_signatures: list) -> bool:
    """
    Validate JSON file contains the required signature string.
    Reads the entire file to ensure the signature is present.
    Returns True if signature found, False otherwise.
    """
    if not os.path.exists(json_path):
        return False

    if os.path.getsize(json_path) == 0:
        return False

    try:
        # Read entire file to check for any signature anywhere in the JSON
        with open(json_path, 'r', encoding='utf-8') as f:
            file_content = f.read()
        return any(sig in file_content for sig in json_signatures)
    except MemoryError:
        # Fallback for extremely large files: read in chunks
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                chunk = f.read(1024 * 1024)  # 1MB chunks
                while chunk:
                    if any(sig in chunk for sig in json_signatures):
                        return True
                    chunk = f.read(1024 * 1024)
            return False
        except Exception:
            return False
    except Exception:
        return False


def should_skip_existing(dst: str, mode: str, cfg: dict) -> bool:
    """
    Check if target file exists, is non-zero size, and is valid.
    Returns True if file exists and appears valid, False otherwise.
    """
    if not os.path.exists(dst):
        return False

    if os.path.getsize(dst) == 0:
        return False

    # Additional validation based on mode
    if mode == "tojson":
        return validate_json(dst, cfg['json_signatures'])
    else:
        # For uasset, check the file and its uexp if present
        uexp_path = dst[:-7] + '.uexp'  # .uasset -> .uexp
        if os.path.exists(uexp_path):
            return validate_uexp(uexp_path, cfg['signatures'])
        return True  # If no uexp, just check uasset exists and is non-zero


# ─────────────────────────────────────────────
# Worker
# ─────────────────────────────────────────────

def convert_one(task):
    i, total, src, dst, cmd, verbose, print_lock, skip_existing, cfg = task
    os.makedirs(os.path.dirname(dst), exist_ok=True)

    max_retries    = cfg['max_retries']
    retry_delay    = cfg['retry_delay']
    signatures     = cfg['signatures']
    json_signatures = cfg['json_signatures']

    # Determine if this is tojson or fromjson mode
    is_tojson = cmd[1] == "tojson"
    mode = "tojson" if is_tojson else "fromjson"

    # Check skip-existing condition
    if skip_existing and should_skip_existing(dst, mode, cfg):
        with print_lock:
            print(f"[{i}/{total}] SKIP {os.path.basename(src)} (destination exists)")
        return True  # Count as success since destination is valid

    for attempt in range(1, max_retries + 1):
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

            # Check basic success
            if result.returncode != 0:
                err = result.stderr.strip() or result.stdout.strip() or "Unknown error"
                if attempt < max_retries:
                    with print_lock:
                        print(f"[{i}/{total}] RETRY {attempt}/{max_retries} {os.path.basename(src)}: {err}")
                    time.sleep(retry_delay)
                    continue
                else:
                    with print_lock:
                        print(f"[{i}/{total}] FAIL {os.path.basename(src)}: {err}")
                    return False

            # Validate output based on mode
            if is_tojson:
                # For tojson: validate JSON file contains required signature
                if not validate_json(dst, json_signatures):
                    if attempt < max_retries:
                        with print_lock:
                            print(f"[{i}/{total}] RETRY {attempt}/{max_retries} {os.path.basename(src)}: JSON missing any of {json_signatures}")
                        # Remove bad file before retry
                        if os.path.exists(dst):
                            os.remove(dst)
                        time.sleep(retry_delay)
                        continue
                    else:
                        with print_lock:
                            # Check if file exists and show size for debugging
                            status = "File missing" if not os.path.exists(dst) else f"File exists ({os.path.getsize(dst)} bytes) but missing signature"
                            print(f"[{i}/{total}] FAIL {os.path.basename(src)}: {status}")
                        return False
            else:
                # For fromjson: validate uexp file header
                uexp_path = dst[:-7] + '.uexp'  # .uasset -> .uexp
                if os.path.exists(uexp_path):
                    if not validate_uexp(uexp_path, signatures):
                        if attempt < max_retries:
                            with print_lock:
                                print(f"[{i}/{total}] RETRY {attempt}/{max_retries} {os.path.basename(src)}: Corrupt uexp header, regenerating...")
                            # Remove bad files before retry
                            if os.path.exists(dst):
                                os.remove(dst)
                            if os.path.exists(uexp_path):
                                os.remove(uexp_path)
                            time.sleep(retry_delay)
                            continue
                        else:
                            with print_lock:
                                header_hex = 'N/A'
                                try:
                                    with open(uexp_path, 'rb') as f:
                                        header_hex = f.read(2).hex()
                                except Exception:
                                    pass
                                print(f"[{i}/{total}] FAIL {os.path.basename(src)}: Invalid uexp header: {header_hex}")
                            return False
                elif not os.path.exists(dst):
                    if attempt < max_retries:
                        with print_lock:
                            print(f"[{i}/{total}] RETRY {attempt}/{max_retries} {os.path.basename(src)}: Output file not created")
                        time.sleep(retry_delay)
                        continue
                    else:
                        with print_lock:
                            print(f"[{i}/{total}] FAIL {os.path.basename(src)}: Output file not created")
                        return False

            # Success!
            with print_lock:
                retry_info = f" (after {attempt} attempt(s))" if attempt > 1 else ""
                print(f"[{i}/{total}] OK   {os.path.basename(src)}{retry_info}")
                if verbose:
                    print(f"  CMD: {' '.join(cmd)}")
            return True

        except subprocess.TimeoutExpired:
            if attempt < max_retries:
                with print_lock:
                    print(f"[{i}/{total}] RETRY {attempt}/{max_retries} {os.path.basename(src)}: Timeout")
                time.sleep(retry_delay)
                continue
            else:
                with print_lock:
                    print(f"[{i}/{total}] FAIL {os.path.basename(src)}: Timeout after {max_retries} attempts")
                return False
        except Exception as e:
            if attempt < max_retries:
                with print_lock:
                    print(f"[{i}/{total}] RETRY {attempt}/{max_retries} {os.path.basename(src)}: {e}")
                time.sleep(retry_delay)
                continue
            else:
                with print_lock:
                    print(f"[{i}/{total}] FAIL {os.path.basename(src)}: {e}")
                return False

    return False


# ─────────────────────────────────────────────
# Post-conversion validation
# ─────────────────────────────────────────────

def validate_outputs(dst_paths: set, mode: str, signatures: list, json_signatures: list) -> tuple:
    """
    Validate only the specific output files processed in this run.
    Returns (valid_count, corrupt_count).
    """
    corrupt_count = 0
    valid_count = 0

    if mode == "fromjson":
        for uasset_path in dst_paths:
            uexp_path = uasset_path[:-7] + '.uexp'
            if not os.path.exists(uexp_path):
                continue  # no uexp to validate
            if validate_uexp(uexp_path, signatures):
                valid_count += 1
            else:
                corrupt_count += 1
                try:
                    with open(uexp_path, 'rb') as f:
                        header = f.read(2).hex()
                except Exception:
                    header = 'ERROR'
                print(f"  [CORRUPT] {uexp_path} (header: {header})")
    elif mode == "tojson":
        for json_path in dst_paths:
            if validate_json(json_path, json_signatures):
                valid_count += 1
            else:
                corrupt_count += 1
                file_size = os.path.getsize(json_path) if os.path.exists(json_path) else 0
                print(f"  [CORRUPT] {json_path} (missing any of {json_signatures}, size: {file_size} bytes)")

    return valid_count, corrupt_count


# ─────────────────────────────────────────────
# Main convert logic
# ─────────────────────────────────────────────

def cmd_convert(args):
    uassetgui = args.uassetgui

    ensure_portable(uassetgui, args.verbose)

    mappings_name = None
    if args.usmap:
        if not os.path.exists(args.usmap):
            print(f"[ERROR] usmap not found: {args.usmap}")
            return
        mappings_name = setup_mappings(uassetgui, args.usmap, args.verbose)
        print(f"[mappings] Using: {mappings_name}")

    mode = args.direction

    # Build runtime config from args
    cfg = {
        'max_retries':    args.max_retries,
        'retry_delay':    args.retry_delay,
        'signatures':     args.uexp_signature,
        'json_signatures': args.json_signature,
    }

    if mode == "tojson":
        pattern = os.path.join(args.input, "**", "*.uasset")
        src_ext, dst_ext = ".uasset", ".json"
    else:
        pattern = os.path.join(args.input, "**", "*.json")
        src_ext, dst_ext = ".json", ".uasset"

    files = sorted(glob.glob(pattern, recursive=True))
    if not files:
        print(f"No {src_ext} files found in: {args.input}")
        return

    # Apply exclusion patterns
    if args.exclude:
        original_count = len(files)
        files = [f for f in files if not matches_exclude_patterns(f, args.exclude, args.input)]
        excluded_count = original_count - len(files)
        if args.verbose or excluded_count > 0:
            print(f"Excluded {excluded_count} file(s) matching patterns: {', '.join(args.exclude)}")
            if args.verbose:
                for f in [f for f in sorted(glob.glob(pattern, recursive=True)) if matches_exclude_patterns(f, args.exclude, args.input)]:
                    print(f"  EXCLUDED: {os.path.relpath(f, args.input)}")

    if not files:
        print(f"No {src_ext} files found after applying exclusion patterns")
        return

    total = len(files)
    print_lock = threading.Lock()

    print(f"Found {total} {src_ext} files | Output: {args.output} | Workers: {args.workers}")
    if args.skip_existing:
        print(f"Skip existing: ON (existing valid destination files will be skipped)")
    if args.exclude:
        print(f"Exclude patterns: {', '.join(args.exclude)}")
    if mode == "fromjson":
        sigs_hex = [s.hex() for s in cfg['signatures']]
        print(f"Validation: uexp header check {sigs_hex} | Max retries: {cfg['max_retries']}")
    else:
        print(f"Validation: JSON signatures {cfg['json_signatures']} (full file scan) | Max retries: {cfg['max_retries']}")
    print("-" * 60)

    tasks = []
    processed_dst_paths = set()  # only files actually being converted this run
    for i, src in enumerate(files, 1):
        rel = os.path.relpath(src, args.input)
        dst = os.path.join(args.output, rel[:-len(src_ext)] + dst_ext)

        # Only include in validation set if not going to be skipped
        skip_mode = mode  # same string works for should_skip_existing
        if not (args.skip_existing and should_skip_existing(dst, skip_mode, cfg)):
            processed_dst_paths.add(dst)

        if mode == "tojson":
            cmd = [uassetgui, "tojson", src, dst, args.version]
            if mappings_name:
                cmd.append(mappings_name)
        else:
            cmd = [uassetgui, "fromjson", src, dst]
            if mappings_name:
                cmd.append(mappings_name)

        tasks.append((i, total, src, dst, cmd, args.verbose, print_lock, args.skip_existing, cfg))

    success = failed = 0
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {executor.submit(convert_one, t): t for t in tasks}
        for future in as_completed(futures):
            if future.result():
                success += 1
            else:
                failed += 1

    print("-" * 60)
    skipped = total - len(processed_dst_paths)
    if args.skip_existing and skipped > 0:
        print(f"Done! Success: {success} | Failed: {failed} | Skipped: {skipped}")
    else:
        print(f"Done! Success: {success} | Failed: {failed}")

    # Post-conversion validation — only newly written files
    print("\nRunning post-conversion validation...")
    if not processed_dst_paths:
        print("Nothing to validate (all files were skipped)")
    else:
        valid, corrupt = validate_outputs(processed_dst_paths, mode, cfg['signatures'], cfg['json_signatures'])
        if corrupt > 0:
            if mode == "tojson":
                print(f"WARNING: Found {corrupt} file(s) missing any of {cfg['json_signatures']} in output. Consider re-running with --workers 1")
            else:
                print(f"WARNING: Found {corrupt} corrupt file(s) in output. Consider re-running with --workers 1")
        else:
            print(f"OK: All {valid} file(s) validated successfully")


# ─────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Batch convert uasset <-> UAssetAPI JSON using UAssetGUI")
    parser.add_argument("direction", choices=["tojson", "fromjson"])
    parser.add_argument("input", help="Input folder")
    parser.add_argument("output", help="Output folder")
    parser.add_argument("--uassetgui", "-u", default="UAssetGUI.exe", help="Path to UAssetGUI.exe")
    parser.add_argument("--version", "-v", default="VER_UE5_5", help="Engine version for tojson (default: VER_UE5_5)")
    parser.add_argument("--usmap", "-m", default=None, help="Path to .usmap mappings file")
    parser.add_argument("--workers", "-w", type=int, default=4, help="Number of parallel workers (default: 4)")
    parser.add_argument("--skip-existing", action="store_true", help="Skip conversion if destination file exists and is non-zero size")
    parser.add_argument("--exclude", "-e", action="append", default=None,
                        help="Exclude files matching pattern (gitignore-style glob). Can be used multiple times. "
                             "Examples: --exclude '**/Temp/**' --exclude '*.backup' --exclude '!important.*'")
    parser.add_argument("--verbose", action="store_true")

    parser.add_argument(
        "--uexp-signature", dest="uexp_signature", action="append",
        metavar="HEX",
        help="Valid uexp header (first 2 bytes) as hex, e.g. 0d02. "
             "Can be specified multiple times (any match = valid). "
             f"Default: {DEFAULT_UEXP_SIGNATURES[0].hex()}",
    )
    parser.add_argument(
        "--json-signature", dest="json_signature", action="append",
        metavar="STR",
        help="String that must appear in converted JSON to be considered valid. "
             "Can be specified multiple times (any match = valid). "
             f"Default: {DEFAULT_JSON_SIGNATURES[0]!r}",
    )
    parser.add_argument(
        "--max-retries", dest="max_retries", type=int,
        default=DEFAULT_MAX_RETRIES,
        help=f"Max conversion attempts per file (default: {DEFAULT_MAX_RETRIES})",
    )
    parser.add_argument(
        "--retry-delay", dest="retry_delay", type=float,
        default=DEFAULT_RETRY_DELAY,
        help=f"Seconds between retries (default: {DEFAULT_RETRY_DELAY})",
    )
    parser.set_defaults(func=cmd_convert)

    args = parser.parse_args()

    # Validate exclusion patterns
    if args.exclude:
        for i, pattern in enumerate(args.exclude):
            if not pattern.strip():
                print(f"[WARNING] Empty exclusion pattern at position {i}, ignoring")
                args.exclude[i] = None
        args.exclude = [p for p in args.exclude if p is not None]

    # Normalise --uexp-signature: hex strings -> bytes list
    if args.uexp_signature:
        parsed = []
        for h in args.uexp_signature:
            h = h.replace('0x', '').replace('0X', '').replace(' ', '')
            try:
                parsed.append(bytes.fromhex(h))
            except ValueError:
                parser.error(f"--uexp-signature: invalid hex value '{h}'")
        args.uexp_signature = parsed
    else:
        args.uexp_signature = list(DEFAULT_UEXP_SIGNATURES)

    # Normalise --json-signature: apply default if not specified
    if not args.json_signature:
        args.json_signature = list(DEFAULT_JSON_SIGNATURES)

    args.func(args)


if __name__ == "__main__":
    main()
