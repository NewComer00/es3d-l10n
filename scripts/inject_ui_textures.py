"""Inject translated DDS into stock UE 5.5 uassets via UE4-DDS-Tools.

Reads mods/ui/zh_cn/textures/manifest.json, injects each DDS into the matching
stock .uasset from build/ui/extracted/, and writes .uasset/.uexp/.ubulk into
mods/ui/zh_cn/assets/ (overlayed at strip time).
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def load_manifest(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit(f"manifest must be a JSON array: {path}")
    return data


def require_dds(path: Path, *, name: str) -> None:
    """Fail fast if path is missing, an unsmudged Git LFS pointer, or not a DDS."""
    if not path.is_file():
        raise SystemExit(
            f"DDS missing for {name}: {path}\n"
            f"Run: git lfs pull\n"
            f"(see mods/ui/README.md)."
        )
    head = path.read_bytes()[:64]
    if head.startswith(b"version https://git-lfs.github.com/spec/v1"):
        raise SystemExit(
            f"DDS for {name} is still a Git LFS pointer (not smudged): {path}\n"
            f"Run: git lfs install && git lfs pull\n"
            f"(see mods/ui/README.md)."
        )
    if not head.startswith(b"DDS "):
        raise SystemExit(
            f"Not a DDS file for {name}: {path} "
            f"(expected magic 'DDS ', got {head[:16]!r})"
        )


def ensure_stock(
    *,
    game_uasset: str,
    extracted: Path,
    repak: Path,
    aes_key: str,
    game_pak: Path,
) -> Path:
    stock = extracted / Path(game_uasset)
    if stock.is_file():
        return stock
    include = game_uasset.replace("\\", "/")
    if not include.lower().endswith(".uasset"):
        include = include + ".uasset"
    stem = include[: -len(".uasset")]
    print(f"[inject-textures] stock missing — unpacking {stem}.{{uasset,uexp,ubulk}}")
    extracted.mkdir(parents=True, exist_ok=True)
    includes = [f"{stem}.uasset", f"{stem}.uexp", f"{stem}.ubulk"]
    cmd = [
        str(repak),
        "--aes-key",
        aes_key,
        "unpack",
        "--output",
        str(extracted),
    ]
    for inc in includes:
        cmd.extend(["--include", inc])
    cmd.append(str(game_pak))
    subprocess.run(cmd, check=True)
    if not stock.is_file():
        raise SystemExit(f"stock uasset still missing after unpack: {stock}")
    return stock


def inject_one(
    *,
    stock: Path,
    dds: Path,
    out_dir: Path,
    tool_root: Path,
    python_cmd: list[str],
    main_py: Path,
    ue_version: str,
) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    # Clear previous outputs for this asset name.
    for old in out_dir.glob(stock.stem + ".*"):
        old.unlink()
    cmd = [
        *python_cmd,
        str(main_py),
        str(stock),
        str(dds),
        "--mode",
        "inject",
        "--version",
        ue_version,
        "--save_folder",
        str(out_dir),
        "--max_workers",
        "1",
    ]
    print(f"[inject-textures] {stock.name} <- {dds.name}")
    subprocess.run(cmd, check=True, cwd=str(tool_root))
    written = sorted(out_dir.glob(stock.stem + ".*"))
    if not written:
        raise SystemExit(f"inject produced no files in {out_dir}")
    return written


def resolve_python_cmd(python: Path | None, uv: Path | None) -> list[str]:
    if python is not None and python.is_file():
        return [str(python), "-E"]
    if uv is not None and uv.is_file():
        return [str(uv), "run", "python"]
    # Last resort: current interpreter
    return [sys.executable]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", type=Path, required=True)
    ap.add_argument("--textures-dir", type=Path, required=True)
    ap.add_argument("--extracted", type=Path, required=True)
    ap.add_argument("--assets", type=Path, required=True)
    ap.add_argument("--tool-root", type=Path, required=True)
    ap.add_argument("--python", type=Path, default=None, help="Embedded UE4-DDS-Tools python.exe")
    ap.add_argument("--uv", type=Path, default=None, help="uv.exe fallback to run python")
    ap.add_argument("--main", type=Path, required=True)
    ap.add_argument("--ue-version", default="5.5")
    ap.add_argument("--repak", type=Path, required=True)
    ap.add_argument("--aes-key", required=True)
    ap.add_argument("--game-pak", type=Path, required=True)
    ap.add_argument(
        "--force",
        action="store_true",
        help="re-inject even if overlay assets already exist",
    )
    args = ap.parse_args()

    if not args.main.is_file():
        raise SystemExit(f"UE4-DDS-Tools main.py not found: {args.main}")
    python_cmd = resolve_python_cmd(args.python, args.uv)
    print(f"[inject-textures] python: {' '.join(python_cmd)}")

    entries = load_manifest(args.manifest)
    if not entries:
        print("[inject-textures] empty manifest — nothing to do")
        return 0

    done = 0
    skipped = 0
    with tempfile.TemporaryDirectory(prefix="es3d-dds-inject-") as tmp:
        tmp_path = Path(tmp)
        for entry in entries:
            name = entry["name"]
            dds = args.textures_dir / entry["dds"]
            game_uasset = entry["game_uasset"].replace("\\", "/")
            dest_uasset = args.assets / Path(game_uasset)
            if dest_uasset.is_file() and not args.force:
                print(f"[inject-textures] cached: {dest_uasset}")
                skipped += 1
                continue
            require_dds(dds, name=name)
            stock = ensure_stock(
                game_uasset=game_uasset,
                extracted=args.extracted,
                repak=args.repak,
                aes_key=args.aes_key,
                game_pak=args.game_pak,
            )
            out_dir = tmp_path / name
            written = inject_one(
                stock=stock,
                dds=dds,
                out_dir=out_dir,
                tool_root=args.tool_root,
                python_cmd=python_cmd,
                main_py=args.main,
                ue_version=args.ue_version,
            )
            dest_dir = dest_uasset.parent
            dest_dir.mkdir(parents=True, exist_ok=True)
            for src in written:
                dest = dest_dir / src.name
                shutil.copy2(src, dest)
                print(f"[inject-textures] wrote {dest} ({dest.stat().st_size})")
            done += 1

    print(f"[inject-textures] done: injected={done} cached={skipped}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
